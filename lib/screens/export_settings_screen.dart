import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';

import '../theme/app_theme.dart';
import '../providers/editor_provider.dart';
import '../providers/project_provider.dart';
import '../services/ffmpeg_service.dart';
import '../widgets/ui/app_toast.dart';

class ExportSettingsScreen extends ConsumerStatefulWidget {
  final bool isAudioOnly;

  const ExportSettingsScreen({super.key, this.isAudioOnly = false});

  @override
  ConsumerState<ExportSettingsScreen> createState() => _ExportSettingsScreenState();
}

class _ExportSettingsScreenState extends ConsumerState<ExportSettingsScreen> with SingleTickerProviderStateMixin {
  late String selectedFormat;
  String selectedResolution = '1080p';
  String selectedFps = '60';
  String selectedAudioQuality = '256kbps';

  bool isExporting = false;
  double exportProgress = 0.0;
  String? savedFilePath;
  
  late AnimationController _progressAnimController;
  late Animation<double> _progressAnimation;
  double _targetProgress = 0.0;

  @override
  void initState() {
    super.initState();
    selectedFormat = widget.isAudioOnly ? 'MP3' : 'MP4';
    
    _progressAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000), // Minimum 3s animation
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressAnimController, curve: Curves.linear),
    );
    _progressAnimController.addListener(() {
      if (mounted && isExporting) {
        setState(() {});
      }
    });
  }
  
  @override
  void dispose() {
    _progressAnimController.dispose();
    super.dispose();
  }
  
  String _getEstimatedSize() {
    final provider = widget.isAudioOnly ? audioEditorProvider : editorProvider;
    final state = ref.read(provider);
    final allClips = widget.isAudioOnly ? state.audioClips : state.videoClips;
    
    if (allClips.isEmpty) return '0 MB';
    
    double durationSeconds = allClips.first.activeDuration.inMilliseconds / 1000.0;
    
    double bitrateKbps = 0;
    if (widget.isAudioOnly) {
      if (selectedFormat == 'WAV') {
        bitrateKbps = 1411; // Standard CD quality WAV
      } else {
        bitrateKbps = double.tryParse(selectedAudioQuality.replaceAll('kbps', '')) ?? 256;
      }
    } else {
      // Video bitrate estimation + 256kbps audio
      if (selectedResolution == '4K') bitrateKbps = 20000;
      else if (selectedResolution == '1080p') bitrateKbps = 8000;
      else if (selectedResolution == '720p') bitrateKbps = 5000;
      else bitrateKbps = 5000;
      
      if (selectedFps == '60') bitrateKbps *= 1.2;
      bitrateKbps += 256; // Audio overhead
    }
    
    double sizeInBits = durationSeconds * bitrateKbps * 1000;
    double sizeInBytes = sizeInBits / 8;
    double sizeInMb = sizeInBytes / (1024 * 1024);
    
    if (sizeInMb < 0.1) return '< 0.1 MB';
    return '~${sizeInMb.toStringAsFixed(1)} MB';
  }

  Future<void> _startExport() async {
    final provider = widget.isAudioOnly ? audioEditorProvider : editorProvider;
    final state = ref.read(provider);
    final allClips = widget.isAudioOnly ? state.audioClips : state.videoClips;

    if (allClips.isEmpty) {
      AppToast.show(context, message: 'Timeline is empty! Add media to export.', type: ToastType.error);
      return;
    }

    setState(() {
      isExporting = true;
      exportProgress = 0.0;
      _targetProgress = 0.0;
    });
    
    _progressAnimController.forward(from: 0.0);

    try {
      final clipToExport = allClips.first;
      
      final docsDir = await getApplicationDocumentsDirectory();
      
      // Get Project Name
      final activeProject = ref.read(projectsProvider).projects.firstOrNull;
      final projectName = activeProject?.name ?? 'Export';
      final sanitizedName = projectName.replaceAll(RegExp(r'[^\w\s]+'), '').trim().replaceAll(' ', '_');
      
      final ext = selectedFormat.toLowerCase();
      final outputPath = '${docsDir.path}/${sanitizedName}.$ext';

      if (File(outputPath).existsSync()) {
        File(outputPath).deleteSync();
      }

      int totalDurationMs = clipToExport.activeDuration.inMilliseconds;

      String command;
      if (widget.isAudioOnly) {
        final previewPath = await FFmpegService.generateAudioPreview(clipToExport);
        if (previewPath == null) throw Exception("Failed to generate audio");
        
        String audioBitrateStr = selectedAudioQuality.replaceAll('kbps', 'k');
        
        if (selectedFormat == 'WAV') {
          File(previewPath).copySync(outputPath);
          _handleExportComplete(outputPath);
          return;
        } else if (selectedFormat == 'AAC') {
          command = '-i "$previewPath" -c:a aac -b:a $audioBitrateStr -y "$outputPath"';
        } else {
          command = '-i "$previewPath" -c:a libmp3lame -b:a $audioBitrateStr -y "$outputPath"';
        }
      } else {
        command = FFmpegService.buildVideoExportCommand(
          clip: clipToExport,
          outputPath: outputPath,
          format: selectedFormat,
          resolution: selectedResolution,
          fps: selectedFps,
        );
      }

      await FFmpegKit.executeAsync(
        command,
        (session) async {
          final returnCode = await session.getReturnCode();
          if (ReturnCode.isSuccess(returnCode)) {
            _handleExportComplete(outputPath);
          } else {
            final logs = await session.getLogsAsString();
            debugPrint('FFmpeg Error: $logs');
            if (mounted) {
              _progressAnimController.stop();
              setState(() => isExporting = false);
              AppToast.show(context, message: 'Export failed!', type: ToastType.error);
            }
          }
        },
        (log) {},
        (Statistics stats) {
          if (totalDurationMs > 0) {
            double p = stats.getTime() / totalDurationMs;
            _targetProgress = p.clamp(0.0, 1.0);
            if (mounted) {
              setState(() {
                exportProgress = _targetProgress;
              });
            }
          }
        },
      );
    } catch (e) {
      debugPrint('Export Error: $e');
      if (mounted) {
        _progressAnimController.stop();
        setState(() => isExporting = false);
        AppToast.show(context, message: 'Error: $e', type: ToastType.error);
      }
    }
  }
  
  Future<void> _handleExportComplete(String path) async {
    if (!mounted) return;
    
    // Ensure the animation has finished its minimum time
    if (_progressAnimController.isAnimating) {
      await _progressAnimController.forward();
    }
    
    if (mounted) {
      _completeExport(path);
    }
  }

  void _completeExport(String path) {
    if (!mounted) return;
    setState(() {
      isExporting = false;
      exportProgress = 1.0;
      savedFilePath = path;
    });

    if (mounted) {
      AppToast.show(context, message: 'Export completed successfully!', type: ToastType.success);
    }
    
    // Automatically try to open the file
    OpenFilex.open(path).then((result) {
      if (result.type != ResultType.done) {
        AppToast.show(context, message: 'Saved to: $path', type: ToastType.info);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Export settings',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: isExporting
                  ? _buildExportingView()
                  : savedFilePath != null
                      ? _buildSuccessView()
                      : _buildSettingsView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Format'),
          _buildOptionsRow(
            options: widget.isAudioOnly ? ['MP3', 'WAV', 'AAC'] : ['MP4', 'MOV'],
            selectedValue: selectedFormat,
            onSelected: (val) => setState(() => selectedFormat = val),
          ),
          
          if (widget.isAudioOnly && selectedFormat != 'WAV') ...[
            const SizedBox(height: 32),
            _buildSectionTitle('Audio Quality'),
            _buildOptionsRow(
              options: ['128kbps', '256kbps', '320kbps'],
              selectedValue: selectedAudioQuality,
              onSelected: (val) => setState(() => selectedAudioQuality = val),
            ),
          ],
          
          if (!widget.isAudioOnly) ...[
            const SizedBox(height: 32),
            _buildSectionTitle('Resolution'),
            _buildOptionsRow(
              options: ['720p', '1080p', '4K'],
              selectedValue: selectedResolution,
              onSelected: (val) => setState(() => selectedResolution = val),
            ),
            
            const SizedBox(height: 32),
            _buildSectionTitle('Frame Rate'),
            _buildOptionsRow(
              options: ['24', '30', '60'],
              selectedValue: selectedFps,
              onSelected: (val) => setState(() => selectedFps = val),
            ),
          ],
          
          const SizedBox(height: 48),
          
          // File Size Estimation
          Center(
            child: Text(
              'Estimated File Size: ${_getEstimatedSize()}',
              style: GoogleFonts.outfit(
                color: AppTheme.textSecondary,
                fontSize: 15,
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Huge Export Button
          SizedBox(
            width: double.infinity,
            height: 64,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: AppTheme.background,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                elevation: 8,
                shadowColor: AppTheme.accent.withValues(alpha: 0.5),
              ),
              onPressed: _startExport,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.upload_rounded, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    widget.isAudioOnly ? 'Export Audio' : 'Export Video',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportingView() {
    // Show max of ffmpeg progress or minimum 3s animation progress
    double displayProgress = isExporting ? (exportProgress > _progressAnimation.value ? exportProgress : _progressAnimation.value) : 1.0;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: displayProgress,
                  strokeWidth: 12,
                  backgroundColor: AppTheme.panelBackground,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
                ),
                Center(
                  child: Text(
                    '${(displayProgress * 100).toInt()}%',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Text(
            'Keep ProEditor open\nand don\'t lock your screen.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: AppTheme.textSecondary,
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: Colors.green, size: 60),
          ),
          const SizedBox(height: 24),
          Text(
            'Ready to Share',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.panelBackground,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    icon: const Icon(Icons.share_rounded),
                    label: Text('Share', style: GoogleFonts.outfit(fontSize: 18)),
                    onPressed: () {
                      if (savedFilePath != null) {
                        Share.shareXFiles([XFile(savedFilePath!)], text: 'Made with ProEditor');
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: AppTheme.background,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text('Play', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      if (savedFilePath != null) {
                        OpenFilex.open(savedFilePath!);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildOptionsRow({
    required List<String> options,
    required String selectedValue,
    required Function(String) onSelected,
  }) {
    return Row(
      children: options.map((opt) {
        final isSelected = selectedValue == opt;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelected(opt),
            child: Container(
              margin: EdgeInsets.only(right: opt == options.last ? 0 : 12),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.accent.withValues(alpha: 0.15) : AppTheme.panelBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppTheme.accent : Colors.white12,
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                opt,
                style: GoogleFonts.outfit(
                  color: isSelected ? AppTheme.accent : Colors.white70,
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

