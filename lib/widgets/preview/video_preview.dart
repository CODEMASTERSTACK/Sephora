import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/editor_provider.dart';
import '../../services/ffmpeg_service.dart';

class VideoPreview extends ConsumerStatefulWidget {
  const VideoPreview({super.key});

  @override
  ConsumerState<VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends ConsumerState<VideoPreview> {
  VideoPlayerController? _controller;
  String? _currentLoadedPath;
  bool _isLoading = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _loadVideo(String path) async {
    if (_currentLoadedPath == path || _isLoading) return;
    _isLoading = true;
    _currentLoadedPath = path;

    final oldController = _controller;
    final ctrl = VideoPlayerController.file(File(path));
    await ctrl.initialize();

    ctrl.addListener(() {
      if (!mounted) return;
      if (ctrl.value.isPlaying) {
        ref.read(editorProvider.notifier).updatePlayhead(ctrl.value.position);
      }
      if (ctrl.value.position >= ctrl.value.duration &&
          ctrl.value.duration > Duration.zero &&
          ctrl.value.isInitialized) {
        if (ref.read(editorProvider).isPlaying) {
          ref.read(editorProvider.notifier).togglePlay();
          ref.read(editorProvider.notifier).updatePlayhead(Duration.zero);
        }
      }
    });

    if (mounted) {
      setState(() {
        _controller = ctrl;
        _isLoading = false;
      });
    }

    oldController?.dispose();
  }

  /// Returns the effective volume after applying track mute/solo rules
  double _effectiveVolume(Clip clip, EditorState state) {
    final track = state.tracks.firstWhere(
      (t) => t.index == clip.trackIndex,
      orElse: () => state.tracks[0],
    );
    if (track.isMuted) return 0.0;

    // If any track has solo, only play clips on soloed tracks
    final hasSolo = state.tracks.any((t) => t.isSolo);
    if (hasSolo && !track.isSolo) return 0.0;

    return clip.volume;
  }

  Clip? _pickActiveClip(EditorState state) {
    if (state.selectedClipId != null) {
      final c = state.clipById(state.selectedClipId!);
      if (c != null && c.type == 'video') return c;
    }
    try {
      return state.videoClips.firstWhere(
          (c) => c.type == 'video' && c.trackIndex == 0);
    } catch (_) {
      return state.videoClips.where((c) => c.type == 'video').firstOrNull;
    }
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(editorProvider);
    final activeClip = _pickActiveClip(editorState);

    if (activeClip != null) {
      final displayPath = activeClip.proxyPath ?? activeClip.path;
      _loadVideo(displayPath);

      if (_controller != null && _controller!.value.isInitialized) {
        // Apply mute/solo-aware volume
        _controller!.setVolume(_effectiveVolume(activeClip, editorState));
        _controller!.setPlaybackSpeed(activeClip.speed.clamp(0.25, 4.0));
      }

      // Auto-generate proxy in background
      if (activeClip.proxyPath == null &&
          !activeClip.isGeneratingProxy &&
          activeClip.type == 'video') {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          ref.read(editorProvider.notifier).setProxyGenerating(activeClip.id, true);
          final proxyPath = await FFmpegService.generateProxy(
              activeClip.path, activeClip.id);
          if (!mounted) return;
          if (proxyPath != null) {
            ref.read(editorProvider.notifier).setProxyPath(activeClip.id, proxyPath);
          } else {
            ref.read(editorProvider.notifier).setProxyGenerating(activeClip.id, false);
          }
        });
      }
    }

    ref.listen<EditorState>(editorProvider, (previous, next) {
      final ctrl = _controller;
      if (ctrl == null || !ctrl.value.isInitialized) return;

      // Play / Pause state changed
      if (previous?.isPlaying != next.isPlaying) {
        if (next.isPlaying) {
          ctrl.play();
        } else {
          ctrl.pause();
        }
      }

      // Playhead scrubbed manually — always seek (playing or not)
      if (previous?.playheadPosition != next.playheadPosition) {
        final diff = (ctrl.value.position - next.playheadPosition).abs();
        // Only seek if significantly out of sync (avoid infinite loop while playing)
        if (!next.isPlaying || diff.inMilliseconds > 300) {
          ctrl.seekTo(next.playheadPosition);
        }
      }

      // Track mute/solo changed — re-apply volume
      if (previous?.tracks != next.tracks) {
        final clip = _pickActiveClip(next);
        if (clip != null) {
          ctrl.setVolume(_effectiveVolume(clip, next));
        }
      }
    });

