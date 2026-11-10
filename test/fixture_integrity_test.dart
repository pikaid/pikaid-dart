@TestOn('vm')
library;

import 'dart:io';

import 'package:pikaid/pikaid.dart';
import 'package:test/test.dart';

import 'support/conformance_cases.dart';
import 'support/hex.dart';
import 'support/reference.dart';
import 'support/sha256.dart';
import 'support/vectors.dart';

/// Pinned digests of the official fixture files.
///
/// These values were taken once with `shasum -a 256` from the files copied out
/// of `pikaid/pikaid-php` v1.2.0 (commit
/// `e3f843edeb5157a5d2d25196cac0d69580810a95`). Recording them here turns any
/// later edit of the fixture into a deliberate, reviewable change: an
/// accidental mutation fails the suite instead of quietly redefining expected
/// behaviour.
const Map<String, String> _fixtureDigests = <String, String>{
  'test/fixtures/pikaid-v1.json':
      'b0c9dfdd063613424414fef5c9065fbd2f81d645d0ab42b34e27cde715613500',
  'test/fixtures/pikaid-v1.schema.json':
      '4441d4dbaa6c5450ae9cbfb2438c53bc0421bba2b7fcc9ef9b158e5d1de0759e',
};

void main() {
  group('SHA-256 helper', () {
    test('matches NIST test vectors', () {
      expect(
        sha256Hex(const <int>[]),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
      expect(
        sha256Hex('abc'.codeUnits),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
      expect(
        sha256Hex(
          'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'.codeUnits,
        ),
        '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
      );
    });

    test('hashes arbitrary bytes, including bytes above 0x7f', () {
      // Digest taken once with `printf '\x00\x01\x7f\x80\xfe\xff' | shasum -a 256`.
      expect(
        sha256Hex(<int>[0x00, 0x01, 0x7f, 0x80, 0xfe, 0xff]),
        'a1d8748d0dbe0c9f4f6769346e7b14f8c57cbd636ef40dd40a21b96d7e78aa39',
      );
    });
  });

  group('official fixture integrity', () {
    for (final entry in _fixtureDigests.entries) {
      test('${entry.key} matches its pinned SHA-256', () {
        final file = File(entry.key);
        expect(file.existsSync(), isTrue, reason: 'missing ${entry.key}');
        expect(sha256Hex(file.readAsBytesSync()), entry.value);
      });
    }

    test('the fixture is pinned to specification 1.0.4', () {
      final meta = loadOfficialVectors().meta;
      expect(meta['spec_revision'], '1.0.4');
      expect(meta['string_length'], 26);
      expect(meta['identifier_format'], 'immutable and unversioned');
    });
  });

  group('fixture and conformance matrix agree', () {
    test('every valid fixture vector is in the generated matrix', () {
      final byId = <String, ConformanceCase>{
        for (final testCase in conformanceCases) testCase.id: testCase,
      };
      for (final vector in loadOfficialVectors().valid) {
        final testCase = byId[vector.id];
        expect(testCase, isNotNull, reason: '${vector.name} missing');
        expect(testCase!.timestamp, vector.timestamp, reason: vector.name);
        expect(testCase.entropyHex, vector.entropyHex, reason: vector.name);
        expect(testCase.binaryHex, vector.binHex, reason: vector.name);
      }
    });

    test('every fixture invalid vector is rejected by both implementations',
        () {
      final vectors = loadOfficialVectors();
      for (final vector in vectors.invalidStrings) {
        expect(Pikaid.isValid(vector.id), isFalse, reason: vector.name);
        expect(referenceIsValid(vector.id), isFalse, reason: vector.name);
        expect(() => Pikaid.parse(vector.id), throwsFormatException,
            reason: vector.name);
      }
      for (final vector in vectors.invalidBinary) {
        final bytes = hexToBytes(vector.binHex);
        expect(() => Pikaid.fromBinary(bytes), throwsFormatException,
            reason: vector.name);
        expect(() => referenceDecodeBinary(bytes), throwsFormatException,
            reason: vector.name);
      }
    });

    test('the fixture keeps both text forms of every invalid vector', () {
      // A regression that dropped a category from the fixture must not reduce
      // the suite silently.
      final vectors = loadOfficialVectors();
      expect(vectors.valid, hasLength(4));
      expect(vectors.invalidStrings, hasLength(6));
      expect(vectors.invalidBinary, hasLength(4));
    });
  });
}
