import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Reads the cold-start push URL written by `SceneDelegate.swift` into
/// UserDefaults. The Dart key here (without the `flutter.` prefix) must match
/// `SceneDelegate.launchRouteKey` (which includes the prefix).
class ColdTapReader {
  static const String _dartKey = 'nova_cold_link';

  static Future<String?> consume() async {
    if (!Platform.isIOS) return null;
    try {
      final preferences = await SharedPreferences.getInstance();
      final value = preferences.getString(_dartKey)?.trim();
      if (value == null || value.isEmpty) return null;
      await preferences.remove(_dartKey);
      return value;
    } catch (_) {
      return null;
    }
  }
}
