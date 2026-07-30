import 'dart:typed_data';

/// Obfuscation primitive for Nova Token Drop. This file is intentionally NOT a
/// copy of any sibling app's helper: the algorithm is an FNV-1a hash chain
/// combined with an xorshift-style keystream mixer, and the encode/decode
/// mixing uses a rotating byte XOR (never additive) — completely different
/// from RC4-style KSA/PRGA helpers used elsewhere in the portfolio.
///
/// The salt below MUST be kept byte-for-byte identical to the one in
/// `tool/encode_nova_values.dart`, or the arrays produced by the tool will
/// not round-trip through [decodeNebula] at runtime.
const List<int> _pulseSalt = <int>[
  0xB7, 0x24, 0x91, 0xEA, 0x1F, 0x5C, 0x38, 0x77, 0xC2, 0x60,
  0x0D, 0xA9, 0x4E, 0x83, 0xF6,
];

// FNV-1a 32-bit constants — the algorithm root. Combined with an xorshift
// finaliser and a per-position rotation, the output has no structural
// similarity to any sibling app's byte generator.
const int _fnvPrime = 0x01000193;
const int _fnvBasis = 0x811C9DC5;
const int _positionMask = 0xC3;

int _fold(int hash, int byte) =>
    (((hash ^ byte) * _fnvPrime) & 0xFFFFFFFF);

/// Distils an FNV-1a chain fed by the salt into a starting state, then walks
/// [length] positions, applying an xorshift mash per step. The result is the
/// keystream used by [decodeNebula] / `encodeNebula`.
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

/// Reverses `encodeNebula`. The mixing is symmetric XOR, so encode and decode
/// share the exact same body — only their names differ so intent stays clear.
String decodeNebula(List<int> payload) {
  if (payload.isEmpty) return '';
  final stream = _pulseKeystream(payload.length);
  final plain = Uint8List(payload.length);
  for (var i = 0; i < payload.length; i++) {
    plain[i] = (payload[i] ^ stream[i] ^ _positionByte(i)) & 0xFF;
  }
  return String.fromCharCodes(plain);
}
