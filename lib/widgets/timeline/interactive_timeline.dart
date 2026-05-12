import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/editor_provider.dart';
import '../../services/ffmpeg_service.dart';

class InteractiveTimeline extends ConsumerStatefulWidget {
  final bool isAudioOnly;

  const InteractiveTimeline({
    super.key,
    this.isAudioOnly = false,
  });

  @override
  ConsumerState<InteractiveTimeline> createState() => _InteractiveTimelineState();
}

class _InteractiveTimelineState extends ConsumerState<InteractiveTimeline> {
  final ScrollController _hScroll = ScrollController();
  final ScrollController _vScroll = ScrollController();
  double _pixelsPerMs = 0.12;
  static const double _trackHeaderWidth = 72.0;
  static const double _trackHeight = 64.0;
  static const double _minPxPerMs = 0.02;
  static const double _maxPxPerMs = 2.0;

  // Drag state
  Duration? _snapIndicatorMs;
  // Track vertical drag delta per clip (clipId -> cumulative Y pixels)
  final Map<String, double> _clipDragYAccum = {};

  /// Returns the correct provider based on whether this is an audio-only timeline
  NotifierProvider<EditorNotifier, EditorState> get _provider =>
      widget.isAudioOnly ? audioEditorProvider : editorProvider;

  @override
  void initState() {
    super.initState();
    _hScroll.addListener(_onHScroll);
  }

  @override
  void dispose() {
    _hScroll.dispose();
    _vScroll.dispose();
    super.dispose();
  }

  void _onHScroll() {
    if (!mounted) return;
    final state = ref.read(_provider);
    if (!state.isPlaying) {
      final ms = _hScroll.offset / _pixelsPerMs;
      ref.read(_provider.notifier).updatePlayhead(
        Duration(milliseconds: ms.toInt().clamp(0, 999999)),
      );
    }
  }

  // Auto-scroll playhead into view during playback
  void _syncPlayhead(Duration position) {
    if (!_hScroll.hasClients) return;
    final target = position.inMilliseconds * _pixelsPerMs;
    final viewportCenter = _hScroll.position.viewportDimension / 2;
    final scrollTo = (target - viewportCenter).clamp(
      0.0, _hScroll.position.maxScrollExtent,
    );
    if ((scrollTo - _hScroll.offset).abs() > 20) {
      _hScroll.jumpTo(scrollTo);
    }
  }

