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

class NovaApp extends StatelessWidget {
  const NovaApp({super.key});

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
