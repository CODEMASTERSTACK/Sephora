import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/ui/toolbar.dart';
import '../widgets/timeline/timeline_view.dart';
import '../widgets/preview/audio_preview.dart';
import '../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/editor_provider.dart';

class AudioEditorScreen extends ConsumerWidget {
  const AudioEditorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        popupMenuTheme: PopupMenuThemeData(
                          color: AppTheme.panelBackground,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          textStyle: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w500),
                        ),
                      ),
                      child: PopupMenuButton<String>(
                        offset: const Offset(0, 40),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Export',
                                  style: GoogleFonts.outfit(
                                    color: AppTheme.background,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  )),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_drop_down, color: AppTheme.background, size: 16),
                            ],
                          ),
                        ),
                        onSelected: (value) async {
                          if (value == 'save') {
                            await ref.read(audioEditorProvider.notifier).saveProject();
                          } else if (value == 'export') {
                            context.push('/export?isAudioOnly=true');
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'save',
                            child: Text('Save Project'),
                          ),
                          const PopupMenuItem(
                            value: 'export',
                            child: Text('Export Audio'),
                          ),
                        ],
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

