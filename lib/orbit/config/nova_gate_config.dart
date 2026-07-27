import '../core/nebula_cipher.dart';

/// Central config for the Nova Token Drop gray gate. All secrets are stored as
/// obfuscated byte arrays produced by `tool/encode_nova_values.dart` (never
/// plaintext). To rotate a value: edit the tool, run
/// `dart run tool/encode_nova_values.dart`, paste the arrays back here.
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
  static const List<int> _endpoint = <int>[
    85, 225, 234, 233, 222, 222, 3, 221, 133, 19, 4, 221, 44, 253, 77, 100,
    166, 1, 189, 178, 123, 233, 163, 169, 215, 109, 109, 122, 114, 41, 249,
    240, 61, 177, 71, 202,
  ];
  static const List<int> _privacy = <int>[
    85, 225, 234, 233, 222, 222, 3, 221, 133, 19, 4, 221, 44, 253, 77, 100,
    166, 1, 189, 178, 123, 233, 163, 169, 215, 109, 122, 125, 109, 57, 241,
    236, 136, 110, 79, 201, 91, 169, 17, 59, 17, 192, 38, 21, 42,
  ];
  static const List<int> _support = <int>[
    85, 225, 234, 233, 222, 222, 3, 221, 133, 19, 4, 221, 44, 253, 77, 100,
    166, 1, 189, 178, 123, 233, 163, 169, 215, 109, 125, 128, 116, 51, 255,
    251, 131, 111, 71, 206, 92, 172,
  ];
  static const List<int> _gcd = <int>[
    85, 225, 234, 233, 222, 222, 3, 221, 126, 7, 242, 239, 28, 249, 16, 96,
    168, 13, 190, 169, 119, 52, 165, 172, 152, 161, 121, 120, 51, 44, 254,
    252, 131, 162, 75, 198, 78, 164, 15, 54, 68, 135, 40, 221, 236, 183, 206,
  ];
  static const List<int> _appsFlyerKey = <int>[
    32, 226, 169, 222, 222, 10, 28, 28, 127, 22, 248, 179, 26, 231, 52, 87,
    170, 23, 126, 187, 80, 37,
  ];
  static const List<int> _firebaseProject = <int>[
    36, 161, 167, 169, 155, 212, 10, 224, 74, 213, 190, 178,
  ];

  // User-Agent version fragments — varied per project (see gray_user_agent).
  static const List<int> _webkit = <int>[35, 157, 171, 167, 156, 210, 5, 227];
  static const List<int> _safari = <int>[30, 165, 164, 174];
  static const List<int> _safariTail = <int>[35, 157, 170, 167, 156];

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
