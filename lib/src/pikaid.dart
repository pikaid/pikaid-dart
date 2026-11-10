import 'dart:typed_data';

import 'base36.dart';
import 'pikaid_entropy_exception.dart';
import 'random_source.dart';

/// An immutable pikaid value.
///
/// A pikaid is a compact, chronologically sortable identifier defined by
/// [pikaid specification revision 1.0.4][spec]. The identifier format is
/// immutable and unversioned; specification revisions do not change it.
///
/// Text form — exactly [stringLength] lowercase Base36 ASCII characters:
///
/// ```text
/// [ 7 characters: Unix seconds, Base36, left-padded ][ 19 characters: 96-bit randomness, Base36, left-padded ]
/// ```
///
/// Binary form — exactly [binaryLength] bytes:
///
/// ```text
/// [ 5 bytes: Unix seconds, unsigned big-endian ][ 12 bytes: randomness, unchanged ]
/// ```
///
/// ## Ordering
///
/// [compareTo] compares the timestamp first and the randomness bytes second,
/// which matches ASCII lexicographic order of the text form and unsigned
/// bytewise order of the binary form. Values with different timestamps sort
/// chronologically. Values generated within the same second are ordered by
/// their random suffix, **not** by generation order: pikaid is not a monotonic
/// sequence generator and has one-second timestamp precision.
///
/// ## Security
///
/// Randomness comes from a cryptographically secure source ([Pikaid.generate]
/// and friends use [SecurePikaidRandomSource], which is backed by
/// `Random.secure`). 96 bits of randomness make accidental collisions
/// unlikely, but uniqueness is **not** guaranteed: applications should enforce
/// uniqueness where it matters. pikaid values are readable and are **not**
/// secrets, authentication tokens, or authorization substitutes.
///
/// ## Errors
///
/// * [FormatException] — an invalid text or binary representation passed to
///   [Pikaid.parse], [Pikaid.tryParse]'s strict counterpart, or
///   [Pikaid.fromBinary]. Invalid input is never normalized, truncated or
///   coerced.
/// * [RangeError] — a caller-supplied timestamp outside
///   `0..Pikaid.maxTimestamp`, or an out-of-range byte in
///   [Pikaid.fromComponents].
/// * [PikaidEntropyException] — the default secure source could not supply
///   secure bytes. Generation fails closed and never substitutes weaker
///   entropy. A custom [PikaidRandomSource] must throw when it cannot provide
///   secure bytes; its error is propagated unchanged.
///
/// [spec]: https://github.com/pikaid/pikaid-specs/tree/v1.0.4
final class Pikaid implements Comparable<Pikaid> {
  Pikaid._(this.timestamp, this._randomness);

  /// Length of the text representation in characters, always `26`.
  static const int stringLength = 26;

  /// Length of the binary representation in bytes, always `17`.
  static const int binaryLength = 17;

  /// Width of the timestamp component in characters, always `7`.
  static const int timestampLength = 7;

  /// Width of the randomness component in characters, always `19`.
  static const int randomnessLength = 19;

  /// Width of the randomness component in bytes, always `12` (96 bits).
  static const int randomnessBytes = 12;

  /// Largest valid timestamp, `36^7 - 1 = 78364164095`
  /// (`4453-04-05T15:21:35Z`).
  static const int maxTimestamp = 78364164095;

  /// Whole Unix seconds since `1970-01-01T00:00:00Z`, in
  /// `0..maxTimestamp`.
  final int timestamp;

  final Uint8List _randomness;

  /// The 12 randomness bytes as an unmodifiable view.
  ///
  /// The view reflects this value's immutable buffer, so it is stable for the
  /// lifetime of the object. Any attempt to modify it throws an
  /// [UnsupportedError].
  Uint8List get randomness => _randomnessView;
  late final Uint8List _randomnessView = _randomness.asUnmodifiableView();

  /// The randomness field as 24 lowercase hexadecimal characters.
  String get randomnessHex => bytesToHex(_randomness);

  /// The timestamp as a UTC [DateTime] with one-second precision.
  DateTime get timestampUtc =>
      DateTime.fromMillisecondsSinceEpoch(timestamp * 1000, isUtc: true);

  /// Creates a pikaid for the current UTC second using secure randomness.
  ///
  /// Throws a [RangeError] if the system clock is outside
  /// `0..maxTimestamp`, and a [PikaidEntropyException] if secure randomness is
  /// unavailable.
  factory Pikaid.generate({
    PikaidRandomSource randomSource = const SecurePikaidRandomSource(),
  }) =>
      Pikaid.generateAt(_currentUnixSeconds(), randomSource: randomSource);

