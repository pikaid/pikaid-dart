import 'dart:typed_data';

/// Decodes a lowercase hexadecimal string into bytes.
///
/// Test-local helper: oracles in this suite are written as hex literals from
/// the specification and from an independent Python implementation, never
/// produced by `package:pikaid` itself.
Uint8List hexToBytes(String hex) {
  if (hex.length.isOdd) {
    throw ArgumentError.value(hex, 'hex', 'must have an even length');
  }
  final bytes = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}

/// Formats bytes as lowercase hexadecimal.
String bytesToHex(List<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
