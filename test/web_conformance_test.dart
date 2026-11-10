// Platform-portable conformance tests.
//
// This file must not import `dart:io` or any VM-only library: the same source
// runs on the Dart VM, on dart2js in Node, and on dart2js in a real headless
// browser (see the `web-conformance` CI job). Known answers are transcribed
// literals from the specification and the independent Python oracle, never
// produced by `package:pikaid` itself.

import 'dart:typed_data';

import 'package:pikaid/pikaid.dart';
import 'package:test/test.dart';

import 'support/hex.dart';
import 'support/node_web_crypto.dart';

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
    name: 'maximum timestamp and maximum entropy',
    timestamp: 78364164095,
    entropyHex: 'ffffffffffffffffffffffff',
    id: 'zzzzzzz7oiylpimjg5u2ca1ypr',
    binaryHex: '123ede3fffffffffffffffffffffffffff',
  ),
  (
    name: 'sample 1700000000',
    timestamp: 1700000000,
    entropyHex: '00112233445566778899aabb',
    id: '0s44we8002loz3po6mcf6vsn23',
    binaryHex: '006553f10000112233445566778899aabb',
  ),
  (
    name: 'timestamp across the 32-bit boundary',
    timestamp: 4294967296,
    entropyHex: '00000000ffffffff00000000',
    id: '1z141z40000003w5e11073oetc',
    binaryHex: '010000000000000000ffffffff00000000',
  ),
  (
    name: 'one and one',
    timestamp: 1,
    entropyHex: '000000000000000000000001',
    id: '00000010000000000000000001',
    binaryHex: '0000000001000000000000000000000001',
  ),
];

