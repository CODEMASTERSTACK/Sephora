import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/ui/toolbar.dart';
import '../widgets/timeline/timeline_view.dart';

class AudioEditorScreen extends StatelessWidget {
  const AudioEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Audio Mix', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text('Export', style: TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Audio Visualizer/Waveform Area Placeholder
          Expanded(
            flex: 4,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.panelBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Center(
                    child: Text('Large Audio Waveform Visualizer', style: TextStyle(color: Colors.white54)),
                  ),
                  Positioned(
                    bottom: 16,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.fast_rewind), onPressed: () {}),
                        IconButton(icon: const Icon(Icons.play_circle_fill, size: 50, color: Colors.pinkAccent), onPressed: () {}),
                        IconButton(icon: const Icon(Icons.fast_forward), onPressed: () {}),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
          
          // Toolbar (we can reuse the same for now, or make a custom one later)
          const EditorToolbar(),
          
          // Timeline
          const Expanded(
            flex: 5,
            child: TimelineView(),
          ),
        ],
      ),
    );
  }
}
