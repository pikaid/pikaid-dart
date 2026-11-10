// Maps the normative operations of pikaid specification revision 1.0.4 to the
// public Dart entrypoints that implement them.
//
// The map exists so that API coverage is auditable: every operation the
// specification requires has a named Dart entrypoint, every mapped entrypoint
// is exercised as a public API (not through internals), and the README API
// table stays in sync with the implementation.
//
// This file is deliberately free of `package:test`; `test/api_parity_test.dart`
// drives it.

import 'dart:typed_data';

import 'package:pikaid/pikaid.dart';

/// One specification operation and the public entrypoint that implements it.
final class ApiParityEntry {
  ApiParityEntry({
    required this.specSection,
    required this.specOperation,
    required this.dartEntrypoint,
    required this.verify,
    this.readmeRow,
  });

  /// Normative section of specification revision 1.0.4.
  final String specSection;

  /// The operation, stated in specification terms.
  final String specOperation;

  /// The public Dart entrypoint that implements the operation.
  final String dartEntrypoint;

  /// A row or fragment that must appear in `README.md`.
  final String? readmeRow;

  /// Exercises the entrypoint and throws [StateError] on a contract violation.
  final void Function() verify;
}

/// The specification-to-Dart parity map.
///
/// Entries are ordered by specification section. Every public member of
/// `lib/src/pikaid.dart` appears in at least one [dartEntrypoint].
final List<ApiParityEntry> apiParityMap = <ApiParityEntry>[
  ApiParityEntry(
    specSection: '§1',
    specOperation: 'Fixed widths and representable ranges',
    dartEntrypoint: 'Pikaid.stringLength, Pikaid.binaryLength, '
        'Pikaid.timestampLength, Pikaid.randomnessLength, '
        'Pikaid.randomnessBytes, Pikaid.maxTimestamp',
    verify: _verifyConstants,
  ),
  ApiParityEntry(
    specSection: '§3.1',
    specOperation: 'Generate a string for the current UTC second',
    dartEntrypoint: 'Pikaid.generate',
    readmeRow: 'Pikaid.generate({randomSource})',
    verify: _verifyGenerate,
  ),
  ApiParityEntry(
    specSection: '§3.1',
    specOperation: 'Generate with a caller-supplied, range-checked timestamp',
    dartEntrypoint: 'Pikaid.generateAt',
    readmeRow: 'Pikaid.generateAt(timestamp, {randomSource})',
    verify: _verifyGenerateAt,
  ),
  ApiParityEntry(
    specSection: '§3.2',
    specOperation: 'Generate the 17-byte binary representation',
    dartEntrypoint: 'Pikaid.generateBinary',
    readmeRow: 'Pikaid.generateBinary({randomSource})',
    verify: _verifyGenerateBinary,
  ),
  ApiParityEntry(
    specSection: '§3.2',
    specOperation: 'Generate binary for an explicit timestamp',
    dartEntrypoint: 'Pikaid.generateBinaryAt',
    readmeRow: 'Pikaid.generateBinaryAt(timestamp, {randomSource})',
    verify: _verifyGenerateBinaryAt,
  ),
  ApiParityEntry(
    specSection: '§4',
    specOperation:
        'Rebuild from the conceptual timestamp and randomness fields',
    dartEntrypoint: 'Pikaid.fromComponents',
    readmeRow: 'Pikaid.fromComponents({timestamp, randomness})',
    verify: _verifyFromComponents,
  ),
  ApiParityEntry(
    specSection: '§4',
    specOperation: 'Strict text parsing that reports invalid values as errors',
    dartEntrypoint: 'Pikaid.parse',
    readmeRow: 'Pikaid.parse(String)',
    verify: _verifyParse,
  ),
  ApiParityEntry(
    specSection: '§4',
    specOperation: 'Non-throwing text parsing returning null',
    dartEntrypoint: 'Pikaid.tryParse',
    readmeRow: 'Pikaid.tryParse(String)',
    verify: _verifyTryParse,
  ),
  ApiParityEntry(
    specSection: '§4',
    specOperation: 'Full semantic validity predicate',
    dartEntrypoint: 'Pikaid.isValid',
    readmeRow: 'Pikaid.isValid(String)',
    verify: _verifyIsValid,
  ),
  ApiParityEntry(
    specSection: '§4',
    specOperation: 'Shape-only well-formedness helper (not full validity)',
    dartEntrypoint: 'Pikaid.isWellFormed',
    readmeRow: 'Pikaid.isWellFormed(String)',
    verify: _verifyIsWellFormed,
  ),
  ApiParityEntry(
    specSection: '§3.2, §4',
    specOperation: 'Strict 17-byte binary decoding',
    dartEntrypoint: 'Pikaid.fromBinary',
    readmeRow: 'Pikaid.fromBinary(List<int>)',
    verify: _verifyFromBinary,
  ),
  ApiParityEntry(
    specSection: '§1, §3.1',
    specOperation: 'Canonical 26-character lowercase Base36 text',
    dartEntrypoint: 'Pikaid.toString',
    verify: _verifyToString,
  ),
  ApiParityEntry(
    specSection: '§3.2',
    specOperation: 'Lossless 17-byte binary encoding',
    dartEntrypoint: 'Pikaid.toBinary',
    readmeRow: 'id.toBinary()',
    verify: _verifyToBinary,
  ),
  ApiParityEntry(
    specSection: '§4',
    specOperation: 'Expose the timestamp at full integer precision',
    dartEntrypoint: 'Pikaid.timestamp',
    readmeRow: 'id.timestamp',
    verify: _verifyTimestamp,
  ),
  ApiParityEntry(
    specSection: '§4',
    specOperation: 'Return the timestamp as a UTC datetime',
    dartEntrypoint: 'Pikaid.timestampUtc',
    readmeRow: 'id.timestampUtc',
    verify: _verifyTimestampUtc,
  ),
  ApiParityEntry(
    specSection: '§4',
    specOperation: 'Preserve the original 12 randomness bytes',
    dartEntrypoint: 'Pikaid.randomness',
    readmeRow: 'id.randomness',
    verify: _verifyRandomness,
  ),
  ApiParityEntry(
    specSection: '§4',
    specOperation: 'Expose randomness as 24 lowercase hexadecimal characters',
    dartEntrypoint: 'Pikaid.randomnessHex',
    readmeRow: 'id.randomnessHex',
    verify: _verifyRandomnessHex,
  ),
  ApiParityEntry(
    specSection: '§5',
    specOperation: 'Order by timestamp, then unsigned randomness',
    dartEntrypoint: 'Pikaid.compareTo',
    readmeRow: 'id.compareTo(other)',
    verify: _verifyCompareTo,
  ),
  ApiParityEntry(
    specSection: '§4',
    specOperation: 'Full value equality and hashing',
    dartEntrypoint: 'Pikaid.operator ==, Pikaid.hashCode',
    readmeRow: 'id == other',
    verify: _verifyEquality,
  ),
  ApiParityEntry(
    specSection: '§2 rule 4',
    specOperation: 'Default generation uses a CSPRNG',
    dartEntrypoint: 'SecurePikaidRandomSource',
    readmeRow: 'SecurePikaidRandomSource',
    verify: _verifySecureRandomSource,
  ),
  ApiParityEntry(
    specSection: '§2 rule 4',
    specOperation: 'Injectable random source fills all 12 bytes or throws',
    dartEntrypoint: 'PikaidRandomSource',
    readmeRow: 'PikaidRandomSource',
    verify: _verifyRandomSourceContract,
  ),
  ApiParityEntry(
    specSection: '§2 rule 4',
    specOperation: 'Entropy failure fails closed, never falls back',
    dartEntrypoint: 'PikaidEntropyException',
    readmeRow: 'PikaidEntropyException',
    verify: _verifyEntropyFailure,
  ),
  ApiParityEntry(
    specSection: '§7',
    specOperation: 'Known-answer interoperability examples',
    dartEntrypoint: 'Pikaid.parse, Pikaid.toString, Pikaid.toBinary',
    verify: _verifyKnownAnswers,
  ),
];

