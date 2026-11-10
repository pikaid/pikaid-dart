@TestOn('vm')
library;

import 'dart:typed_data';

import 'package:pikaid/pikaid.dart';
import 'package:test/test.dart';

import 'support/hex.dart';

void main() {
  group('current-time generation', () {
    test('generate uses the current UTC whole second', () {
      final before = _nowSeconds();
      final id = Pikaid.generate();
      final after = _nowSeconds();
      expect(id.timestamp, inInclusiveRange(before, after));
      expect(id.toString().length, Pikaid.stringLength);
      expect(Pikaid.isValid(id.toString()), isTrue);
    });

    test('generateBinary uses the current UTC whole second', () {
      final before = _nowSeconds();
      final bytes = Pikaid.generateBinary();
      final after = _nowSeconds();
      expect(bytes.length, Pikaid.binaryLength);
      final id = Pikaid.fromBinary(bytes);
      expect(id.timestamp, inInclusiveRange(before, after));
      expect(Pikaid.isValid(id.toString()), isTrue);
    });

    test('generated values are unique in practice', () {
      final ids = <String>{};
      for (var i = 0; i < 1000; i++) {
        ids.add(Pikaid.generate().toString());
      }
      expect(ids.length, 1000);
    });
  });

  group('explicit timestamps and injected entropy', () {
    test('generateAt matches an independent known-answer vector', () {
      final source = _FixedSource(hexToBytes('00112233445566778899aabb'));
      final id = Pikaid.generateAt(1700000000, randomSource: source);

      expect(id.toString(), '0s44we8002loz3po6mcf6vsn23');
      expect(id.timestamp, 1700000000);
      expect(id.randomnessHex, '00112233445566778899aabb');
      expect(source.calls, 1);
      expect(source.destinationLengths, <int>[Pikaid.randomnessBytes]);
    });

    test('generateBinaryAt matches an independent known-answer vector', () {
      final source = _FixedSource(hexToBytes('00112233445566778899aabb'));
      final bytes = Pikaid.generateBinaryAt(1700000000, randomSource: source);
      expect(bytes, hexToBytes('006553f10000112233445566778899aabb'));
      expect(source.calls, 1);
      expect(source.destinationLengths, <int>[Pikaid.randomnessBytes]);
    });

    test('entropy is independent of the timestamp', () {
      final source = _FixedSource(hexToBytes('deadbeef0011223344556677'));
      final early = Pikaid.generateAt(0, randomSource: source);
      final late = Pikaid.generateAt(Pikaid.maxTimestamp, randomSource: source);
      expect(early.randomnessHex, 'deadbeef0011223344556677');
      expect(late.randomnessHex, early.randomnessHex);
      expect(early.timestamp, isNot(late.timestamp));
      expect(early.toString(), isNot(late.toString()));
    });

    test('every generation asks for exactly twelve entropy bytes', () {
      final source = _SequenceSource();
      Pikaid.generateAt(0, randomSource: source);
      Pikaid.generateAt(1, randomSource: source);
      Pikaid.generateBinaryAt(2, randomSource: source);
      expect(source.calls, 3);
      expect(source.destinationLengths, <int>[12, 12, 12]);
    });

    test('the source buffer is fully consumed without extra reads', () {
      final source = _SequenceSource();
      final id = Pikaid.generateAt(0, randomSource: source);
      expect(
        id.randomnessHex,
        '0102030405060708090a0b0c',
      );
      expect(source.calls, 1);
    });

    test('all-zero and all-ones entropy are preserved exactly', () {
      final zero = Pikaid.generateAt(
        0,
        randomSource: _FixedSource(List<int>.filled(12, 0)),
      );
      expect(zero.toString(), '00000000000000000000000000');
      expect(zero.randomnessHex, '000000000000000000000000');

      final ones = Pikaid.generateAt(
        0,
        randomSource: _FixedSource(List<int>.filled(12, 0xff)),
      );
      expect(ones.toString(), '00000007oiylpimjg5u2ca1ypr');
      expect(ones.randomnessHex, 'ffffffffffffffffffffffff');
    });

    test('timestamp boundaries are allowed', () {
      for (final timestamp in <int>[0, 1, Pikaid.maxTimestamp]) {
        final id = Pikaid.generateAt(
          timestamp,
          randomSource: _FixedSource(List<int>.filled(12, 0)),
        );
        expect(id.timestamp, timestamp);
        expect(Pikaid.isValid(id.toString()), isTrue);
      }
    });
  });

  group('timestamp validation', () {
    const invalid = <int>[-1, Pikaid.maxTimestamp + 1, 1 << 40, 1 << 62];

    for (final timestamp in invalid) {
      test('generateAt rejects $timestamp before touching the CSPRNG', () {
        final source = _SequenceSource();
        expect(
          () => Pikaid.generateAt(timestamp, randomSource: source),
          throwsRangeError,
        );
        expect(source.calls, 0);
      });

      test('generateBinaryAt rejects $timestamp before touching the CSPRNG',
          () {
        final source = _SequenceSource();
        expect(
          () => Pikaid.generateBinaryAt(timestamp, randomSource: source),
          throwsRangeError,
        );
        expect(source.calls, 0);
      });
    }
  });

  group('cryptographic failure handling', () {
    test('PikaidEntropyException from the source is propagated', () {
      final source = _ThrowingSource();
      expect(
        () => Pikaid.generateAt(0, randomSource: source),
        throwsA(
          isA<PikaidEntropyException>()
              .having((error) => error.message, 'message', 'no entropy'),
        ),
      );
      expect(source.calls, 1);
    });

    test('binary generation also fails closed', () {
      final source = _ThrowingSource();
      expect(
        () => Pikaid.generateBinaryAt(0, randomSource: source),
        throwsA(isA<PikaidEntropyException>()),
      );
      expect(source.calls, 1);
    });

    test('an arbitrary source error propagates; no weaker fallback is used',
        () {
      final source = _ErrorSource();
      expect(
        () => Pikaid.generateAt(0, randomSource: source),
        throwsStateError,
      );
      expect(source.calls, 1);
    });

    test('the default source is backed by Random.secure and fills the buffer',
        () {
      const source = SecurePikaidRandomSource();
      final first = Uint8List(12);
      final second = Uint8List(12);
      source.fillBytes(first);
      source.fillBytes(second);
      expect(first.length, 12);
      expect(second.length, 12);
      expect(first.any((byte) => byte != 0), isTrue);
      // A collision between two 96-bit CSPRNG outputs is negligible.
      expect(first, isNot(equals(second)));
    });

    test('PikaidEntropyException exposes its cause and message', () {
      final error = PikaidEntropyException('unavailable', cause: 'reason');
      expect(error.message, 'unavailable');
      expect(error.cause, 'reason');
      expect(error.toString(), contains('unavailable'));
    });
  });
}

