import 'package:flutter_riverpod/flutter_riverpod.dart';

class Clip {
  final String id;
  final String path;
  final String type; // 'video' or 'audio'
  final Duration start;
  final Duration duration;

  Clip({
    required this.id,
    required this.path,
    required this.type,
    required this.start,
    required this.duration,
  });
}

class EditorState {
  final List<Clip> videoClips;
  final List<Clip> audioClips;
  final Duration playheadPosition;
  final bool isPlaying;

  EditorState({
    this.videoClips = const [],
    this.audioClips = const [],
    this.playheadPosition = Duration.zero,
    this.isPlaying = false,
  });

  EditorState copyWith({
    List<Clip>? videoClips,
    List<Clip>? audioClips,
    Duration? playheadPosition,
    bool? isPlaying,
  }) {
    return EditorState(
      videoClips: videoClips ?? this.videoClips,
      audioClips: audioClips ?? this.audioClips,
      playheadPosition: playheadPosition ?? this.playheadPosition,
      isPlaying: isPlaying ?? this.isPlaying,
    );
  }
}

class EditorNotifier extends Notifier<EditorState> {
  @override
  EditorState build() {
    return EditorState();
  }

  void addVideoClip(Clip clip) {
    state = state.copyWith(videoClips: [...state.videoClips, clip]);
  }

  void addAudioClip(Clip clip) {
    state = state.copyWith(audioClips: [...state.audioClips, clip]);
  }

  void updatePlayhead(Duration position) {
    state = state.copyWith(playheadPosition: position);
  }

  void togglePlay() {
    state = state.copyWith(isPlaying: !state.isPlaying);
  }
}

final editorProvider = NotifierProvider<EditorNotifier, EditorState>(() {
  return EditorNotifier();
});
