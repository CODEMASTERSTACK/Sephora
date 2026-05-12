import 'package:go_router/go_router.dart';
import '../screens/home_screen.dart';
import '../screens/video_editor_screen.dart';
import '../screens/audio_editor_screen.dart';
import '../screens/export_settings_screen.dart';
import '../screens/download_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/video-editor',
      builder: (context, state) => const VideoEditorScreen(),
    ),
    GoRoute(
      path: '/audio-editor',
      builder: (context, state) => const AudioEditorScreen(),
    ),
    GoRoute(
      path: '/export',
      builder: (context, state) {
        final isAudioOnly = state.uri.queryParameters['isAudioOnly'] == 'true';
        return ExportSettingsScreen(isAudioOnly: isAudioOnly);
      },
    ),
    GoRoute(
      path: '/download',
      builder: (context, state) => const DownloadScreen(),
    ),
  ],
);
