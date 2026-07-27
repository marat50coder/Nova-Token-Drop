import 'dart:typed_data';

/// Obfuscation seed for Nova Token Drop. Unique per project — never reuse a
/// sibling app's seed. Keep this list byte-for-byte identical to the copy in
/// `tool/encode_nova_values.dart`, or the encoded arrays will not decode.
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

/// Reverses [encodeNebula] (see tool/encode_nova_values.dart).
String decodeNebula(List<int> encoded) {
  if (encoded.isEmpty) return '';
  final stream = _driftStream(encoded.length);
  final plain = Uint8List(encoded.length);
  for (var index = 0; index < encoded.length; index++) {
    plain[index] = (encoded[index] - stream[index] - (index * 23)) & 0xff;
  }
  return String.fromCharCodes(plain);
}
