import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/editor_provider.dart';

class SpeedRampPanel extends ConsumerStatefulWidget {
  final Clip clip;
  const SpeedRampPanel({super.key, required this.clip});

  @override
  ConsumerState<SpeedRampPanel> createState() => _SpeedRampPanelState();
}

class _SpeedRampPanelState extends ConsumerState<SpeedRampPanel> {
  SpeedPoint? _selected;

  @override
  Widget build(BuildContext context) {
    final clip = ref.watch(editorProvider).clipById(widget.clip.id) ?? widget.clip;
    final durationMs = clip.activeDuration.inMilliseconds.toDouble();

    return Container(
      height: 380,
      decoration: const BoxDecoration(
        color: Color(0xFF13131B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Speed Ramp', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        // Reset all speed points
                        for (final sp in clip.speedPoints) {
                          ref.read(editorProvider.notifier).deleteSpeedPoint(clip.id, sp.id);
                        }
                      },
                      child: const Text('Reset', style: TextStyle(color: Colors.white38, fontSize: 12)),
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

          // Speed curve graph
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTapUp: (d) {
                  final size = context.size;
                  if (size == null) return;
                  final timeMs = (d.localPosition.dx / size.width) * durationMs;
                  final speedFrac = 1.0 - (d.localPosition.dy / size.height);
                  final speed = (speedFrac * 4.0).clamp(0.25, 4.0);
                  final pt = SpeedPoint(
                    id: 'sp_${DateTime.now().millisecondsSinceEpoch}',
                    timeMs: timeMs.clamp(0, durationMs),
                    speed: speed,
                  );
                  ref.read(editorProvider.notifier).addSpeedPoint(clip.id, pt);
                },
                onPanUpdate: (d) {
                  if (_selected == null) return;
                  final size = context.size;
                  if (size == null) return;
                  final dtMs = (d.delta.dx / size.width) * durationMs;
                  final dSpeed = -(d.delta.dy / size.height) * 4.0;
                  ref.read(editorProvider.notifier).updateSpeedPoint(
                    clip.id, _selected!.id,
                    (sp) => sp.copyWith(
                      timeMs: (sp.timeMs + dtMs).clamp(0, durationMs),
                      speed: (sp.speed + dSpeed).clamp(0.25, 4.0),
                    ),
                  );
                },
                child: CustomPaint(
                  size: const Size(double.infinity, double.infinity),
                  painter: _SpeedCurvePainter(
                    speedPoints: clip.speedPoints,
                    durationMs: durationMs,
                    selectedId: _selected?.id,
                  ),
                ),
              ),
            ),
          ),

          // Speed point list
          Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: clip.speedPoints.isEmpty
                ? const Center(
                    child: Text('Tap on the graph to add a speed point',
                        style: TextStyle(color: Colors.white24, fontSize: 12)),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: clip.speedPoints.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final sp = clip.speedPoints[i];
                      final isSel = _selected?.id == sp.id;
                      return GestureDetector(
                        onTap: () => setState(() => _selected = sp),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSel
                                ? Colors.orangeAccent.withValues(alpha: 0.25)
                                : Colors.white.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isSel ? Colors.orangeAccent : Colors.white12),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('${sp.speed.toStringAsFixed(2)}×',
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              Text('${(sp.timeMs / 1000).toStringAsFixed(1)}s',
                                  style: const TextStyle(color: Colors.white54, fontSize: 10)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Delete selected
          if (_selected != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextButton.icon(
                onPressed: () {
                  ref.read(editorProvider.notifier).deleteSpeedPoint(clip.id, _selected!.id);
                  setState(() => _selected = null);
                },
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
                label: const Text('Delete Point', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
              ),
            ),
        ],
      ),
    );
  }
}

class _SpeedCurvePainter extends CustomPainter {
  final List<SpeedPoint> speedPoints;
  final double durationMs;
  final String? selectedId;

  const _SpeedCurvePainter({
    required this.speedPoints,
    required this.durationMs,
    this.selectedId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Grid
    final gridP = Paint()..color = Colors.white.withValues(alpha: 0.05)..strokeWidth = 1;
    // Y axis: 0.25x, 0.5x, 1x, 2x, 4x
    final yLabels = [0.25, 0.5, 1.0, 2.0, 4.0];
    for (final speed in yLabels) {
      final y = size.height * (1.0 - (speed / 4.0));
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridP);
      final tp = TextPainter(
        text: TextSpan(
          text: '${speed}×',
          style: const TextStyle(color: Colors.white24, fontSize: 8),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(2, y - 8));
    }

    // Highlight 1× line
    final onePaint = Paint()..color = Colors.white24..strokeWidth = 1;
    final oneY = size.height * (1.0 - (1.0 / 4.0));
    canvas.drawLine(Offset(0, oneY), Offset(size.width, oneY), onePaint);

    if (speedPoints.isEmpty || durationMs <= 0) return;

    // Build points
    final pts = [
      Offset(0, size.height * (1.0 - 1.0 / 4.0)), // start at 1x
      ...speedPoints.map((sp) => Offset(
        (sp.timeMs / durationMs) * size.width,
        size.height * (1.0 - sp.speed / 4.0),
      )),
      Offset(size.width, size.height * (1.0 - 1.0 / 4.0)), // end at 1x
    ];

    // Smooth curve
    final curvePaint = Paint()
      ..color = Colors.orangeAccent.withValues(alpha: 0.9)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 0; i < pts.length - 1; i++) {
      final midX = (pts[i].dx + pts[i + 1].dx) / 2;
      path.cubicTo(midX, pts[i].dy, midX, pts[i + 1].dy, pts[i + 1].dx, pts[i + 1].dy);
    }
    canvas.drawPath(path, curvePaint);

    // Fill under curve
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()..color = Colors.orangeAccent.withValues(alpha: 0.08),
    );

    // Dots for user speed points
    for (int i = 0; i < speedPoints.length; i++) {
      final pt = pts[i + 1];
      final isSel = speedPoints[i].id == selectedId;
      canvas.drawCircle(
        pt, isSel ? 8 : 5,
        Paint()..color = isSel ? Colors.white : Colors.orangeAccent,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpeedCurvePainter old) =>
      old.speedPoints != speedPoints || old.selectedId != selectedId;
}
