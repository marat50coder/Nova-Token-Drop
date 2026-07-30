import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Reads the cold-start push URL stashed by `SceneDelegate.swift` in
/// UserDefaults. The Dart key here (without the `flutter.` prefix) MUST match
/// `SceneDelegate.coldRouteKey` on the iOS side (which adds the prefix).
class ColdTapReader {
  const ColdTapReader._();

  /// Key visible to Dart (SharedPreferences strips the `flutter.` prefix
  /// that iOS UserDefaults sees).
  static const String coldTapKey = 'ntd_route_seed';

  static Future<String?> consume() async {
    if (!Platform.isIOS) return null;
    final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
    final raw = prefs.getString(coldTapKey);
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(coldTapKey);
      return null;
    }
    await prefs.remove(coldTapKey);
    return trimmed;
  }
}
