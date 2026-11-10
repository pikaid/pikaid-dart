/// Internal, integer-safe Base36 and big-endian byte codecs.
///
/// The pikaid randomness field is 96 bits wide, which is larger than a
/// JavaScript-safe integer. Every conversion here therefore works on byte
/// arrays with 16-bit-safe intermediate values (`0..9215`) instead of relying
/// on 64-bit `int` arithmetic or `BigInt`. The same code is exact on the Dart
/// VM, on dart2js and on dart2wasm.
///
/// This library is an implementation detail of `package:pikaid` and is not
/// exported by `package:pikaid/pikaid.dart`.
library;

import 'dart:typed_data';

/// The Base36 alphabet in ascending digit order, as required by the
/// specification.
const String base36Alphabet = '0123456789abcdefghijklmnopqrstuvwxyz';

/// The Base36 radix.
const int base36Radix = 36;

/// Number of bytes used by the binary timestamp field.
const int timestampFieldBytes = 5;

/// Converts an ASCII [codeUnit] to its Base36 digit value.
///
/// Returns `-1` for every code unit outside `[0-9a-z]`, including uppercase
/// letters and any non-ASCII value.
int base36DigitValue(int codeUnit) {
  if (codeUnit >= 0x30 && codeUnit <= 0x39) {
    return codeUnit - 0x30;
  }
  if (codeUnit >= 0x61 && codeUnit <= 0x7a) {
    return codeUnit - 0x61 + 10;
  }
  return -1;
}

/// The ASCII code unit for a Base36 digit [value] in `0..35`.
int base36CodeUnit(int value) => value < 10 ? 0x30 + value : 0x61 + value - 10;

/// Whether [value] is exactly [length] ASCII characters from `[0-9a-z]`.
///
/// This is a shape check only: it never looks at the numeric meaning of the
/// decoded components.
bool isBase36String(String value, int length) {
  if (value.length != length) {
    return false;
  }
  for (var i = 0; i < length; i++) {
    if (base36DigitValue(value.codeUnitAt(i)) < 0) {
      return false;
    }
  }
  return true;
}

/// Encodes a non-negative [value] in lowercase Base36 and left-pads it with
/// `0` to exactly [width] characters.
///
/// Throws an [ArgumentError] if [value] is negative or needs more than
/// [width] digits. Callers are expected to range-check first; the throw is a
/// programming-error guard.
String encodeBase36Fixed(int value, int width) {
  if (value < 0) {
    throw ArgumentError.value(value, 'value', 'must not be negative');
  }
  final digits = Uint8List(width);
  var remaining = value;
  var index = width - 1;
  while (remaining > 0) {
    if (index < 0) {
      throw ArgumentError.value(
        value,
        'value',
        'does not fit in $width Base36 digits',
      );
    }
    digits[index] = remaining % base36Radix;
    remaining ~/= base36Radix;
    index--;
  }
  return _digitsToString(digits);
}

/// Decodes exactly [length] Base36 characters starting at [start] into an
/// `int`.
///
/// The characters must already be known to be lowercase Base36. The result is
/// exact for up to 11 Base36 digits (all values below `2^53`); pikaid only
/// uses this for the 7-character timestamp field.
int decodeBase36Int(String value, int start, int length) {
  var result = 0;
  final end = start + length;
  for (var i = start; i < end; i++) {
    final digit = base36DigitValue(value.codeUnitAt(i));
    if (digit < 0) {
      throw ArgumentError.value(value, 'value', 'not lowercase Base36');
    }
    result = result * base36Radix + digit;
  }
  return result;
}

