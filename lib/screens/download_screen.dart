import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gal/gal.dart';

import '../theme/app_theme.dart';
import '../widgets/ui/app_toast.dart';
import '../services/pinterest_service.dart';

class DownloadScreen extends StatefulWidget {
  const DownloadScreen({super.key});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _statusMessage = '';

  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      final storage = await Permission.storage.request();
      if (storage.isGranted) return true;

      final photos = await Permission.photos.request();
      if (photos.isGranted) return true;

      // For Android 13+ video permission
      final videos = await Permission.videos.request();
      if (videos.isGranted) return true;

      return false;
    } else if (Platform.isIOS) {
      final photos = await Permission.photos.request();
      final photosAdd = await Permission.photosAddOnly.request();
      return photos.isGranted || photosAdd.isGranted || photos.isLimited;
    }
    return false;
  }

  void _downloadPinterestVideo() async {
    final url = _urlController.text.trim();

    if (url.isEmpty ||
        (!url.contains('pin.it') && !url.contains('pinterest.com'))) {
      AppToast.show(
        context,
        message: 'Please enter a valid Pinterest URL',
        type: ToastType.error,
      );
      return;
    }

    final hasPermission = await _requestPermissions();
    if (!mounted) return;

    if (!hasPermission) {
      AppToast.show(
        context,
        message: 'Storage permission is required',
        type: ToastType.error,
      );
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _statusMessage = 'Resolving link...';
    });

    try {
      final videoInfo = await PinterestService.getVideoInfo(url);

      if (videoInfo == null || videoInfo.videoUrl.isEmpty) {
        throw Exception('Could not find video URL');
      }

      debugPrint('VIDEO URL: ${videoInfo.videoUrl}');

      setState(() {
        _statusMessage = 'Downloading video...';
      });

      final tempDir = await getTemporaryDirectory();

      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final tempPath = '${tempDir.path}/pinterest_$timestamp.mp4';

      final dio = Dio();

      dio.options.followRedirects = true;
      dio.options.maxRedirects = 5;

      final response = await dio.get(
        videoInfo.videoUrl,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
            'Referer': 'https://www.pinterest.com/',
            'Origin': 'https://www.pinterest.com',
            'Accept': '*/*',
          },
        ),
        onReceiveProgress: (received, total) {
          if (total > 0) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
      );

      debugPrint('STATUS: ${response.statusCode}');

      debugPrint('CONTENT TYPE: ${response.headers.value('content-type')}');

      debugPrint('SIZE: ${response.data.length}');

      if (response.statusCode != 200) {
        throw Exception('Pinterest blocked download');
      }

      final contentType = response.headers.value('content-type') ?? '';

      if (!contentType.contains('video') && !contentType.contains('mp4')) {
        throw Exception('Invalid video response');
      }

      if (response.data.length < 10000) {
        throw Exception('Downloaded file is invalid');
      }

      final file = File(tempPath);

      await file.writeAsBytes(response.data);

      setState(() {
        _statusMessage = 'Saving to gallery...';
      });

      await Gal.putVideo(tempPath);

      if (file.existsSync()) {
        file.deleteSync();
      }

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 1.0;
          _urlController.clear();
        });

        AppToast.show(
          context,
          message: 'Video saved successfully!',
          type: ToastType.success,
        );
      }
    } catch (e) {
      debugPrint('DOWNLOAD ERROR: $e');

      if (mounted) {
        setState(() {
          _isDownloading = false;
        });

        AppToast.show(
          context,
          message: 'Download failed: ${e.toString()}',
          type: ToastType.error,
        );
      }
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
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
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Download',
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pinterest Video',
                      style: GoogleFonts.outfit(
                        color: AppTheme.accent,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Paste a Pinterest video URL below to download it to your device.',
                      style: GoogleFonts.outfit(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _urlController,
                      style: GoogleFonts.outfit(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'https://pin.it/...',
                        hintStyle: GoogleFonts.outfit(color: Colors.white38),
                        filled: true,
                        fillColor: AppTheme.panelBackground,
                        prefixIcon: const Icon(
                          Icons.link,
                          color: Colors.white54,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: AppTheme.accent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (_isDownloading) ...[
                      Column(
                        children: [
                          LinearProgressIndicator(
                            value: _downloadProgress > 0
                                ? _downloadProgress
                                : null,
                            backgroundColor: AppTheme.panelBackground,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.accent,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            minHeight: 8,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _statusMessage,
                            style: GoogleFonts.outfit(
                              color: AppTheme.accent,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ],

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: AppTheme.background,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _isDownloading
                            ? null
                            : _downloadPinterestVideo,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.download_rounded),
                            const SizedBox(width: 8),
                            Text(
                              _isDownloading ? 'Downloading...' : 'Download',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
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
    );
  }
}