  Future<void> _importToTrack(int trackIndex) async {
    final isAudio = trackIndex >= 6 || widget.isAudioOnly;
    final result = await FilePicker.pickFiles(
      type: isAudio ? FileType.audio : FileType.custom,
      allowedExtensions: isAudio
          ? null
          : ['mp4', 'mov', 'avi', 'mkv', 'mp3', 'wav', 'aac', 'png', 'jpg'],
    );
    if (result == null || result.files.single.path == null) return;

    final file = result.files.single;
    final state = ref.read(_provider);
    final clipsOnTrack = state.clipsOnTrack(trackIndex);
    final startMs = clipsOnTrack.isNotEmpty
        ? clipsOnTrack.last.start.inMilliseconds + clipsOnTrack.last.activeDuration.inMilliseconds
        : 0;

    final clip = Clip(
      id: '${file.name}_${DateTime.now().millisecondsSinceEpoch}',
      path: file.path!,
      type: isAudio ? 'audio' : 'video',
      trackIndex: trackIndex,
      start: Duration(milliseconds: startMs),
      duration: const Duration(seconds: 30),
    );

    ref.read(_provider.notifier).addClipToTrack(clip, trackIndex);

    // Auto-generate proxy for video clips in background
    if (!isAudio) {
      final addedClipId = clip.id;
      ref.read(_provider.notifier).setProxyGenerating(addedClipId, true);
      FFmpegService.generateProxy(file.path!, addedClipId).then((proxyPath) {
        if (!mounted) return;
        if (proxyPath != null) {
          ref.read(_provider.notifier).setProxyPath(addedClipId, proxyPath);
        } else {
          ref.read(_provider.notifier).setProxyGenerating(addedClipId, false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_provider);

    // Sync playhead scroll during playback
    ref.listen<EditorState>(_provider, (prev, next) {
      if (next.isPlaying) _syncPlayhead(next.playheadPosition);
    });

    final tracks = widget.isAudioOnly
        ? state.tracks.where((t) => t.index >= 6).toList()
        : state.tracks;

    final totalDurationMs = _computeTotalDuration(state);
    final timelineWidth = (totalDurationMs * _pixelsPerMs) + 600;

    return GestureDetector(
      onScaleUpdate: (d) {
        if (d.pointerCount < 2) return;
        setState(() {
          _pixelsPerMs = (_pixelsPerMs * d.scale).clamp(_minPxPerMs, _maxPxPerMs);
        });
      },
      // Only clear selection if tap is not on a clip (clips stop propagation)
      onTap: () => ref.read(_provider.notifier).clearSelection(),
      child: Column(
        children: [
          _buildSnapBar(state),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Track headers (fixed left column)
                _buildTrackHeaders(tracks, state),

                // Scrollable track content
                Expanded(
                  child: Stack(
                    children: [
                      SingleChildScrollView(
                        controller: _vScroll,
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          controller: _hScroll,
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: SizedBox(
                            width: timelineWidth,
                            child: Column(
                              children: [
                                _buildRuler(timelineWidth),
                                ...tracks.map((track) => _buildTrackLane(
                                  track: track,
                                  clips: state.clipsOnTrack(track.index),
                                  timelineWidth: timelineWidth,
                                  selectedId: state.selectedClipId,
                                )),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Snap indicator (yellow vertical line)
                      if (_snapIndicatorMs != null)
                        _buildSnapLine(_snapIndicatorMs!),

                      // Playhead (fixed center overlay)
                      _buildPlayhead(state.playheadPosition),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Snap toggle bar ──────────────────────────────────────────────────────────

  Widget _buildSnapBar(EditorState state) {
    return Container(
      height: 32,
      color: const Color(0xFF1A1A22),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          InkWell(
            onTap: () => ref.read(_provider.notifier).toggleSnap(),
            child: Row(
              children: [
                Icon(
                  state.snapEnabled ? Icons.grid_4x4 : Icons.grid_off,
                  color: state.snapEnabled ? Colors.amberAccent : Colors.white38,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  'Snap',
                  style: TextStyle(
                    color: state.snapEnabled ? Colors.amberAccent : Colors.white38,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '${_pixelsPerMs.toStringAsFixed(2)}px/ms',
            style: const TextStyle(color: Colors.white24, fontSize: 10),
          ),
        ],
      ),
    );
  }

  // ── Track headers ────────────────────────────────────────────────────────────

  Widget _buildTrackHeaders(List<VideoTrack> tracks, EditorState state) {
    return SingleChildScrollView(
      controller: _vScroll,
      scrollDirection: Axis.vertical,
      child: Column(
        children: [
          const SizedBox(height: 24), // ruler height offset
          ...tracks.map((track) => _buildTrackHeader(track)),
        ],
      ),
    );
  }

  Widget _buildTrackHeader(VideoTrack track) {
    final isVideo = track.index < 6;
    final color = isVideo ? const Color(0xFF3B4CCA) : const Color(0xFF8B2FC9);

    return Container(
      width: _trackHeaderWidth,
      height: _trackHeight,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E28),
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1),
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.04), width: 1),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 20,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                track.label,
                style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _trackIconBtn(
                track.isMuted ? Icons.volume_off : Icons.volume_up,
                track.isMuted ? Colors.redAccent : Colors.white38,
                () => ref.read(_provider.notifier).toggleTrackMute(track.index),
              ),
              _trackIconBtn(
                Icons.headphones,
                track.isSolo ? Colors.amberAccent : Colors.white38,
                () => ref.read(_provider.notifier).toggleTrackSolo(track.index),
              ),
              _trackIconBtn(
                track.isLocked ? Icons.lock : Icons.lock_open,
                track.isLocked ? Colors.orangeAccent : Colors.white38,
                () => ref.read(_provider.notifier).toggleTrackLock(track.index),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _trackIconBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, size: 13, color: color),
    );
  }

  // ── Time ruler ───────────────────────────────────────────────────────────────

  Widget _buildRuler(double totalWidth) {
    void seekTo(double localX) {
      final ms = (localX / _pixelsPerMs).clamp(0.0, 999999.0);
      ref.read(_provider.notifier).updatePlayhead(
            Duration(milliseconds: ms.toInt()));
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (d) => seekTo(d.localPosition.dx),
      onPanUpdate: (d) => seekTo(d.localPosition.dx),
      child: CustomPaint(
        size: Size(totalWidth, 24),
        painter: _RulerPainter(pixelsPerMs: _pixelsPerMs),
      ),
    );
  }

  // ── Track lane ───────────────────────────────────────────────────────────────

  Widget _buildTrackLane({
    required VideoTrack track,
    required List<Clip> clips,
    required double timelineWidth,
    required String? selectedId,
  }) {
    final isVideo = track.index < 6;

    return GestureDetector(
      onTapUp: (details) async {
        // Tap on empty track area = import
        if (clips.isEmpty && !track.isLocked) {
          _importToTrack(track.index);
        }
      },
      child: Container(
        width: timelineWidth,
        height: _trackHeight,
        decoration: BoxDecoration(
          color: isVideo
              ? const Color(0xFF16161E)
              : const Color(0xFF12121A),
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.04), width: 1),
          ),
        ),
        child: Stack(
          children: [
            // Grid lines
            CustomPaint(
              size: Size(timelineWidth, _trackHeight),
              painter: _GridPainter(pixelsPerMs: _pixelsPerMs),
            ),

            // Clips
            ...clips.map((clip) => _buildClip(clip, track, selectedId)),

            // Empty track hint
            if (clips.isEmpty && !track.isLocked)
              Positioned(
                left: 12,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_outline,
                          size: 14, color: Colors.white.withValues(alpha: 0.15)),
                      const SizedBox(width: 4),
                      Text(
                        'Tap to import',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.15),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Clip widget ──────────────────────────────────────────────────────────────

  Widget _buildClip(Clip clip, VideoTrack track, String? selectedId) {
    final isSelected = selectedId == clip.id;
    final left = clip.start.inMilliseconds * _pixelsPerMs;
    final width = (clip.activeDuration.inMilliseconds * _pixelsPerMs).clamp(10.0, double.infinity);
    final isVideo = clip.type != 'audio';
    final baseColor = isVideo ? const Color(0xFF3B4CCA) : const Color(0xFF8B2FC9);

    return Positioned(
      left: left,
      top: 4,
      height: _trackHeight - 8,
      width: width,
      child: GestureDetector(
        onTap: () {
          ref.read(_provider.notifier).selectClip(clip.id);
        },
        onPanStart: track.isLocked
            ? null
            : (_) {
                _clipDragYAccum[clip.id] = 0.0;
              },
        onPanUpdate: track.isLocked
            ? null
            : (details) {
                // Horizontal: move clip start position
                final msDelta = details.delta.dx / _pixelsPerMs;
                final newStart = Duration(
                  milliseconds: (clip.start.inMilliseconds + msDelta).toInt().clamp(0, 999999),
                );

                // Vertical: accumulate Y to determine track change
                _clipDragYAccum[clip.id] = (_clipDragYAccum[clip.id] ?? 0.0) + details.delta.dy;
                final yAccum = _clipDragYAccum[clip.id]!;
                int newTrackIndex = track.index;
                if (yAccum.abs() >= _trackHeight) {
                  final trackDelta = (yAccum / _trackHeight).round();
                  // Keep video on video tracks (0-5) and audio on audio tracks (6-11)
                  final minTrack = clip.type == 'audio' ? 6 : 0;
                  final maxTrack = clip.type == 'audio' ? 11 : 5;
                  newTrackIndex = (track.index + trackDelta).clamp(minTrack, maxTrack);
                  if (newTrackIndex != track.index) {
                    _clipDragYAccum[clip.id] = 0.0;
                  }
                }

                ref.read(_provider.notifier).moveClip(
                  clip.id, newTrackIndex, newStart,
                );

                if (ref.read(_provider).snapEnabled) {
                  setState(() => _snapIndicatorMs = newStart);
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (mounted) setState(() => _snapIndicatorMs = null);
                  });
                }
              },
        onPanEnd: (_) => _clipDragYAccum.remove(clip.id),
        child: Stack(
          children: [
            // Clip body
            Container(
              decoration: BoxDecoration(
                color: baseColor.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected ? Colors.white : baseColor.withValues(alpha: 0.7),
                  width: isSelected ? 2.0 : 1.0,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Stack(
                  children: [
                    // Waveform / thumbnail
                    Opacity(
                      opacity: 0.4,
                      child: CustomPaint(
                        size: Size(width, _trackHeight - 8),
                        painter: isVideo
                            ? _VideoThumbnailPainter(baseColor)
                            : _WaveformPainter(baseColor),
                      ),
                    ),
                    // Clip name
                    Positioned(
                      left: 20,
                      top: 4,
                      right: 20,
                      child: Text(
                        clip.id.split('_').first,
                        style: const TextStyle(color: Colors.white, fontSize: 9),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Proxy badge
                    if (clip.isGeneratingProxy)
                      const Positioned(
                        right: 20,
                        top: 4,
                        child: SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: Colors.amberAccent,
                          ),
                        ),
                      ),
                    // Blend mode badge
                    if (clip.blendMode != 'normal')
                      Positioned(
                        left: 20,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            clip.blendMode,
                            style: const TextStyle(color: Colors.white70, fontSize: 7),
                          ),
                        ),
                      ),
                    // Keyframe dots
                    ...clip.keyframes.map((kf) => Positioned(
                      left: kf.timeMs / clip.duration.inMilliseconds * width - 4,
                      bottom: 2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.yellowAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )),
                  ],
                ),
              ),
            ),

            // Left trim handle
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                onHorizontalDragUpdate: track.isLocked
                    ? null
                    : (d) {
                        final msDelta = d.primaryDelta! / _pixelsPerMs;
                        final newStart = (clip.trimStart.inMilliseconds + msDelta)
                            .clamp(0.0, clip.trimEnd.inMilliseconds - 100.0);
                        ref.read(_provider.notifier).updateClipState(
                          clip.id,
                          (c) => c.copyWith(trimStart: Duration(milliseconds: newStart.toInt())),
                        );
                      },
                child: Container(
                  width: 14,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.4),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(6),
                      bottomLeft: Radius.circular(6),
                    ),
                  ),
                  child: const Icon(Icons.drag_indicator, size: 10, color: Colors.black54),
                ),
              ),
            ),

            // Right trim handle
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                onHorizontalDragUpdate: track.isLocked
                    ? null
                    : (d) {
                        final msDelta = d.primaryDelta! / _pixelsPerMs;
                        final newEnd = (clip.trimEnd.inMilliseconds + msDelta)
                            .clamp(clip.trimStart.inMilliseconds + 100.0, clip.duration.inMilliseconds.toDouble());
                        ref.read(_provider.notifier).updateClipState(
                          clip.id,
                          (c) => c.copyWith(trimEnd: Duration(milliseconds: newEnd.toInt())),
                        );
                      },
                child: Container(
                  width: 14,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.4),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(6),
                      bottomRight: Radius.circular(6),
                    ),
                  ),
                  child: const Icon(Icons.drag_indicator, size: 10, color: Colors.black54),
                ),
              ),
            ),

            // Delete button on selection
            if (isSelected)
              Positioned(
                top: -2,
                right: 16,
                child: GestureDetector(
                  onTap: () => ref.read(_provider.notifier).deleteClip(clip.id),
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 11, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Playhead ─────────────────────────────────────────────────────────────────

  Widget _buildPlayhead(Duration position) {
    final px = position.inMilliseconds * _pixelsPerMs;
    final viewportOffset = _hScroll.hasClients ? _hScroll.offset : 0.0;
    final screenX = px - viewportOffset;
    if (screenX < -20) return const SizedBox.shrink();

    return Positioned(
      left: screenX - 8, // extra padding for touch target
      top: 0,
      bottom: 0,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (d) {
          final newScreenX = (screenX + d.delta.dx).clamp(0.0, double.infinity);
          final newMs = ((newScreenX + viewportOffset) / _pixelsPerMs)
              .clamp(0.0, 999999.0);
          ref.read(_provider.notifier).updatePlayhead(
                Duration(milliseconds: newMs.toInt()));
        },
        child: SizedBox(
          width: 18, // wider touch target
          child: Center(
            child: Container(
              width: 2,
              color: Colors.redAccent,
              child: Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Snap indicator ────────────────────────────────────────────────────────────

  Widget _buildSnapLine(Duration posMs) {
    final px = posMs.inMilliseconds * _pixelsPerMs;
    final viewportOffset = _hScroll.hasClients ? _hScroll.offset : 0.0;
    final screenX = px - viewportOffset;

    return Positioned(
      left: screenX,
      top: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Container(
          width: 1.5,
          color: Colors.amberAccent.withValues(alpha: 0.85),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  double _computeTotalDuration(EditorState state) {
    double maxMs = 30000; // minimum 30 seconds visible
    for (final c in state.allClips) {
      final end = (c.start + c.activeDuration).inMilliseconds.toDouble();
      if (end > maxMs) maxMs = end;
    }
    return maxMs;
  }
}

// ─── Custom Painters ──────────────────────────────────────────────────────────

class _RulerPainter extends CustomPainter {
  final double pixelsPerMs;
  _RulerPainter({required this.pixelsPerMs});

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFF111118);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bg);

    final linePaint = Paint()..color = Colors.white24..strokeWidth = 1;
    final textStyle = const TextStyle(color: Colors.white38, fontSize: 8);

    // Determine tick interval based on zoom
    final msPerPixel = 1.0 / pixelsPerMs;
    int tickIntervalMs = 1000;
    if (msPerPixel > 50) tickIntervalMs = 5000;
    if (msPerPixel > 200) tickIntervalMs = 30000;
    if (pixelsPerMs > 0.5) tickIntervalMs = 500;
    if (pixelsPerMs > 1.0) tickIntervalMs = 100;

    for (double ms = 0; ms < size.width / pixelsPerMs; ms += tickIntervalMs) {
      final x = ms * pixelsPerMs;
      canvas.drawLine(Offset(x, 8), Offset(x, size.height), linePaint);

      final secs = ms ~/ 1000;
      final mins = secs ~/ 60;
      final label = '${mins.toString().padLeft(2, '0')}:${(secs % 60).toString().padLeft(2, '0')}';
      final tp = TextPainter(
        text: TextSpan(text: label, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x + 3, 2));
    }
  }

  @override
  bool shouldRepaint(_RulerPainter old) => old.pixelsPerMs != pixelsPerMs;
}

class _GridPainter extends CustomPainter {
  final double pixelsPerMs;
  _GridPainter({required this.pixelsPerMs});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1;
    final msPerPixel = 1.0 / pixelsPerMs;
    int tickMs = msPerPixel > 50 ? 5000 : 1000;

    for (double ms = 0; ms < size.width / pixelsPerMs; ms += tickMs) {
      final x = ms * pixelsPerMs;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.pixelsPerMs != pixelsPerMs;
}

class _WaveformPainter extends CustomPainter {
  final Color color;
  _WaveformPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..strokeWidth = 1.5;
    final rng = Random(42);
    for (double x = 2; x < size.width; x += 4) {
      final h = (size.height * 0.2) + (size.height * 0.65) * rng.nextDouble();
      canvas.drawLine(
        Offset(x, (size.height - h) / 2),
        Offset(x, (size.height + h) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) => false;
}

class _VideoThumbnailPainter extends CustomPainter {
  final Color color;
  _VideoThumbnailPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    // Stylized film-strip pattern
    final bg = Paint()..color = color.withValues(alpha: 0.15);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bg);

    final framePaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const frameW = 40.0;
    for (double x = 0; x < size.width; x += frameW) {
      canvas.drawRect(Rect.fromLTWH(x + 2, 4, frameW - 4, size.height - 8), framePaint);
      // Film sprocket holes
      canvas.drawCircle(Offset(x + 8, 6), 2, Paint()..color = color.withValues(alpha: 0.3));
      canvas.drawCircle(Offset(x + 8, size.height - 6), 2, Paint()..color = color.withValues(alpha: 0.3));
    }
  }

  @override
  bool shouldRepaint(covariant _VideoThumbnailPainter old) => false;
}