    return Container(
      decoration: const BoxDecoration(color: Colors.black),
      child: ClipRect(
        child: _buildContent(editorState, activeClip),
      ),
    );
  }

  Widget _buildContent(EditorState state, Clip? clip) {
    if (clip == null) return _buildEmptyState();
    if (_isLoading || _controller == null || !_controller!.value.isInitialized) {
      return _buildLoadingState(clip);
    }

    final grade = clip.colorGrade;
    final hasColorGrade = grade.contrast != 0 ||
        grade.highlights != 0 ||
        grade.shadows != 0 ||
        grade.temperature != 0 ||
        grade.tint != 0 ||
        grade.saturation.any((s) => s != 0);

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Video with color grade applied DIRECTLY ──────────────────────
        Center(
          child: AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: hasColorGrade
                ? ColorFiltered(
                    colorFilter: ColorFilter.matrix(_buildColorMatrix(grade)),
                    child: VideoPlayer(_controller!),
                  )
                : VideoPlayer(_controller!),
          ),
        ),

        // ── Opacity overlay (blend mode approximation) ───────────────────
        if (clip.opacity < 1.0)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                  color: Colors.black.withValues(alpha: 1.0 - clip.opacity)),
            ),
          ),

        // ── Blend mode tint overlay (visual approximation) ───────────────
        if (clip.blendMode != 'normal')
          Positioned.fill(
            child: IgnorePointer(
              child: _buildBlendOverlay(clip.blendMode),
            ),
          ),

        // ── Proxy status badge ───────────────────────────────────────────
        if (clip.isGeneratingProxy)
          Positioned(
            top: 8, right: 8,
            child: _badge('Building Proxy…', Colors.amberAccent,
                showSpinner: true),
          )
        else if (clip.proxyPath != null)
          Positioned(
            top: 8, right: 8,
            child: _badge('PROXY', Colors.green),
          ),

        // ── Track muted indicator ────────────────────────────────────────
        if (_isTrackMuted(clip, state))
          Positioned(
            top: 8, left: 8,
            child: _badge('🔇 MUTED', Colors.redAccent),
          ),

        // ── Play button (when paused) ────────────────────────────────────
        if (!state.isPlaying)
          Center(
            child: GestureDetector(
              onTap: () => ref.read(editorProvider.notifier).togglePlay(),
              child: Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow,
                    color: Colors.white, size: 38),
              ),
            ),
          ),

        // ── Tap to pause ─────────────────────────────────────────────────
        if (state.isPlaying)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => ref.read(editorProvider.notifier).togglePlay(),
              child: Container(color: Colors.transparent),
            ),
          ),

        // ── Progress scrub bar ───────────────────────────────────────────
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: VideoProgressIndicator(
            _controller!,
            allowScrubbing: true,
            padding: EdgeInsets.zero,
            colors: const VideoProgressColors(
              playedColor: Colors.pinkAccent,
              backgroundColor: Colors.white12,
              bufferedColor: Colors.white24,
            ),
          ),
        ),
      ],
    );
  }

  bool _isTrackMuted(Clip clip, EditorState state) {
    final track = state.tracks.firstWhere(
      (t) => t.index == clip.trackIndex,
      orElse: () => const VideoTrack(index: 0, label: 'V1'),
    );
    if (track.isMuted) return true;
    final hasSolo = state.tracks.any((t) => t.isSolo);
    return hasSolo && !track.isSolo;
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.movie_outlined, color: Colors.white24, size: 52),
          SizedBox(height: 12),
          Text('Import video from the timeline below',
              style: TextStyle(color: Colors.white24, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildLoadingState(Clip clip) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
              color: Colors.pinkAccent, strokeWidth: 2),
          const SizedBox(height: 12),
          Text(clip.id.split('_').first,
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color, {bool showSpinner = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSpinner) ...[
            SizedBox(
              width: 10, height: 10,
              child: CircularProgressIndicator(
                  strokeWidth: 1.5, color: color),
            ),
            const SizedBox(width: 6),
          ],
          Text(text,
              style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  /// Approximates blend mode with a semi-transparent tint overlay
  Widget _buildBlendOverlay(String mode) {
    switch (mode) {
      case 'multiply':
        return Container(
          color: Colors.black.withValues(alpha: 0.35),
        );
      case 'screen':
        return Container(
          color: Colors.white.withValues(alpha: 0.2),
        );
      case 'overlay':
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0x22FFFFFF),
                Color(0x22000000),
              ],
            ),
          ),
        );
      case 'darken':
        return Container(color: Colors.black.withValues(alpha: 0.25));
      case 'lighten':
        return Container(color: Colors.white.withValues(alpha: 0.15));
      case 'difference':
        return Container(
          color: Colors.deepPurple.withValues(alpha: 0.2),
        );
      case 'exclusion':
        return Container(color: Colors.teal.withValues(alpha: 0.15));
      default:
        return const SizedBox.shrink();
    }
  }

  /// Proper 5×4 RGBA color matrix with contrast, brightness, temperature
  List<double> _buildColorMatrix(ColorGrade grade) {
    // Contrast: 1.0 = normal, >1 = more contrast, <1 = less
    final c = 1.0 + grade.contrast / 100.0;
    // Brightness offset from highlights/shadows
    final bright = (grade.highlights - grade.shadows) / 500.0;
    // Contrast translate to keep midpoint at 0.5
    final t = 0.5 * (1.0 - c) + bright;
    // Temperature: positive = warm (more red, less blue), negative = cool
    final temp = grade.temperature / 200.0;
    // Tint: positive = green, negative = magenta
    final tint = grade.tint / 200.0;
    // Saturation average (simplified)
    final satAdj = grade.saturation.reduce((a, b) => a + b) / 7.0 / 100.0;
    final sat = 1.0 + satAdj;
    // Desaturate then re-saturate
    // Luminance weights
    const lr = 0.2126;
    const lg = 0.7152;
    const lb = 0.0722;
    final sr = (1.0 - sat) * lr;
    final sg = (1.0 - sat) * lg;
    final sb = (1.0 - sat) * lb;

    return [
      (sr + sat) * c + temp, sg * c,           sb * c,           0, t,
      sr * c,           (sg + sat) * c + tint,  sb * c,           0, t,
      sr * c,           sg * c,           (sb + sat) * c - temp, 0, t,
      0,                0,                0,                1, 0,
    ];
  }
}
