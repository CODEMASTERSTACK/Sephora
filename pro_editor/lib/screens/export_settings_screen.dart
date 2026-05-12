import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class ExportSettingsScreen extends StatefulWidget {
  const ExportSettingsScreen({super.key});

  @override
  State<ExportSettingsScreen> createState() => _ExportSettingsScreenState();
}

class _ExportSettingsScreenState extends State<ExportSettingsScreen> {
  String selectedResolution = '1080p';
  String selectedFps = '60';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Export Settings'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Resolution', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: ['720p', '1080p', '4K'].map((res) {
                final isSelected = selectedResolution == res;
                return ChoiceChip(
                  label: Text(res),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) setState(() => selectedResolution = res);
                  },
                  selectedColor: AppTheme.accent,
                  backgroundColor: AppTheme.panelBackground,
                  labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white70),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            const Text('Frame Rate', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: ['24', '30', '60'].map((fps) {
                final isSelected = selectedFps == fps;
                return ChoiceChip(
                  label: Text('$fps FPS'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) setState(() => selectedFps = fps);
                  },
                  selectedColor: AppTheme.accent,
                  backgroundColor: AppTheme.panelBackground,
                  labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white70),
                );
              }).toList(),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  // Trigger FFmpeg export logic here
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Starting export at $selectedResolution and $selectedFps fps...')),
                  );
                  Future.delayed(const Duration(seconds: 2), () {
                    if (context.mounted) context.pop();
                  });
                },
                child: const Text('Export Video', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
