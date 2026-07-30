import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/gate_models.dart';

/// SharedPreferences + SecureStorage owner for the Nova gate. Every key is
/// namespaced under a project-unique prefix (`ntd.drop.*`) so nothing here
/// collides with — or clusters against — sibling apps in the portfolio.
class OrbitVault {
  static const String _prefix = 'ntd.drop';

  // Prefs (route + timestamps + booleans).
  static const String _kRoute = '$_prefix.route';
  static const String _kExpiry = '$_prefix.cache.expiry';
  static const String _kInviteAfter = '$_prefix.invite.after';
  static const String _kPushAllowed = '$_prefix.push.allowed';
  static const String _kPushOsDenied = '$_prefix.push.osdenied';

  // SecureStorage (URLs — sensitive).
  static const String _kSecureCachedUrl = '$_prefix.secure.link';
  static const String _kSecurePendingUrl = '$_prefix.secure.pending';

  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  late final SharedPreferences _prefs;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  GateRoute get route => GateRoute.parse(_prefs.getString(_kRoute));

  Future<void> saveRoute(GateRoute route) =>
      _prefs.setString(_kRoute, route.storageValue);

  Future<String?> savedUrl() async {
    try {
      return await _secure.read(key: _kSecureCachedUrl);
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheUrl(String url, int? expiresAt) async {
    try {
      await _secure.write(key: _kSecureCachedUrl, value: url);
    } catch (_) {
      return;
    }
    if (expiresAt != null) {
      await _prefs.setInt(_kExpiry, expiresAt);
    }
  }

  bool get cachedUrlExpired {
    final expiry = _prefs.getInt(_kExpiry);
    if (expiry == null) return true;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now >= expiry;
  }

  Future<void> stashPushUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    try {
      await _secure.write(key: _kSecurePendingUrl, value: trimmed);
    } catch (_) {}
  }

  Future<String?> consumePushUrl() async {
    try {
      final value = await _secure.read(key: _kSecurePendingUrl);
      if (value != null) await _secure.delete(key: _kSecurePendingUrl);
      return value;
    } catch (_) {
      return null;
    }
  }

  bool get pushAllowed => _prefs.getBool(_kPushAllowed) ?? false;
  bool get pushDeniedByOs => _prefs.getBool(_kPushOsDenied) ?? false;

  Future<void> setPushAllowed(bool value) =>
      _prefs.setBool(_kPushAllowed, value);

  Future<void> markPushDeniedByOs() =>
      _prefs.setBool(_kPushOsDenied, true);

  bool get shouldShowPushInvite {
    if (pushAllowed || pushDeniedByOs) return false;
    final resumeAt = _prefs.getInt(_kInviteAfter);
    if (resumeAt == null) return true;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now >= resumeAt;
  }

  Future<void> snoozePushInvite(int epochSeconds) =>
      _prefs.setInt(_kInviteAfter, epochSeconds);
}
