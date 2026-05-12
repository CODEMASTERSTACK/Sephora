import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/editor_provider.dart';

class SpatialAudioPanel extends ConsumerStatefulWidget {
  final Clip clip;
  const SpatialAudioPanel({super.key, required this.clip});

  @override
  ConsumerState<SpatialAudioPanel> createState() => _SpatialAudioPanelState();
}

class _SpatialAudioPanelState extends ConsumerState<SpatialAudioPanel>
    with SingleTickerProviderStateMixin {
  late bool _enabled;
  late double _rotation;
  late double _width;
  late double _depth;
  late double _elevation;

  late AnimationController _orbAnimController;

  @override
  void initState() {
    super.initState();
    _enabled = widget.clip.spatial3dEnabled;
    _rotation = widget.clip.spatial3dRotation;
    _width = widget.clip.spatial3dWidth;
    _depth = widget.clip.spatial3dDepth;
    _elevation = widget.clip.spatial3dElevation;

    _orbAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _orbAnimController.dispose();
    super.dispose();
  }

  void _save() {
    ref.read(audioEditorProvider.notifier).updateClipState(
      widget.clip.id,
      (c) => c.copyWith(
        spatial3dEnabled: _enabled,
        spatial3dRotation: _rotation,
        spatial3dWidth: _width,
        spatial3dDepth: _depth,
        spatial3dElevation: _elevation,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 520,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1030), Color(0xFF0D0D14)],
        ),
      ),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.surround_sound, color: Colors.cyanAccent, size: 22),
                    SizedBox(width: 8),
                    Text('3D Spatial Audio',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                Row(
                  children: [
                    // Enable/Disable toggle
                    Switch(
                      value: _enabled,
                      activeTrackColor: Colors.cyanAccent,
                      onChanged: (val) {
                        setState(() => _enabled = val);
                        _save();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Creates binaural 3D audio that rotates around the listener\'s head using stereo panning, phase shifts, and spatial reverb.',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ),

          const SizedBox(height: 12),

          // ── 3D Orbit Visualizer ─────────────────────────────────
          AnimatedOpacity(
            opacity: _enabled ? 1.0 : 0.3,
            duration: const Duration(milliseconds: 300),
            child: SizedBox(
              height: 140,
              child: AnimatedBuilder(
                animation: _orbAnimController,
                builder: (context, _) {
                  return CustomPaint(
                    size: const Size(double.infinity, 140),
                    painter: _SpatialOrbPainter(
                      phase: _orbAnimController.value,
                      rotationHz: _rotation,
                      width: _width,
                      depth: _depth,
                      elevation: _elevation,
                      enabled: _enabled,
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ── Sliders ─────────────────────────────────────────────
          Expanded(
            child: AnimatedOpacity(
              opacity: _enabled ? 1.0 : 0.4,
              duration: const Duration(milliseconds: 300),
              child: IgnorePointer(
                ignoring: !_enabled,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildSlider(
                      icon: Icons.rotate_right,
                      label: 'Rotation',
                      sublabel: '${_rotation.toStringAsFixed(1)} Hz',
                      value: _rotation,
                      min: 0.1,
                      max: 5.0,
                      activeColor: Colors.cyanAccent,
                      onChanged: (v) => setState(() => _rotation = v),
                    ),
                    _buildSlider(
                      icon: Icons.swap_horiz,
                      label: 'Width',
                      sublabel: '${(_width * 25).toInt()}%',
                      value: _width,
                      min: 0.0,
                      max: 4.0,
                      activeColor: Colors.purpleAccent,
                      onChanged: (v) => setState(() => _width = v),
                    ),
                    _buildSlider(
                      icon: Icons.blur_on,
                      label: 'Depth',
                      sublabel: '${(_depth * 100).toInt()}%',
                      value: _depth,
                      min: 0.0,
                      max: 1.0,
                      activeColor: Colors.blueAccent,
                      onChanged: (v) => setState(() => _depth = v),
                    ),
                    _buildSlider(
                      icon: Icons.height,
                      label: 'Elevation',
                      sublabel: _elevation > 0
                          ? '+${(_elevation * 100).toInt()}%'
                          : '${(_elevation * 100).toInt()}%',
                      value: _elevation,
                      min: -1.0,
                      max: 1.0,
                      activeColor: Colors.amberAccent,
                      onChanged: (v) => setState(() => _elevation = v),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Presets ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _presetChip('Subtle Orbit', 0.5, 1.5, 0.15, 0.0),
                  const SizedBox(width: 8),
                  _presetChip('Cinematic Spin', 1.2, 2.5, 0.4, 0.2),
                  const SizedBox(width: 8),
                  _presetChip('Deep Immersion', 0.8, 3.0, 0.7, -0.3),
                  const SizedBox(width: 8),
                  _presetChip('Fast Whirl', 3.5, 3.5, 0.3, 0.0),
                  const SizedBox(width: 8),
                  _presetChip('Overhead Float', 0.3, 2.0, 0.5, 0.8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _presetChip(String label, double rot, double w, double d, double e) {
    return ActionChip(
      backgroundColor: const Color(0xFF2A2040),
      side: BorderSide(color: Colors.cyanAccent.withValues(alpha: 0.3)),
      label: Text(label,
          style: const TextStyle(color: Colors.cyanAccent, fontSize: 11)),
      onPressed: () {
        setState(() {
          _enabled = true;
          _rotation = rot;
          _width = w;
          _depth = d;
          _elevation = e;
        });
        _save();
      },
    );
  }

  Widget _buildSlider({
    required IconData icon,
    required String label,
    required String sublabel,
    required double value,
    required double min,
    required double max,
    required Color activeColor,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: activeColor, size: 18),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12)),
                Text(sublabel,
                    style: TextStyle(
                        color: activeColor.withValues(alpha: 0.7),
                        fontSize: 10)),
              ],
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: activeColor,
                inactiveTrackColor: activeColor.withValues(alpha: 0.15),
                thumbColor: activeColor,
                overlayColor: activeColor.withValues(alpha: 0.15),
                trackHeight: 3,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: onChanged,
                onChangeEnd: (_) => _save(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 3D Orbit Visualizer Painter ──────────────────────────────────────────────

class _SpatialOrbPainter extends CustomPainter {
  final double phase;
  final double rotationHz;
  final double width;
  final double depth;
  final double elevation;
  final bool enabled;

  _SpatialOrbPainter({
    required this.phase,
    required this.rotationHz,
    required this.width,
    required this.depth,
    required this.elevation,
    required this.enabled,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Head circle (listener)
    final headPaint = Paint()
      ..color = enabled
          ? Colors.white.withValues(alpha: 0.5)
          : Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset(cx, cy), 14, headPaint);

    // Ear indicators
    final earPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4);
    canvas.drawCircle(Offset(cx - 14, cy), 3, earPaint);
    canvas.drawCircle(Offset(cx + 14, cy), 3, earPaint);

    // "L" and "R" labels
    final lStyle = TextPainter(
      text: TextSpan(
          text: 'L',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3), fontSize: 8)),
      textDirection: TextDirection.ltr,
    )..layout();
    lStyle.paint(canvas, Offset(cx - 24, cy - 4));
    final rStyle = TextPainter(
      text: TextSpan(
          text: 'R',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3), fontSize: 8)),
      textDirection: TextDirection.ltr,
    )..layout();
    rStyle.paint(canvas, Offset(cx + 19, cy - 4));

    if (!enabled) return;

    // Orbit ellipse
    final orbitRadiusX = 30 + width * 14; // wider = more horizontal spread
    final orbitRadiusY = 20 + depth * 25; // depth = more oval depth
    final orbitPaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, cy + elevation * -20),
          width: orbitRadiusX * 2,
          height: orbitRadiusY * 2),
      orbitPaint,
    );

    // Orbiting sound source
    final angle = phase * 2 * pi * rotationHz;
    final sx = cx + orbitRadiusX * cos(angle);
    final sy = cy + elevation * -20 + orbitRadiusY * sin(angle);

    // Glow
    final glowPaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(Offset(sx, sy), 12, glowPaint);

    // Source dot
    final srcPaint = Paint()..color = Colors.cyanAccent;
    canvas.drawCircle(Offset(sx, sy), 5, srcPaint);

    // Trail (fading dots behind)
    for (int i = 1; i <= 8; i++) {
      final trailAngle = angle - (i * 0.15);
      final tx = cx + orbitRadiusX * cos(trailAngle);
      final ty = cy + elevation * -20 + orbitRadiusY * sin(trailAngle);
      final alpha = 0.4 - (i * 0.045);
      final trailPaint = Paint()
        ..color = Colors.cyanAccent.withValues(alpha: alpha.clamp(0.02, 0.4));
      canvas.drawCircle(Offset(tx, ty), 2.5 - i * 0.2, trailPaint);
    }

    // Distance lines from source to ears
    final linePaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.08)
      ..strokeWidth = 0.5;
    canvas.drawLine(Offset(sx, sy), Offset(cx - 14, cy), linePaint);
    canvas.drawLine(Offset(sx, sy), Offset(cx + 14, cy), linePaint);
  }

  @override
  bool shouldRepaint(covariant _SpatialOrbPainter old) => true;
}
