import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/editor_provider.dart';
import '../../../theme/app_theme.dart';

class CompressorPanel extends ConsumerStatefulWidget {
  final Clip clip;
  const CompressorPanel({super.key, required this.clip});

  @override
  ConsumerState<CompressorPanel> createState() => _CompressorPanelState();
}

class _CompressorPanelState extends ConsumerState<CompressorPanel> {
  late bool _isCompressed;

  @override
  void initState() {
    super.initState();
    _isCompressed = widget.clip.isCompressed;
  }

  void _toggleCompression(bool val) {
    setState(() => _isCompressed = val);
    ref.read(audioEditorProvider.notifier).updateClipState(
      widget.clip.id, 
      (c) => c.copyWith(isCompressed: val),
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
              const Text('Dynamic Compressor', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              Switch(
                value: _isCompressed,
                activeColor: AppTheme.accent,
                onChanged: _toggleCompression,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Evens out audio levels so loud sounds and soft whispers stay at a similar, listenable volume.', 
            style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 24),
          Opacity(
            opacity: _isCompressed ? 1.0 : 0.4,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildKnob('Threshold', '-20dB'),
                _buildKnob('Ratio', '4:1'),
                _buildKnob('Makeup', '+4dB'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKnob(String label, String value) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.accent, width: 2),
          ),
          child: const Center(child: Icon(Icons.settings_input_component, color: AppTheme.accent)),
        ),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }
}
