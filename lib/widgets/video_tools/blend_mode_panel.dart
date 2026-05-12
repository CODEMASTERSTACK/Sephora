import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/editor_provider.dart';

class BlendModePanel extends ConsumerWidget {
  final Clip clip;
  const BlendModePanel({super.key, required this.clip});

  static const _modes = [
    ('Normal', 'normal', Icons.filter_none),
    ('Multiply', 'multiply', Icons.filter_b_and_w),
    ('Screen', 'screen', Icons.brightness_high),
    ('Overlay', 'overlay', Icons.layers),
    ('Darken', 'darken', Icons.brightness_3),
    ('Lighten', 'lighten', Icons.brightness_7),
    ('Difference', 'difference', Icons.compare),
    ('Exclusion', 'exclusion', Icons.swap_horiz),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(editorProvider).clipById(clip.id) ?? clip;

    return Container(
      height: 340,
      decoration: const BoxDecoration(
        color: Color(0xFF15151F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Blend Mode & Opacity',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Opacity slider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('Opacity', style: TextStyle(color: Colors.white54, fontSize: 12)),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.cyanAccent,
                      thumbColor: Colors.cyanAccent,
                      inactiveTrackColor: Colors.white12,
                      trackHeight: 2,
                    ),
                    child: Slider(
                      value: current.opacity,
                      min: 0.0,
                      max: 1.0,
                      onChanged: (v) =>
                          ref.read(editorProvider.notifier).setOpacity(clip.id, v),
                    ),
                  ),
                ),
                Text(
                  '${(current.opacity * 100).toInt()}%',
                  style: const TextStyle(color: Colors.cyanAccent, fontSize: 11),
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(color: Colors.white12),
          ),

          // Blend mode grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 1.1,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _modes.length,
              itemBuilder: (_, i) {
                final (label, mode, icon) = _modes[i];
                final isActive = current.blendMode == mode;
                return GestureDetector(
                  onTap: () => ref.read(editorProvider.notifier).setBlendMode(clip.id, mode),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.cyanAccent.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isActive ? Colors.cyanAccent : Colors.white12,
                        width: isActive ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon,
                          color: isActive ? Colors.cyanAccent : Colors.white38,
                          size: 22,
                        ),
                        const SizedBox(height: 4),
                        Text(label,
                          style: TextStyle(
                            color: isActive ? Colors.cyanAccent : Colors.white54,
                            fontSize: 9,
                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
