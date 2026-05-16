import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

// ─── Sub-models ──────────────────────────────────────────────────────────────

class Keyframe {
  final String id;
  final double timeMs;      // position in clip (ms)
  final double posX;        // 0.0 = center
  final double posY;
  final double scale;       // 1.0 = 100%
  final double rotation;    // degrees
  final double opacity;     // 0.0–1.0
  final double easeIn;      // 0.0–1.0 bezier handle
  final double easeOut;

  const Keyframe({
    required this.id,
    required this.timeMs,
    this.posX = 0.0,
    this.posY = 0.0,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.opacity = 1.0,
    this.easeIn = 0.33,
    this.easeOut = 0.67,
  });

  Keyframe copyWith({
    String? id, double? timeMs, double? posX, double? posY,
    double? scale, double? rotation, double? opacity,
    double? easeIn, double? easeOut,
  }) => Keyframe(
    id: id ?? this.id,
    timeMs: timeMs ?? this.timeMs,
    posX: posX ?? this.posX,
    posY: posY ?? this.posY,
    scale: scale ?? this.scale,
    rotation: rotation ?? this.rotation,
    opacity: opacity ?? this.opacity,
    easeIn: easeIn ?? this.easeIn,
    easeOut: easeOut ?? this.easeOut,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'timeMs': timeMs,
    'posX': posX,
    'posY': posY,
    'scale': scale,
    'rotation': rotation,
    'opacity': opacity,
    'easeIn': easeIn,
    'easeOut': easeOut,
  };

  factory Keyframe.fromJson(Map<String, dynamic> json) => Keyframe(
    id: json['id'],
    timeMs: (json['timeMs'] as num).toDouble(),
    posX: (json['posX'] as num?)?.toDouble() ?? 0.0,
    posY: (json['posY'] as num?)?.toDouble() ?? 0.0,
    scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
    rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
    opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
    easeIn: (json['easeIn'] as num?)?.toDouble() ?? 0.33,
    easeOut: (json['easeOut'] as num?)?.toDouble() ?? 0.67,
  );
}

class SpeedPoint {
  final String id;
  final double timeMs;  // position in clip (ms)
  final double speed;   // 0.25–4.0
  final double ease;    // 0.0 = sharp, 1.0 = smooth ramp

  const SpeedPoint({
    required this.id,
    required this.timeMs,
    this.speed = 1.0,
    this.ease = 0.5,
  });

  SpeedPoint copyWith({
    String? id, double? timeMs, double? speed, double? ease,
  }) => SpeedPoint(
    id: id ?? this.id,
    timeMs: timeMs ?? this.timeMs,
    speed: speed ?? this.speed,
    ease: ease ?? this.ease,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'timeMs': timeMs,
    'speed': speed,
    'ease': ease,
  };

  factory SpeedPoint.fromJson(Map<String, dynamic> json) => SpeedPoint(
    id: json['id'],
    timeMs: (json['timeMs'] as num).toDouble(),
    speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
    ease: (json['ease'] as num?)?.toDouble() ?? 0.5,
  );
}

class ColorGrade {
  // Basic adjustments
  final double contrast;      // -100 to 100
  final double highlights;    // -100 to 100
  final double shadows;       // -100 to 100
  final double temperature;   // -100 to 100
  final double tint;          // -100 to 100

  // HSL per-channel [red, orange, yellow, green, cyan, blue, magenta]
  final List<double> hue;
  final List<double> saturation;
  final List<double> luminance;

  // LUT
  final String? lutPath;
  final String? lutName;
  final double lutIntensity; // 0.0–1.0

  const ColorGrade({
    this.contrast = 0,
    this.highlights = 0,
    this.shadows = 0,
    this.temperature = 0,
    this.tint = 0,
    this.hue = const [0, 0, 0, 0, 0, 0, 0],
    this.saturation = const [0, 0, 0, 0, 0, 0, 0],
    this.luminance = const [0, 0, 0, 0, 0, 0, 0],
    this.lutPath,
    this.lutName,
    this.lutIntensity = 1.0,
  });

