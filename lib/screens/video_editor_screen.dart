import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/editor_provider.dart';
import '../widgets/ui/toolbar.dart';
import '../widgets/timeline/timeline_view.dart';
import '../widgets/preview/video_preview.dart';
import '../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class VideoEditorScreen extends ConsumerWidget {
  const VideoEditorScreen({super.key});

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(d.inHours)}:'
        '${twoDigits(d.inMinutes.remainder(60))}:'
        '${twoDigits(d.inSeconds.remainder(60))}:'
        '${(d.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playhead = ref.watch(editorProvider.select((s) => s.playheadPosition));
    final isPlaying = ref.watch(editorProvider.select((s) => s.isPlaying));
    final snapEnabled = ref.watch(editorProvider.select((s) => s.snapEnabled));

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Premium Header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  // Back button
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 4),

                  // Title
                  Text(
                    'Video Edit',
                    style: GoogleFonts.caveat(
                      color: AppTheme.accent,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Timecode
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.panelBackground,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Text(
                              _formatDuration(playhead),
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Snap toggle
                          GestureDetector(
                            onTap: () => ref.read(editorProvider.notifier).toggleSnap(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: snapEnabled
                                    ? AppTheme.accent.withValues(alpha: 0.15)
                                    : AppTheme.panelBackground,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: snapEnabled ? AppTheme.accent.withValues(alpha: 0.5) : Colors.white12,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.grid_4x4, size: 14,
                                      color: snapEnabled ? AppTheme.accent : Colors.white38),
                                  const SizedBox(width: 4),
                                  Text('Snap',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: snapEnabled ? AppTheme.accent : Colors.white38,
                                      )),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Play/Pause
                          GestureDetector(
                            onTap: () => ref.read(editorProvider.notifier).togglePlay(),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Container(
                                key: ValueKey(isPlaying),
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: isPlaying
                                      ? AppTheme.accent
                                      : AppTheme.panelBackground,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: isPlaying ? AppTheme.accent : Colors.white24),
                                ),
                                child: Icon(
                                  isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: isPlaying ? AppTheme.background : Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Export button
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
                                    await ref.read(editorProvider.notifier).saveProject();
                                  } else if (value == 'export') {
                                    context.push('/export');
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'save',
                                    child: Text('Save Project'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'export',
                                    child: Text('Export Video'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

              // ── Video Preview Monitor ───────────────────────────────────
              Expanded(
                flex: 4,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const VideoPreview(),
                ),
              ),

              // ── Tool Bar ───────────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  border: Border.symmetric(
                    horizontal: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                ),
                child: const EditorToolbar(isAudioOnly: false),
              ),

              // ── Multi-Track Timeline ───────────────────────────────────
              Expanded(
                flex: 5,
                child: TimelineView(isAudioOnly: false),
              ),
            ],
          ),
        ),
      );
    }
  }