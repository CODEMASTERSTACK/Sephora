import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/editor_provider.dart';
import '../../theme/app_theme.dart';

class InteractiveTimeline extends ConsumerWidget {
  const InteractiveTimeline({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editorState = ref.watch(editorProvider);
    
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        // Simple mock of scrubbing logic
        final currentMs = editorState.playheadPosition.inMilliseconds;
        final newMs = currentMs - (details.delta.dx * 10).toInt();
        if (newMs >= 0) {
          ref.read(editorProvider.notifier).updatePlayhead(Duration(milliseconds: newMs));
        }
      },
      child: Container(
        color: AppTheme.background,
        child: Stack(
          children: [
            // Track background grid (optional)
            
            // Video Tracks
            if (editorState.videoClips.isEmpty)
              const Center(child: Text("Drag media here", style: TextStyle(color: Colors.white24)))
            else
              ListView.builder(
                itemCount: editorState.videoClips.length,
                itemBuilder: (context, index) {
                  final clip = editorState.videoClips[index];
                  return Container(
                    height: 50,
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.accent),
                    ),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(clip.id, style: const TextStyle(color: Colors.white, fontSize: 12)),
                  );
                },
              ),
              
            // Playhead indicator
            Positioned(
              left: MediaQuery.of(context).size.width / 2, // Centered playhead
              top: 0,
              bottom: 0,
              child: Container(
                width: 2,
                color: Colors.redAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
