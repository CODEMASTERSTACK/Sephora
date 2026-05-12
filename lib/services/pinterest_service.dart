import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

class PinterestVideoInfo {
  final String videoUrl;
  final String title;

  PinterestVideoInfo({
    required this.videoUrl,
    required this.title,
  });
}

class PinterestService {
  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept': 'application/json, text/javascript, */*; q=0.01',
    'Accept-Language': 'en-US,en;q=0.9',
    'X-Requested-With': 'XMLHttpRequest',
    'X-PINTEREST-AppState': 'active',
  };

  static Future<PinterestVideoInfo?> getVideoInfo(
    String rawUrl,
  ) async {
    final client = http.Client();

    try {
      final initialRes = await client.get(
        Uri.parse(rawUrl),
        headers: _headers,
      );

      final formattedCookies =
          _formatCookies(initialRes.headers['set-cookie']);

      final csrfToken =
          RegExp(r'csrftoken=([^;]+)')
                  .firstMatch(formattedCookies)
                  ?.group(1) ??
              'no_csrf';

      final longUrl =
          initialRes.request?.url.toString() ?? rawUrl;

      final pinId = _smartIdExtract(
        longUrl,
        initialRes.body,
      );

      if (pinId == null) {
        debugPrint('Could not extract Pin ID');
        return null;
      }

      debugPrint('Targeted Pin ID: $pinId');

      // FAST TRACK
      final fastTrackVideo =
          _extractFromHtml(initialRes.body, pinId);

      if (fastTrackVideo != null) {
        debugPrint('Fast-track video found');
        return fastTrackVideo;
      }

      // API FALLBACK
      final Map<String, dynamic> options = {
        "options": {
          "id": pinId,
          "field_set_key": "detailed",
        },
        "context": {},
      };

      final encodedData =
          Uri.encodeComponent(jsonEncode(options));

      final apiUrl = Uri.parse(
        'https://www.pinterest.com/resource/PinResource/get/?data=$encodedData',
      );

      final apiRes = await client.get(
        apiUrl,
        headers: {
          ..._headers,
          if (formattedCookies.isNotEmpty)
            'Cookie': formattedCookies,
          if (csrfToken != 'no_csrf')
            'X-CSRFToken': csrfToken,
          'Referer': longUrl,
        },
      );

      if (apiRes.statusCode == 200) {
        final decoded = jsonDecode(apiRes.body);

        final data =
            decoded['resource_response']?['data'];

        if (data != null) {
          final videoUrl =
              _findVideoUrlInJson(data);

          if (videoUrl != null) {
            debugPrint(
              'Video URL extracted: $videoUrl',
            );

            return PinterestVideoInfo(
              videoUrl: videoUrl,
              title:
                  data['grid_title'] ??
                  data['title'] ??
                  "Pin_$pinId",
            );
          }
        }
      }

      debugPrint(
        'Pinterest API failed: ${apiRes.statusCode}',
      );

      return null;
    } catch (e) {
      debugPrint(
        'Pinterest Service Error: $e',
      );
      return null;
    } finally {
      client.close();
    }
  }

  static String _formatCookies(String? rawSetCookie) {
    if (rawSetCookie == null ||
        rawSetCookie.isEmpty) {
      return '';
    }

    final sessMatch = RegExp(
      r'_pinterest_sess=([^;,\s]+)',
    ).firstMatch(rawSetCookie);

    final csrfMatch = RegExp(
      r'csrftoken=([^;,\s]+)',
    ).firstMatch(rawSetCookie);

    List<String> validCookies = [];

    if (sessMatch != null) {
      validCookies.add(sessMatch.group(0)!);
    }

    if (csrfMatch != null) {
      validCookies.add(csrfMatch.group(0)!);
    }

    return validCookies.join('; ');
  }

  static String? _smartIdExtract(
    String url,
    String body,
  ) {
    final urlMatch =
        RegExp(r'pin/(\d+)').firstMatch(url);

    if (urlMatch != null) {
      return urlMatch.group(1);
    }

    final metaMatch = RegExp(
      r'content="https://www.pinterest.com/pin/(\d+)',
    ).firstMatch(body);

    if (metaMatch != null) {
      return metaMatch.group(1);
    }

    final jsonMatch =
        RegExp(r'"/pin/(\d+)/"').firstMatch(body);

    if (jsonMatch != null) {
      return jsonMatch.group(1);
    }

    return null;
  }

  static PinterestVideoInfo? _extractFromHtml(
    String body,
    String pinId,
  ) {
    // OG VIDEO
    final ogMatch = RegExp(
      r'<meta property="og:video(?:\:secure_url)?" content="(https://[^"]+\.mp4)"',
    ).firstMatch(body);

    if (ogMatch != null) {
      return PinterestVideoInfo(
        videoUrl: ogMatch.group(1)!,
        title: "Pin_$pinId",
      );
    }

    // JSON DATA
    final jsonMatch = RegExp(
      r'<script id="__PWS_DATA__" type="application/json">(.*?)</script>',
    ).firstMatch(body);

    if (jsonMatch != null) {
      try {
        final data =
            jsonDecode(jsonMatch.group(1)!);

        final url =
            _findVideoUrlInJson(data);

        if (url != null) {
          return PinterestVideoInfo(
            videoUrl: url,
            title: "Pin_$pinId",
          );
        }
      } catch (_) {}
    }

    // RAW MP4 ONLY
    final rawMatch = RegExp(
      r'''https://v1\.pinimg\.com/[^"'<>]+\.mp4''',
    ).firstMatch(body);

    if (rawMatch != null) {
      return PinterestVideoInfo(
        videoUrl: rawMatch.group(0)!,
        title: "Pin_$pinId",
      );
    }

    return null;
  }

  static String? _findVideoUrlInJson(
    dynamic data,
  ) {
    if (data is Map) {
      if (data.containsKey('video_list') &&
          data['video_list'] is Map) {
        final vl = data['video_list'];

        dynamic source;

        if (vl['V_720P'] != null) {
          source = vl['V_720P'];
        } else if (vl['V_EXP7'] != null) {
          source = vl['V_EXP7'];
        } else if (vl['V_EXP5'] != null) {
          source = vl['V_EXP5'];
        } else {
          for (var item in vl.values) {
            if (item is Map &&
                item['url'] != null &&
                item['url']
                    .toString()
                    .contains('.mp4')) {
              source = item;
              break;
            }
          }
        }

        if (source is Map &&
            source['url'] != null) {
          final url =
              source['url'].toString();

          if (url.contains('.mp4')) {
            return url;
          }
        }
      }

      for (var value in data.values) {
        final res =
            _findVideoUrlInJson(value);

        if (res != null) {
          return res;
        }
      }
    }

    if (data is List) {
      for (var item in data) {
        final res =
            _findVideoUrlInJson(item);

        if (res != null) {
          return res;
        }
      }
    }

    if (data is String) {
      if (data.startsWith(
            'https://v1.pinimg.com/',
          ) &&
          data.contains('.mp4')) {
        return data;
      }
    }

    return null;
  }
}