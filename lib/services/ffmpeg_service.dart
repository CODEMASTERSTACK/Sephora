import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import '../providers/editor_provider.dart';

class FFmpegService {
  static Future<String?> generateAudioPreview(Clip clip) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final safeName = clip.id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final outputPath = '${tempDir.path}/preview_$safeName.wav';

      if (File(outputPath).existsSync()) {
        File(outputPath).deleteSync();
      }

      List<String> filters = [];

      // EQ — each band is a separate filter in the chain
      if (clip.eqBands.any((v) => v != 0.0)) {
        final freqs = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];
        for (int i = 0; i < 10; i++) {
          if (clip.eqBands[i] != 0.0) {
            filters.add(
                'equalizer=f=${freqs[i]}:width_type=h:width=${freqs[i] ~/ 2}:g=${clip.eqBands[i]}');
          }
        }
      }

      // Compressor
      if (clip.isCompressed) {
        filters.add('acompressor=threshold=-20dB:ratio=4:makeup=4dB');
      }

      // Pitch Shift & Tempo
      if (clip.pitchShift != 0.0 || clip.tempo != 1.0) {
        double rate = 44100.0 * pow(2, clip.pitchShift / 12);
        double pitchTempoAdjust = 1.0 / pow(2, clip.pitchShift / 12);

        // Combine pitch compensation with user-defined tempo
        double finalTempo = pitchTempoAdjust * clip.tempo;

        // FFmpeg's atempo accepts 0.5 to 100.0
        // Chain multiple atempo filters if outside safe range
        filters.add('asetrate=$rate');
        filters.add('aresample=44100');
        if (finalTempo >= 0.5 && finalTempo <= 2.0) {
          filters.add('atempo=$finalTempo');
        } else if (finalTempo > 2.0) {
          filters.add('atempo=2.0');
          filters.add('atempo=${finalTempo / 2.0}');
        } else if (finalTempo < 0.5) {
          filters.add('atempo=0.5');
          filters.add('atempo=${finalTempo / 0.5}');
        }
      }

      // 3D Spatial Audio (binaural simulation)
      if (clip.spatial3dEnabled) {
        // 1. apulsator: Creates binaural panning that rotates sound around the head
        //    hz = rotation speed, amount = intensity (derived from width)
        final pulsatorAmount = (clip.spatial3dWidth / 4.0).clamp(0.0, 1.0);
        filters.add(
            'apulsator=mode=sine:hz=${clip.spatial3dRotation}:amount=$pulsatorAmount');

        // 2. Stereo widening via extrastereo
        //    width 0=mono, 1=normal, 2+=wide
        if (clip.spatial3dWidth > 0) {
          filters.add('extrastereo=m=${clip.spatial3dWidth.clamp(0.0, 4.0)}');
        }

        // 3. Depth — simulate distance with subtle echo/reverb
        if (clip.spatial3dDepth > 0.05) {
          final delayMs = (20 + clip.spatial3dDepth * 60).toInt(); // 20-80ms
          final decay = (0.15 + clip.spatial3dDepth * 0.35)
              .clamp(0.15, 0.5); // subtle reverb
          filters.add(
              'aecho=0.8:0.88:$delayMs|${delayMs + 11}:$decay|${decay * 0.7}');
        }

        // 4. Elevation — simulate vertical position with EQ emphasis
        //    Positive elevation = boost highs (above), negative = boost lows (below)
        if (clip.spatial3dElevation.abs() > 0.05) {
          if (clip.spatial3dElevation > 0) {
            // Above: boost high frequencies, cut lows
            final hiGain = (clip.spatial3dElevation * 6).clamp(0.0, 6.0);
            final loGain = -(clip.spatial3dElevation * 3).clamp(0.0, 3.0);
            filters.add(
                'equalizer=f=8000:width_type=h:width=4000:g=$hiGain');
            filters.add(
                'equalizer=f=200:width_type=h:width=100:g=$loGain');
          } else {
            // Below: boost low frequencies, cut highs
            final loGain = (clip.spatial3dElevation.abs() * 6).clamp(0.0, 6.0);
            final hiGain =
                -(clip.spatial3dElevation.abs() * 3).clamp(0.0, 3.0);
            filters.add(
                'equalizer=f=150:width_type=h:width=75:g=$loGain');
            filters.add(
                'equalizer=f=10000:width_type=h:width=5000:g=$hiGain');
          }
        }
      }

      String command = '-i "${clip.path}"';

      if (filters.isNotEmpty) {
        // Chain all audio filters with comma separator
        command += ' -af "${filters.join(',')}"';
      } else {
        // If no filters, just return the original path to save time!
        return clip.path;
      }

      command += ' -y "$outputPath"';

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        return outputPath;
      }
      
      return null;
    } catch (e) {
      debugPrint('FFmpeg Audio Error: $e');
      return null;
    }
  }

  /// Generates a 480p proxy file for smooth mobile editing.
  /// Returns the proxy path, or null on failure.
  static Future<String?> generateProxy(String originalPath, String clipId) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final safeName = clipId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final outputPath = '${tempDir.path}/proxy_$safeName.mp4';

      if (File(outputPath).existsSync()) return outputPath; // already cached

      // Scale to 480p, fast H.264, low quality (editing proxy only)
      final command = '-i "$originalPath" -vf scale=480:-2 -c:v libx264 -crf 28 -preset ultrafast -c:a aac -b:a 96k -y "$outputPath"';
      final session = await FFmpegKit.execute(command);
      final rc = await session.getReturnCode();

      if (ReturnCode.isSuccess(rc)) return outputPath;
      return null;
    } catch (e) {
      debugPrint('Proxy generation error: $e');
      return null;
    }
  }

  /// Builds the FFmpeg export command for a video clip applying all non-destructive edits.
  static String buildVideoExportCommand({
    required Clip clip,
    required String outputPath,
    required String format,
    required String resolution,
    required String fps,
  }) {
    final src = clip.path; // Always use original, not proxy
    final List<String> vFilters = [];
    final List<String> aFilters = [];

    // Resolution scaling
    final scaleMap = {'720p': '1280:720', '1080p': '1920:1080', '4K': '3840:2160'};
    final scale = scaleMap[resolution] ?? '1920:1080';
    vFilters.add('scale=$scale:force_original_aspect_ratio=decrease,pad=$scale:(ow-iw)/2:(oh-ih)/2');

    // Speed ramp / basic speed
    if (clip.speedPoints.isNotEmpty) {
      // FFmpeg setpts for speed ramp (simplified uniform speed from first point)
      final avgSpeed = clip.speedPoints.map((p) => p.speed).reduce((a, b) => a + b) / clip.speedPoints.length;
      vFilters.add('setpts=${1.0 / avgSpeed}*PTS');
      aFilters.add('atempo=$avgSpeed');
    } else if (clip.speed != 1.0) {
      vFilters.add('setpts=${1.0 / clip.speed}*PTS');
      aFilters.add('atempo=${clip.speed.clamp(0.5, 2.0)}');
    }

    // Color grading
    final g = clip.colorGrade;
    if (g.contrast != 0 || g.highlights != 0 || g.shadows != 0 || g.temperature != 0) {
      final contrast = 1.0 + g.contrast / 100;
      final brightness = (g.highlights - g.shadows) / 500;
      vFilters.add('eq=contrast=$contrast:brightness=$brightness');
    }
    if (g.saturation.any((s) => s != 0)) {
      final avgSat = 1.0 + g.saturation.reduce((a, b) => a + b) / 7 / 100;
      vFilters.add('hue=s=$avgSat');
    }

    // LUT
    if (g.lutPath != null) {
      vFilters.add('lut3d="${g.lutPath}"');
    }

    // Opacity via alpha
    if (clip.opacity < 1.0) {
      vFilters.add('colorchannelmixer=aa=${clip.opacity}');
    }

    // Trim
    final ss = clip.trimStart.inMilliseconds / 1000.0;
    final to = clip.trimEnd.inMilliseconds / 1000.0;

    var cmd = '-ss $ss -to $to -i "$src"';
    if (vFilters.isNotEmpty) cmd += ' -vf "${vFilters.join(',')}"';
    if (aFilters.isNotEmpty) cmd += ' -af "${aFilters.join(',')}"';
    cmd += ' -r $fps -c:v libx264 -crf 18 -preset slow -c:a aac -b:a 192k -y "$outputPath"';

    return cmd;
  }
}

