import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/audio.dart';
import 'core/storage.dart';
import 'core/theme.dart';
import 'screens/loading_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // Loading screen supports both orientations; the game locks to portrait later.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await GameStorage.instance.init();
  await Audio.instance.init();
  runApp(const NovaApp());
}

class NovaApp extends StatefulWidget {
  const NovaApp({super.key});

  @override
  State<NovaApp> createState() => _NovaAppState();
}

class _NovaAppState extends State<NovaApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Covers leaving the game entirely: Home button, task switch, screen
    // lock, or the app being closed — music (and any live SFX) must stop
    // instead of keeping playing in the background.
    if (state == AppLifecycleState.resumed) {
      Audio.instance.resumeFromBackground();
    } else {
      Audio.instance.pauseForBackground();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nova Token Drop',
      debugShowCheckedModeBanner: false,
      theme: NovaTheme.build(),
      home: const LoadingScreen(),
    );
  }
}

/// Locks the app to portrait for gameplay/menus.
Future<void> lockPortrait() =>
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
