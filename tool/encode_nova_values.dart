// ignore_for_file: avoid_print

import 'dart:typed_data';

/// Keep byte-for-byte identical to `_pulseSalt` in
/// `lib/orbit/core/nebula_cipher.dart` — otherwise the arrays this tool prints
/// will not round-trip through `decodeNebula` at runtime.
const List<int> _pulseSalt = <int>[
  0xB7, 0x24, 0x91, 0xEA, 0x1F, 0x5C, 0x38, 0x77, 0xC2, 0x60,
  0x0D, 0xA9, 0x4E, 0x83, 0xF6,
];

const int _fnvPrime = 0x01000193;
const int _fnvBasis = 0x811C9DC5;
const int _positionMask = 0xC3;

int _fold(int hash, int byte) =>
    (((hash ^ byte) * _fnvPrime) & 0xFFFFFFFF);

Uint8List _pulseKeystream(int length) {
  var state = _fnvBasis;
  for (final byte in _pulseSalt) {
    state = _fold(state, byte);
  }
  state = _fold(state, length & 0xFF);
  state = _fold(state, (length >> 8) & 0xFF);
  final buffer = Uint8List(length);
  for (var i = 0; i < length; i++) {
    state = _fold(state, i & 0xFF);
    state = (state ^ ((state << 13) & 0xFFFFFFFF)) & 0xFFFFFFFF;
    state = (state ^ (state >> 17)) & 0xFFFFFFFF;
    state = (state ^ ((state << 5) & 0xFFFFFFFF)) & 0xFFFFFFFF;
    buffer[i] = (state ^ (state >> 8) ^ (state >> 16) ^ (state >> 24)) & 0xFF;
  }
  return buffer;
}

int _positionByte(int index) =>
    (((index * _positionMask) ^ ((index << 3) & 0xFF) ^ (index >> 2)) & 0xFF);

List<int> encodeNebula(String value) {
  final bytes = Uint8List.fromList(value.codeUnits);
  final stream = _pulseKeystream(bytes.length);
  return List<int>.generate(
    bytes.length,
    (i) => (bytes[i] ^ stream[i] ^ _positionByte(i)) & 0xFF,
  );
}

String decodeNebula(List<int> payload) {
  if (payload.isEmpty) return '';
  final stream = _pulseKeystream(payload.length);
  return String.fromCharCodes(
    List<int>.generate(
      payload.length,
      (i) => (payload[i] ^ stream[i] ^ _positionByte(i)) & 0xFF,
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
    'safari': '18.4',
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
