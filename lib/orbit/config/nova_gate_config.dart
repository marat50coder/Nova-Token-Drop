import '../core/nebula_cipher.dart';

/// Central config for the Nova Token Drop gray gate. Every credential lives as
/// an obfuscated byte array produced by `tool/encode_nova_values.dart` — this
/// file never contains plaintext URLs, keys or project ids.
///
/// Rotation workflow:
///   1. Edit `tool/encode_nova_values.dart` (plaintext map at the bottom).
///   2. Run `dart run tool/encode_nova_values.dart`.
///   3. Paste the printed byte arrays here in the matching slots.
///   4. The tool's VERIFY footer must confirm a round-trip.
///
/// The gate stays disabled (game only) until [endpoint], [appsFlyerKey] and
/// [firebaseProjectNumber] all decode to non-empty strings.
abstract final class NovaGateConfig {
  static const String appTitle = 'Nova Token Drop';
  static const String bundleId = 'com.novatoken.dropgame';

  /// iOS App Store numeric id — used for GCD + `store_id` (sent as `id<num>`).
  static const String iosStoreId = '6792760721';

  static const int pushSnoozeSeconds = 259200; // 3 days
  static const int organicRecheckSeconds = 6;

  // ── Encoded secrets (from tool/encode_nova_values.dart) ──────────────────
  // https://novatokendrop.com/config.php
  static const List<int> _endpoint = <int>[
    115, 153, 14, 55, 1, 243, 204, 90, 119, 68, 65, 214, 181, 211, 106, 222,
    199, 173, 105, 117, 73, 170, 81, 169, 30, 184, 21, 66, 240, 89, 203, 139,
    157, 8, 174, 207,
  ];
  // https://novatokendrop.com/privacy-policy.html
  static const List<int> _privacy = <int>[
    131, 61, 138, 181, 61, 236, 71, 28, 52, 78, 148, 158, 203, 198, 142, 58,
    106, 27, 49, 149, 50, 219, 130, 108, 84, 20, 218, 65, 99, 170, 226, 191,
    188, 220, 161, 12, 192, 171, 148, 24, 64, 91, 165, 89, 101,
  ];
  // https://novatokendrop.com/support.html
  static const List<int> _support = <int>[
    253, 135, 184, 208, 157, 190, 56, 31, 246, 224, 111, 55, 189, 59, 187, 86,
    132, 170, 244, 162, 154, 125, 251, 224, 222, 76, 74, 165, 107, 24, 73, 70,
    124, 153, 162, 45, 12, 138,
  ];
  // https://gcdsdk.appsflyer.com/install_data/v5.0/
  static const List<int> _gcd = <int>[
    31, 228, 85, 162, 195, 225, 242, 93, 82, 178, 113, 14, 221, 200, 250, 71,
    199, 131, 115, 194, 220, 73, 106, 143, 244, 224, 198, 147, 85, 55, 146,
    108, 235, 233, 82, 123, 139, 213, 117, 12, 141, 59, 207, 203, 210, 144, 68,
  ];
  static const List<int> _appsFlyerKey = <int>[
    254, 206, 12, 175, 126, 243, 173, 244, 235, 118, 114, 69, 210, 164, 91, 4,
    202, 74, 225, 103, 48, 213,
  ];
  static const List<int> _firebaseProject = <int>[
    163, 29, 198, 114, 173, 131, 247, 110, 62, 244, 104, 68,
  ];

  // User-Agent version fragments — varied per project.
  static const List<int> _webkit = <int>[
    102, 106, 85, 167, 56, 41, 86, 187,
  ];
  static const List<int> _safari = <int>[244, 92, 122, 0];
  static const List<int> _safariTail = <int>[59, 69, 93, 34, 211];

  static String get endpoint => decodeNebula(_endpoint);
  static String get privacyUrl => decodeNebula(_privacy);
  static String get supportUrl => decodeNebula(_support);
  static String get gcdBase => decodeNebula(_gcd);
  static String get webKitVersion => decodeNebula(_webkit);
  static String get safariVersion => decodeNebula(_safari);
  static String get safariTail => decodeNebula(_safariTail);
  static String get appsFlyerKey => decodeNebula(_appsFlyerKey);
  static String get firebaseProjectNumber => decodeNebula(_firebaseProject);

  static String get storeToken => 'id$iosStoreId';

  /// Gate needs config endpoint + AF key + Firebase project number. Do NOT add
  /// optional values here — a missing optional would disable the whole gate.
  static bool get gateCredentialsReady =>
      endpoint.isNotEmpty &&
      appsFlyerKey.isNotEmpty &&
      firebaseProjectNumber.isNotEmpty;
}