/// Encodes an unsigned big-endian integer held in [bytes] as lowercase Base36
/// and left-pads it with `0` to exactly [width] characters.
///
/// The encoder is a base-256 to base-36 long division. Intermediate values are
/// at most `35 * 256 + 255 = 9215`, so no 53-bit (JavaScript) integer limit is
/// reachable, and no big-integer library is required.
String encodeBase36BytesFixed(List<int> bytes, int width) {
  final work = Uint8List.fromList(bytes);

  // Skip leading zero bytes; they do not change the numeric value.
  var start = 0;
  while (start < work.length && work[start] == 0) {
    start++;
  }
  var activeLength = work.length - start;
  if (activeLength == 0) {
    return '0' * width;
  }
  if (start > 0) {
    work.setRange(0, activeLength, work, start);
  }

  final digits = <int>[];
  while (activeLength > 0) {
    var remainder = 0;
    var write = 0;
    for (var i = 0; i < activeLength; i++) {
      final current = remainder * 256 + work[i];
      final quotient = current ~/ base36Radix;
      remainder = current - quotient * base36Radix;
      if (write > 0 || quotient != 0) {
        work[write] = quotient;
        write++;
      }
    }
    digits.add(remainder);
    activeLength = write;
  }

  if (digits.length > width) {
    throw ArgumentError.value(
      bytes,
      'bytes',
      'does not fit in $width Base36 digits',
    );
  }
  final buffer = StringBuffer();
  for (var i = digits.length; i < width; i++) {
    buffer.write('0');
  }
  for (var i = digits.length - 1; i >= 0; i--) {
    buffer.writeCharCode(base36CodeUnit(digits[i]));
  }
  return buffer.toString();
}

/// Decodes [length] lowercase Base36 characters starting at [start] into
/// exactly [byteLength] big-endian bytes, left-padded with zero bytes.
///
/// Returns `null` when the decoded value does not fit in [byteLength] bytes,
/// which for pikaid means the randomness component exceeded 96 bits. The
/// overflow test is exact: it is a carry out of the most significant byte.
///
/// Throws an [ArgumentError] if the input contains a non-Base36 character;
/// callers validate the alphabet before calling this function.
Uint8List? decodeBase36Bytes(
  String value, {
  required int start,
  required int length,
  required int byteLength,
}) {
  final bytes = Uint8List(byteLength);
  final end = start + length;
  for (var i = start; i < end; i++) {
    var carry = base36DigitValue(value.codeUnitAt(i));
    if (carry < 0) {
      throw ArgumentError.value(value, 'value', 'not lowercase Base36');
    }
    for (var j = byteLength - 1; j >= 0; j--) {
      final current = bytes[j] * base36Radix + carry;
      bytes[j] = current & 0xff;
      carry = current >> 8;
    }
    if (carry != 0) {
      return null;
    }
  }
  return bytes;
}

/// Encodes [timestamp] as exactly 5 unsigned big-endian bytes.
///
/// [timestamp] must be in `0..78364164095`; callers range-check it.
Uint8List encodeTimestampBytes(int timestamp) {
  final bytes = Uint8List(timestampFieldBytes);
  var remaining = timestamp;
  for (var i = timestampFieldBytes - 1; i >= 0; i--) {
    bytes[i] = remaining % 256;
    remaining ~/= 256;
  }
  return bytes;
}

/// Decodes 5 unsigned big-endian bytes starting at [offset] into an `int`.
///
/// The maximum representable value is `2^40 - 1`, which is exact on every
/// supported runtime.
int decodeTimestampBytes(List<int> bytes, [int offset = 0]) {
  var value = 0;
  for (var i = 0; i < timestampFieldBytes; i++) {
    value = value * 256 + bytes[offset + i];
  }
  return value;
}

/// Formats [bytes] as a lowercase hexadecimal string of `2 * bytes.length`
/// characters.
String bytesToHex(List<int> bytes) {
  final buffer = StringBuffer();
  for (final byte in bytes) {
    buffer
      ..writeCharCode(hexCodeUnit(byte >> 4))
      ..writeCharCode(hexCodeUnit(byte & 0x0f));
  }
  return buffer.toString();
}

/// The ASCII code unit for a lowercase hexadecimal digit in `0..15`.
int hexCodeUnit(int value) => value < 10 ? 0x30 + value : 0x61 + value - 10;

String _digitsToString(Uint8List digits) {
  final codes = Uint8List(digits.length);
  for (var i = 0; i < digits.length; i++) {
    codes[i] = base36CodeUnit(digits[i]);
  }
  return String.fromCharCodes(codes);
}
