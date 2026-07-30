import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../config/nova_gate_config.dart';
import 'signal_agent.dart';

/// Assert-wrapped logger — the closure AND its string literal are stripped
/// from release builds so `[NTD.*]` tags never ship in the binary.
void ntdLog(String Function() build) {
  assert(() {
    debugPrint(build());
    return true;
  }());
}

/// Owns AppsFlyer + ATT + GCD fetch for the Nova gate. Emits a single unified
/// payload via [compose] that mixes install + reopen + deep-link data on top
/// of the app identity fields.
class DriftAttribution {
  DriftAttribution(this._agent);

  final SignalAgent _agent;

  AppsflyerSdk? _sdk;
  Map<String, dynamic>? _install;
  Map<String, dynamic>? _reopen;
  Map<String, dynamic>? _deepLink;
  Future<void>? _bootstrap;

  final Completer<void> _installGate = Completer<void>();
  final Completer<void> _deepLinkGate = Completer<void>();

  Future<void> start() => _bootstrap ??= _bootstrap0();

  Future<void> _bootstrap0() async {
    if (!NovaGateConfig.gateCredentialsReady) {
      _fulfillEmpty();
      return;
    }
    try {
      await _requestTrackingIfNeeded();
      final sdk = AppsflyerSdk(
        AppsFlyerOptions(
          afDevKey: NovaGateConfig.appsFlyerKey,
          appId: NovaGateConfig.iosStoreId,
          showDebug: kDebugMode,
          timeToWaitForATTUserAuthorization: 4,
        ),
      );
      _sdk = sdk;

      sdk.onInstallConversionData(_onInstall);
      sdk.onAppOpenAttribution((payload) => _reopen = _flatten(payload));
      sdk.onDeepLinking(_onDeepLink);

      await sdk.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );
    } catch (error) {
      ntdLog(() => '[NTD.DRIFT] init error: $error');
      _fulfillEmpty();
    }
  }

  void _onDeepLink(DeepLinkResult result) {
    final event = result.deepLink?.clickEvent;
    if (event != null) {
      _deepLink = Map<String, dynamic>.from(event);
    }
    if (!_deepLinkGate.isCompleted) _deepLinkGate.complete();
  }

  Future<void> _requestTrackingIfNeeded() async {
    if (!Platform.isIOS) return;
    final status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status != TrackingStatus.notDetermined) return;
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 320));
    await AppTrackingTransparency.requestTrackingAuthorization();
  }

  Future<void> _onInstall(dynamic raw) async {
    try {
      final flat = _flatten(raw);
      final status = flat['status']?.toString().toLowerCase();
      // AppsFlyer delivers `{status:"failure", ...}` when it can't reach its
      // servers (e.g. an ad-blocking VPN blackholes *.appsflyersdk.com). We
      // must not merge that error map into the payload.
      final failed = status == 'failure' ||
          (flat['af_status'] == null && flat.containsKey('status'));

      ntdLog(
        () => '[NTD.DRIFT] conversion status=$status '
            'af_status=${flat['af_status']} keys=${flat.keys.toList()}',
      );

      if (failed) {
        _install = <String, dynamic>{};
      } else if (flat['af_status'] == 'Organic') {
        await Future<void>.delayed(
          const Duration(seconds: NovaGateConfig.organicRecheckSeconds),
        );
        _install = (await _fetchGcd()) ?? flat;
      } else {
        _install = flat;
      }
    } catch (error) {
      ntdLog(() => '[NTD.DRIFT] conversion parse error: $error');
      _install = <String, dynamic>{};
    } finally {
      if (!_installGate.isCompleted) _installGate.complete();
    }
  }

  Map<String, dynamic> _flatten(dynamic raw) {
    if (raw is! Map) return <String, dynamic>{};
    final outer = Map<String, dynamic>.from(raw);
    final inner = outer['payload'];
    return inner is Map ? Map<String, dynamic>.from(inner) : outer;
  }

  Future<Map<String, dynamic>?> _fetchGcd() async {
    final uid = await appsFlyerId();
    if (uid == null || uid.isEmpty) return null;
    try {
      // iOS GCD wants the numeric App Store id, not the bundle id.
      final base = NovaGateConfig.gcdBase;
      final separator = base.contains('?') ? '&' : '?';
      final uri = Uri.parse(
        '$base${separator}app_id=${NovaGateConfig.iosStoreId}'
        '&device_id=$uid',
      );
      final response = await _agent
          .get(
            uri,
            headers: <String, String>{
              'Authorization': 'Bearer ${NovaGateConfig.appsFlyerKey}',
            },
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> awaitSignals({
    Duration installTimeout = const Duration(seconds: 8),
  }) async {
    await start();
    await Future.wait<void>(<Future<void>>[
      _installGate.future.timeout(installTimeout, onTimeout: () {}),
      _deepLinkGate.future
          .timeout(const Duration(seconds: 5), onTimeout: () {}),
    ]);
  }

  Future<String?> appsFlyerId() async {
    try {
      return await _sdk?.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> compose({
    required String locale,
    String? pushToken,
  }) async {
    final payload = <String, dynamic>{};

    // Install first, then reopen, then deep-link — deep-link never overrides
    // an install-time value; earlier sources win on collisions.
    void mergeIfAbsent(Map<String, dynamic>? source) {
      if (source == null) return;
      for (final entry in source.entries) {
        payload.putIfAbsent(entry.key, () => entry.value);
      }
    }

    if (_install != null) payload.addAll(_install!);
    mergeIfAbsent(_reopen);
    mergeIfAbsent(_deepLink);

    payload['af_id'] = await appsFlyerId() ?? payload['af_id'] ?? '';
    payload['bundle_id'] = NovaGateConfig.bundleId;
    payload['os'] = 'iOS';
    payload['store_id'] = NovaGateConfig.storeToken;
    payload['locale'] = locale;

    final firebaseId = NovaGateConfig.firebaseProjectNumber;
    if (pushToken != null && pushToken.isNotEmpty && firebaseId.isNotEmpty) {
      payload['push_token'] = pushToken;
      payload['firebase_project_id'] = firebaseId;
    }

    if (Platform.isIOS) {
      final idfa = await _readIdfaIfAuthorised();
      if (idfa != null) payload['sub_id_10'] = idfa;
    }

    ntdLog(() => '[NTD.DRIFT] payload ${jsonEncode(payload)}');
    return payload;
  }

  Future<String?> _readIdfaIfAuthorised() async {
    try {
      final auth = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (auth != TrackingStatus.authorized) return null;
      final idfa = await AppTrackingTransparency.getAdvertisingIdentifier();
      if (idfa.isEmpty || idfa.startsWith('00000000-')) return null;
      return idfa;
    } catch (_) {
      return null;
    }
  }

  void _fulfillEmpty() {
    if (!_installGate.isCompleted) _installGate.complete();
    if (!_deepLinkGate.isCompleted) _deepLinkGate.complete();
  }
}