  ColorGrade copyWith({
    double? contrast, double? highlights, double? shadows,
    double? temperature, double? tint,
    List<double>? hue, List<double>? saturation, List<double>? luminance,
    String? lutPath, String? lutName, double? lutIntensity,
    bool clearLut = false,
  }) => ColorGrade(
    contrast: contrast ?? this.contrast,
    highlights: highlights ?? this.highlights,
    shadows: shadows ?? this.shadows,
    temperature: temperature ?? this.temperature,
    tint: tint ?? this.tint,
    hue: hue ?? this.hue,
    saturation: saturation ?? this.saturation,
    luminance: luminance ?? this.luminance,
    lutPath: clearLut ? null : (lutPath ?? this.lutPath),
    lutName: clearLut ? null : (lutName ?? this.lutName),
    lutIntensity: lutIntensity ?? this.lutIntensity,
  );

  Map<String, dynamic> toJson() => {
    'contrast': contrast,
    'highlights': highlights,
    'shadows': shadows,
    'temperature': temperature,
    'tint': tint,
    'hue': hue,
    'saturation': saturation,
    'luminance': luminance,
    'lutPath': lutPath,
    'lutName': lutName,
    'lutIntensity': lutIntensity,
  };

  factory ColorGrade.fromJson(Map<String, dynamic> json) => ColorGrade(
    contrast: (json['contrast'] as num?)?.toDouble() ?? 0,
    highlights: (json['highlights'] as num?)?.toDouble() ?? 0,
    shadows: (json['shadows'] as num?)?.toDouble() ?? 0,
    temperature: (json['temperature'] as num?)?.toDouble() ?? 0,
    tint: (json['tint'] as num?)?.toDouble() ?? 0,
    hue: (json['hue'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? const [0, 0, 0, 0, 0, 0, 0],
    saturation: (json['saturation'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? const [0, 0, 0, 0, 0, 0, 0],
    luminance: (json['luminance'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? const [0, 0, 0, 0, 0, 0, 0],
    lutPath: json['lutPath'],
    lutName: json['lutName'],
    lutIntensity: (json['lutIntensity'] as num?)?.toDouble() ?? 1.0,
  );
}

// ─── Clip ────────────────────────────────────────────────────────────────────

class Clip {
  final String id;
  final String path;
  final String type;           // 'video' | 'audio' | 'image'
  final int trackIndex;        // 0-11
  final Duration start;        // position on timeline
  final Duration duration;     // source duration
  final Duration trimStart;
  final Duration trimEnd;

  // Playback
  final double volume;
  final double speed;
  final List<SpeedPoint> speedPoints;

  // Audio DSP (shared with audio editor)
  final double tempo;
  final double pitchShift;
  final bool isCompressed;
  final List<double> eqBands;

  // Visual
  final double opacity;
  final String blendMode;       // 'normal','multiply','screen','overlay','darken','lighten','difference','exclusion'
  final ColorGrade colorGrade;
  final List<Keyframe> keyframes;

  // Proxy
  final String? proxyPath;
  final bool isGeneratingProxy;

  // 3D Spatial Audio
  final bool spatial3dEnabled;
  final double spatial3dRotation;   // 0.1–5.0 Hz (rotation speed around head)
  final double spatial3dWidth;      // 0.0–4.0 (stereo widening multiplier)
  final double spatial3dDepth;      // 0.0–1.0 (reverb/echo depth)
  final double spatial3dElevation;  // -1.0 to 1.0 (simulated vertical position)

  // Motion tracking placeholder
  final bool motionTrackingEnabled;
  final String? trackedObjectId;

  Clip({
    required this.id,
    required this.path,
    required this.type,
    this.trackIndex = 0,
    required this.start,
    required this.duration,
    this.trimStart = Duration.zero,
    Duration? trimEnd,
    this.volume = 1.0,
    this.speed = 1.0,
    this.speedPoints = const [],
    this.tempo = 1.0,
    this.pitchShift = 0.0,
    this.isCompressed = false,
    this.eqBands = const [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    this.opacity = 1.0,
    this.blendMode = 'normal',
    this.colorGrade = const ColorGrade(),
    this.keyframes = const [],
    this.proxyPath,
    this.isGeneratingProxy = false,
    this.spatial3dEnabled = false,
    this.spatial3dRotation = 1.0,
    this.spatial3dWidth = 2.0,
    this.spatial3dDepth = 0.3,
    this.spatial3dElevation = 0.0,
    this.motionTrackingEnabled = false,
    this.trackedObjectId,
  }) : trimEnd = trimEnd ?? duration;

  Duration get activeDuration => trimEnd - trimStart;

  Clip copyWith({
    String? id, String? path, String? type, int? trackIndex,
    Duration? start, Duration? duration, Duration? trimStart, Duration? trimEnd,
    double? volume, double? speed, List<SpeedPoint>? speedPoints,
    double? tempo, double? pitchShift, bool? isCompressed, List<double>? eqBands,
    double? opacity, String? blendMode, ColorGrade? colorGrade,
    List<Keyframe>? keyframes, String? proxyPath, bool? isGeneratingProxy,
    bool? spatial3dEnabled, double? spatial3dRotation, double? spatial3dWidth,
    double? spatial3dDepth, double? spatial3dElevation,
    bool? motionTrackingEnabled, String? trackedObjectId,
  }) => Clip(
    id: id ?? this.id,
    path: path ?? this.path,
    type: type ?? this.type,
    trackIndex: trackIndex ?? this.trackIndex,
    start: start ?? this.start,
    duration: duration ?? this.duration,
    trimStart: trimStart ?? this.trimStart,
    trimEnd: trimEnd ?? this.trimEnd,
    volume: volume ?? this.volume,
    speed: speed ?? this.speed,
    speedPoints: speedPoints ?? this.speedPoints,
    tempo: tempo ?? this.tempo,
    pitchShift: pitchShift ?? this.pitchShift,
    isCompressed: isCompressed ?? this.isCompressed,
    eqBands: eqBands ?? this.eqBands,
    opacity: opacity ?? this.opacity,
    blendMode: blendMode ?? this.blendMode,
    colorGrade: colorGrade ?? this.colorGrade,
    keyframes: keyframes ?? this.keyframes,
    proxyPath: proxyPath ?? this.proxyPath,
    isGeneratingProxy: isGeneratingProxy ?? this.isGeneratingProxy,
    spatial3dEnabled: spatial3dEnabled ?? this.spatial3dEnabled,
    spatial3dRotation: spatial3dRotation ?? this.spatial3dRotation,
    spatial3dWidth: spatial3dWidth ?? this.spatial3dWidth,
    spatial3dDepth: spatial3dDepth ?? this.spatial3dDepth,
    spatial3dElevation: spatial3dElevation ?? this.spatial3dElevation,
    motionTrackingEnabled: motionTrackingEnabled ?? this.motionTrackingEnabled,
    trackedObjectId: trackedObjectId ?? this.trackedObjectId,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'type': type,
    'trackIndex': trackIndex,
    'startMs': start.inMilliseconds,
    'durationMs': duration.inMilliseconds,
    'trimStartMs': trimStart.inMilliseconds,
    'trimEndMs': trimEnd.inMilliseconds,
    'volume': volume,
    'speed': speed,
    'speedPoints': speedPoints.map((e) => e.toJson()).toList(),
    'tempo': tempo,
    'pitchShift': pitchShift,
    'isCompressed': isCompressed,
    'eqBands': eqBands,
    'opacity': opacity,
    'blendMode': blendMode,
    'colorGrade': colorGrade.toJson(),
    'keyframes': keyframes.map((e) => e.toJson()).toList(),
    'proxyPath': proxyPath,
    'isGeneratingProxy': isGeneratingProxy,
    'spatial3dEnabled': spatial3dEnabled,
    'spatial3dRotation': spatial3dRotation,
    'spatial3dWidth': spatial3dWidth,
    'spatial3dDepth': spatial3dDepth,
    'spatial3dElevation': spatial3dElevation,
    'motionTrackingEnabled': motionTrackingEnabled,
    'trackedObjectId': trackedObjectId,
  };

  factory Clip.fromJson(Map<String, dynamic> json) => Clip(
    id: json['id'],
    path: json['path'],
    type: json['type'],
    trackIndex: json['trackIndex'] ?? 0,
    start: Duration(milliseconds: json['startMs'] ?? 0),
    duration: Duration(milliseconds: json['durationMs'] ?? 0),
    trimStart: Duration(milliseconds: json['trimStartMs'] ?? 0),
    trimEnd: Duration(milliseconds: json['trimEndMs'] ?? json['durationMs'] ?? 0),
    volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
    speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
    speedPoints: (json['speedPoints'] as List?)?.map((e) => SpeedPoint.fromJson(e)).toList() ?? const [],
    tempo: (json['tempo'] as num?)?.toDouble() ?? 1.0,
    pitchShift: (json['pitchShift'] as num?)?.toDouble() ?? 0.0,
    isCompressed: json['isCompressed'] ?? false,
    eqBands: (json['eqBands'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? const [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
    blendMode: json['blendMode'] ?? 'normal',
    colorGrade: json['colorGrade'] != null ? ColorGrade.fromJson(json['colorGrade']) : const ColorGrade(),
    keyframes: (json['keyframes'] as List?)?.map((e) => Keyframe.fromJson(e)).toList() ?? const [],
    proxyPath: json['proxyPath'],
    isGeneratingProxy: json['isGeneratingProxy'] ?? false,
    spatial3dEnabled: json['spatial3dEnabled'] ?? false,
    spatial3dRotation: (json['spatial3dRotation'] as num?)?.toDouble() ?? 1.0,
    spatial3dWidth: (json['spatial3dWidth'] as num?)?.toDouble() ?? 2.0,
    spatial3dDepth: (json['spatial3dDepth'] as num?)?.toDouble() ?? 0.3,
    spatial3dElevation: (json['spatial3dElevation'] as num?)?.toDouble() ?? 0.0,
    motionTrackingEnabled: json['motionTrackingEnabled'] ?? false,
    trackedObjectId: json['trackedObjectId'],
  );
}

// ─── VideoTrack ───────────────────────────────────────────────────────────────

class VideoTrack {
  final int index;
  final String label;
  final bool isMuted;
  final bool isSolo;
  final bool isLocked;
  final double height;      // px, default 64.0

  const VideoTrack({
    required this.index,
    required this.label,
    this.isMuted = false,
    this.isSolo = false,
    this.isLocked = false,
    this.height = 64.0,
  });

  VideoTrack copyWith({
    int? index, String? label, bool? isMuted, bool? isSolo,
    bool? isLocked, double? height,
  }) => VideoTrack(
    index: index ?? this.index,
    label: label ?? this.label,
    isMuted: isMuted ?? this.isMuted,
    isSolo: isSolo ?? this.isSolo,
    isLocked: isLocked ?? this.isLocked,
    height: height ?? this.height,
  );

  Map<String, dynamic> toJson() => {
    'index': index,
    'label': label,
    'isMuted': isMuted,
    'isSolo': isSolo,
    'isLocked': isLocked,
    'height': height,
  };

  factory VideoTrack.fromJson(Map<String, dynamic> json) => VideoTrack(
    index: json['index'],
    label: json['label'],
    isMuted: json['isMuted'] ?? false,
    isSolo: json['isSolo'] ?? false,
    isLocked: json['isLocked'] ?? false,
    height: (json['height'] as num?)?.toDouble() ?? 64.0,
  );
}

// ─── EditorState ─────────────────────────────────────────────────────────────

class EditorState {
  final String? projectId;
  final List<Clip> videoClips;
  final List<Clip> audioClips;
  final List<VideoTrack> tracks;
  final Duration playheadPosition;
  final bool isPlaying;
  final String? selectedClipId;
  final int selectedTrackIndex;
  final bool snapEnabled;
  final double snapThresholdMs;   // ms within which to snap

  EditorState({
    this.projectId,
    this.videoClips = const [],
    this.audioClips = const [],
    List<VideoTrack>? tracks,
    this.playheadPosition = Duration.zero,
    this.isPlaying = false,
    this.selectedClipId,
    this.selectedTrackIndex = 0,
    this.snapEnabled = true,
    this.snapThresholdMs = 200.0,
  }) : tracks = tracks ?? _defaultTracks();

  static List<VideoTrack> _defaultTracks() => [
    const VideoTrack(index: 0, label: 'V1'),
    const VideoTrack(index: 1, label: 'V2'),
    const VideoTrack(index: 2, label: 'V3'),
    const VideoTrack(index: 3, label: 'V4'),
    const VideoTrack(index: 4, label: 'V5'),
    const VideoTrack(index: 5, label: 'V6'),
    const VideoTrack(index: 6, label: 'A1'),
    const VideoTrack(index: 7, label: 'A2'),
    const VideoTrack(index: 8, label: 'A3'),
    const VideoTrack(index: 9, label: 'A4'),
    const VideoTrack(index: 10, label: 'A5'),
    const VideoTrack(index: 11, label: 'A6'),
  ];

  // All clips across both lists unified
  List<Clip> get allClips => [...videoClips, ...audioClips];

  Clip? clipById(String id) {
    try {
      return allClips.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  // Clips on a specific track index
  List<Clip> clipsOnTrack(int trackIndex) =>
      allClips.where((c) => c.trackIndex == trackIndex).toList()
        ..sort((a, b) => a.start.compareTo(b.start));

  EditorState copyWith({
    String? projectId,
    List<Clip>? videoClips,
    List<Clip>? audioClips,
    List<VideoTrack>? tracks,
    Duration? playheadPosition,
    bool? isPlaying,
    String? selectedClipId,
    bool clearSelectedClip = false,
    int? selectedTrackIndex,
    bool? snapEnabled,
    double? snapThresholdMs,
  }) => EditorState(
    projectId: projectId ?? this.projectId,
    videoClips: videoClips ?? this.videoClips,
    audioClips: audioClips ?? this.audioClips,
    tracks: tracks ?? this.tracks,
    playheadPosition: playheadPosition ?? this.playheadPosition,
    isPlaying: isPlaying ?? this.isPlaying,
    selectedClipId: clearSelectedClip ? null : (selectedClipId ?? this.selectedClipId),
    selectedTrackIndex: selectedTrackIndex ?? this.selectedTrackIndex,
    snapEnabled: snapEnabled ?? this.snapEnabled,
    snapThresholdMs: snapThresholdMs ?? this.snapThresholdMs,
  );

  Map<String, dynamic> toJson() => {
    'projectId': projectId,
    'videoClips': videoClips.map((c) => c.toJson()).toList(),
    'audioClips': audioClips.map((c) => c.toJson()).toList(),
    'tracks': tracks.map((t) => t.toJson()).toList(),
    'playheadPositionMs': playheadPosition.inMilliseconds,
    'snapEnabled': snapEnabled,
  };

  factory EditorState.fromJson(Map<String, dynamic> json) => EditorState(
    projectId: json['projectId'],
    videoClips: (json['videoClips'] as List?)?.map((e) => Clip.fromJson(e)).toList() ?? const [],
    audioClips: (json['audioClips'] as List?)?.map((e) => Clip.fromJson(e)).toList() ?? const [],
    tracks: json['tracks'] != null ? (json['tracks'] as List).map((e) => VideoTrack.fromJson(e)).toList() : null,
    playheadPosition: Duration(milliseconds: json['playheadPositionMs'] ?? 0),
    snapEnabled: json['snapEnabled'] ?? true,
  );
}

// ─── EditorNotifier ───────────────────────────────────────────────────────────

class EditorNotifier extends Notifier<EditorState> {
  @override
  EditorState build() => EditorState();

  // ── Persistence ────────────────────────────────────────────────────────────

  Future<void> loadProject(String projectId) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/editor_state_$projectId.json');
      if (await file.exists()) {
        final jsonStr = await file.readAsString();
        final Map<String, dynamic> data = jsonDecode(jsonStr);
        state = EditorState.fromJson(data);
      } else {
        state = EditorState(projectId: projectId);
      }
    } catch (e) {
      debugPrint('Error loading project state: $e');
      state = EditorState(projectId: projectId);
    }
  }

  Future<void> saveProject() async {
    final projectId = state.projectId;
    if (projectId == null) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/editor_state_$projectId.json');
      final jsonStr = jsonEncode(state.toJson());
      await file.writeAsString(jsonStr);
    } catch (e) {
      debugPrint('Error saving project state: $e');
    }
  }

  // ── Clip import ────────────────────────────────────────────────────────────

  void addVideoClip(Clip clip) {
    state = state.copyWith(videoClips: [...state.videoClips, clip]);
  }

  void addAudioClip(Clip clip) {
    state = state.copyWith(audioClips: [...state.audioClips, clip]);
  }

  void addClipToTrack(Clip clip, int trackIndex) {
    final track = state.tracks[trackIndex];
    if (track.isLocked) return;

    final positioned = _applyMagneticSnap(clip.copyWith(trackIndex: trackIndex), trackIndex);

    if (trackIndex >= 6) {
      state = state.copyWith(audioClips: [...state.audioClips, positioned]);
    } else {
      state = state.copyWith(videoClips: [...state.videoClips, positioned]);
    }
  }

  // ── Magnetic snapping ───────────────────────────────────────────────────────

  Clip _applyMagneticSnap(Clip clip, int trackIndex) {
    if (!state.snapEnabled) return clip;
    final threshold = Duration(milliseconds: state.snapThresholdMs.toInt());
    final clipsOnTrack = state.clipsOnTrack(trackIndex).where((c) => c.id != clip.id);

    Duration best = clip.start;
    Duration bestDist = threshold + const Duration(milliseconds: 1);

    for (final other in clipsOnTrack) {
      // Snap clip start to other's end
      final dist1 = (clip.start - other.start - other.activeDuration).abs();
      if (dist1 < bestDist) { bestDist = dist1; best = other.start + other.activeDuration; }
      // Snap clip end to other's start
      final clipEnd = clip.start + clip.activeDuration;
      final dist2 = (clipEnd - other.start).abs();
      if (dist2 < bestDist) { bestDist = dist2; best = other.start - clip.activeDuration; }
    }

    return clip.copyWith(start: best < Duration.zero ? Duration.zero : best);
  }

  // ── Move clip ───────────────────────────────────────────────────────────────

  void moveClip(String id, int newTrackIndex, Duration newStart) {
    if (newTrackIndex < 0 || newTrackIndex >= state.tracks.length) return;
    final track = state.tracks[newTrackIndex];
    if (track.isLocked) return;

    final clip = state.clipById(id);
    if (clip == null) return;

    final moved = clip.copyWith(trackIndex: newTrackIndex, start: newStart);
    final snapped = _applyMagneticSnap(moved, newTrackIndex);

    // Remove from both lists, then add to the correct one based on new track
    final withoutOld = _mapAllClips((c) => c).where((c) => c.id != id).toList();
    final updated = [...withoutOld, snapped];

    state = state.copyWith(
      videoClips: updated.where((c) => c.trackIndex < 6).toList(),
      audioClips: updated.where((c) => c.trackIndex >= 6).toList(),
    );
  }

  // ── Playback ────────────────────────────────────────────────────────────────

  void updatePlayhead(Duration position) =>
      state = state.copyWith(playheadPosition: position);

  void togglePlay() {
    if (state.audioClips.isEmpty && state.videoClips.isEmpty) return;
    state = state.copyWith(isPlaying: !state.isPlaying);
  }

  // ── Selection ───────────────────────────────────────────────────────────────

  void selectClip(String id) => state = state.copyWith(selectedClipId: id);

  void clearSelection() => state = state.copyWith(clearSelectedClip: true);

  void selectTrack(int index) => state = state.copyWith(selectedTrackIndex: index);

  // ── Delete ──────────────────────────────────────────────────────────────────

  void deleteClip(String id) {
    state = state.copyWith(
      videoClips: state.videoClips.where((c) => c.id != id).toList(),
      audioClips: state.audioClips.where((c) => c.id != id).toList(),
      clearSelectedClip: state.selectedClipId == id,
    );
  }

  // ── Generic clip state update ───────────────────────────────────────────────

  void updateClipState(String id, Clip Function(Clip) updater) {
    state = state.copyWith(
      videoClips: state.videoClips.map((c) => c.id == id ? updater(c) : c).toList(),
      audioClips: state.audioClips.map((c) => c.id == id ? updater(c) : c).toList(),
    );
  }

  // ── Track operations ────────────────────────────────────────────────────────

  void updateTrack(int index, VideoTrack Function(VideoTrack) updater) {
    final updated = List<VideoTrack>.from(state.tracks);
    updated[index] = updater(updated[index]);
    state = state.copyWith(tracks: updated);
  }

  void toggleTrackMute(int index) =>
      updateTrack(index, (t) => t.copyWith(isMuted: !t.isMuted));

  void toggleTrackSolo(int index) =>
      updateTrack(index, (t) => t.copyWith(isSolo: !t.isSolo));

  void toggleTrackLock(int index) =>
      updateTrack(index, (t) => t.copyWith(isLocked: !t.isLocked));

  // ── Keyframes ───────────────────────────────────────────────────────────────

  void addKeyframe(String clipId, Keyframe keyframe) {
    updateClipState(clipId, (c) {
      final frames = List<Keyframe>.from(c.keyframes)..add(keyframe);
      frames.sort((a, b) => a.timeMs.compareTo(b.timeMs));
      return c.copyWith(keyframes: frames);
    });
  }

  void updateKeyframe(String clipId, String keyframeId, Keyframe Function(Keyframe) updater) {
    updateClipState(clipId, (c) => c.copyWith(
      keyframes: c.keyframes.map((k) => k.id == keyframeId ? updater(k) : k).toList(),
    ));
  }

  void deleteKeyframe(String clipId, String keyframeId) {
    updateClipState(clipId, (c) => c.copyWith(
      keyframes: c.keyframes.where((k) => k.id != keyframeId).toList(),
    ));
  }

  // ── Speed ramp ──────────────────────────────────────────────────────────────

  void addSpeedPoint(String clipId, SpeedPoint point) {
    updateClipState(clipId, (c) {
      final points = List<SpeedPoint>.from(c.speedPoints)..add(point);
      points.sort((a, b) => a.timeMs.compareTo(b.timeMs));
      return c.copyWith(speedPoints: points);
    });
  }

  void updateSpeedPoint(String clipId, String pointId, SpeedPoint Function(SpeedPoint) updater) {
    updateClipState(clipId, (c) => c.copyWith(
      speedPoints: c.speedPoints.map((p) => p.id == pointId ? updater(p) : p).toList(),
    ));
  }

  void deleteSpeedPoint(String clipId, String pointId) {
    updateClipState(clipId, (c) => c.copyWith(
      speedPoints: c.speedPoints.where((p) => p.id != pointId).toList(),
    ));
  }

  // ── Color grading ───────────────────────────────────────────────────────────

  void applyColorGrade(String clipId, ColorGrade Function(ColorGrade) updater) {
    updateClipState(clipId, (c) => c.copyWith(colorGrade: updater(c.colorGrade)));
  }

  // ── Blend mode & opacity ────────────────────────────────────────────────────

  void setBlendMode(String clipId, String mode) {
    updateClipState(clipId, (c) => c.copyWith(blendMode: mode));
  }

  void setOpacity(String clipId, double opacity) {
    updateClipState(clipId, (c) => c.copyWith(opacity: opacity.clamp(0.0, 1.0)));
  }

  // ── Proxy ───────────────────────────────────────────────────────────────────

  void setProxyGenerating(String clipId, bool generating) {
    updateClipState(clipId, (c) => c.copyWith(isGeneratingProxy: generating));
  }

  void setProxyPath(String clipId, String proxyPath) {
    updateClipState(clipId, (c) => c.copyWith(
      proxyPath: proxyPath,
      isGeneratingProxy: false,
    ));
  }

  // ── Split ───────────────────────────────────────────────────────────────────

  void splitClip(String id, Duration playheadAbsolute) {
    final target = state.clipById(id);
    if (target == null) return;

    // Convert absolute playhead to position relative to clip start
    final relativeMs = playheadAbsolute.inMilliseconds - target.start.inMilliseconds;

    // Guard: split point must be within the clip's active range (at least 100ms from edges)
    if (relativeMs < 100 || relativeMs > target.activeDuration.inMilliseconds - 100) {
      return; // Too close to edge or outside clip — do nothing
    }

    final splitPoint = Duration(milliseconds: relativeMs);

    final clip1 = target.copyWith(
      trimEnd: target.trimStart + splitPoint,
    );
    final clip2 = target.copyWith(
      id: '${target.id}_split_${playheadAbsolute.inMilliseconds}',
      start: target.start + splitPoint,
      trimStart: target.trimStart + splitPoint,
    );

    if (target.type == 'audio') {
      final list = List<Clip>.from(state.audioClips);
      final idx = list.indexWhere((c) => c.id == id);
      if (idx < 0) return;
      list.replaceRange(idx, idx + 1, [clip1, clip2]);
      state = state.copyWith(audioClips: list);
    } else {
      final list = List<Clip>.from(state.videoClips);
      final idx = list.indexWhere((c) => c.id == id);
      if (idx < 0) return;
      list.replaceRange(idx, idx + 1, [clip1, clip2]);
      state = state.copyWith(videoClips: list);
    }
  }

  // ── Settings ────────────────────────────────────────────────────────────────

  void toggleSnap() => state = state.copyWith(snapEnabled: !state.snapEnabled);

  // ── Internal helpers ────────────────────────────────────────────────────────

  List<Clip> _mapAllClips(Clip Function(Clip) fn) =>
      state.allClips.map(fn).toList();
}

// ─── Providers ────────────────────────────────────────────────────────────────

/// Video editor screen state (tracks V1-V6, A1-A6)
final editorProvider = NotifierProvider<EditorNotifier, EditorState>(
  EditorNotifier.new,
);

/// Audio mix screen state — completely independent from video editor
final audioEditorProvider = NotifierProvider<EditorNotifier, EditorState>(
  EditorNotifier.new,
);