/// Extracts the public member names declared by the `Pikaid` class.
///
/// Dart has no runtime reflection in this package (and none on the web), so the
/// parity test reads the declaration source and pins the extracted set. Adding
/// a public member therefore fails the test until it is added to the parity map.
Set<String> extractPublicPikaidMembers(String source) {
  final names = <String>{};
  void collect(RegExp pattern) {
    for (final match in pattern.allMatches(source)) {
      final name = match.group(1)!;
      if (!name.startsWith('_')) {
        names.add(name);
      }
    }
  }

  collect(RegExp(r'^  static const int (\w+) =', multiLine: true));
  collect(RegExp(r'^  final int (\w+);', multiLine: true));
  collect(RegExp(r'^  Uint8List get (\w+)', multiLine: true));
  collect(RegExp(r'^  String get (\w+)', multiLine: true));
  collect(RegExp(r'^  DateTime get (\w+)', multiLine: true));
  collect(RegExp(r'^  factory Pikaid\.(\w+)', multiLine: true));
  collect(
      RegExp(r'^  static (?:Uint8List|bool|Pikaid\?) (\w+)', multiLine: true));
  collect(RegExp(r'^  Uint8List (\w+)\(', multiLine: true));
  collect(RegExp(r'^  int (\w+)\(', multiLine: true));
  collect(RegExp(r'^  int get (\w+)', multiLine: true));
  collect(RegExp(r'^  String (\w+)\(', multiLine: true));
  if (source.contains('bool operator ==')) {
    names.add('==');
  }
  return names;
}

