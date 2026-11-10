@TestOn('vm')
library;

import 'package:pikaid/pikaid.dart';
import 'package:test/test.dart';

import 'support/hex.dart';

/// One independent known-answer case.
///
/// Expected strings and hex were produced by a small standalone Python
/// implementation of the specification (`int.to_bytes` + Base36 conversion),
/// not by `package:pikaid`. They are transcribed here as literals so the test
/// oracle cannot drift with the Dart code under test.
typedef _Case = ({
  String name,
  int timestamp,
  String entropyHex,
  String id,
  String binaryHex,
});

const List<_Case> _cases = <_Case>[
  (
    name: 'zero',
    timestamp: 0,
    entropyHex: '000000000000000000000000',
    id: '00000000000000000000000000',
    binaryHex: '0000000000000000000000000000000000',
  ),
  (
    name: 'zero timestamp, maximum entropy',
    timestamp: 0,
    entropyHex: 'ffffffffffffffffffffffff',
    id: '00000007oiylpimjg5u2ca1ypr',
    binaryHex: '0000000000ffffffffffffffffffffffff',
  ),
  (
    name: 'maximum timestamp, zero entropy',
    timestamp: 78364164095,
    entropyHex: '000000000000000000000000',
    id: 'zzzzzzz0000000000000000000',
    binaryHex: '123ede3fff000000000000000000000000',
  ),
  (
    name: 'maximum timestamp and maximum entropy',
    timestamp: 78364164095,
    entropyHex: 'ffffffffffffffffffffffff',
    id: 'zzzzzzz7oiylpimjg5u2ca1ypr',
    binaryHex: '123ede3fffffffffffffffffffffffffff',
  ),
  (
    name: 'one below both maximums',
    timestamp: 78364164094,
    entropyHex: 'fffffffffffffffffffffffe',
    id: 'zzzzzzy7oiylpimjg5u2ca1ypq',
    binaryHex: '123ede3ffefffffffffffffffffffffffe',
  ),
  (
    name: 'one and one',
    timestamp: 1,
    entropyHex: '000000000000000000000001',
    id: '00000010000000000000000001',
    binaryHex: '0000000001000000000000000000000001',
  ),
  (
    name: 'sample 1700000000',
    timestamp: 1700000000,
    entropyHex: '00112233445566778899aabb',
    id: '0s44we8002loz3po6mcf6vsn23',
    binaryHex: '006553f10000112233445566778899aabb',
  ),
  (
    name: 'timestamp with zero low bytes',
    timestamp: 951782400,
    entropyHex: '000000000000000000000000',
    id: '0fqo0000000000000000000000',
    binaryHex: '0038bb0c00000000000000000000000000',
  ),
  (
    name: 'timestamp across the 32-bit boundary',
    timestamp: 4294967296,
    entropyHex: '00000000ffffffff00000000',
    id: '1z141z40000003w5e11073oetc',
    binaryHex: '010000000000000000ffffffff00000000',
  ),
  (
    name: 'entropy uses every byte position',
    timestamp: 1234567890,
    entropyHex: '0f0e0d0c0b0a090807060504',
    id: '0kf12oi0g9fkzfp86wwsw2yfic',
    binaryHex: '00499602d20f0e0d0c0b0a090807060504',
  ),
  (
    name: 'timestamp just below a power-of-36 boundary',
    timestamp: 2176782335,
    entropyHex: '800000000000000000000000',
    id: '0zzzzzz3u9haurb9q2x1650zcw',
    binaryHex: '0081bf0fff800000000000000000000000',
  ),
  (
    name: 'timestamp at a power-of-36 boundary',
    timestamp: 2176782336,
    entropyHex: '0000000000000000000000ff',
    id: '10000000000000000000000073',
    binaryHex: '0081bf10000000000000000000000000ff',
  ),
];

