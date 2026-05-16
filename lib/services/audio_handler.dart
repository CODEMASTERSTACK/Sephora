import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';

ProEditorAudioHandler? audioHandler;

Future<ProEditorAudioHandler> initAudioService() async {
  final handler = await AudioService.init(
    builder: () => ProEditorAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.proeditor.audio',
      androidNotificationChannelName: 'ProEditor Audio',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
  audioHandler = handler;
  return handler;
}

class ProEditorAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  ProEditorAudioHandler() {
    _player.onPlayerStateChanged.listen((state) {
      final playing = state == PlayerState.playing;
      playbackState.add(playbackState.value.copyWith(
        playing: playing,
        controls: [
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
        ],
        androidCompactActionIndices: const [0],
        processingState: AudioProcessingState.ready,
      ));
    });

    _player.onPositionChanged.listen((position) {
      playbackState.add(
        playbackState.value.copyWith(updatePosition: position),
      );
    });

    _player.onPlayerComplete.listen((_) {
      playbackState.add(playbackState.value.copyWith(
        playing: false,
        processingState: AudioProcessingState.completed,
      ));
    });
  }

  Future<void> playFile(String path, {String title = 'ProEditor Audio'}) async {
    mediaItem.add(MediaItem(
      id: path,
      title: title,
      album: 'ProEditor Export',
    ));

    playbackState.add(playbackState.value.copyWith(
      playing: false,
      controls: [MediaControl.play, MediaControl.stop],
      processingState: AudioProcessingState.loading,
    ));

    await _player.setSourceDeviceFile(path);
    await _player.resume();
  }

  @override
  Future<void> play() => _player.resume();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    mediaItem.add(null);
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      processingState: AudioProcessingState.idle,
    ));
    await super.stop();
  }

  Stream<PlayerState> get playerStateStream => _player.onPlayerStateChanged;
  Stream<Duration> get positionStream => _player.onPositionChanged;
  Stream<Duration> get durationStream => _player.onDurationChanged;
  bool get isPlaying => _player.state == PlayerState.playing;

  @override
  Future<void> onTaskRemoved() => stop();
}
