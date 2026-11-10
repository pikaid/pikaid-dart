// Platform-portable conformance matrix.
//
// This file must not import `dart:io` or any VM-only library: the same source
// runs on the Dart VM, on dart2js in Node and on dart2js in a real browser.
//
// The expected values come from `tool/generate_conformance_cases.py`, an
// independent BigInt implementation written directly from specification
// revision 1.0.4. Every case is additionally recomputed in Dart by
// `support/reference.dart`, a second independent BigInt implementation, so a
// transcription error in the generated table cannot silently pass.

import 'dart:typed_data';

import 'package:pikaid/pikaid.dart';
import 'package:test/test.dart';

import 'support/conformance_cases.dart';
import 'support/deterministic_random_source.dart';
import 'support/hex.dart';
import 'support/reference.dart';

void main() {
  group('generated table integrity', () {
    test('contains every pinned case', () {
      expect(conformanceCases, hasLength(conformanceCaseCount));
      expect(invalidConformanceText, hasLength(invalidTextCaseCount));
      expect(invalidConformanceBinary, hasLength(invalidBinaryCaseCount));
      expect(
        conformanceCases.map((testCase) => testCase.name).toSet(),
        hasLength(conformanceCaseCount),
        reason: 'case names must stay unique',
      );
    });

    test('every expected value is recomputed by the Dart reference oracle', () {
      for (final testCase in conformanceCases) {
        final entropy = hexToBytes(testCase.entropyHex);
        expect(
          referenceEncode(testCase.timestamp, entropy),
          testCase.id,
          reason: '${testCase.name}: text',
        );
        expect(
          bytesToHex(referenceBinary(testCase.timestamp, entropy)),
          testCase.binaryHex,
          reason: '${testCase.name}: binary',
        );
        final decoded = referenceDecode(testCase.id);
        expect(decoded.timestamp, testCase.timestamp,
            reason: '${testCase.name}: timestamp');
        expect(decoded.randomnessHex, testCase.entropyHex,
            reason: '${testCase.name}: randomness');
        expect(bytesToHex(entropy), testCase.entropyHex,
            reason: '${testCase.name}: fixture entropy must be canonical hex');
        expect(testCase.id, hasLength(Pikaid.stringLength));
        expect(entropy, hasLength(Pikaid.randomnessBytes));
      }
    });

    test('invalid text classifications match the reference oracle', () {
      for (final testCase in invalidConformanceText) {
        expect(referenceIsWellFormed(testCase.value), testCase.wellFormed,
            reason: '${testCase.name}: shape');
        expect(referenceIsValid(testCase.value), isFalse,
            reason: '${testCase.name}: semantics');
      }
    });

    test('invalid binary cases are rejected by the reference oracle', () {
      for (final testCase in invalidConformanceBinary) {
        expect(
          () => referenceDecodeBinary(hexToBytes(testCase.value)),
          throwsFormatException,
          reason: testCase.name,
        );
      }
    });
  });

  group('valid conformance matrix', () {
    for (final testCase in conformanceCases) {
      group(testCase.name, () {
        final expected = referenceDecode(testCase.id);

        test('parse exposes the pinned components', () {
          final id = Pikaid.parse(testCase.id);
          expect(id.timestamp, testCase.timestamp);
          expect(id.randomnessHex, testCase.entropyHex);
          expect(id.toString(), testCase.id);
          expect(bytesToHex(id.toBinary()), testCase.binaryHex);
          expect(id, Pikaid.parse(testCase.id));
          expect(
            id.timestampUtc,
            DateTime.fromMillisecondsSinceEpoch(
              testCase.timestamp * 1000,
              isUtc: true,
            ),
          );
          expect(id.timestampUtc.isUtc, isTrue);
          expect(expected.timestamp, testCase.timestamp);
        });

        test('fromBinary agrees with parse', () {
          final fromBinary = Pikaid.fromBinary(hexToBytes(testCase.binaryHex));
          expect(fromBinary, Pikaid.parse(testCase.id));
          expect(fromBinary.timestamp, testCase.timestamp);
          expect(fromBinary.randomnessHex, testCase.entropyHex);
          expect(fromBinary.toString(), testCase.id);
        });

        test('fromComponents agrees with parse', () {
          final fromComponents = Pikaid.fromComponents(
            timestamp: testCase.timestamp,
            randomness: hexToBytes(testCase.entropyHex),
          );
          expect(fromComponents, Pikaid.parse(testCase.id));
          expect(fromComponents.toString(), testCase.id);
          expect(bytesToHex(fromComponents.toBinary()), testCase.binaryHex);
        });

        test('predicates and tryParse accept the value', () {
          final parsed = Pikaid.parse(testCase.id);
          expect(Pikaid.tryParse(testCase.id), parsed);
          expect(Pikaid.isValid(testCase.id), isTrue);
          expect(Pikaid.isWellFormed(testCase.id), isTrue);
          expect(referenceIsValid(testCase.id), isTrue);
        });

        test('binary output is an independent copy', () {
          final id = Pikaid.parse(testCase.id);
          final first = id.toBinary();
          first[0] ^= 0xff;
          expect(bytesToHex(id.toBinary()), testCase.binaryHex);
        });
      });
    }
  });

  group('invalid text corpus', () {
    for (final testCase in invalidConformanceText) {
      test(testCase.name, () {
        expect(() => Pikaid.parse(testCase.value), throwsFormatException);
        expect(Pikaid.tryParse(testCase.value), isNull);
        expect(Pikaid.isValid(testCase.value), isFalse);
        expect(Pikaid.isWellFormed(testCase.value), testCase.wellFormed);
        expect(referenceIsWellFormed(testCase.value), testCase.wellFormed);
        expect(referenceIsValid(testCase.value), isFalse);
      });
    }
  });

  group('invalid binary corpus', () {
    for (final testCase in invalidConformanceBinary) {
      test(testCase.name, () {
        final bytes = hexToBytes(testCase.value);
        expect(() => Pikaid.fromBinary(bytes), throwsFormatException);
        expect(() => referenceDecodeBinary(bytes), throwsFormatException);
      });
    }
  });

  group('deterministic generation', () {
    test('generateAt reproduces the reference value for a fixed seed', () {
      for (var seed = 0; seed < 16; seed++) {
        final randomness = Uint8List(Pikaid.randomnessBytes);
        DeterministicRandomSource(seed).fillBytes(randomness);
        final expectedId = referenceEncode(1700000000 + seed, randomness);

        final generated = Pikaid.generateAt(
          1700000000 + seed,
          randomSource: DeterministicRandomSource(seed),
        );
        expect(generated.toString(), expectedId, reason: 'seed $seed');
        expect(generated.randomnessHex, bytesToHex(randomness));
        expect(generated, Pikaid.parse(expectedId));

        final binary = Pikaid.generateBinaryAt(
          1700000000 + seed,
          randomSource: DeterministicRandomSource(seed),
        );
        expect(bytesToHex(binary), bytesToHex(generated.toBinary()));
      }
    });

    test('every generated value re-encodes to the same id', () {
      final source = DeterministicRandomSource(20260101);
      for (var i = 0; i < 200; i++) {
        final timestampBytes = Uint8List(5);
        source.fillBytes(timestampBytes);
        var timestamp = 0;
        for (final byte in timestampBytes) {
          timestamp = (timestamp << 8) | byte;
        }
        timestamp %= Pikaid.maxTimestamp + 1;

        final randomness = Uint8List(Pikaid.randomnessBytes);
        source.fillBytes(randomness);

        final id = Pikaid.fromComponents(
          timestamp: timestamp,
          randomness: randomness,
        );
        final expected = referenceEncode(timestamp, randomness);
        expect(id.toString(), expected);
        expect(Pikaid.parse(expected), id);
        expect(
          Pikaid.fromBinary(hexToBytes(bytesToHex(id.toBinary()))),
          id,
        );
      }
    });
  });
}