/// Cases where Base36 carries ripple through a component.
const List<_Case> _digitCarryCases = <_Case>[
  (
    name: 'timestamp digit carry: 35 -> z',
    timestamp: 35,
    entropyHex: '000000000000000000000000',
    id: '000000z0000000000000000000',
    binaryHex: '0000000023000000000000000000000000',
  ),
  (
    name: 'timestamp digit carry: 36 -> 1000010 style carry',
    timestamp: 36,
    entropyHex: '000000000000000000000000',
    id: '00000100000000000000000000',
    binaryHex: '0000000024000000000000000000000000',
  ),
  (
    name: 'timestamp digit carry: 1295 -> 00000zz',
    timestamp: 1295,
    entropyHex: '000000000000000000000000',
    id: '00000zz0000000000000000000',
    binaryHex: '000000050f000000000000000000000000',
  ),
  (
    name: 'timestamp digit carry: 1296 -> 0000100',
    timestamp: 1296,
    entropyHex: '000000000000000000000000',
    id: '00001000000000000000000000',
    binaryHex: '0000000510000000000000000000000000',
  ),
  (
    name: 'entropy digit carry: 35 -> z',
    timestamp: 0,
    entropyHex: '000000000000000000000023',
    id: '0000000000000000000000000z',
    binaryHex: '0000000000000000000000000000000023',
  ),
  (
    name: 'entropy digit carry: 36 -> 10',
    timestamp: 0,
    entropyHex: '000000000000000000000024',
    id: '00000000000000000000000010',
    binaryHex: '0000000000000000000000000000000024',
  ),
  (
    name: 'entropy digit carry: 1295 -> zz',
    timestamp: 0,
    entropyHex: '00000000000000000000050f',
    id: '000000000000000000000000zz',
    binaryHex: '000000000000000000000000000000050f',
  ),
  (
    name: 'entropy digit carry: 1296 -> 100',
    timestamp: 0,
    entropyHex: '000000000000000000000510',
    id: '00000000000000000000000100',
    binaryHex: '0000000000000000000000000000000510',
  ),
  (
    name: 'entropy at 36^18 uses all nineteen digits',
    timestamp: 0,
    entropyHex: '2153e468b91c6d1000000000',
    id: '00000001000000000000000000',
    binaryHex: '00000000002153e468b91c6d1000000000',
  ),
];

