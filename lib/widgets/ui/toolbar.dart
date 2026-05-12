import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../providers/editor_provider.dart';
import 'app_toast.dart';
import 'audio_tools/eq_panel.dart';
import 'audio_tools/compressor_panel.dart';
import 'audio_tools/pitch_tempo_panel.dart';
import 'audio_tools/spatial_audio_panel.dart';
import '../video_tools/keyframe_editor.dart';
import '../video_tools/speed_ramp_panel.dart';
import '../video_tools/color_grade_panel.dart';
import '../video_tools/blend_mode_panel.dart';

class EditorToolbar extends ConsumerWidget {
  final bool isAudioOnly;

  const EditorToolbar({
    super.key,
    this.isAudioOnly = false,
  });

  /// Returns the correct provider based on audio/video mode
  NotifierProvider<EditorNotifier, EditorState> get _prov =>
      isAudioOnly ? audioEditorProvider : editorProvider;

  void _showSliderDialog(
    BuildContext context,
    String title,
    double initialValue,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.panelBackground,
      builder: (context) {
        double value = initialValue;
        return StatefulBuilder(
          builder: (context, setState) => Container(
            padding: const EdgeInsets.all(24),
            height: 200,
            child: Column(
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Slider(
                  value: value,
                  min: min,
                  max: max,
                  activeColor: AppTheme.accent,
                  onChanged: (val) {
                    setState(() => value = val);
                    onChanged(val);
                  },
                ),
                Text(value.toStringAsFixed(2), style: const TextStyle(color: Colors.white54)),
              ],
            ),
          ),
        );
      },
    );
  }

  Clip? _getTarget(WidgetRef ref) {
    final state = ref.read(_prov);
    final allClips = isAudioOnly ? state.audioClips : state.videoClips;
    // Use selected clip first, then fall back to first clip in list
    final id = state.selectedClipId;
    if (id != null) {
      final c = state.clipById(id);
      if (c != null) return c;
    }
    return allClips.firstOrNull;
  }

  void _handleToolTap(BuildContext context, WidgetRef ref, String label) {
    final clip = _getTarget(ref);

    if (clip == null) {
      AppToast.show(context, message: 'Import a clip first!', type: ToastType.warning);
      return;
    }

    switch (label) {
      case 'Split':
        final pos = ref.read(_prov).playheadPosition;
        // Find the clip that the playhead falls within
        Clip? splitTarget = clip;
        final allClips = isAudioOnly
            ? ref.read(_prov).audioClips
            : ref.read(_prov).videoClips;
        for (final c in allClips) {
          final clipEnd = c.start + c.activeDuration;
          if (pos >= c.start && pos <= clipEnd) {
            splitTarget = c;
            break;
          }
        }
        if (splitTarget == null) {
          AppToast.show(context, message: 'Move playhead over a clip to split', type: ToastType.warning);
          return;
        }
        final relMs = pos.inMilliseconds - splitTarget.start.inMilliseconds;
        if (relMs < 100 || relMs > splitTarget.activeDuration.inMilliseconds - 100) {
          AppToast.show(context, message: 'Playhead too close to clip edge', type: ToastType.warning);
          return;
        }
        ref.read(_prov.notifier).splitClip(splitTarget.id, pos);
        AppToast.show(context, message: 'Clip split at playhead ✂️', type: ToastType.success);
        break;

      case 'Volume':
        _showSliderDialog(context, 'Volume', clip.volume, 0.0, 2.0,
          (v) => ref.read(_prov.notifier).updateClipState(clip.id, (c) => c.copyWith(volume: v)));
        break;

      case 'Speed':
        _showSliderDialog(context, 'Speed', clip.speed, 0.25, 4.0,
          (v) => ref.read(_prov.notifier).updateClipState(clip.id, (c) => c.copyWith(speed: v)));
        break;

      case 'EQ':
        showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
          builder: (_) => EQPanel(clip: clip));
        break;

      case 'Compressor':
        showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
          builder: (_) => CompressorPanel(clip: clip));
        break;

      case 'Pitch/Tempo':
        showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
          builder: (_) => PitchTempoPanel(clip: clip));
        break;

      case 'Keyframe':
        showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
          builder: (_) => KeyframeEditor(clip: clip));
        break;

      case 'Speed Ramp':
        showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
          builder: (_) => SpeedRampPanel(clip: clip));
        break;

      case 'Color Grade':
        showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
          builder: (_) => ColorGradePanel(clip: clip));
        break;

      case 'Blend':
        showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
          builder: (_) => BlendModePanel(clip: clip));
        break;

      case '3D Audio':
        showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
          builder: (_) => SpatialAudioPanel(clip: clip));
        break;

      default:
        AppToast.show(context, message: '$label coming soon!', type: ToastType.info);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tools = isAudioOnly
        ? [
            {'icon': Icons.cut, 'label': 'Split'},
            {'icon': Icons.volume_up, 'label': 'Volume'},
            {'icon': Icons.equalizer, 'label': 'EQ'},
            {'icon': Icons.compress, 'label': 'Compressor'},
            {'icon': Icons.speed, 'label': 'Pitch/Tempo'},
            {'icon': Icons.surround_sound, 'label': '3D Audio'},
          ]
        : [
            {'icon': Icons.cut, 'label': 'Split'},
            {'icon': Icons.volume_up, 'label': 'Volume'},
            {'icon': Icons.add_box_outlined, 'label': 'Keyframe'},
            {'icon': Icons.show_chart, 'label': 'Speed Ramp'},
            {'icon': Icons.color_lens_outlined, 'label': 'Color Grade'},
            {'icon': Icons.layers_outlined, 'label': 'Blend'},
            {'icon': Icons.linear_scale, 'label': 'Speed'},
          ];

    return Container(
      height: 80,
      color: AppTheme.panelBackground,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: tools.length,
        itemBuilder: (context, index) {
          final tool = tools[index];
          return InkWell(
            onTap: () => _handleToolTap(context, ref, tool['label'] as String),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(tool['icon'] as IconData, color: Colors.white, size: 26),
                  const SizedBox(height: 5),
                  Text(
                    tool['label'] as String,
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