/// The pinned public member set of `Pikaid`, independent of the extraction
/// implementation.
const Set<String> pinnedPikaidPublicMembers = <String>{
  'binaryLength',
  'compareTo',
  'fromBinary',
  'fromComponents',
  'generate',
  'generateAt',
  'generateBinary',
  'generateBinaryAt',
  'hashCode',
  'isValid',
  'isWellFormed',
  'maxTimestamp',
  'parse',
  'randomness',
  'randomnessBytes',
  'randomnessHex',
  'randomnessLength',
  'stringLength',
  'timestamp',
  'timestampLength',
  'timestampUtc',
  'toBinary',
  'toString',
  'tryParse',
  '==',
};

// ---------------------------------------------------------------------------
// Verification helpers. These use only the public API.
// ---------------------------------------------------------------------------

const _exampleText = '0s44we8002loz3po6mcf6vsn23';
const _exampleBinary = '006553f10000112233445566778899aabb';
const _maxText = 'zzzzzzz7oiylpimjg5u2ca1ypr';

void _require(bool condition, String message) {
  if (!condition) {
    throw StateError(message);
  }
}

void _expectThrowsFormat(void Function() action, String label) {
  try {
    action();
  } on FormatException {
    return;
  }
  throw StateError('$label did not throw FormatException');
}

void _verifyConstants() {
  _require(Pikaid.stringLength == 26, 'stringLength');
  _require(Pikaid.binaryLength == 17, 'binaryLength');
  _require(Pikaid.timestampLength == 7, 'timestampLength');
  _require(Pikaid.randomnessLength == 19, 'randomnessLength');
  _require(Pikaid.randomnessBytes == 12, 'randomnessBytes');
  _require(Pikaid.maxTimestamp == 78364164095, 'maxTimestamp');
}

void _verifyGenerate() {
  final before = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final id = Pikaid.generate();
  final after = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  _require(id.toString().length == Pikaid.stringLength, 'generated length');
  _require(Pikaid.isValid(id.toString()), 'generated value is valid');
  _require(
    id.timestamp >= before && id.timestamp <= after,
    'generated timestamp is the current second',
  );
}

void _verifyGenerateAt() {
  final id = Pikaid.generateAt(
    1700000000,
    randomSource: _FixedSource.fromHex('00112233445566778899aabb'),
  );
  _require(id.toString() == _exampleText, 'generateAt known answer');
}

void _verifyGenerateBinary() {
  final bytes = Pikaid.generateBinary(
    randomSource: _FixedSource.fromHex('00112233445566778899aabb'),
  );
  final before = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final after = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  _require(bytes.length == Pikaid.binaryLength, 'binary length');
  final id = Pikaid.fromBinary(bytes);
  _require(
    id.timestamp >= before && id.timestamp <= after,
    'generated binary timestamp is the current second',
  );
}

void _verifyGenerateBinaryAt() {
  final bytes = Pikaid.generateBinaryAt(
    1700000000,
    randomSource: _FixedSource.fromHex('00112233445566778899aabb'),
  );
  _require(_hex(bytes) == _exampleBinary, 'generateBinaryAt known answer');
}

void _verifyFromComponents() {
  final randomness = Uint8List.fromList(List<int>.filled(12, 0));
  final id =
      Pikaid.fromComponents(timestamp: 1700000000, randomness: randomness);
  randomness[0] = 0xff;
  _require(id.toString() == '0s44we80000000000000000000', 'components input');
  _require(id.randomnessHex == '000000000000000000000000', 'components copy');
}

void _verifyParse() {
  final id = Pikaid.parse(_exampleText);
  _require(id.timestamp == 1700000000, 'parsed timestamp');
  _require(id.randomnessHex == '00112233445566778899aabb', 'parsed randomness');
  _expectThrowsFormat(
      () => Pikaid.parse('0000000ZZZZZZZZZZZZZZZZZZZ'), 'uppercase parse');
  _expectThrowsFormat(
      () => Pikaid.parse('0000000zzzzzzzzzzzzzzzzzzz'), 'overflow parse');
}

