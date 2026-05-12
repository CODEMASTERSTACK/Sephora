import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/editor_provider.dart';
import '../../services/ffmpeg_service.dart';

class AudioPreview extends ConsumerStatefulWidget {
  const AudioPreview({super.key});

  @override
  ConsumerState<AudioPreview> createState() => _AudioPreviewState();
}

class _AudioPreviewState extends ConsumerState<AudioPreview>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayerReady = false;
  String? _currentPath;

  bool _isGeneratingProxy = false;
  // Stores the DSP-relevant snapshot so we know when to re-render
  String _lastDspSignature = '';
  String? _proxyPath;

  late final AnimationController _bgAnimController;

  @override
  void initState() {
    super.initState();
    _bgAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();

    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted && _isPlayerReady && ref.read(audioEditorProvider).isPlaying) {
        ref.read(audioEditorProvider.notifier).updatePlayhead(position);
      }
    });

    // Stop playback when audio completes
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted && ref.read(audioEditorProvider).isPlaying) {
        ref.read(audioEditorProvider.notifier).togglePlay();
        ref.read(audioEditorProvider.notifier).updatePlayhead(Duration.zero);
      }
    });
  }

  @override
  void dispose() {
    _bgAnimController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadAudio(String path) async {
    if (_currentPath == path) return;
    _currentPath = path;
    _isPlayerReady = false;

    try {
      await _audioPlayer.setSourceDeviceFile(path);
      _isPlayerReady = true;
    } catch (e) {
      debugPrint('AudioPlayer load error: $e');
      _isPlayerReady = false;
    }

    if (mounted) setState(() {});
  }

  /// Build a unique signature from DSP-affecting parameters.
  /// When this changes, we need to regenerate the FFmpeg preview.
  String _dspSignature(Clip clip) {
    return '${clip.id}'
        '|eq:${clip.eqBands.join(',')}'
        '|comp:${clip.isCompressed}'
        '|pitch:${clip.pitchShift}'
        '|tempo:${clip.tempo}'
        '|3d:${clip.spatial3dEnabled}'
        '|3dRot:${clip.spatial3dRotation}'
        '|3dW:${clip.spatial3dWidth}'
        '|3dD:${clip.spatial3dDepth}'
        '|3dE:${clip.spatial3dElevation}';
  }

  /// Pick the active audio clip — selected clip first, else first in list.
  Clip? _pickActiveClip(EditorState state) {
    if (state.selectedClipId != null) {
      final c = state.clipById(state.selectedClipId!);
      if (c != null && c.type == 'audio') return c;
    }
    return state.audioClips.firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(audioEditorProvider);
    final activeClip = _pickActiveClip(editorState);

    if (activeClip != null) {
      final sig = _dspSignature(activeClip);

      // Check if we need to regenerate the DSP proxy
      if (sig != _lastDspSignature && !_isGeneratingProxy) {
        _lastDspSignature = sig;

        // Check if there are DSP effects that need rendering
        final hasDspEffects = activeClip.eqBands.any((v) => v != 0.0) ||
            activeClip.isCompressed ||
            activeClip.pitchShift != 0.0 ||
            activeClip.tempo != 1.0 ||
            activeClip.spatial3dEnabled;

        if (hasDspEffects) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _isGeneratingProxy = true);
            FFmpegService.generateAudioPreview(activeClip).then((path) {
              if (!mounted) return;
              setState(() => _isGeneratingProxy = false);
              if (path != null) {
                _proxyPath = path;
                _currentPath = null; // force reload
                _loadAudio(path).then((_) {
                  if (mounted && ref.read(audioEditorProvider).isPlaying) {
                    _audioPlayer.resume();
                  }
                });
              }
            });
          });
        } else {
          // No DSP effects — play original file directly
          _proxyPath = null;
          _currentPath = null; // force reload
          _loadAudio(activeClip.path);
        }
      } else if (!_isGeneratingProxy) {
        // No DSP change — just make sure audio is loaded
        _loadAudio(_proxyPath ?? activeClip.path);
      }

      // Apply real-time parameters (no FFmpeg needed)
      if (_isPlayerReady) {
        // Apply volume
        _audioPlayer.setVolume(activeClip.volume);
        // Apply tempo as playback rate
        // (pitch is handled by FFmpeg, tempo also uses FFmpeg for 
        //  pitch-independent time-stretching, but we use playbackRate 
        //  as a secondary speed control via the Speed slider)
        _audioPlayer.setPlaybackRate(activeClip.speed);
      }
    }

    // Listen for state changes
    ref.listen<EditorState>(audioEditorProvider, (previous, next) {
      if (!_isPlayerReady) return;

      // Play/Pause
      if (previous?.isPlaying != next.isPlaying) {
        if (next.isPlaying) {
          _audioPlayer.resume();
        } else {
          _audioPlayer.pause();
        }
      }

      // Seek when playhead is scrubbed (not during playback)
      if (!next.isPlaying &&
          previous != null &&
          previous.playheadPosition != next.playheadPosition) {
        _audioPlayer.seek(next.playheadPosition);
      }
    });

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Animated Abstract Background
          AnimatedBuilder(
            animation: _bgAnimController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: const [
                      Color(0xFF2A0845),
                      Color(0xFF6441A5),
                      Color(0xFF1F1C2C),
                    ],
                    stops: [
                      0.0,
                      0.5 + 0.3 * sin(_bgAnimController.value * 2 * pi),
                      1.0,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    transform: GradientRotation(
                        _bgAnimController.value * 2 * pi),
                  ),
                ),
              );
            },
          ),

          // Glassmorphism Blur
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: Colors.black.withValues(alpha: 0.2),
            ),
          ),

          // Content
          _isGeneratingProxy
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.pinkAccent),
                    SizedBox(height: 16),
                    Text('Rendering DSP Effects...',
                        style: TextStyle(color: Colors.white70)),
                  ],
                )
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    // Audio wave icon
                    Icon(
                      Icons.multitrack_audio,
                      size: 96,
                      color: Colors.white.withValues(alpha: 0.15),
                    ),

                    // Volume indicator
                    if (activeClip != null)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                activeClip.volume == 0
                                    ? Icons.volume_off
                                    : Icons.volume_up,
                                color: Colors.white54,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${(activeClip.volume * 100).toInt()}%',
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // DSP badge
                    if (activeClip != null &&
                        (activeClip.pitchShift != 0 ||
                            activeClip.tempo != 1.0 ||
                            activeClip.isCompressed ||
                            activeClip.eqBands.any((v) => v != 0)))
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('DSP ACTIVE',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),

                    // Play/Pause Button
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: _isPlayerReady
                          ? IconButton(
                              key: ValueKey(editorState.isPlaying),
                              icon: Icon(
                                editorState.isPlaying
                                    ? Icons.pause_circle_filled
                                    : Icons.play_circle_fill,
                                size: 72,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                              onPressed: () {
                                ref
                                    .read(audioEditorProvider.notifier)
                                    .togglePlay();
                              },
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
        ],
      ),
    );
  }
}