int _nowSeconds() =>
    DateTime.now().toUtc().millisecondsSinceEpoch ~/
    Duration.millisecondsPerSecond;

final class _FixedSource implements PikaidRandomSource {
  _FixedSource(this.bytes);

  final List<int> bytes;
  int calls = 0;
  final List<int> destinationLengths = <int>[];

  @override
  void fillBytes(Uint8List destination) {
    calls++;
    destinationLengths.add(destination.length);
    if (bytes.length != destination.length) {
      throw StateError(
        'expected ${destination.length} bytes, got ${bytes.length}',
      );
    }
    destination.setAll(0, bytes);
  }
}

final class _SequenceSource implements PikaidRandomSource {
  int calls = 0;
  final List<int> destinationLengths = <int>[];

  @override
  void fillBytes(Uint8List destination) {
    final call = calls++;
    destinationLengths.add(destination.length);
    for (var i = 0; i < destination.length; i++) {
      destination[i] = (call * 12 + i + 1) & 0xff;
    }
  }
}

final class _ThrowingSource implements PikaidRandomSource {
  int calls = 0;

  @override
  void fillBytes(Uint8List destination) {
    calls++;
    throw const PikaidEntropyException('no entropy');
  }
}

final class _ErrorSource implements PikaidRandomSource {
  int calls = 0;

  @override
  void fillBytes(Uint8List destination) {
    calls++;
    throw StateError('unexpected platform failure');
  }
}
