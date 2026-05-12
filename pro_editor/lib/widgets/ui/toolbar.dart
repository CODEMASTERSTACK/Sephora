import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class EditorToolbar extends StatelessWidget {
  const EditorToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    final tools = [
      {'icon': Icons.cut, 'label': 'Split'},
      {'icon': Icons.linear_scale, 'label': 'Speed'},
      {'icon': Icons.volume_up, 'label': 'Volume'},
      {'icon': Icons.animation, 'label': 'Animation'},
      {'icon': Icons.auto_fix_high, 'label': 'Effects'},
      {'icon': Icons.layers, 'label': 'Overlay'},
      {'icon': Icons.format_color_fill, 'label': 'Filters'},
    ];

    return Container(
      height: 80,
      color: AppTheme.panelBackground,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tools.length,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          final tool = tools[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(tool['icon'] as IconData, color: Colors.white, size: 28),
                const SizedBox(height: 6),
                Text(
                  tool['label'] as String,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
