import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/editor_provider.dart';

class KeyframeEditor extends ConsumerStatefulWidget {
  final Clip clip;
  const KeyframeEditor({super.key, required this.clip});

  @override
  ConsumerState<KeyframeEditor> createState() => _KeyframeEditorState();
}

class _KeyframeEditorState extends ConsumerState<KeyframeEditor>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String _activeProperty = 'scale';
  Keyframe? _selectedKeyframe;

  final _props = ['position', 'scale', 'rotation', 'opacity'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _props.length, vsync: this);
    _tabs.addListener(() {
      setState(() => _activeProperty = _props[_tabs.index]);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _addKeyframeAt(double timeMs) {
    final kf = Keyframe(
      id: 'kf_${DateTime.now().millisecondsSinceEpoch}',
      timeMs: timeMs,
    );
    ref.read(editorProvider.notifier).addKeyframe(widget.clip.id, kf);
  }

  @override
  Widget build(BuildContext context) {
    final clip = ref.watch(editorProvider).clipById(widget.clip.id) ?? widget.clip;
    final durationMs = clip.activeDuration.inMilliseconds.toDouble();

    return Container(
      height: 420,
      decoration: const BoxDecoration(
        color: Color(0xFF16161E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Keyframe Editor',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Property tabs
          TabBar(
            controller: _tabs,
            isScrollable: true,
            indicatorColor: Colors.purpleAccent,
            labelColor: Colors.purpleAccent,
            unselectedLabelColor: Colors.white38,
            tabs: _props.map((p) => Tab(text: p[0].toUpperCase() + p.substring(1))).toList(),
          ),

          const SizedBox(height: 8),

          // Graph Editor canvas
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTapUp: (d) {
                  final tapMs = (d.localPosition.dx / 280.0) * durationMs;
                  _addKeyframeAt(tapMs.clamp(0, durationMs));
                },
                child: CustomPaint(
                  size: const Size(double.infinity, double.infinity),
                  painter: _GraphEditorPainter(
                    keyframes: clip.keyframes,
                    durationMs: durationMs,
                    property: _activeProperty,
                    selectedId: _selectedKeyframe?.id,
                  ),
                ),
              ),
            ),
          ),

          // Keyframe list
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: clip.keyframes.isEmpty
                ? const Center(
                    child: Text('Tap on the graph to add a keyframe',
                        style: TextStyle(color: Colors.white24, fontSize: 12)),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: clip.keyframes.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final kf = clip.keyframes[i];
                      final isSelected = _selectedKeyframe?.id == kf.id;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedKeyframe = kf),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.purpleAccent.withValues(alpha: 0.3)
                                : Colors.white.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? Colors.purpleAccent : Colors.white12,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('${(kf.timeMs / 1000).toStringAsFixed(1)}s',
                                  style: const TextStyle(color: Colors.white, fontSize: 11)),
                              Text('s:${kf.scale.toStringAsFixed(1)}',
                                  style: const TextStyle(color: Colors.white54, fontSize: 9)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Ease handles for selected keyframe
          if (_selectedKeyframe != null) _buildEaseControls(_selectedKeyframe!, clip),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildEaseControls(Keyframe kf, Clip clip) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Text('Ease In', style: TextStyle(color: Colors.white54, fontSize: 11)),
          Expanded(
            child: Slider(
              value: kf.easeIn,
              min: 0.0,
              max: 1.0,
              activeColor: Colors.purpleAccent,
              onChanged: (v) {
                ref.read(editorProvider.notifier).updateKeyframe(
                  clip.id, kf.id,
                  (k) => k.copyWith(easeIn: v),
                );
                setState(() => _selectedKeyframe = kf.copyWith(easeIn: v));
              },
            ),
          ),
          const Text('Out', style: TextStyle(color: Colors.white54, fontSize: 11)),
          Expanded(
            child: Slider(
              value: kf.easeOut,
              min: 0.0,
              max: 1.0,
              activeColor: Colors.purpleAccent,
              onChanged: (v) {
                ref.read(editorProvider.notifier).updateKeyframe(
                  clip.id, kf.id,
                  (k) => k.copyWith(easeOut: v),
                );
                setState(() => _selectedKeyframe = kf.copyWith(easeOut: v));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GraphEditorPainter extends CustomPainter {
  final List<Keyframe> keyframes;
  final double durationMs;
  final String property;
  final String? selectedId;

  _GraphEditorPainter({
    required this.keyframes,
    required this.durationMs,
    required this.property,
    this.selectedId,
  });

  double _valueForProperty(Keyframe kf) {
    switch (property) {
      case 'scale': return kf.scale;
      case 'rotation': return (kf.rotation + 180) / 360;
      case 'opacity': return kf.opacity;
      case 'position': return (kf.posX + 1.0) / 2.0;
      default: return 0.5;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Background grid
    final gridPaint = Paint()..color = Colors.white.withValues(alpha: 0.05)..strokeWidth = 1;
    for (int i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (int i = 1; i < 8; i++) {
      final x = size.width * i / 8;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // Base line at 0.5
    canvas.drawLine(
      Offset(0, size.height * 0.5),
      Offset(size.width, size.height * 0.5),
      Paint()..color = Colors.white24..strokeWidth = 1..style = PaintingStyle.stroke,
    );

    if (keyframes.isEmpty || durationMs <= 0) return;

    // Build curve through keyframes
    final points = keyframes.map((kf) {
      final x = (kf.timeMs / durationMs) * size.width;
      final v = _valueForProperty(kf);
      final y = size.height * (1.0 - v.clamp(0.0, 1.5));
      return Offset(x, y);
    }).toList();

    // Draw bezier curve
    final curvePaint = Paint()
      ..color = Colors.purpleAccent.withValues(alpha: 0.8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    if (points.length == 1) {
      canvas.drawCircle(points[0], 5, Paint()..color = Colors.purpleAccent);
    } else {
      final path = Path()..moveTo(points[0].dx, points[0].dy);
      for (int i = 0; i < points.length - 1; i++) {
        final cp1 = Offset(
          points[i].dx + (points[i + 1].dx - points[i].dx) * keyframes[i].easeOut,
          points[i].dy,
        );
        final cp2 = Offset(
          points[i + 1].dx - (points[i + 1].dx - points[i].dx) * keyframes[i + 1].easeIn,
          points[i + 1].dy,
        );
        path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, points[i + 1].dx, points[i + 1].dy);
      }
      canvas.drawPath(path, curvePaint);
    }

    // Draw keyframe dots
    for (int i = 0; i < points.length; i++) {
      final kf = keyframes[i];
      final isSelected = kf.id == selectedId;
      canvas.drawCircle(
        points[i],
        isSelected ? 7 : 5,
        Paint()..color = isSelected ? Colors.white : Colors.purpleAccent,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GraphEditorPainter old) =>
      old.keyframes != keyframes || old.selectedId != selectedId;
}
