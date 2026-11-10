@TestOn('vm')
library;

import 'dart:typed_data';

import 'package:pikaid/pikaid.dart';
import 'package:test/test.dart';

import 'support/hex.dart';

void main() {
  group('fixed boundary round trips', () {
    final timestamps = <int>[
      0,
      1,
      35,
      36,
      Pikaid.maxTimestamp - 1,
      Pikaid.maxTimestamp,
    ];
    final entropies = <String>[
      '000000000000000000000000',
      '000000000000000000000001',
      '0000000000000000000000ff',
      '000000000000000000000100',
      '800000000000000000000000',
      'fffffffffffffffffffffffe',
      'ffffffffffffffffffffffff',
      '00112233445566778899aabb',
    ];

    for (final timestamp in timestamps) {
      for (final entropyHex in entropies) {
        test('timestamp $timestamp entropy $entropyHex', () {
          final id = Pikaid.fromComponents(
            timestamp: timestamp,
            randomness: hexToBytes(entropyHex),
          );

          final text = id.toString();
          expect(text.length, Pikaid.stringLength);
          expect(RegExp(r'^[0-9a-z]{26}$').hasMatch(text), isTrue);

          final parsed = Pikaid.parse(text);
          expect(parsed.timestamp, timestamp);
          expect(parsed.randomnessHex, entropyHex);
          expect(parsed, id);

          final binary = id.toBinary();
          expect(binary.length, Pikaid.binaryLength);
          final decoded = Pikaid.fromBinary(binary);
          expect(decoded, id);
          expect(decoded.toBinary(), binary);
          expect(decoded.toString(), text);
        });
      }
    }
  });

  group('powers of 36', () {
    test('timestamp boundaries at every Base36 width', () {
      var power = 1;
      for (var digits = 1; digits <= Pikaid.timestampLength; digits++) {
        for (final timestamp in <int>[power - 1, power]) {
          if (timestamp < 0 || timestamp > Pikaid.maxTimestamp) {
            continue;
          }
          final id = Pikaid.fromComponents(
            timestamp: timestamp,
            randomness: List<int>.filled(12, 0),
          );
          expect(
            id.toString().substring(0, Pikaid.timestampLength).length,
            Pikaid.timestampLength,
          );
          expect(Pikaid.parse(id.toString()), id);
          expect(Pikaid.fromBinary(id.toBinary()), id);
        }
        power *= 36;
      }
    });

    test('randomness boundaries at every Base36 width', () {
      var power = 1;
      for (var digits = 1; digits <= Pikaid.randomnessLength; digits++) {
        for (final value in <int>[power - 1, power]) {
          if (value < 0 || value.toRadixString(16).length > 24) {
            continue;
          }
          final hex = value.toRadixString(16).padLeft(24, '0');
          final id = Pikaid.fromComponents(
            timestamp: 0,
            randomness: hexToBytes(hex),
          );
          expect(
            id.toString().substring(Pikaid.timestampLength).length,
            Pikaid.randomnessLength,
          );
          expect(Pikaid.parse(id.toString()), id);
          expect(Pikaid.fromBinary(id.toBinary()), id);
        }
        power *= 36;
      }
    });

    test('the last power below 2^96 is the largest 19-digit prefix', () {
      // 36^18 is representable; 36^19 is not a valid 96-bit value.
      final largest = Pikaid.fromComponents(
        timestamp: 0,
        randomness: hexToBytes('2153e468b91c6d1000000000'),
      );
      expect(largest.toString().substring(7), '1000000000000000000');
      expect(Pikaid.isValid(largest.toString()), isTrue);
      expect(Pikaid.isValid('0000000' 'zzzzzzzzzzzzzzzzzzz'), isFalse);
    });
  });

  group('randomized round trips', () {
    test('text and binary representations are lossless', () {
      final random = _XorShift(0x5EED1234);
      for (var i = 0; i < 500; i++) {
        final timestamp = _nextInt(random, Pikaid.maxTimestamp + 1);
        final entropy = Uint8List(12);
        for (var j = 0; j < entropy.length; j++) {
          entropy[j] = _nextInt(random, 256);
        }

        final id = Pikaid.fromComponents(
          timestamp: timestamp,
          randomness: entropy,
        );
        final text = id.toString();
        final binary = id.toBinary();

        expect(text.length, 26, reason: 'case $i');
        expect(binary.length, 17, reason: 'case $i');
        expect(Pikaid.isValid(text), isTrue, reason: 'case $i');
        expect(Pikaid.parse(text), id, reason: 'case $i');
        expect(Pikaid.fromBinary(binary), id, reason: 'case $i');
        expect(Pikaid.fromBinary(binary).toBinary(), binary);
        expect(Pikaid.parse(text).toString(), text);
        expect(Pikaid.parse(text).timestamp, timestamp);
        expect(Pikaid.parse(text).randomness, entropy);
      }
    });

    test(
        'mutating any single text character changes the value or invalidates it',
        () {
      const id = '0s44we8002loz3po6mcf6vsn23';
      final original = Pikaid.parse(id);
      const alphabet = '0123456789abcdefghijklmnopqrstuvwxyz';
      final seen = <String>{id};

      for (var index = 0; index < id.length; index++) {
        for (final replacement in alphabet.split('')) {
          if (replacement == id[index]) {
            continue;
          }
          final mutated = id.replaceRange(index, index + 1, replacement);
          final parsed = Pikaid.tryParse(mutated);
          if (parsed != null) {
            expect(parsed, isNot(original), reason: mutated);
            seen.add(mutated);
          }
        }
      }
      expect(seen.length, greaterThan(850));
    });

    test('different timestamps never round-trip to the same value', () {
      final ids = <String>{};
      for (var timestamp = 0; timestamp < 200; timestamp++) {
        final id = Pikaid.fromComponents(
          timestamp: timestamp,
          randomness: List<int>.filled(12, 0),
        );
        expect(ids.add(id.toString()), isTrue);
        expect(Pikaid.parse(id.toString()).timestamp, timestamp);
        expect(Pikaid.fromBinary(id.toBinary()).timestamp, timestamp);
      }
    });
  });

  group('binary mutation', () {
    test('mutating any single byte parses to a different value or is rejected',
        () {
      // Timestamp 1700000000 (0x6553f100) followed by 12 entropy bytes.
      final binary = Uint8List.fromList(<int>[
        0x00,
        0x65,
        0x53,
        0xf1,
        0x00,
        ...List<int>.generate(12, (index) => (index * 17) & 0xff),
      ]);
      final original = Pikaid.fromBinary(binary);
      const replacements = <int>[0x00, 0x01, 0x7f, 0x80, 0xff];
      var accepted = 0;

      for (var index = 0; index < binary.length; index++) {
        for (final replacement in replacements) {
          if (binary[index] == replacement) {
            continue;
          }
          final mutated = Uint8List.fromList(binary)..[index] = replacement;
          final Pikaid parsed;
          try {
            parsed = Pikaid.fromBinary(mutated);
          } on FormatException {
            continue; // A timestamp mutation may overflow the 40-bit field.
          }
          expect(parsed, isNot(original),
              reason: 'byte $index -> $replacement');
          expect(parsed.toBinary(), mutated);
          accepted++;
        }
      }

      expect(accepted, greaterThan(60));
    });
  });

  group('buffer independence', () {
    test('toBinary returns a fresh buffer', () {
      final id = Pikaid.fromComponents(
        timestamp: 1,
        randomness: List<int>.filled(12, 0xab),
      );
      final first = id.toBinary();
      final second = id.toBinary();
      expect(first, second);
      expect(identical(first, second), isFalse);
      first[0] = 0;
      expect(id.toBinary(), second);
    });

    test('fromBinary copies its input', () {
      final bytes = hexToBytes('0000000001' '0000000000000000000000ff');
      final id = Pikaid.fromBinary(bytes);
      bytes[5] = 0;
      bytes[0] = 0xff;
      expect(id.timestamp, 1);
      expect(id.randomnessHex, '0000000000000000000000ff');
    });

    test('randomness is an immutable view', () {
      final id = Pikaid.parse('0s44we8002loz3po6mcf6vsn23');
      expect(id.randomness, hexToBytes('00112233445566778899aabb'));
      expect(
        () => id.randomness[0] = 0,
        throwsUnsupportedError,
      );
      expect(
        () => id.randomness.fillRange(0, 12, 0),
        throwsUnsupportedError,
      );
      expect(id.randomnessHex, '00112233445566778899aabb');
    });
  });
}

/// A deterministic xorshift generator, used only for test inputs.
///
/// This is deliberately not a secure source and is never passed to
/// `Pikaid.generate*`; it only produces arbitrary timestamps and entropy.
final class _XorShift {
  _XorShift(int seed) : _state = seed & 0xffffffff;

  int _state;

  int next() {
    var value = _state;
    value ^= (value << 13) & 0xffffffff;
    value ^= value >> 17;
    value ^= (value << 5) & 0xffffffff;
    _state = value & 0xffffffff;
    return _state;
  }
}

int _nextInt(_XorShift random, int maximum) {
  final a = random.next() & 0xffff;
  final b = random.next() & 0xffff;
  final c = random.next() & 0xffff;
  final d = random.next() & 0xffff;
  final value = (a << 48) | (b << 32) | (c << 16) | d;
  return value % maximum;
}
