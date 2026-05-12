import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class VideoPreview extends ConsumerStatefulWidget {
  const VideoPreview({super.key});

  @override
  ConsumerState<VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends ConsumerState<VideoPreview> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    // In a real app, this would initialize with the selected clip.
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: _controller != null && _controller!.value.isInitialized
          ? AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            )
          : const Center(
              child: Text(
                'No Media Selected',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            ),
    );
  }
}
