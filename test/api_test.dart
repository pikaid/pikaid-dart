@TestOn('vm')
library;

import 'dart:typed_data';

import 'package:pikaid/pikaid.dart';
import 'package:test/test.dart';

import 'support/hex.dart';

void main() {
  group('constants', () {
    test('match specification revision 1.0.4', () {
      expect(Pikaid.stringLength, 26);
      expect(Pikaid.binaryLength, 17);
      expect(Pikaid.timestampLength, 7);
      expect(Pikaid.randomnessLength, 19);
      expect(Pikaid.randomnessBytes, 12);
      expect(Pikaid.maxTimestamp, 36 * 36 * 36 * 36 * 36 * 36 * 36 - 1);
      expect(Pikaid.maxTimestamp, 78364164095);
      expect(Pikaid.maxTimestamp, 0x123ede3fff);
    });
  });

  group('fields', () {
    test('timestamp is whole Unix seconds', () {
      final id = Pikaid.parse('0s44we8002loz3po6mcf6vsn23');
      expect(id.timestamp, 1700000000);
      expect(id.timestamp, isA<int>());
    });

    test('timestampUtc is UTC with one-second precision', () {
      expect(
        Pikaid.parse('00000000000000000000000000').timestampUtc,
        DateTime.utc(1970),
      );
      final sample = Pikaid.parse('0s44we8002loz3po6mcf6vsn23');
      expect(sample.timestampUtc.isUtc, isTrue);
      expect(
        sample.timestampUtc,
        DateTime.utc(2023, 11, 14, 22, 13, 20),
      );
      expect(sample.timestampUtc.millisecond, 0);
      expect(sample.timestampUtc.microsecond, 0);
      expect(
        Pikaid.parse('zzzzzzz0000000000000000000').timestampUtc,
        DateTime.utc(4453, 4, 5, 15, 21, 35),
      );
    });

    test('randomness is the exact 12-byte value', () {
      final id = Pikaid.parse('00000010000000000000000001');
      expect(id.randomness, hexToBytes('000000000000000000000001'));
      expect(id.randomness.length, Pikaid.randomnessBytes);
      expect(id.randomnessHex, '000000000000000000000001');
      expect(id.randomnessHex.length, 24);
      expect(RegExp(r'^[0-9a-f]{24}$').hasMatch(id.randomnessHex), isTrue);
    });

    test('randomnessHex preserves leading zero bytes', () {
      final id = Pikaid.fromComponents(
        timestamp: 0,
        randomness: hexToBytes('000000000000000000000001'),
      );
      expect(id.randomnessHex, '000000000000000000000001');
    });
  });

  group('equality and hashing', () {
    test('equal values from every construction path are equal', () {
      final parsed = Pikaid.parse('0s44we8002loz3po6mcf6vsn23');
      final fromBinary = Pikaid.fromBinary(
        hexToBytes('006553f10000112233445566778899aabb'),
      );
      final fromComponents = Pikaid.fromComponents(
        timestamp: 1700000000,
        randomness: hexToBytes('00112233445566778899aabb'),
      );

      expect(parsed, fromBinary);
      expect(parsed, fromComponents);
      expect(fromBinary, fromComponents);
      expect(parsed.hashCode, fromBinary.hashCode);
      expect(parsed.hashCode, fromComponents.hashCode);
      expect(parsed == parsed, isTrue);
    });

    test('different timestamps are not equal', () {
      final a = Pikaid.fromComponents(
        timestamp: 1,
        randomness: List<int>.filled(12, 0),
      );
      final b = Pikaid.fromComponents(
        timestamp: 2,
        randomness: List<int>.filled(12, 0),
      );
      expect(a, isNot(b));
      expect(a.hashCode, isNot(b.hashCode));
    });

    test('different randomness is not equal', () {
      final a = Pikaid.fromComponents(
        timestamp: 1,
        randomness: List<int>.filled(12, 0),
      );
      final b = Pikaid.fromComponents(
        timestamp: 1,
        randomness: List<int>.filled(12, 0)..[11] = 1,
      );
      expect(a, isNot(b));
    });

    test('a Pikaid is not equal to an unrelated object', () {
      final id = Pikaid.parse('00000000000000000000000000');
      const Object other = '00000000000000000000000000';
      expect(id == other, isFalse);
      expect(id == Object(), isFalse);
    });
  });

  group('comparison', () {
    test('compareTo orders by timestamp, then randomness', () {
      final early = Pikaid.fromComponents(
        timestamp: 1,
        randomness: List<int>.filled(12, 0xff),
      );
      final late = Pikaid.fromComponents(
        timestamp: 2,
        randomness: List<int>.filled(12, 0),
      );
      expect(early.compareTo(late), lessThan(0));
      expect(late.compareTo(early), greaterThan(0));
      expect(early.compareTo(early), 0);
    });

    test('same timestamp falls back to unsigned entropy order', () {
      final low = Pikaid.fromComponents(
        timestamp: 5,
        randomness: List<int>.filled(12, 0),
      );
      final high = Pikaid.fromComponents(
        timestamp: 5,
        randomness: List<int>.filled(12, 1),
      );
      expect(low.compareTo(high), lessThan(0));
      expect(high.compareTo(low), greaterThan(0));
    });

    test('List.sort uses compareTo', () {
      final ids = <Pikaid>[
        Pikaid.fromComponents(
          timestamp: 3,
          randomness: List<int>.filled(12, 0),
        ),
        Pikaid.fromComponents(
          timestamp: 1,
          randomness: List<int>.filled(12, 9),
        ),
        Pikaid.fromComponents(
          timestamp: 2,
          randomness: List<int>.filled(12, 1),
        ),
      ];
      ids.sort();
      expect(ids.map((id) => id.timestamp), <int>[1, 2, 3]);
    });
  });

  group('conversion and buffers', () {
    test('toBinary is exactly 17 bytes and independent of the object', () {
      final id = Pikaid.parse('0s44we8002loz3po6mcf6vsn23');
      final bytes = id.toBinary();
      expect(bytes.length, 17);
      expect(bytes, isA<Uint8List>());
      expect(
        bytes,
        hexToBytes('006553f10000112233445566778899aabb'),
      );
      bytes.fillRange(0, 17, 0);
      expect(
        Pikaid.parse('0s44we8002loz3po6mcf6vsn23').toBinary(),
        hexToBytes('006553f10000112233445566778899aabb'),
      );
    });

    test('fromBinary accepts any List<int>', () {
      final bytes = <int>[...hexToBytes('006553f10000112233445566778899aabb')];
      final id = Pikaid.fromBinary(bytes);
      expect(id.toString(), '0s44we8002loz3po6mcf6vsn23');
      bytes[0] = 0xff;
      expect(id.toString(), '0s44we8002loz3po6mcf6vsn23');
    });

    test('a binary representation is exactly reversible', () {
      final id = Pikaid.parse('zzzzzzz7oiylpimjg5u2ca1ypr');
      expect(Pikaid.fromBinary(id.toBinary()), id);
      expect(Pikaid.fromBinary(id.toBinary()).toBinary(), id.toBinary());
    });
  });

  group('public API surface', () {
    test('tryParse returns null for invalid input without throwing', () {
      expect(() => Pikaid.tryParse('not-a-pikaid'), returnsNormally);
      expect(Pikaid.tryParse('not-a-pikaid'), isNull);
      expect(Pikaid.tryParse(''), isNull);
      expect(Pikaid.tryParse('0000000zzzzzzzzzzzzzzzzzzz'), isNull);
    });

    test('parse exposes a FormatException with source and offset', () {
      try {
        Pikaid.parse('0000000000000000000000000Z');
        fail('expected FormatException');
      } on FormatException catch (error) {
        expect(error.source, '0000000000000000000000000Z');
        expect(error.offset, 25);
        expect(error.message, contains('lowercase Base36'));
      }
    });

    test('unmodifiable randomness view does not alias external input', () {
      final source = Uint8List.fromList(List<int>.filled(12, 0xaa));
      final id = Pikaid.fromComponents(timestamp: 0, randomness: source);
      source[0] = 0;
      expect(id.randomness[0], 0xaa);
      expect(id.randomnessHex, 'aaaaaaaaaaaaaaaaaaaaaaaa');
    });

    test('the example vector behaves as documented', () {
      final id = Pikaid.generateAt(
        1700000000,
        randomSource: _FixedSource(hexToBytes('00112233445566778899aabb')),
      );
      expect(id.toString(), '0s44we8002loz3po6mcf6vsn23');
      expect(id.timestampUtc.toIso8601String(), '2023-11-14T22:13:20.000Z');
      expect(id.toBinary(), hexToBytes('006553f10000112233445566778899aabb'));
    });
  });
}

final class _FixedSource implements PikaidRandomSource {
  _FixedSource(this.bytes);

  final List<int> bytes;

  @override
  void fillBytes(Uint8List destination) => destination.setAll(0, bytes);
}
