@TestOn('vm')
library;

import 'dart:typed_data';

import 'package:pikaid/src/base36.dart';
import 'package:test/test.dart';

void main() {
  group('base36DigitValue', () {
    test('maps the full lowercase alphabet in ascending order', () {
      const alphabet = '0123456789abcdefghijklmnopqrstuvwxyz';
      for (var i = 0; i < alphabet.length; i++) {
        expect(base36DigitValue(alphabet.codeUnitAt(i)), i);
      }
    });

    test('rejects uppercase, punctuation, whitespace and non-ASCII', () {
      for (final unit in <int>[
        0x41, // A
        0x5a, // Z
        0x2d, // -
        0x5f, // _
        0x20, // space
        0x0a, // newline
        0x00, // NUL
        0x7f, // DEL
        0xe9, // é
        0x100,
        -1,
      ]) {
        expect(base36DigitValue(unit), -1,
            reason: 'U+${unit.toRadixString(16)}');
      }
    });
  });

  group('base36CodeUnit', () {
    test('maps digits back to ASCII', () {
      expect(base36CodeUnit(0), 0x30);
      expect(base36CodeUnit(9), 0x39);
      expect(base36CodeUnit(10), 0x61);
      expect(base36CodeUnit(35), 0x7a);
      for (var i = 0; i < 36; i++) {
        expect(base36DigitValue(base36CodeUnit(i)), i);
      }
    });
  });

  group('isBase36String', () {
    test('requires an exact length and lowercase alphabet', () {
      expect(isBase36String('', 0), isTrue);
      expect(isBase36String('abc', 3), isTrue);
      expect(isBase36String('abc', 2), isFalse);
      expect(isBase36String('abc', 4), isFalse);
      expect(isBase36String('aBc', 3), isFalse);
      expect(isBase36String('ab-', 3), isFalse);
      expect(isBase36String('é', 1), isFalse);
    });
  });

  group('encodeBase36Fixed', () {
    test('left-pads to the requested width', () {
      expect(encodeBase36Fixed(0, 7), '0000000');
      expect(encodeBase36Fixed(1, 7), '0000001');
      expect(encodeBase36Fixed(35, 7), '000000z');
      expect(encodeBase36Fixed(36, 7), '0000010');
      expect(encodeBase36Fixed(1295, 7), '00000zz');
      expect(encodeBase36Fixed(1296, 7), '0000100');
      expect(encodeBase36Fixed(78364164095, 7), 'zzzzzzz');
    });

    test('handles a zero width for zero', () {
      expect(encodeBase36Fixed(0, 0), '');
    });

    test('rejects negative values and values that do not fit', () {
      expect(() => encodeBase36Fixed(-1, 7), throwsArgumentError);
      expect(() => encodeBase36Fixed(36, 1), throwsArgumentError);
      expect(() => encodeBase36Fixed(78364164096, 7), throwsArgumentError);
    });
  });

  group('decodeBase36Int', () {
    test('decodes with an offset and exact precision', () {
      expect(decodeBase36Int('0000000', 0, 7), 0);
      expect(decodeBase36Int('zzzzzzz', 0, 7), 78364164095);
      expect(decodeBase36Int('x0000001y', 1, 7), 1);
      expect(decodeBase36Int('0s44we8', 0, 7), 1700000000);
    });

    test('rejects non-Base36 characters', () {
      expect(() => decodeBase36Int('00A0000', 0, 7), throwsArgumentError);
      expect(() => decodeBase36Int('000000-', 0, 7), throwsArgumentError);
    });
  });

  group('encodeBase36BytesFixed', () {
    test('encodes zero and leading-zero byte arrays as zero padding', () {
      expect(
        encodeBase36BytesFixed(Uint8List(12), 19),
        '0000000000000000000',
      );
      expect(
        encodeBase36BytesFixed(
          Uint8List.fromList(<int>[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]),
          19,
        ),
        '0000000000000000001',
      );
    });

    test('encodes single-byte boundaries', () {
      expect(
        encodeBase36BytesFixed(
          Uint8List.fromList(<int>[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 35]),
          19,
        ),
        '000000000000000000z',
      );
      expect(
        encodeBase36BytesFixed(
          Uint8List.fromList(<int>[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255]),
          19,
        ),
        '0000000000000000073',
      );
    });

    test('encodes the full 96-bit maximum', () {
      expect(
        encodeBase36BytesFixed(
            Uint8List.fromList(List<int>.filled(12, 0xff)), 19),
        '7oiylpimjg5u2ca1ypr',
      );
      expect(
        encodeBase36BytesFixed(
          Uint8List.fromList(<int>[0x80, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
          19,
        ),
        '3u9haurb9q2x1650zcw',
      );
    });

    test('rejects a width that is too small', () {
      expect(
        () => encodeBase36BytesFixed(Uint8List.fromList(<int>[36]), 1),
        throwsArgumentError,
      );
      expect(
        () => encodeBase36BytesFixed(
          Uint8List.fromList(List<int>.filled(12, 0xff)),
          18,
        ),
        throwsArgumentError,
      );
    });
  });

  group('decodeBase36Bytes', () {
    test('left-pads into the requested byte width', () {
      expect(
        decodeBase36Bytes('1', start: 0, length: 1, byteLength: 12),
        Uint8List.fromList(<int>[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]),
      );
      expect(
        decodeBase36Bytes('z', start: 0, length: 1, byteLength: 12),
        Uint8List.fromList(<int>[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 35]),
      );
      expect(
        decodeBase36Bytes('10', start: 0, length: 2, byteLength: 12),
        Uint8List.fromList(<int>[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 36]),
      );
    });

    test('respects start and length', () {
      expect(
        decodeBase36Bytes('xx73yy', start: 2, length: 2, byteLength: 1),
        Uint8List.fromList(<int>[255]),
      );
    });

    test('returns null exactly when the value exceeds the byte width', () {
      expect(
        decodeBase36Bytes(
          '7oiylpimjg5u2ca1ypr',
          start: 0,
          length: 19,
          byteLength: 12,
        ),
        Uint8List.fromList(List<int>.filled(12, 0xff)),
      );
      expect(
        decodeBase36Bytes(
          '7oiylpimjg5u2ca1yps',
          start: 0,
          length: 19,
          byteLength: 12,
        ),
        isNull,
      );
      expect(
        decodeBase36Bytes(
          'zzzzzzzzzzzzzzzzzzz',
          start: 0,
          length: 19,
          byteLength: 12,
        ),
        isNull,
      );
    });

    test('rejects non-Base36 characters', () {
      expect(
        () => decodeBase36Bytes('A', start: 0, length: 1, byteLength: 12),
        throwsArgumentError,
      );
    });
  });

  group('timestamp bytes', () {
    test('encodeTimestampBytes is five-byte big-endian', () {
      expect(encodeTimestampBytes(0), <int>[0, 0, 0, 0, 0]);
      expect(encodeTimestampBytes(1), <int>[0, 0, 0, 0, 1]);
      expect(encodeTimestampBytes(0x0102030405), <int>[1, 2, 3, 4, 5]);
      expect(
        encodeTimestampBytes(78364164095),
        <int>[0x12, 0x3e, 0xde, 0x3f, 0xff],
      );
      expect(
        encodeTimestampBytes(0xffffffffff),
        <int>[0xff, 0xff, 0xff, 0xff, 0xff],
      );
    });

    test('decodeTimestampBytes reads any offset exactly', () {
      expect(decodeTimestampBytes(<int>[0, 0, 0, 0, 0]), 0);
      expect(decodeTimestampBytes(<int>[0, 0, 0, 0, 1]), 1);
      expect(
        decodeTimestampBytes(<int>[0x12, 0x3e, 0xde, 0x3f, 0xff]),
        78364164095,
      );
      expect(
        decodeTimestampBytes(<int>[9, 1, 2, 3, 4, 5], 1),
        0x0102030405,
      );
    });

    test('timestamp bytes round-trip across the 40-bit range', () {
      for (var i = 0; i <= 40; i++) {
        final value = (1 << i) - 1;
        expect(decodeTimestampBytes(encodeTimestampBytes(value)), value);
      }
    });
  });

  group('hex helpers', () {
    test('bytesToHex is lowercase and zero-padded', () {
      expect(bytesToHex(<int>[]), '');
      expect(bytesToHex(<int>[0, 15, 16, 255]), '000f10ff');
      expect(bytesToHex(List<int>.filled(12, 0xab)), 'ab' * 12);
    });

    test('hexCodeUnit maps all sixteen digits', () {
      const digits = '0123456789abcdef';
      for (var i = 0; i < 16; i++) {
        expect(hexCodeUnit(i), digits.codeUnitAt(i));
      }
    });
  });
}
