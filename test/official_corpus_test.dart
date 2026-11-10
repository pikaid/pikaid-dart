// Official cross-language conformance corpus, transcribed verbatim from the
// immutable suite and checked in as `test/support/official_cases.dart`.
//
// This file must not import `dart:io` or any VM-only library: the same source
// runs on the Dart VM, on dart2js in Node, on dart2js in a real headless
// browser and on dart2wasm (see the CI jobs). Expected values come from the
// official fixtures, never from `package:pikaid` itself.

import 'dart:typed_data';

import 'package:pikaid/pikaid.dart';
import 'package:test/test.dart';

import 'support/hex.dart';
import 'support/official_cases.dart';

/// A random source that replays one case's official randomness bytes.
final class _FixedRandomSource implements PikaidRandomSource {
  _FixedRandomSource(Uint8List bytes) : _bytes = bytes;

  final Uint8List _bytes;

  @override
  void fillBytes(Uint8List destination) {
    if (destination.length != _bytes.length) {
      throw StateError('unexpected randomness length ${destination.length}');
    }
    destination.setAll(0, _bytes);
  }
}

int _compareBytes(List<int> left, List<int> right) {
  final shared = left.length < right.length ? left.length : right.length;
  for (var i = 0; i < shared; i++) {
    if (left[i] != right[i]) {
      return left[i] < right[i] ? -1 : 1;
    }
  }
  return (left.length - right.length).sign;
}

void main() {
  group('official suite provenance', () {
    test('pins the immutable suite revision', () {
      expect(
        officialSuiteCommit,
        '059780cc0e5b113443812720d95c630649bf3aa3',
      );
      expect(officialPackageRevision, '1.0.0');
      expect(officialSpecRevision, '1.0.4');
      expect(officialSuiteStatus, 'OFFICIAL');
    });

    test('embeds a digest for every corpus fixture', () {
      expect(officialFixtureSha256.keys, <String>[
        'cases/invalid-binary.json',
        'cases/invalid-string.json',
        'cases/ordering.json',
        'cases/valid.json',
        'manifest.json',
      ]);
      for (final digest in officialFixtureSha256.values) {
        expect(digest, matches(RegExp(r'^[0-9a-f]{64}$')));
      }
    });

    test('retains the exact fixture counts', () {
      expect(officialValidCaseCount, 596);
      expect(officialInvalidStringCaseCount, 258);
      expect(officialInvalidBinaryCaseCount, 33);
      expect(officialOrderingCaseCount, 186);
      expect(officialValidCases, hasLength(officialValidCaseCount));
      expect(
        officialInvalidStringCases,
        hasLength(officialInvalidStringCaseCount),
      );
      expect(
        officialInvalidBinaryCases,
        hasLength(officialInvalidBinaryCaseCount),
      );
      expect(officialOrderingCases, hasLength(officialOrderingCaseCount));
    });
  });

  group('official valid corpus', () {
    for (final testCase in officialValidCases) {
      test(testCase.name, () {
        final binary = hexToBytes(testCase.binaryHex);
        final parsed = Pikaid.parse(testCase.id);

        expect(parsed.timestamp, testCase.timestamp);
        expect(parsed.randomnessHex, testCase.randomnessHex);
        expect(parsed.toString(), testCase.id);
        expect(parsed.toBinary(), binary);
        expect(Pikaid.fromBinary(binary).toString(), testCase.id);
        expect(Pikaid.isValid(testCase.id), isTrue);
        expect(Pikaid.isWellFormed(testCase.id), isTrue);

        final source = _FixedRandomSource(hexToBytes(testCase.randomnessHex));
        expect(
          Pikaid.generateAt(testCase.timestamp, randomSource: source)
              .toString(),
          testCase.id,
        );
        expect(
          Pikaid.generateBinaryAt(testCase.timestamp, randomSource: source),
          binary,
        );
      });
    }
  });

  group('official invalid string corpus', () {
    for (final testCase in officialInvalidStringCases) {
      test(testCase.name, () {
        expect(Pikaid.isValid(testCase.value), testCase.valid);
        expect(Pikaid.isWellFormed(testCase.value), testCase.wellFormed);
        expect(
          () => Pikaid.parse(testCase.value),
          throwsA(isA<FormatException>()),
          reason: testCase.reason,
        );
      });
    }
  });

  group('official invalid binary corpus', () {
    for (final testCase in officialInvalidBinaryCases) {
      test(testCase.name, () {
        final bytes = hexToBytes(testCase.value);
        expect(
          () => Pikaid.fromBinary(bytes),
          throwsA(isA<FormatException>()),
          reason: testCase.reason,
        );
      });
    }
  });

  group('official ordering corpus', () {
    for (final testCase in officialOrderingCases) {
      test(testCase.name, () {
        final a = Pikaid.parse(testCase.aId);
        final b = Pikaid.parse(testCase.bId);

        expect(a.compareTo(b), testCase.expectedCompare);
        expect(
          _compareBytes(
            hexToBytes(testCase.aBinaryHex),
            hexToBytes(testCase.bBinaryHex),
          ),
          testCase.expectedCompare,
        );
        expect(Pikaid.fromBinary(hexToBytes(testCase.aBinaryHex)), a);
        expect(Pikaid.fromBinary(hexToBytes(testCase.bBinaryHex)), b);
      });
    }
  });
}
