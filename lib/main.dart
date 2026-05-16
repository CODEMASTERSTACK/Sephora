import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'routes/app_router.dart';
import 'theme/app_theme.dart';
import 'services/audio_handler.dart';

void main() async {
  debugPrint('APP STARTING...');
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('WIDGETS INITIALIZED');
  
  runApp(const ProviderScope(child: ProEditorApp()));
  
  // Initialize in the background after runApp
  Future.delayed(Duration.zero, () async {
    try {
      debugPrint('INITIALIZING AUDIO SERVICE...');
      await initAudioService();
      debugPrint('AUDIO SERVICE INITIALIZED');
    } catch (e) {
      debugPrint('Failed to initialize audio service: $e');
    }
  });
}

class ProEditorApp extends StatelessWidget {
  const ProEditorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Pro Editor',
      theme: AppTheme.darkTheme,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