void main() {
  group('independent known-answer vectors', () {
    for (final vector in _cases) {
      test(vector.name, () {
        final entropy = hexToBytes(vector.entropyHex);

        final built = Pikaid.fromComponents(
          timestamp: vector.timestamp,
          randomness: entropy,
        );
        expect(built.timestamp, vector.timestamp);
        expect(built.randomness, entropy);
        expect(built.randomnessHex, vector.entropyHex);
        expect(built.toString(), vector.id);
        expect(built.toBinary(), hexToBytes(vector.binaryHex));

        final parsed = Pikaid.parse(vector.id);
        expect(parsed, built);
        expect(parsed.timestamp, vector.timestamp);
        expect(parsed.randomness, entropy);

        final decoded = Pikaid.fromBinary(hexToBytes(vector.binaryHex));
        expect(decoded, built);

        // Both conversions are reversible for valid values.
        expect(Pikaid.parse(built.toString()), built);
        expect(Pikaid.fromBinary(built.toBinary()).toString(), vector.id);
        expect(decoded.toBinary(), hexToBytes(vector.binaryHex));

        expect(Pikaid.isValid(vector.id), isTrue);
        expect(Pikaid.tryParse(vector.id), built);
      });
    }
  });

  group('digit carries and padding', () {
    for (final vector in _digitCarryCases) {
      test(vector.name, () {
        final id = Pikaid.fromComponents(
          timestamp: vector.timestamp,
          randomness: hexToBytes(vector.entropyHex),
        );
        expect(id.toString(), vector.id);
        expect(id.toBinary(), hexToBytes(vector.binaryHex));
        expect(Pikaid.parse(id.toString()), id);
      });
    }

    test('timestamp prefixes are exactly seven digits', () {
      const expected = <int, String>{
        0: '0000000',
        1: '0000001',
        35: '000000z',
        36: '0000010',
        1295: '00000zz',
        1296: '0000100',
        2176782335: '0zzzzzz',
        2176782336: '1000000',
        78364164095: 'zzzzzzz',
      };
      expected.forEach((timestamp, prefix) {
        final id = Pikaid.fromComponents(
          timestamp: timestamp,
          randomness: List<int>.filled(12, 0),
        );
        expect(id.toString().substring(0, 7), prefix);
        expect(id.toString().substring(7), '0' * 19);
      });
    });

    test('randomness suffixes are exactly nineteen digits', () {
      final cases = <String, String>{
        '000000000000000000000000': '0000000000000000000',
        '000000000000000000000001': '0000000000000000001',
        '000000000000000000000023': '000000000000000000z',
        '000000000000000000000024': '0000000000000000010',
        '00000000000000000000050f': '00000000000000000zz',
        '000000000000000000000510': '0000000000000000100',
        '0000000000000000000000ff': '0000000000000000073',
        '800000000000000000000000': '3u9haurb9q2x1650zcw',
        'ffffffffffffffffffffffff': '7oiylpimjg5u2ca1ypr',
      };
      cases.forEach((hex, suffix) {
        final id = Pikaid.fromComponents(
          timestamp: 0,
          randomness: hexToBytes(hex),
        );
        expect(id.toString().substring(7), suffix);
      });
    });
  });

  group('specification section 7 examples', () {
    test('all-zero identifier', () {
      const id = '00000000000000000000000000';
      const binaryHex = '0000000000000000000000000000000000';
      final parsed = Pikaid.parse(id);
      expect(parsed.timestamp, 0);
      expect(parsed.randomnessHex, '000000000000000000000000');
      expect(parsed.toBinary(), hexToBytes(binaryHex));
    });

    test('timestamp 1, randomness 1', () {
      const id = '00000010000000000000000001';
      const binaryHex = '0000000001000000000000000000000001';
      final parsed = Pikaid.parse(id);
      expect(parsed.timestamp, 1);
      expect(parsed.randomnessHex, '000000000000000000000001');
      expect(parsed.toBinary(), hexToBytes(binaryHex));
    });

    test('maximum values', () {
      const id = 'zzzzzzz7oiylpimjg5u2ca1ypr';
      const binaryHex = '123ede3fffffffffffffffffffffffffff';
      final parsed = Pikaid.parse(id);
      expect(parsed.timestamp, Pikaid.maxTimestamp);
      expect(parsed.randomnessHex, 'ffffffffffffffffffffffff');
      expect(parsed.toBinary(), hexToBytes(binaryHex));
      expect(parsed.timestampUtc.toIso8601String(), '4453-04-05T15:21:35.000Z');
    });

    test('randomness above 96 bits is rejected', () {
      expect(
        () => Pikaid.parse('0000000zzzzzzzzzzzzzzzzzzz'),
        throwsFormatException,
      );
    });

    test('binary timestamp above the string maximum is rejected', () {
      expect(
        () => Pikaid.fromBinary(
          hexToBytes('ffffffffff000000000000000000000000'),
        ),
        throwsFormatException,
      );
      expect(
        () => Pikaid.fromBinary(
          hexToBytes('123ede4000000000000000000000000000'),
        ),
        throwsFormatException,
      );
    });
  });

  group('representable boundaries', () {
    test('maximum entropy is not the maximum 19-digit Base36 value', () {
      // 2^96 - 1 encodes as 7oiylpimjg5u2ca1ypr; 36^19 - 1 is larger.
      expect(
        Pikaid.parse('00000007oiylpimjg5u2ca1ypr').randomnessHex,
        'ffffffffffffffffffffffff',
      );
      for (final suffix in <String>[
        '7oiylpimjg5u2ca1yps', // exactly 2^96
        'zzzzzzzzzzzzzzzzzzz', // 36^19 - 1
      ]) {
        final id = '0000000$suffix';
        expect(Pikaid.isWellFormed(id), isTrue);
        expect(Pikaid.isValid(id), isFalse);
        expect(() => Pikaid.parse(id), throwsFormatException);
      }
    });

    test('zero-padded components survive every conversion', () {
      final id = Pikaid.fromComponents(
        timestamp: 0,
        randomness: hexToBytes('000000000000000000000001'),
      );
      expect(id.toString(), '00000000000000000000000001');
      expect(id.toBinary(), hexToBytes('0000000000000000000000000000000001'));
      expect(Pikaid.parse(id.toString()), id);
      expect(Pikaid.fromBinary(id.toBinary()), id);
    });

    test('maximum timestamp validates in both representations', () {
      expect(Pikaid.isValid('zzzzzzz0000000000000000000'), isTrue);
      expect(
        Pikaid.fromBinary(
          hexToBytes('123ede3fff000000000000000000000000'),
        ).timestamp,
        Pikaid.maxTimestamp,
      );
    });

    test('one past the maximum timestamp is rejected in binary', () {
      expect(Pikaid.maxTimestamp + 1, 78364164096);
      expect(
        () => Pikaid.fromBinary(
          hexToBytes('123ede4000000000000000000000000000'),
        ),
        throwsFormatException,
      );
    });
  });
}
