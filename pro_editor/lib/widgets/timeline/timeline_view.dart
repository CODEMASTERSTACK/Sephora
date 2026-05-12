import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'interactive_timeline.dart';

class TimelineView extends StatelessWidget {
  const TimelineView({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      child: Column(
        children: [
          // Timecode ruler
          Container(
            height: 30,
            width: double.infinity,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: const Center(
              child: Text(
                '00:00:00:00',
                style: TextStyle(fontFamily: 'monospace', color: AppTheme.textSecondary),
              ),
            ),
          ),
          // Tracks area
          const Expanded(
            child: InteractiveTimeline(),
          ),
        ],
      ),
    );
  }
}