void _verifyTryParse() {
  _require(Pikaid.tryParse(_exampleText)?.toString() == _exampleText,
      'tryParse valid');
  _require(Pikaid.tryParse('not-a-pikaid') == null, 'tryParse invalid');
  _require(Pikaid.tryParse(' $_exampleText') == null, 'tryParse no trim');
}

void _verifyIsValid() {
  _require(Pikaid.isValid('00000000000000000000000000'), 'zero value');
  _require(Pikaid.isValid(_maxText), 'maximum value');
  _require(!Pikaid.isValid('0000000zzzzzzzzzzzzzzzzzzz'), 'overflow');
  _require(!Pikaid.isValid('0000000ZZZZZZZZZZZZZZZZZZZ'), 'uppercase');
  _require(!Pikaid.isValid('0000001000000000000000000'), 'short');
  _require(!Pikaid.isValid('000000100000000000000000001'), 'long');
  _require(!Pikaid.isValid('0000001000000000000000000-'), 'non-Base36');
}

void _verifyIsWellFormed() {
  _require(
    Pikaid.isWellFormed('0000000zzzzzzzzzzzzzzzzzzz'),
    'shape-only accepts overflow',
  );
  _require(!Pikaid.isValid('0000000zzzzzzzzzzzzzzzzzzz'),
      'semantic check rejects overflow');
  _require(!Pikaid.isWellFormed('0000000ZZZZZZZZZZZZZZZZZZZ'),
      'shape rejects uppercase');
  _require(!Pikaid.isWellFormed('0000000zzzzzzzzzzzzzzzzzz'),
      'shape rejects wrong length');
}

void _verifyFromBinary() {
  final bytes = _fromHex(_exampleBinary);
  final id = Pikaid.fromBinary(bytes);
  _require(id.toString() == _exampleText, 'binary known answer');
  bytes[5] ^= 0xff;
  _require(
      id.randomnessHex == '00112233445566778899aabb', 'binary input is copied');
  _expectThrowsFormat(() => Pikaid.fromBinary(Uint8List(16)), 'short binary');
  _expectThrowsFormat(() => Pikaid.fromBinary(Uint8List(18)), 'long binary');
  _expectThrowsFormat(
    () => Pikaid.fromBinary(_fromHex('ffffffffff000000000000000000000000')),
    'timestamp overflow binary',
  );
}

void _verifyToString() {
  final id = Pikaid.parse(_maxText);
  _require(id.toString() == _maxText, 'canonical text');
  _require(id.toString().length == 26, 'canonical length');
  _require(id.toString() == id.toString().toLowerCase(), 'lowercase text');
}

void _verifyToBinary() {
  final id = Pikaid.parse(_exampleText);
  _require(_hex(id.toBinary()) == _exampleBinary, 'binary known answer');
  final bytes = id.toBinary();
  bytes[0] = 0;
  _require(_hex(id.toBinary()) == _exampleBinary, 'binary output is a copy');
}

void _verifyTimestamp() {
  _require(Pikaid.parse(_exampleText).timestamp == 1700000000, 'timestamp');
  _require(Pikaid.parse('00000000000000000000000000').timestamp == 0, 'zero');
  _require(Pikaid.parse(_maxText).timestamp == Pikaid.maxTimestamp, 'maximum');
}

void _verifyTimestampUtc() {
  final utc = Pikaid.parse(_exampleText).timestampUtc;
  _require(utc.isUtc, 'timestampUtc is UTC');
  _require(utc.toIso8601String() == '2023-11-14T22:13:20.000Z', 'timestampUtc');
  _require(utc.millisecond == 0 && utc.microsecond == 0, 'second precision');
}

void _verifyRandomness() {
  final id = Pikaid.parse(_exampleText);
  _require(id.randomness.length == 12, 'randomness length');
  _require(id.randomnessHex == '00112233445566778899aabb', 'randomness bytes');
  var unmodifiable = false;
  try {
    id.randomness[0] = 0xff;
  } on UnsupportedError {
    unmodifiable = true;
  }
  _require(unmodifiable, 'randomness view is unmodifiable');
  _require(id.randomnessHex == '00112233445566778899aabb',
      'randomness view unchanged after rejected write');
}

void _verifyRandomnessHex() {
  _require(
      Pikaid.parse(_exampleText).randomnessHex == '00112233445566778899aabb',
      'randomnessHex');
  _require(
      Pikaid.parse('00000000000000000000000000').randomnessHex ==
          '000000000000000000000000',
      'leading zero bytes are preserved');
  final hex = Pikaid.parse(_maxText).randomnessHex;
  _require(hex == 'ffffffffffffffffffffffff', 'maximum randomness');
  _require(hex == hex.toLowerCase() && hex.length == 24, 'lowercase hex');
}

