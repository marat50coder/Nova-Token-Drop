import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

import 'orbit_vault.dart';

@pragma('vm:entry-point')
Future<void> ntdBackgroundMessage(RemoteMessage _) async {}

/// Firebase Messaging + APNs bootstrap and push-permission requests for the
/// Nova gate. Cold-start taps are read separately via [ColdTapReader].
class PulseHub {
  PulseHub(this._vault, {required this.enabled});

  static const int _initialMessageTimeoutSeconds = 4;
  static const int _apnsPollDelayMs = 550;
  static const int _apnsShortAttempts = 6;
  static const int _apnsLongAttempts = 14;

  static const List<String> _linkKeys = <String>[
    'deep_link',
    'target',
    'url',
    'deeplink',
    'link',
  ];
  static const List<String> _nestedContainers = <String>['payload', 'data'];

  final OrbitVault _vault;
  final bool enabled;

  FirebaseMessaging? _messaging;
  Future<void>? _bootFuture;
  Future<bool>? _permissionFuture;
  String? _token;

  void Function(String url)? onDestination;
  void Function(String token)? onTokenChanged;

  String? get token => _token;

  Future<void> boot() => _bootFuture ??= _boot();

  Future<void> _boot() async {
    if (!enabled) return;
    final messaging = FirebaseMessaging.instance;
    _messaging = messaging;

    await _consumeInitialMessage(messaging);

    FirebaseMessaging.onBackgroundMessage(ntdBackgroundMessage);
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    messaging.onTokenRefresh.listen(_onTokenRefreshed);
    FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationOpened);

    await _waitForApnsToken(_apnsShortAttempts);
    _token = await messaging.getToken();
  }

  Future<void> _consumeInitialMessage(FirebaseMessaging messaging) async {
    final initial = await messaging.getInitialMessage().timeout(
      const Duration(seconds: _initialMessageTimeoutSeconds),
      onTimeout: () => null,
    );
    if (initial == null) return;
    final url = _extractUrl(initial.data);
    if (url != null) await _vault.stashPushUrl(url);
  }

  void _onTokenRefreshed(String value) {
    _token = value;
    onTokenChanged?.call(value);
  }

  void _onNotificationOpened(RemoteMessage message) {
    final url = _extractUrl(message.data);
    if (url == null) return;
    final callback = onDestination;
    if (callback != null) {
      callback(url);
      return;
    }
    _vault.stashPushUrl(url);
  }

  String? _extractUrl(Map<String, dynamic> payload) {
    for (final key in _linkKeys) {
      final value = payload[key];
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) return trimmed;
      }
    }
    for (final container in _nestedContainers) {
      final nested = payload[container];
      if (nested is Map) {
        final found = _extractUrl(Map<String, dynamic>.from(nested));
        if (found != null) return found;
      }
    }
    return null;
  }

  Future<void> _waitForApnsToken(int attempts) async {
    final messaging = _messaging;
    if (messaging == null) return;
    for (var i = 0; i < attempts; i++) {
      try {
        final apns = await messaging.getAPNSToken();
        if ((apns?.isNotEmpty) ?? false) return;
      } catch (_) {}
      await Future<void>.delayed(
        const Duration(milliseconds: _apnsPollDelayMs),
      );
    }
  }

  Future<bool> canOfferPermission() async {
    if (!enabled) return false;
    if (_vault.pushDeniedByOs) return false;
    final messaging = _messaging;
    if (messaging == null) return false;
    final settings = await messaging.getNotificationSettings();
    final status = settings.authorizationStatus;
    if (status == AuthorizationStatus.denied) {
      await _vault.markPushDeniedByOs();
      return false;
    }
    return status == AuthorizationStatus.notDetermined ||
        status == AuthorizationStatus.provisional;
  }

  Future<bool> askPermission() =>
      _permissionFuture ??= _requestPermission().whenComplete(
        () => _permissionFuture = null,
      );

  Future<bool> _requestPermission() async {
    final messaging = _messaging;
    if (!enabled || messaging == null) return false;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;

    await _vault.setPushAllowed(granted);
    if (!granted &&
        settings.authorizationStatus == AuthorizationStatus.denied) {
      await _vault.markPushDeniedByOs();
    }

    if (granted) {
      await _waitForApnsToken(_apnsLongAttempts);
      _token = await messaging.getToken();
      final refreshed = _token;
      if (refreshed != null && refreshed.isNotEmpty) {
        onTokenChanged?.call(refreshed);
      }
    }
    return granted;
  }
}
