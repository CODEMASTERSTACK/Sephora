import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../providers/editor_provider.dart';

class ColorGradePanel extends ConsumerStatefulWidget {
  final Clip clip;
  const ColorGradePanel({super.key, required this.clip});

  @override
  ConsumerState<ColorGradePanel> createState() => _ColorGradePanelState();
}

class _ColorGradePanelState extends ConsumerState<ColorGradePanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _update(ColorGrade Function(ColorGrade) fn) {
    ref.read(editorProvider.notifier).applyColorGrade(widget.clip.id, fn);
  }

  @override
  Widget build(BuildContext context) {
    final clip = ref.watch(editorProvider).clipById(widget.clip.id) ?? widget.clip;
    final grade = clip.colorGrade;

    return Container(
      height: 420,
      decoration: const BoxDecoration(
        color: Color(0xFF141420),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Color Grade', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          TabBar(
            controller: _tabs,
            indicatorColor: Colors.tealAccent,
            labelColor: Colors.tealAccent,
            unselectedLabelColor: Colors.white38,
            tabs: const [Tab(text: 'Basics'), Tab(text: 'HSL'), Tab(text: 'LUT')],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _buildBasicsTab(grade),
                _buildHSLTab(grade),
                _buildLUTTab(grade, clip),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicsTab(ColorGrade grade) {
    final sliders = [
      ('Contrast', grade.contrast, -100.0, 100.0, (v) => _update((g) => g.copyWith(contrast: v))),
      ('Highlights', grade.highlights, -100.0, 100.0, (v) => _update((g) => g.copyWith(highlights: v))),
      ('Shadows', grade.shadows, -100.0, 100.0, (v) => _update((g) => g.copyWith(shadows: v))),
      ('Temperature', grade.temperature, -100.0, 100.0, (v) => _update((g) => g.copyWith(temperature: v))),
      ('Tint', grade.tint, -100.0, 100.0, (v) => _update((g) => g.copyWith(tint: v))),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: sliders.map((s) {
        final (label, value, min, max, onChanged) = s;
        return _buildSliderRow(label, value, min, max, onChanged as Function(double), Colors.tealAccent);
      }).toList(),
    );
  }

  Widget _buildHSLTab(ColorGrade grade) {
    final channelNames = ['Red', 'Orange', 'Yellow', 'Green', 'Cyan', 'Blue', 'Magenta'];
    final channelColors = [
      Colors.red, Colors.orange, Colors.yellow,
      Colors.green, Colors.cyan, Colors.blue, Colors.purple,
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Hue', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...List.generate(7, (i) => _buildSliderRow(
          channelNames[i], grade.hue[i], -180.0, 180.0,
          (v) {
            final newHue = List<double>.from(grade.hue);
            newHue[i] = v;
            _update((g) => g.copyWith(hue: newHue));
          },
          channelColors[i],
        )),
        const Divider(color: Colors.white12, height: 24),
        const Text('Saturation', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...List.generate(7, (i) => _buildSliderRow(
          channelNames[i], grade.saturation[i], -100.0, 100.0,
          (v) {
            final newSat = List<double>.from(grade.saturation);
            newSat[i] = v;
            _update((g) => g.copyWith(saturation: newSat));
          },
          channelColors[i],
        )),
        const Divider(color: Colors.white12, height: 24),
        const Text('Luminance', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...List.generate(7, (i) => _buildSliderRow(
          channelNames[i], grade.luminance[i], -100.0, 100.0,
          (v) {
            final newLum = List<double>.from(grade.luminance);
            newLum[i] = v;
            _update((g) => g.copyWith(luminance: newLum));
          },
          channelColors[i],
        )),
      ],
    );
  }

  Widget _buildLUTTab(ColorGrade grade, Clip clip) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Import a .cube LUT file to apply cinematic color grading. The LUT will be baked into the final export via FFmpeg.',
            style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 24),
          if (grade.lutPath != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.tealAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tune, color: Colors.tealAccent, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      grade.lutName ?? 'Custom LUT',
                      style: const TextStyle(color: Colors.tealAccent, fontSize: 13),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                    onPressed: () => _update((g) => g.copyWith(clearLut: true)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('LUT Intensity', style: TextStyle(color: Colors.white54, fontSize: 12)),
            _buildSliderRow('', grade.lutIntensity, 0.0, 1.0,
              (v) => _update((g) => g.copyWith(lutIntensity: v)),
              Colors.tealAccent,
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.tealAccent),
                  foregroundColor: Colors.tealAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.upload_file),
                label: const Text('Import .cube LUT File'),
                onPressed: () async {
                  final result = await FilePicker.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['cube', 'CUBE'],
                  );
                  if (result != null && result.files.single.path != null) {
                    _update((g) => g.copyWith(
                      lutPath: result.files.single.path!,
                      lutName: result.files.single.name,
                    ));
                  }
                },
              ),
            ),
          ],
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '💡 Tip: Download free cinematic LUTs from sites like LUTs.com or FreeLUTs.com. Export applies it via FFmpeg\'s lut3d filter.',
              style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderRow(String label, double value, double min, double max, Function(double) onChanged, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (label.isNotEmpty)
            SizedBox(
              width: 72,
              child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: color,
                thumbColor: color,
                inactiveTrackColor: Colors.white12,
                overlayColor: color.withValues(alpha: 0.15),
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                onChanged: (v) => onChanged(v),
              ),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              value.toStringAsFixed(0),
              style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 10),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
