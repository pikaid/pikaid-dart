/// An independent reference implementation of pikaid specification 1.0.4.
///
/// This file is intentionally *not* built on `package:pikaid`: it uses
/// arbitrary-precision [BigInt] arithmetic and `dart:typed_data` only, so the
/// package under test is compared against a second implementation rather than
/// against itself. It also never uses `dart:io`, so the same oracle runs on the
/// VM, dart2js and dart2wasm.
library;

import 'dart:typed_data';

const String _alphabet = '0123456789abcdefghijklmnopqrstuvwxyz';
const int _timestampCharacters = 7;
const int _randomnessCharacters = 19;
const int _randomnessBytes = 12;
const int _maxTimestamp = 78364164095;
final BigInt _randomnessLimit = BigInt.one << 96;

/// Encodes [timestamp] and exactly 12 [randomness] bytes as pikaid text.
///
/// Throws [ArgumentError] when the inputs are not representable.
String referenceEncode(int timestamp, List<int> randomness) {
  if (timestamp < 0 || timestamp > _maxTimestamp) {
    throw ArgumentError.value(timestamp, 'timestamp', 'out of range');
  }
  if (randomness.length != _randomnessBytes) {
    throw ArgumentError.value(
      randomness.length,
      'randomness',
      'must be exactly $_randomnessBytes bytes',
    );
  }
  final randomnessValue = _bigIntFromBytes(randomness);
  return _base36(BigInt.from(timestamp), _timestampCharacters) +
      _base36(randomnessValue, _randomnessCharacters);
}

/// Encodes [timestamp] and [randomness] as the 17-byte binary representation.
Uint8List referenceBinary(int timestamp, List<int> randomness) {
  if (timestamp < 0 || timestamp > _maxTimestamp) {
    throw ArgumentError.value(timestamp, 'timestamp', 'out of range');
  }
  if (randomness.length != _randomnessBytes) {
    throw ArgumentError.value(
      randomness.length,
      'randomness',
      'must be exactly $_randomnessBytes bytes',
    );
  }
  final bytes = Uint8List(5 + _randomnessBytes);
  // The timestamp field is 40 bits wide, which exceeds the 32-bit integer
  // shift semantics of dart2js. Use BigInt so the oracle is portable.
  var remaining = BigInt.from(timestamp);
  for (var i = 4; i >= 0; i--) {
    bytes[i] = (remaining & BigInt.from(0xff)).toInt();
    remaining = remaining >> 8;
  }
  bytes.setRange(5, bytes.length, randomness);
  return bytes;
}

/// Decodes pikaid text into its components, or throws [FormatException].
({int timestamp, String randomnessHex}) referenceDecode(String value) {
  if (value.length != _timestampCharacters + _randomnessCharacters) {
    throw FormatException('wrong length', value);
  }
  for (var i = 0; i < value.length; i++) {
    if (!_isLowercaseBase36(value.codeUnitAt(i))) {
      throw FormatException('not lowercase Base36', value, i);
    }
  }
  final timestamp = _decode(value.substring(0, _timestampCharacters));
  if (timestamp > BigInt.from(_maxTimestamp)) {
    throw FormatException('timestamp overflow', value);
  }
  final randomness = _decode(value.substring(_timestampCharacters));
  if (randomness >= _randomnessLimit) {
    throw FormatException('randomness overflow', value);
  }
  return (
    timestamp: timestamp.toInt(),
    randomnessHex: _hexFromBigInt(randomness, _randomnessBytes),
  );
}

/// Whether [value] is a fully valid pikaid, computed independently.
bool referenceIsValid(String value) {
  try {
    referenceDecode(value);
    return true;
  } on FormatException {
    return false;
  }
}

/// Whether [value] has the pikaid shape: 26 lowercase Base36 characters.
///
/// The shape check deliberately does not decode; it mirrors the documented
/// shape-only semantics of `Pikaid.isWellFormed`.
bool referenceIsWellFormed(String value) {
  if (value.length != _timestampCharacters + _randomnessCharacters) {
    return false;
  }
  for (var i = 0; i < value.length; i++) {
    if (!_isLowercaseBase36(value.codeUnitAt(i))) {
      return false;
    }
  }
  return true;
}

/// Decodes a 17-byte binary representation into its components.
({int timestamp, String randomnessHex}) referenceDecodeBinary(
  List<int> bytes,
) {
  if (bytes.length != 5 + _randomnessBytes) {
    throw FormatException('wrong length', bytes);
  }
  var timestamp = BigInt.zero;
  for (var i = 0; i < 5; i++) {
    final byte = bytes[i];
    if (byte < 0 || byte > 0xff) {
      throw FormatException('byte out of range at $i', bytes, i);
    }
    timestamp = (timestamp << 8) | BigInt.from(byte);
  }
  if (timestamp > BigInt.from(_maxTimestamp)) {
    throw FormatException('timestamp overflow', bytes);
  }
  final randomness = bytes.sublist(5);
  for (var i = 0; i < randomness.length; i++) {
    final byte = randomness[i];
    if (byte < 0 || byte > 0xff) {
      throw FormatException('byte out of range at ${5 + i}', bytes, 5 + i);
    }
  }
  return (timestamp: timestamp.toInt(), randomnessHex: _hex(randomness));
}

bool _isLowercaseBase36(int codeUnit) =>
    (codeUnit >= 0x30 && codeUnit <= 0x39) ||
    (codeUnit >= 0x61 && codeUnit <= 0x7a);

BigInt _decode(String digits) {
  var value = BigInt.zero;
  for (var i = 0; i < digits.length; i++) {
    final codeUnit = digits.codeUnitAt(i);
    final digit = codeUnit <= 0x39 ? codeUnit - 0x30 : codeUnit - 0x61 + 10;
    value = value * BigInt.from(36) + BigInt.from(digit);
  }
  return value;
}

String _base36(BigInt value, int width) {
  var current = value;
  final buffer = StringBuffer();
  if (current == BigInt.zero) {
    buffer.write('0');
  }
  while (current > BigInt.zero) {
    final digit = (current % BigInt.from(36)).toInt();
    buffer.write(_alphabet[digit]);
    current = current ~/ BigInt.from(36);
  }
  final digits = buffer.toString().split('').reversed.join();
  if (digits.length > width) {
    throw ArgumentError.value(value, 'value', 'does not fit in $width digits');
  }
  return digits.padLeft(width, '0');
}

BigInt _bigIntFromBytes(List<int> bytes) {
  var value = BigInt.zero;
  for (final byte in bytes) {
    if (byte < 0 || byte > 0xff) {
      throw ArgumentError.value(byte, 'byte', 'out of range');
    }
    value = (value << 8) | BigInt.from(byte);
  }
  return value;
}

String _hexFromBigInt(BigInt value, int bytes) {
  var remaining = value;
  final buffer = List<int>.filled(bytes, 0);
  for (var i = bytes - 1; i >= 0; i--) {
    buffer[i] = (remaining & BigInt.from(0xff)).toInt();
    remaining = remaining >> 8;
  }
  return _hex(buffer);
}

String _hex(List<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
