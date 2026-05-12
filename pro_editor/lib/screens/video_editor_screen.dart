import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/ui/toolbar.dart';
import '../widgets/timeline/timeline_view.dart';
import '../widgets/preview/video_preview.dart';

class VideoEditorScreen extends StatelessWidget {
  const VideoEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('00:00:00:00', style: TextStyle(fontFamily: 'monospace')),
        actions: [
          TextButton(
            onPressed: () => context.push('/export'),
            child: const Text('Export', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Preview Monitor
          const Expanded(
            flex: 4,
            child: VideoPreview(),
          ),
          
          // Toolbar
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