void main() {
  // `dart test -p node` prepends node_preamble, whose `self` object is not the
  // global object; Node's brand-checked Web Crypto getter rejects that
  // receiver. Restore the genuine Node CSPRNG as a data property on the global
  // object before any test body runs. No-op on the VM and in browsers.
  repairNodeWebCrypto();

  group('known answers', () {
    for (final testCase in _cases) {
      test(testCase.name, () {
        final id = Pikaid.parse(testCase.id);
        expect(id.timestamp, testCase.timestamp);
        expect(id.randomnessHex, testCase.entropyHex);
        expect(bytesToHex(id.toBinary()), testCase.binaryHex);

        final fromBinary = Pikaid.fromBinary(hexToBytes(testCase.binaryHex));
        expect(fromBinary.toString(), testCase.id);
        expect(fromBinary, id);

        final fromComponents = Pikaid.fromComponents(
          timestamp: testCase.timestamp,
          randomness: hexToBytes(testCase.entropyHex),
        );
        expect(fromComponents.toString(), testCase.id);

        expect(Pikaid.tryParse(testCase.id), id);
        expect(Pikaid.isValid(testCase.id), isTrue);
        expect(Pikaid.isWellFormed(testCase.id), isTrue);
      });
    }
  });

  group('round trips', () {
    test('text and binary forms preserve every component', () {
      for (final testCase in _cases) {
        final id = Pikaid.parse(testCase.id);
        expect(Pikaid.fromBinary(id.toBinary()), id, reason: testCase.name);
        expect(
          bytesToHex(Pikaid.fromBinary(id.toBinary()).toBinary()),
          testCase.binaryHex,
          reason: testCase.name,
        );
      }
    });

    test('binary output is a fresh copy owned by the caller', () {
      final id = Pikaid.parse('0s44we8002loz3po6mcf6vsn23');
      final first = id.toBinary();
      first.fillRange(0, first.length, 0);
      expect(
        bytesToHex(id.toBinary()),
        '006553f10000112233445566778899aabb',
      );
    });

    test('fromBinary copies its input', () {
      final input = hexToBytes('006553f10000112233445566778899aabb');
      final id = Pikaid.fromBinary(input);
      input.fillRange(0, input.length, 0);
      expect(id.randomnessHex, '00112233445566778899aabb');
      expect(bytesToHex(id.toBinary()), '006553f10000112233445566778899aabb');
    });

    test('leading zeros are preserved in both directions', () {
      final id = Pikaid.parse('00000000000000000000000000');
      expect(id.timestamp, 0);
      expect(id.randomnessHex, '000000000000000000000000');
      expect(id.toString(), '00000000000000000000000000');
      expect(bytesToHex(id.toBinary()), '0' * 34);
      expect(Pikaid.fromBinary(id.toBinary()), id);
    });
  });

  group('rejection', () {
    test('malformed text is never normalized', () {
      final samples = <String>[
        '',
        '0' * 25,
        '0' * 27,
        '0s44we8002loz3po6mcf6vsn2A', // uppercase
        '0s44we8002loz3po6mcf6vsn2_', // outside the alphabet
        '0s44we8002loz3po6mcf6vsn2\u00e9', // non-ASCII
        ' 0s44we8002loz3po6mcf6vsn2', // leading space
      ];
      for (final sample in samples) {
        expect(() => Pikaid.parse(sample), throwsFormatException,
            reason: sample);
        expect(Pikaid.tryParse(sample), isNull, reason: sample);
        expect(Pikaid.isValid(sample), isFalse, reason: sample);
      }
    });

    test('randomness above 2^96 is rejected', () {
      const overflow = '0000000zzzzzzzzzzzzzzzzzzz';
      expect(overflow.length, Pikaid.stringLength);
      expect(Pikaid.isWellFormed(overflow), isTrue);
      expect(Pikaid.isValid(overflow), isFalse);
      expect(() => Pikaid.parse(overflow), throwsFormatException);
      expect(Pikaid.tryParse(overflow), isNull);
    });

    test('malformed binary is rejected', () {
      for (final length in <int>[0, 1, 5, 12, 16, 18, 34]) {
        expect(
          () => Pikaid.fromBinary(List<int>.filled(length, 0)),
          throwsFormatException,
          reason: 'length $length',
        );
      }

      final negative = List<int>.filled(Pikaid.binaryLength, 0)..[5] = -1;
      final tooLarge = List<int>.filled(Pikaid.binaryLength, 0)..[11] = 256;
      for (final bytes in <List<int>>[negative, tooLarge]) {
        expect(() => Pikaid.fromBinary(bytes), throwsFormatException);
      }
    });

    test('timestamp fields above 36^7 - 1 are rejected', () {
      for (final hex in <String>[
        '123ede4000000000000000000000000000',
        'ffffffffff000000000000000000000000',
      ]) {
        expect(
          () => Pikaid.fromBinary(hexToBytes(hex)),
          throwsFormatException,
          reason: hex,
        );
      }
    });

    test('component construction rejects out-of-range values', () {
      expect(
        () => Pikaid.fromComponents(
          timestamp: -1,
          randomness: List<int>.filled(12, 0),
        ),
        throwsRangeError,
      );
      expect(
        () => Pikaid.fromComponents(
          timestamp: Pikaid.maxTimestamp + 1,
          randomness: List<int>.filled(12, 0),
        ),
        throwsRangeError,
      );
      expect(
        () => Pikaid.fromComponents(timestamp: 0, randomness: <int>[0]),
        throwsArgumentError,
      );
      expect(
        () => Pikaid.fromComponents(
          timestamp: 0,
          randomness: List<int>.filled(12, 256),
        ),
        throwsRangeError,
      );
    });
  });

  group('generation', () {
    test('explicit timestamps are deterministic with a fixed source', () {
      final source = _CountingSource(List<int>.generate(12, (index) => index));
      final id = Pikaid.generateAt(1700000000, randomSource: source);
      expect(id.timestamp, 1700000000);
      expect(id.randomnessHex, '000102030405060708090a0b');
      expect(source.fillCount, 1);
      expect(source.destinationLengths, <int>[Pikaid.randomnessBytes]);

      expect(
        bytesToHex(
          Pikaid.generateBinaryAt(1700000000, randomSource: source),
        ),
        bytesToHex(id.toBinary()),
      );
      expect(source.fillCount, 2);
    });

    test('invalid timestamps are rejected before entropy is requested', () {
      for (final timestamp in <int>[-1, Pikaid.maxTimestamp + 1]) {
        final source = _CountingSource(List<int>.filled(12, 0));
        expect(
          () => Pikaid.generateAt(timestamp, randomSource: source),
          throwsRangeError,
        );
        expect(source.fillCount, 0);
      }
    });

    test('a failing random source fails closed', () {
      expect(
        () => Pikaid.generateAt(0, randomSource: _ThrowingSource()),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'the default CSPRNG produces valid round-trippable values',
      () {
        final before = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        final text = Pikaid.generate();
        final binary = Pikaid.generateBinary();
        final after = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

        expect(Pikaid.isValid(text.toString()), isTrue);
        final fromBinary = Pikaid.fromBinary(binary);
        expect(Pikaid.isValid(fromBinary.toString()), isTrue);
        expect(Pikaid.fromBinary(text.toBinary()), text);
        expect(fromBinary.toBinary(), binary);

        for (final id in <Pikaid>[text, fromBinary]) {
          expect(id.timestamp, greaterThanOrEqualTo(before - 1));
          expect(id.timestamp, lessThanOrEqualTo(after + 1));
        }
      },
    );
  });

  group('ordering', () {
    test('text order, binary order and compareTo agree', () {
      final ids = <Pikaid>[
        Pikaid.fromComponents(
          timestamp: 2,
          randomness: List<int>.filled(12, 0),
        ),
        Pikaid.fromComponents(
          timestamp: 1,
          randomness: List<int>.filled(12, 0xff),
        ),
        Pikaid.fromComponents(
          timestamp: 1,
          randomness: List<int>.filled(12, 0),
        ),
        Pikaid.fromComponents(
          timestamp: Pikaid.maxTimestamp,
          randomness: List<int>.filled(12, 0),
        ),
      ];

      final byText = <String>[...ids.map((id) => id.toString())]..sort();
      final byBinary = <Uint8List>[...ids.map((id) => id.toBinary())]
        ..sort(_compareBytes);
      final byObject = <Pikaid>[...ids]..sort();

      expect(byText, byObject.map((id) => id.toString()).toList());
      expect(byBinary, byObject.map((id) => id.toBinary()).toList());
      for (var i = 0; i + 1 < byObject.length; i++) {
        expect(byObject[i].compareTo(byObject[i + 1]), isNegative);
      }
    });

    test('timestamps order before randomness, which orders bytewise', () {
      final earlier = Pikaid.fromComponents(
        timestamp: 10,
        randomness: List<int>.filled(12, 0xff),
      );
      final later = Pikaid.fromComponents(
        timestamp: 11,
        randomness: List<int>.filled(12, 0),
      );
      final lowEntropy = Pikaid.fromComponents(
        timestamp: 10,
        randomness: List<int>.filled(12, 0),
      );

      expect(earlier.compareTo(later), isNegative);
      expect(lowEntropy.compareTo(earlier), isNegative);
      expect(earlier.timestampUtc.isBefore(later.timestampUtc), isTrue);
      expect(
          earlier.timestampUtc.isAtSameMomentAs(lowEntropy.timestampUtc), true);
    });
  });
}

int _compareBytes(List<int> a, List<int> b) {
  for (var i = 0; i < a.length && i < b.length; i++) {
    final difference = a[i] - b[i];
    if (difference != 0) {
      return difference;
    }
  }
  return a.length - b.length;
}

final class _CountingSource implements PikaidRandomSource {
  _CountingSource(this._bytes);

  final List<int> _bytes;
  int fillCount = 0;
  final List<int> destinationLengths = <int>[];

  @override
  void fillBytes(Uint8List destination) {
    fillCount++;
    destinationLengths.add(destination.length);
    destination.setAll(0, _bytes);
  }
}

final class _ThrowingSource implements PikaidRandomSource {
  @override
  void fillBytes(Uint8List destination) {
    throw StateError('CSPRNG unavailable');
  }
}
