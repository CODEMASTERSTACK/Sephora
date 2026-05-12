import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'interactive_timeline.dart';

class TimelineView extends ConsumerWidget {
  final bool isAudioOnly;

  const TimelineView({
    super.key,
    this.isAudioOnly = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: const Color(0xFF0E0E16),
      child: InteractiveTimeline(isAudioOnly: isAudioOnly),
    );
  }
}