void _verifyCompareTo() {
  final zero = Pikaid.parse('00000000000000000000000000');
  final one = Pikaid.parse('00000010000000000000000000');
  _require(zero.compareTo(one) < 0, 'different timestamps');
  _require(one.compareTo(zero) > 0, 'different timestamps reversed');
  _require(zero.compareTo(zero) == 0, 'equal values');
  final low = Pikaid.fromComponents(
    timestamp: 1,
    randomness: Uint8List(12),
  );
  final high = Pikaid.fromComponents(
    timestamp: 1,
    randomness: Uint8List.fromList(List<int>.filled(12, 0xff)),
  );
  _require(low.compareTo(high) < 0, 'same-second unsigned randomness');
  _require(low.toString().compareTo(high.toString()) < 0,
      'text order matches compareTo');
}

void _verifyEquality() {
  final left = Pikaid.parse(_exampleText);
  final right = Pikaid.fromComponents(
    timestamp: 1700000000,
    randomness: _fromHex('00112233445566778899aabb'),
  );
  _require(left == right, 'equal values');
  _require(left.hashCode == right.hashCode, 'equal hashes');
  _require(
      left != Pikaid.parse('00000010000000000000000001'), 'different values');
  _require(left != Object(), 'unrelated object');
}

void _verifySecureRandomSource() {
  const source = SecurePikaidRandomSource();
  final buffer = Uint8List(12);
  source.fillBytes(buffer);
  _require(buffer.length == 12, 'buffer length');
  _require(buffer.any((byte) => byte != 0), 'buffer was filled');
  final id = Pikaid.generateAt(1700000000, randomSource: source);
  _require(Pikaid.isValid(id.toString()), 'secure source generates valid ids');
}

void _verifyRandomSourceContract() {
  final source = _RecordingSource();
  Pikaid.generateAt(42, randomSource: source);
  _require(source.calls == 1, 'source called once');
  _require(source.lastLength == 12, 'source receives 12 bytes');
}

void _verifyEntropyFailure() {
  try {
    Pikaid.generateAt(42, randomSource: _ThrowingSource());
  } on PikaidEntropyException {
    return;
  }
  throw StateError('throwing random source did not raise '
      'PikaidEntropyException');
}

void _verifyKnownAnswers() {
  const rows = <(String, int, String, String)>[
    (
      '00000000000000000000000000',
      0,
      '000000000000000000000000',
      '0000000000000000000000000000000000'
    ),
    (
      '00000010000000000000000001',
      1,
      '000000000000000000000001',
      '0000000001000000000000000000000001'
    ),
    (
      _maxText,
      Pikaid.maxTimestamp,
      'ffffffffffffffffffffffff',
      '123ede3fffffffffffffffffffffffffff'
    ),
  ];
  for (final (text, timestamp, randomnessHex, binaryHex) in rows) {
    final id = Pikaid.parse(text);
    _require(id.timestamp == timestamp, 'timestamp for $text');
    _require(id.randomnessHex == randomnessHex, 'randomness for $text');
    _require(_hex(id.toBinary()) == binaryHex, 'binary for $text');
    _require(id.toString() == text, 'text for $text');
  }
  _expectThrowsFormat(
      () => Pikaid.parse('0000000zzzzzzzzzzzzzzzzzzz'), 'invalid example');
}

// ---------------------------------------------------------------------------
// Test doubles and byte helpers.
// ---------------------------------------------------------------------------

final class _FixedSource implements PikaidRandomSource {
  _FixedSource(this.bytes);

  factory _FixedSource.fromHex(String hex) => _FixedSource(_fromHex(hex));

  final Uint8List bytes;

  @override
  void fillBytes(Uint8List destination) => destination.setAll(0, bytes);
}

final class _RecordingSource implements PikaidRandomSource {
  int calls = 0;
  int? lastLength;

  @override
  void fillBytes(Uint8List destination) {
    calls++;
    lastLength = destination.length;
    destination.fillRange(0, destination.length, 0);
  }
}

final class _ThrowingSource implements PikaidRandomSource {
  @override
  void fillBytes(Uint8List destination) =>
      throw const PikaidEntropyException('entropy unavailable');
}

Uint8List _fromHex(String hex) {
  if (hex.length.isOdd) {
    throw ArgumentError.value(hex, 'hex', 'must have an even length');
  }
  final bytes = Uint8List(hex.length ~/ 2);
  for (var index = 0; index < bytes.length; index++) {
    bytes[index] =
        int.parse(hex.substring(index * 2, index * 2 + 2), radix: 16);
  }
  return bytes;
}

String _hex(List<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
