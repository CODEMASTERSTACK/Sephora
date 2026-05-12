import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/ui/toolbar.dart';
import '../widgets/timeline/timeline_view.dart';
import '../widgets/preview/audio_preview.dart';
import '../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class AudioEditorScreen extends StatelessWidget {
  const AudioEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Sleek Transparent Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                        onPressed: () => context.pop(),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Audio Mix',
                        style: GoogleFonts.caveat(
                          color: AppTheme.accent,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accent.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextButton(
                      onPressed: () => context.push('/export?isAudioOnly=true'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Export',
                        style: GoogleFonts.outfit(
                          color: AppTheme.background,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
              
              // Audio Visualizer/Waveform Area
              Expanded(
                flex: 4,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: const AudioPreview(),
                ),
              ),
              
              // Custom styling for toolbar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1),
                    bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1),
                  ),
                ),
                child: const EditorToolbar(isAudioOnly: true),
              ),
              
              // Lower panel: Audio Tracks
              Expanded(
                flex: 5,
                child: TimelineView(isAudioOnly: true),
              ),
            ],
          ),
        ),   
    );
  }
}

