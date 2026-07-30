import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

import '../config/nova_gate_config.dart';

/// HTTP client that forges a real Mobile Safari User-Agent. The SAME UA is used
/// by the WebView (`OrbitPortal.setUserAgent`) so the partner backend sees a
/// consistent identity. Never leaks Dart/Flutter/CFNetwork/Darwin tokens.
class SignalAgent extends http.BaseClient {
  SignalAgent({http.Client? transport, DeviceInfoPlugin? deviceInfo})
      : _transport = transport ?? http.Client(),
        _deviceInfo = deviceInfo ?? DeviceInfoPlugin();

  static const String _fallbackIosVersion = '18.4';
  static const int _minMajorIos = 18;
  static const int _maxIosComponents = 3;

  final http.Client _transport;
  final DeviceInfoPlugin _deviceInfo;
  String? _cachedUserAgent;

  Future<void> prepare() async {
    _cachedUserAgent = await _resolveUserAgent();
  }

  String get userAgent => _cachedUserAgent ??= _forgeSafariHeader(
        _fallbackIosVersion,
      );

  Future<String> _resolveUserAgent() async {
    if (!Platform.isIOS) return _forgeSafariHeader(_fallbackIosVersion);
    try {
      final info = await _deviceInfo.iosInfo;
      final normalised = _normaliseIosVersion(info.systemVersion);
      return _forgeSafariHeader(normalised);
    } catch (_) {
      return _forgeSafariHeader(_fallbackIosVersion);
    }
  }

  String _normaliseIosVersion(String raw) {
    final parts = <int>[];
    for (final segment in raw.split('.')) {
      final parsed = int.tryParse(segment);
      if (parsed == null) continue;
      parts.add(parsed);
      if (parts.length == _maxIosComponents) break;
    }
    if (parts.isEmpty || parts.first < _minMajorIos) {
      return _fallbackIosVersion;
    }
    return parts.join('.');
  }

  // GAME THEME CATEGORY: crash (no appid/appname suffix).
  String _forgeSafariHeader(String iosVersion) {
    final buffer = StringBuffer('Mozilla/5.0 (iPhone; CPU iPhone OS ')
      ..write(iosVersion.replaceAll('.', '_'))
      ..write(' like Mac OS X) AppleWebKit/')
      ..write(NovaGateConfig.webKitVersion)
      ..write(' (KHTML, like Gecko) Version/')
      ..write(NovaGateConfig.safariVersion)
      ..write(' Mobile/15E148 Safari/')
      ..write(NovaGateConfig.safariTail);
    return buffer.toString();
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.putIfAbsent('User-Agent', () => userAgent);
    return _transport.send(request);
  }

  @override
  void close() => _transport.close();
}