  /// Creates a pikaid with an explicit [timestamp] and secure randomness.
  ///
  /// The caller is responsible for choosing a meaningful timestamp; it is
  /// still range-checked. Entropy always comes from [randomSource] and is
  /// never derived from the timestamp.
  ///
  /// Throws a [RangeError] if [timestamp] is outside `0..maxTimestamp`, and a
  /// [PikaidEntropyException] if secure randomness is unavailable.
  factory Pikaid.generateAt(
    int timestamp, {
    PikaidRandomSource randomSource = const SecurePikaidRandomSource(),
  }) {
    _checkTimestamp(timestamp);
    return Pikaid._(timestamp, _secureRandomness(randomSource));
  }

  /// Rebuilds a pikaid from validated components.
  ///
  /// Every byte of [randomness] is preserved, including leading zero bytes.
  /// Use this to restore a value from storage that keeps the fields separately,
  /// or to construct deterministic test values.
  ///
  /// Throws a [RangeError] if [timestamp] is outside `0..maxTimestamp` or a
  /// randomness byte is outside `0..255`, and an [ArgumentError] if
  /// [randomness] is not exactly [randomnessBytes] bytes long.
  factory Pikaid.fromComponents({
    required int timestamp,
    required List<int> randomness,
  }) {
    _checkTimestamp(timestamp);
    if (randomness.length != randomnessBytes) {
      throw ArgumentError.value(
        randomness.length,
        'randomness.length',
        'must be exactly $randomnessBytes bytes',
      );
    }
    final bytes = Uint8List(randomnessBytes);
    for (var i = 0; i < randomnessBytes; i++) {
      final byte = randomness[i];
      if (byte < 0 || byte > 255) {
        throw RangeError.range(byte, 0, 255, 'randomness[$i]');
      }
      bytes[i] = byte;
    }
    return Pikaid._(timestamp, bytes);
  }

  /// Parses a strict pikaid text representation.
  ///
  /// Accepts only exactly [stringLength] ASCII characters from `[0-9a-z]`
  /// whose timestamp and randomness components are both in range. Uppercase
  /// letters, separators, prefixes, suffixes, non-ASCII characters, wrong
  /// lengths and a randomness component above 96 bits are rejected with a
  /// [FormatException]; nothing is trimmed, lowercased or truncated.
  factory Pikaid.parse(String value) {
    if (value.length != stringLength) {
      throw FormatException(
        'pikaid must be exactly $stringLength ASCII characters long, '
        'got ${value.length}',
        value,
      );
    }
    for (var i = 0; i < stringLength; i++) {
      if (base36DigitValue(value.codeUnitAt(i)) < 0) {
        throw FormatException(
          'pikaid characters must be lowercase Base36 ([0-9a-z]); '
          'found ${_describeCodeUnit(value.codeUnitAt(i))} at index $i',
          value,
          i,
        );
      }
    }
    final timestamp = decodeBase36Int(value, 0, timestampLength);
    final randomness = decodeBase36Bytes(
      value,
      start: timestampLength,
      length: randomnessLength,
      byteLength: randomnessBytes,
    );
    if (randomness == null) {
      throw FormatException(
        'pikaid randomness exceeds 96 bits (19 Base36 characters can encode '
        'more than 2^96 values)',
        value,
        timestampLength,
      );
    }
    return Pikaid._(timestamp, randomness);
  }

  /// Parses a strict pikaid binary representation of exactly [binaryLength]
  /// bytes: 5 unsigned big-endian timestamp bytes followed by 12 randomness
  /// bytes.
  ///
  /// The randomness bytes are preserved unchanged, including leading zeros.
  /// Throws a [FormatException] for a wrong length, a byte outside `0..255`, or
  /// a timestamp field above [maxTimestamp]; other values would not correspond
  /// to any valid text representation.
  factory Pikaid.fromBinary(List<int> bytes) {
    final length = bytes.length;
    if (length != binaryLength) {
      throw FormatException(
        'pikaid binary representation must be exactly $binaryLength bytes '
        'long, got $length',
      );
    }
    // Read every byte exactly once into a private buffer and validate that
    // copy. Decoding from the caller's list directly would let a stateful
    // List<int> return a valid byte during validation and a different value
    // during decoding or copying; a Uint8List assignment would silently
    // truncate such a value instead of rejecting it.
    final copy = Uint8List(binaryLength);
    for (var i = 0; i < binaryLength; i++) {
      final byte = bytes[i];
      if (byte < 0 || byte > 255) {
        throw FormatException(
          'pikaid binary representation must contain bytes in 0..255; '
          'found $byte at index $i',
        );
      }
      copy[i] = byte;
    }
    final decodedTimestamp = decodeTimestampBytes(copy);
    if (decodedTimestamp > maxTimestamp) {
      throw FormatException(
        'pikaid binary timestamp field $decodedTimestamp exceeds the maximum '
        'valid timestamp $maxTimestamp',
      );
    }
    final randomness = Uint8List(randomnessBytes);
    for (var i = 0; i < randomnessBytes; i++) {
      randomness[i] = copy[timestampFieldBytes + i];
    }
    return Pikaid._(decodedTimestamp, randomness);
  }

