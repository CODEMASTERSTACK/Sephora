import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/editor_provider.dart';
import '../../../theme/app_theme.dart';

class EQPanel extends ConsumerStatefulWidget {
  final Clip clip;
  const EQPanel({super.key, required this.clip});

  @override
  ConsumerState<EQPanel> createState() => _EQPanelState();
}

class _EQPanelState extends ConsumerState<EQPanel> {
  late List<double> _bands;
  final List<String> _labels = ['32', '64', '125', '250', '500', '1k', '2k', '4k', '8k', '16k'];

  @override
  void initState() {
    super.initState();
    _bands = List.from(widget.clip.eqBands);
  }

  void _applyPreset(List<double> preset) {
    setState(() {
      _bands = List.from(preset);
    });
    _saveToState();
  }

  void _saveToState() {
    ref.read(audioEditorProvider.notifier).updateClipState(
      widget.clip.id, 
      (c) => c.copyWith(eqBands: _bands),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: 350,
      decoration: const BoxDecoration(
        color: AppTheme.panelBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('10-Band Parametric EQ', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
            ],
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ActionChip(label: const Text('Flat'), onPressed: () => _applyPreset([0,0,0,0,0,0,0,0,0,0])),
                const SizedBox(width: 8),
                ActionChip(label: const Text('Bass Boost'), onPressed: () => _applyPreset([4,5,4,2,0,0,0,0,0,0])),
                const SizedBox(width: 8),
                ActionChip(label: const Text('Podcast Clear'), onPressed: () => _applyPreset([0, -2, -2, 0, 2, 4, 3, 2, 0, 0])),
                const SizedBox(width: 8),
                ActionChip(label: const Text('Treble Reducer'), onPressed: () => _applyPreset([0,0,0,0,0,-1,-2,-3,-4,-5])),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(10, (index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Column(
                      children: [
                        Expanded(
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: Slider(
                              value: _bands[index],
                              min: -12.0,
                              max: 12.0,
                              activeColor: AppTheme.accent,
                              onChanged: (val) {
                                setState(() => _bands[index] = val);
                              },
                              onChangeEnd: (val) => _saveToState(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(_labels[index], style: const TextStyle(color: Colors.white54, fontSize: 10)),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
