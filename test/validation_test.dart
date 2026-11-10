@TestOn('vm')
library;

import 'dart:collection';

import 'package:pikaid/pikaid.dart';
import 'package:test/test.dart';

import 'support/hex.dart';

const String _valid = '00000000000000000000000000';

void main() {
  group('text length', () {
    final invalid = <String>[
      '',
      '0',
      '0' * 25,
      '0' * 27,
      '${_valid}0',
      '0$_valid',
      '$_valid\n',
      '\n$_valid',
      ' $_valid',
      '$_valid ',
    ];

    for (final value in invalid) {
      test('rejects ${_describe(value)}', () {
        expect(() => Pikaid.parse(value), throwsFormatException);
        expect(Pikaid.tryParse(value), isNull);
        expect(Pikaid.isValid(value), isFalse);
      });
    }

    test('length is counted in UTF-16 code units, never bytes or runes', () {
      // Thirteen astral characters are 26 UTF-16 code units but not ASCII.
      final value = '\u{1F600}' * 13;
      expect(value.length, 26);
      expect(Pikaid.isWellFormed(value), isFalse);
      expect(Pikaid.isValid(value), isFalse);
      expect(() => Pikaid.parse(value), throwsFormatException);
    });
  });

  group('alphabet', () {
    final invalid = <String, String>{
      'uppercase suffix': '0000000AAAAAAAAAAAAAAAAAA',
      'uppercase prefix': 'ZZZZZZZ0000000000000000000',
      'mixed case': '0000000aBcDeFgHiJkLmNoPqR',
      'hyphen separator': '0000000-000000000000000000',
      'underscore': '0000000000000000000000000_',
      'colon after timestamp': '0000000:0000000000000000000',
      'space inside': '0000000 0000000000000000000',
      'tab inside': '0000000\t000000000000000000',
      'newline inside': '0000000\n0000000000000000000',
      'plus prefix': '+0000000000000000000000000',
      'dot': '0000000000000000000000000.',
      'tilde': '0000000000000000000000000~',
      'NUL suffix': '0000000000000000000000000\u0000',
      'fullwidth digits': '００００００００００００００００００００００００００',
      'accented letter': '0000000é000000000000000000',
      'cyrillic': '0000000а000000000000000000',
      'non-ASCII in prefix': '000000é0000000000000000000',
    };

    invalid.forEach((name, value) {
      test('rejects $name', () {
        expect(() => Pikaid.parse(value), throwsFormatException);
        expect(Pikaid.tryParse(value), isNull);
        expect(Pikaid.isValid(value), isFalse);
        expect(Pikaid.isWellFormed(value), isFalse);
      });
    });

    test('reports the offending index without modifying the input', () {
      const value = '0000000A000000000000000000';
      try {
        Pikaid.parse(value);
        fail('expected a FormatException');
      } on FormatException catch (error) {
        expect(error.source, value);
        expect(error.offset, 7);
        expect(error.message, contains('index 7'));
      }
    });

    test('accepts every lowercase Base36 digit in a low-order position', () {
      const alphabet = '0123456789abcdefghijklmnopqrstuvwxyz';
      for (var i = 0; i < alphabet.length; i++) {
        final suffix = '${'0' * 18}${alphabet[i]}';
        expect(Pikaid.isValid('0000000$suffix'), isTrue, reason: suffix);
      }
    });

    test('accepts leading digits 0..7 but not 8..9 within 96 bits', () {
      for (var i = 0; i < 8; i++) {
        final suffix = '$i${'0' * 18}';
        expect(Pikaid.isValid('0000000$suffix'), isTrue, reason: suffix);
      }
      for (var i = 8; i < 10; i++) {
        final suffix = '$i${'0' * 18}';
        expect(Pikaid.isValid('0000000$suffix'), isFalse, reason: suffix);
      }
    });
  });

  group('randomness range', () {
    final overflow = <String>[
      '7oiylpimjg5u2ca1yps', // exactly 2^96
      '7oiylpimjg5u2ca1ypt',
      '8000000000000000000',
      'zzzzzzzzzzzzzzzzzzz',
      '9zzzzzzzzzzzzzzzzzz',
    ];

    for (final suffix in overflow) {
      test('rejects suffix $suffix', () {
        final id = '0000000$suffix';
        expect(id.length, 26);
        expect(Pikaid.isWellFormed(id), isTrue);
        expect(Pikaid.isValid(id), isFalse);
        expect(Pikaid.tryParse(id), isNull);
        expect(
          () => Pikaid.parse(id),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              contains('96 bits'),
            ),
          ),
        );
        expect(
          () => Pikaid.parse(id),
          throwsA(
            isA<FormatException>().having(
              (error) => error.offset,
              'offset',
              Pikaid.timestampLength,
            ),
          ),
        );
      });
    }

    test('accepts the largest valid suffix', () {
      const id = '00000007oiylpimjg5u2ca1ypr';
      expect(Pikaid.isValid(id), isTrue);
      expect(Pikaid.parse(id).randomnessHex, 'ffffffffffffffffffffffff');
    });

    test('accepts the largest 96-bit value with any timestamp', () {
      const id = 'zzzzzzz7oiylpimjg5u2ca1ypr';
      expect(Pikaid.isValid(id), isTrue);
      expect(Pikaid.parse(id).timestamp, Pikaid.maxTimestamp);
    });
  });

  group('timestamp range in the text form', () {
    test('seven Base36 digits cannot exceed the maximum by construction', () {
      // 36^7 needs eight digits, so every 7-digit lowercase suffix is valid.
      expect(Pikaid.isValid('zzzzzzz0000000000000000000'), isTrue);
      expect(Pikaid.maxTimestamp, 78364164095);
      expect(Pikaid.maxTimestamp + 1, 78364164096);
      expect((Pikaid.maxTimestamp + 1).toRadixString(36), '10000000');
    });

    test('does not wrap or truncate a larger prefix', () {
      // A 27-character value with an extra timestamp digit is rejected before
      // any numeric conversion can wrap.
      expect(Pikaid.tryParse('100000000000000000000000000'), isNull);
    });
  });

  group('binary decoding', () {
    test('rejects wrong lengths', () {
      for (final length in <int>[0, 1, 5, 12, 16, 18, 34]) {
        final bytes = List<int>.filled(length, 0);
        expect(
          () => Pikaid.fromBinary(bytes),
          throwsFormatException,
          reason: 'length $length must be rejected',
        );
      }
    });

    test('rejects bytes outside 0..255', () {
      final negative = List<int>.filled(Pikaid.binaryLength, 0)..[5] = -1;
      final tooLarge = List<int>.filled(Pikaid.binaryLength, 0)..[11] = 256;
      for (final bytes in <List<int>>[negative, tooLarge]) {
        expect(() => Pikaid.fromBinary(bytes), throwsFormatException);
      }
    });

    test('rejects timestamp fields above 36^7 - 1', () {
      final inputs = <String>[
        '123ede4000000000000000000000000000', // max + 1
        '123ede4000ffffffffffffffffffffffff', // max + 1 with entropy
        'ffffffffff000000000000000000000000', // 2^40 - 1
      ];
      for (final hex in inputs) {
        expect(
          () => Pikaid.fromBinary(hexToBytes(hex)),
          throwsFormatException,
          reason: hex,
        );
      }
    });

    test('accepts both timestamp boundaries', () {
      expect(
        Pikaid.fromBinary(hexToBytes('0000000000${'00' * 12}')).timestamp,
        0,
      );
      expect(
        Pikaid.fromBinary(hexToBytes('123ede3fff${'ff' * 12}')).timestamp,
        Pikaid.maxTimestamp,
      );
    });

    test('preserves every randomness byte, including leading zeros', () {
      final bytes = hexToBytes('0000000001' '0000000000000000000000ff');
      final id = Pikaid.fromBinary(bytes);
      expect(id.timestamp, 1);
      expect(id.randomnessHex, '0000000000000000000000ff');
      expect(id.toBinary(), bytes);
    });

    test('reads every byte once from a stateful List<int>', () {
      // A caller can pass any List<int>, including one that changes between
      // reads. Bytes at or after the timestamp field return 256 on every read
      // after the first, which a Uint8List assignment would silently truncate
      // to zero if decoding re-read the caller's list.
      final bytes = hexToBytes('006553f10000112233445566778899aabb');
      final id = Pikaid.fromBinary(_ShiftingList(bytes));
      expect(id.timestamp, 1700000000);
      expect(id.randomnessHex, '00112233445566778899aabb');
      expect(id.toBinary(), bytes);
    });
  });

  group('component construction', () {
    test('rejects out-of-range timestamps', () {
      for (final timestamp in <int>[-1, Pikaid.maxTimestamp + 1, 1 << 40]) {
        expect(
          () => Pikaid.fromComponents(
            timestamp: timestamp,
            randomness: List<int>.filled(12, 0),
          ),
          throwsRangeError,
          reason: 'timestamp $timestamp',
        );
      }
    });

    test('rejects wrong randomness lengths', () {
      for (final length in <int>[0, 11, 13, 24]) {
        expect(
          () => Pikaid.fromComponents(
            timestamp: 0,
            randomness: List<int>.filled(length, 0),
          ),
          throwsArgumentError,
          reason: 'length $length',
        );
      }
    });

    test('rejects out-of-range randomness bytes', () {
      for (final byte in <int>[-1, 256, 1000]) {
        final randomness = List<int>.filled(12, 0)..[6] = byte;
        expect(
          () => Pikaid.fromComponents(timestamp: 0, randomness: randomness),
          throwsRangeError,
          reason: 'byte $byte',
        );
      }
    });

    test('accepts a plain List<int> and copies it', () {
      final randomness = List<int>.generate(12, (index) => 255 - index);
      final id = Pikaid.fromComponents(timestamp: 7, randomness: randomness);
      expect(id.randomnessHex, 'fffefdfcfbfaf9f8f7f6f5f4');
      randomness[0] = 0;
      expect(id.randomnessHex, 'fffefdfcfbfaf9f8f7f6f5f4');
    });
  });

  group('predicates', () {
    test('isValid never throws for arbitrary strings', () {
      final samples = <String>[
        '',
        '\u0000',
        '\u{10FFFF}',
        _valid,
        'A' * 26,
        '0' * 10000,
      ];
      for (final sample in samples) {
        expect(() => Pikaid.isValid(sample), returnsNormally);
        expect(Pikaid.isValid(sample), isA<bool>());
      }
    });

    test('isWellFormed is only a shape check', () {
      expect(Pikaid.isWellFormed(_valid), isTrue);
      expect(
        Pikaid.isWellFormed('0000000zzzzzzzzzzzzzzzzzzz'),
        isTrue,
        reason: 'shape is correct even though randomness exceeds 96 bits',
      );
      expect(Pikaid.isWellFormed('Z' * 26), isFalse);
      expect(Pikaid.isWellFormed('0' * 25), isFalse);
      expect(Pikaid.isWellFormed('0' * 27), isFalse);
    });

    test('tryParse and isValid agree', () {
      final samples = <String>[
        _valid,
        'zzzzzzz7oiylpimjg5u2ca1ypr',
        '0000000zzzzzzzzzzzzzzzzzzz',
        'not-a-pikaid',
        '',
      ];
      for (final sample in samples) {
        expect(
          Pikaid.tryParse(sample) != null,
          Pikaid.isValid(sample),
          reason: sample,
        );
      }
    });
  });
}

String _describe(String value) {
  if (value.isEmpty) {
    return 'an empty string';
  }
  if (value.length > 30) {
    return 'a ${value.length}-character string';
  }
  return '"${value.replaceAll('\n', r'\n').replaceAll('\t', r'\t')}"';
}

/// A fixed-length `List<int>` that returns `256` for repeated reads of the
/// randomness field, modelling a caller that mutates its buffer while
/// [Pikaid.fromBinary] decodes it.
final class _ShiftingList extends ListBase<int> {
  _ShiftingList(Iterable<int> values) : _values = List<int>.of(values);

  final List<int> _values;
  final Set<int> _read = <int>{};

  @override
  int get length => _values.length;

  @override
  set length(int newLength) => throw UnsupportedError('fixed length');

  @override
  int operator [](int index) {
    if (_read.add(index) ||
        index < Pikaid.binaryLength - Pikaid.randomnessBytes) {
      return _values[index];
    }
    return 256;
  }

  @override
  void operator []=(int index, int value) =>
      throw UnsupportedError('read-only view');
}
