@TestOn('vm')
library;

import 'package:pikaid/pikaid.dart';
import 'package:test/test.dart';

import 'support/hex.dart';
import 'support/vectors.dart';

/// Runs every applicable vector from the shared `pikaid-v1.json` fixture.
///
/// The fixture is independent of this implementation: it is copied from
/// `pikaid/pikaid-php` v1.2.0, which itself follows specification revision
/// 1.0.4. Expected values are read from the fixture, never from
/// `package:pikaid`.
void main() {
  final vectors = loadOfficialVectors();

  group('fixture metadata', () {
    test('agrees with the package constants', () {
      final meta = vectors.meta;
      expect(meta['project'], 'pikaid');
      expect(meta['spec_revision'], '1.0.4');
      expect(meta['identifier_format'], 'immutable and unversioned');
      expect(meta['string_length'], Pikaid.stringLength);

      final timestamp = meta['timestamp']! as Map<String, Object?>;
      expect(timestamp['encoding'], 'base36-lower');
      expect(timestamp['chars'], Pikaid.timestampLength);
      expect(timestamp['min'], 0);
      expect(timestamp['max'], Pikaid.maxTimestamp);

      final entropy = meta['entropy']! as Map<String, Object?>;
      expect(entropy['bytes'], Pikaid.randomnessBytes);
      expect(entropy['encoding'], 'base36-lower');
      expect(entropy['chars'], Pikaid.randomnessLength);

      final binary = meta['binary']! as Map<String, Object?>;
      expect(binary['bytes'], Pikaid.binaryLength);
      expect(
        binary['layout'],
        '[5 bytes timestamp big-endian][12 bytes entropy]',
      );
    });

    test('contains every vector category', () {
      expect(vectors.valid, isNotEmpty);
      expect(vectors.invalidStrings, isNotEmpty);
      expect(vectors.invalidBinary, isNotEmpty);
      expect(
        vectors.valid.map((vector) => vector.timestamp),
        containsAll(<int>[0, Pikaid.maxTimestamp]),
        reason: 'the fixture must keep both timestamp boundaries',
      );
    });

    test('is internally consistent', () {
      final idPattern = RegExp(r'^[0-9a-z]{26}$');
      final binPattern = RegExp(r'^[0-9a-f]{34}$');
      for (final vector in vectors.valid) {
        expect(idPattern.hasMatch(vector.id), isTrue, reason: vector.name);
        expect(binPattern.hasMatch(vector.binHex), isTrue, reason: vector.name);
        expect(
          RegExp(r'^[0-9a-f]{24}$').hasMatch(vector.entropyHex),
          isTrue,
          reason: vector.name,
        );
        expect(
          hexToBytes(vector.binHex).sublist(0, 5),
          hexToBytes(
            vector.timestamp.toRadixString(16).padLeft(10, '0'),
          ),
          reason: '${vector.name}: timestamp bytes must be big-endian',
        );
        expect(
          hexToBytes(vector.binHex).sublist(5),
          hexToBytes(vector.entropyHex),
          reason: '${vector.name}: entropy bytes must be preserved',
        );
      }
    });

    test('valid ids sort by timestamp, then by entropy', () {
      final byTimestamp = [...vectors.valid]..sort((a, b) {
          final bySecond = a.timestamp.compareTo(b.timestamp);
          return bySecond != 0
              ? bySecond
              : a.entropyHex.compareTo(b.entropyHex);
        });
      final byString = [...vectors.valid]..sort((a, b) => a.id.compareTo(b.id));
      expect(
        byString.map((vector) => vector.name),
        byTimestamp.map((vector) => vector.name),
      );
    });
  });

  group('valid vectors', () {
    for (final vector in vectors.valid) {
      test(vector.name, () {
        final parsed = Pikaid.parse(vector.id);
        expect(parsed.timestamp, vector.timestamp);
        expect(parsed.randomnessHex, vector.entropyHex);
        expect(parsed.randomness, hexToBytes(vector.entropyHex));
        expect(parsed.toString(), vector.id);
        expect(parsed.toBinary(), hexToBytes(vector.binHex));

        final fromBinary = Pikaid.fromBinary(hexToBytes(vector.binHex));
        expect(fromBinary.timestamp, vector.timestamp);
        expect(fromBinary.randomnessHex, vector.entropyHex);
        expect(fromBinary.toString(), vector.id);

        final fromComponents = Pikaid.fromComponents(
          timestamp: vector.timestamp,
          randomness: hexToBytes(vector.entropyHex),
        );
        expect(fromComponents.toString(), vector.id);

        expect(Pikaid.isValid(vector.id), isTrue);
        expect(Pikaid.isWellFormed(vector.id), isTrue);
        expect(Pikaid.tryParse(vector.id), parsed);
        expect(fromBinary, parsed);
        expect(fromComponents, parsed);
      });
    }
  });

  group('invalid text vectors', () {
    for (final vector in vectors.invalidStrings) {
      test(vector.name, () {
        expect(
          () => Pikaid.parse(vector.id),
          throwsFormatException,
          reason: '${vector.name} must not be parsed',
        );
        expect(Pikaid.tryParse(vector.id), isNull);
        expect(Pikaid.isValid(vector.id), isFalse);
        expect(
          Pikaid.isWellFormed(vector.id),
          _shapeIsValid(vector.id),
          reason: 'shape-only checks must stay independent of range checks',
        );
      });
    }

    test('entropy-overflow is well formed but invalid', () {
      final vector = vectors.invalidStrings
          .singleWhere((vector) => vector.name == 'entropy-overflow');
      expect(Pikaid.isWellFormed(vector.id), isTrue);
      expect(Pikaid.isValid(vector.id), isFalse);
      expect(
        () => Pikaid.parse(vector.id),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('96 bits'),
          ),
        ),
      );
    });
  });

  group('invalid binary vectors', () {
    for (final vector in vectors.invalidBinary) {
      test(vector.name, () {
        expect(
          () => Pikaid.fromBinary(hexToBytes(vector.binHex)),
          throwsFormatException,
          reason: '${vector.name} must not be decoded',
        );
      });
    }

    test('timestamp overflow is one second past the maximum', () {
      final vector = vectors.invalidBinary
          .singleWhere((vector) => vector.name == 'timestamp-overflow');
      final bytes = hexToBytes(vector.binHex);
      final timestamp = bytes.sublist(0, 5).fold<int>(
            0,
            (value, byte) => value * 256 + byte,
          );
      expect(timestamp, Pikaid.maxTimestamp + 1);
    });
  });
}

/// Independent shape check used as the oracle for `Pikaid.isWellFormed`.
bool _shapeIsValid(String value) {
  if (value.length != Pikaid.stringLength) {
    return false;
  }
  for (final unit in value.codeUnits) {
    final isDigit = unit >= 0x30 && unit <= 0x39;
    final isLowercase = unit >= 0x61 && unit <= 0x7a;
    if (!isDigit && !isLowercase) {
      return false;
    }
  }
  return true;
}
