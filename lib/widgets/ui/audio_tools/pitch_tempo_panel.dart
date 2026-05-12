import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/editor_provider.dart';
import '../../../theme/app_theme.dart';

class PitchTempoPanel extends ConsumerStatefulWidget {
  final Clip clip;
  const PitchTempoPanel({super.key, required this.clip});

  @override
  ConsumerState<PitchTempoPanel> createState() => _PitchTempoPanelState();
}

class _PitchTempoPanelState extends ConsumerState<PitchTempoPanel> {
  late double _pitch;
  late double _tempo;

  @override
  void initState() {
    super.initState();
    _pitch = widget.clip.pitchShift;
    _tempo = widget.clip.tempo;
  }

  void _saveToState() {
    ref.read(audioEditorProvider.notifier).updateClipState(
      widget.clip.id, 
      (c) => c.copyWith(pitchShift: _pitch, tempo: _tempo),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      height: 300,
      decoration: const BoxDecoration(
        color: AppTheme.panelBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Pitch & Tempo Shifter', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const SizedBox(width: 60, child: Text('Pitch', style: TextStyle(color: Colors.white))),
              Expanded(
                child: Slider(
                  value: _pitch,
                  min: -12.0,
                  max: 12.0,
                  divisions: 24,
                  activeColor: AppTheme.accent,
                  onChanged: (val) {
                    setState(() => _pitch = val);
                  },
                  onChangeEnd: (val) => _saveToState(),
                ),
              ),
              SizedBox(width: 40, child: Text('${_pitch > 0 ? '+' : ''}${_pitch.toInt()} st', style: const TextStyle(color: Colors.white54))),
            ],
          ),
          const Text('Shifts the voice to sound deeper or higher without changing speed.', style: TextStyle(color: Colors.white38, fontSize: 10)),
          const SizedBox(height: 24),
          Row(
            children: [
              const SizedBox(width: 60, child: Text('Tempo', style: TextStyle(color: Colors.white))),
              Expanded(
                child: Slider(
                  value: _tempo,
                  min: 0.5,
                  max: 2.0,
                  activeColor: AppTheme.accent,
                  onChanged: (val) {
                    setState(() => _tempo = val);
                  },
                  onChangeEnd: (val) => _saveToState(),
                ),
              ),
              SizedBox(width: 40, child: Text('${(_tempo * 100).toInt()}%', style: const TextStyle(color: Colors.white54))),
            ],
          ),
          const Text('Changes playback speed independently of pitch.', style: TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }
}
