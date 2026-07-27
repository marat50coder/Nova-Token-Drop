// ignore_for_file: avoid_print

import 'dart:typed_data';

/// Keep byte-for-byte identical to `_driftSeed` in
/// lib/orbit/core/nebula_cipher.dart.
const List<int> _driftSeed = <int>[
  78, 118, 55, 68, 114, 48, 112, 46, 79, 114, 98, 105, 116,
];

Uint8List _driftStream(int length) {
  final state = List<int>.generate(256, (index) => index);
  var cursor = 0;
  for (var index = 0; index < state.length; index++) {
    cursor =
        (cursor + state[index] + _driftSeed[index % _driftSeed.length] + index) &
        0xff;
    final swap = state[index];
    state[index] = state[cursor];
    state[cursor] = swap;
  }
  final result = Uint8List(length);
  var left = 0;
  var right = 0;
  for (var index = 0; index < length; index++) {
    left = (left + 1) & 0xff;
    right = (right + state[left] + index) & 0xff;
    final swap = state[left];
    state[left] = state[right];
    state[right] = swap;
    result[index] = state[(state[left] + state[right]) & 0xff];
  }
  return result;
}

List<int> encodeNebula(String value) {
  final bytes = Uint8List.fromList(value.codeUnits);
  final stream = _driftStream(bytes.length);
  return List<int>.generate(
    bytes.length,
    (index) => (bytes[index] + stream[index] + (index * 23)) & 0xff,
  );
}

String decodeNebula(List<int> encoded) {
  final stream = _driftStream(encoded.length);
  return String.fromCharCodes(
    List<int>.generate(
      encoded.length,
      (index) => (encoded[index] - stream[index] - (index * 23)) & 0xff,
    ),
  );
}

void main() {
  // Nova Token Drop credentials. After editing, run:
  //   dart run tool/encode_nova_values.dart
  // then paste the printed arrays into
  // lib/orbit/config/nova_gate_config.dart.
  const values = <String, String>{
    'endpoint': 'https://novatokendrop.com/config.php',
    'privacy': 'https://novatokendrop.com/privacy-policy.html',
    'support': 'https://novatokendrop.com/support.html',
    'gcd': 'https://gcdsdk.appsflyer.com/install_data/v5.0/',
    'webkit': '605.1.15',
    'safari': '18.5',
    'safariTail': '604.1',
    'appsFlyerKey': '3u3esfHnhrj7bYRXrz3xEj',
    'firebaseProject': '741000623106',
  };

  for (final entry in values.entries) {
    final encoded = encodeNebula(entry.value);
    print('${entry.key}: <int>[${encoded.join(', ')}]');
    if (decodeNebula(encoded) != entry.value) {
      throw StateError('Round-trip failed for ${entry.key}');
    }
  }
  print('VERIFY: all values round-tripped');
}