  /// Generates a pikaid for the current UTC second directly in binary form.
  ///
  /// Equivalent to `Pikaid.generate().toBinary()`, without materializing the
  /// text form.
  static Uint8List generateBinary({
    PikaidRandomSource randomSource = const SecurePikaidRandomSource(),
  }) =>
      generateBinaryAt(_currentUnixSeconds(), randomSource: randomSource);

  /// Generates a pikaid with an explicit [timestamp] directly in binary form.
  ///
  /// Equivalent to `Pikaid.generateAt(timestamp).toBinary()`, without
  /// materializing the text form.
  static Uint8List generateBinaryAt(
    int timestamp, {
    PikaidRandomSource randomSource = const SecurePikaidRandomSource(),
  }) {
    _checkTimestamp(timestamp);
    return _binaryOf(timestamp, _secureRandomness(randomSource));
  }

  /// Returns `true` for a fully valid pikaid: correct length, lowercase Base36
  /// alphabet, and both components within their representable ranges.
  ///
  /// This is the semantic predicate; it returns `false` instead of throwing.
  /// See [isWellFormed] for a shape-only check.
  static bool isValid(String value) {
    try {
      Pikaid.parse(value);
      return true;
    } on FormatException {
      return false;
    }
  }

  /// Returns `true` when [value] has the right length and alphabet, without
  /// checking whether the randomness component fits in 96 bits.
  ///
  /// A well-formed string is not necessarily valid: for example
  /// `0000000zzzzzzzzzzzzzzzzzzz` is well formed but invalid. Do not describe
  /// this result as full validity.
  static bool isWellFormed(String value) => isBase36String(value, stringLength);

  /// Parses [value], returning `null` when it is not a valid pikaid.
  ///
  /// Unlike [Pikaid.parse], malformed input is not reported as an exception.
  static Pikaid? tryParse(String value) {
    try {
      return Pikaid.parse(value);
    } on FormatException {
      return null;
    }
  }

  /// The 17-byte binary representation.
  ///
  /// The returned buffer is a fresh, modifiable copy owned by the caller.
  Uint8List toBinary() => _binaryOf(timestamp, _randomness);

  @override
  int compareTo(Pikaid other) {
    if (timestamp != other.timestamp) {
      return timestamp < other.timestamp ? -1 : 1;
    }
    for (var i = 0; i < randomnessBytes; i++) {
      final left = _randomness[i];
      final right = other._randomness[i];
      if (left != right) {
        return left < right ? -1 : 1;
      }
    }
    return 0;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Pikaid || timestamp != other.timestamp) {
      return false;
    }
    for (var i = 0; i < randomnessBytes; i++) {
      if (_randomness[i] != other._randomness[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(timestamp, Object.hashAll(_randomness));

  /// The canonical 26-character lowercase Base36 text representation.
  @override
  String toString() =>
      encodeBase36Fixed(timestamp, timestampLength) +
      encodeBase36BytesFixed(_randomness, randomnessLength);

  static Uint8List _secureRandomness(PikaidRandomSource source) {
    final bytes = Uint8List(randomnessBytes);
    source.fillBytes(bytes);
    return bytes;
  }

  static Uint8List _binaryOf(int timestamp, Uint8List randomness) {
    final bytes = Uint8List(binaryLength)
      ..setRange(0, timestampFieldBytes, encodeTimestampBytes(timestamp))
      ..setRange(timestampFieldBytes, binaryLength, randomness);
    return bytes;
  }

  static void _checkTimestamp(int timestamp) {
    if (timestamp < 0 || timestamp > maxTimestamp) {
      throw RangeError.range(timestamp, 0, maxTimestamp, 'timestamp');
    }
  }
}

/// The current whole UTC second, rounded down.
///
/// `%` is Euclidean for a positive divisor, so this floors correctly for
/// pre-epoch clocks instead of truncating toward zero.
int _currentUnixSeconds() {
  const microsecondsPerSecond = 1000000;
  final microseconds = DateTime.now().toUtc().microsecondsSinceEpoch;
  return (microseconds - microseconds % microsecondsPerSecond) ~/
      microsecondsPerSecond;
}

String _describeCodeUnit(int codeUnit) {
  if (codeUnit >= 0x20 && codeUnit <= 0x7e) {
    return '${String.fromCharCode(codeUnit)} (U+${_hex4(codeUnit)})';
  }
  return 'a non-ASCII or control code unit (U+${_hex4(codeUnit)})';
}

String _hex4(int value) =>
    value.toRadixString(16).padLeft(4, '0').toUpperCase();
