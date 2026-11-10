@TestOn('vm')
library;

import 'dart:typed_data';

import 'package:pikaid/pikaid.dart';
import 'package:test/test.dart';

import 'support/hex.dart';

void main() {
  group('cross-representation ordering', () {
    test('text order equals compareTo for fixed values', () {
      final ids = <Pikaid>[
        Pikaid.parse('00000000000000000000000000'),
        Pikaid.parse('00000010000000000000000001'),
        Pikaid.parse('0s44we8002loz3po6mcf6vsn23'),
        Pikaid.parse('zzzzzzz0000000000000000000'),
        Pikaid.parse('zzzzzzz7oiylpimjg5u2ca1ypr'),
      ];
      for (var i = 0; i < ids.length; i++) {
        for (var j = 0; j < ids.length; j++) {
          expect(
            _sign(ids[i].toString().compareTo(ids[j].toString())),
            _sign(ids[i].compareTo(ids[j])),
            reason: '${ids[i]} vs ${ids[j]}',
          );
        }
      }
    });

    test('binary order equals compareTo for fixed values', () {
      final ids = <Pikaid>[
        Pikaid.parse('00000000000000000000000000'),
        Pikaid.parse('00000010000000000000000001'),
        Pikaid.parse('0s44we8002loz3po6mcf6vsn23'),
        Pikaid.parse('zzzzzzz0000000000000000000'),
        Pikaid.parse('zzzzzzz7oiylpimjg5u2ca1ypr'),
      ];
      for (final left in ids) {
        for (final right in ids) {
          expect(
            _sign(_compareBytes(left.toBinary(), right.toBinary())),
            _sign(left.compareTo(right)),
            reason: '$left vs $right',
          );
        }
      }
    });

    test('randomized pairs agree across all three orderings', () {
      final random = _XorShift(0x0DDBAA);
      for (var i = 0; i < 300; i++) {
        final a = _randomId(random);
        final b = _randomId(random);
        final byValue = _sign(a.compareTo(b));
        final byText = _sign(a.toString().compareTo(b.toString()));
        final byBinary = _sign(_compareBytes(a.toBinary(), b.toBinary()));
        expect(byText, byValue, reason: 'case $i text');
        expect(byBinary, byValue, reason: 'case $i binary');
      }
    });

    test('a different-second timestamp dominates any random suffix', () {
      final early = Pikaid.fromComponents(
        timestamp: 100,
        randomness: List<int>.filled(12, 0xff),
      );
      final late = Pikaid.fromComponents(
        timestamp: 101,
        randomness: List<int>.filled(12, 0),
      );
      expect(early.compareTo(late), lessThan(0));
      expect(early.toString().compareTo(late.toString()), lessThan(0));
      expect(
        _compareBytes(early.toBinary(), late.toBinary()),
        lessThan(0),
      );
    });

    test('within one second, entropy determines the order', () {
      final low = Pikaid.fromComponents(
        timestamp: 42,
        randomness: hexToBytes('000000000000000000000000'),
      );
      final middle = Pikaid.fromComponents(
        timestamp: 42,
        randomness: hexToBytes('800000000000000000000000'),
      );
      final high = Pikaid.fromComponents(
        timestamp: 42,
        randomness: hexToBytes('ffffffffffffffffffffffff'),
      );
      final sorted = <Pikaid>[high, low, middle]..sort();
      expect(sorted, <Pikaid>[low, middle, high]);
      expect(low.toString().compareTo(middle.toString()), lessThan(0));
      expect(middle.toString().compareTo(high.toString()), lessThan(0));
    });
  });

  group('non-monotonic generation within a second', () {
    test('later generation can sort before earlier generation', () {
      // A decreasing entropy source makes the non-guarantee observable.
      final source = _DecreasingSource();
      final first = Pikaid.generateAt(1234, randomSource: source);
      final second = Pikaid.generateAt(1234, randomSource: source);
      final third = Pikaid.generateAt(1234, randomSource: source);

      expect(first.timestamp, second.timestamp);
      expect(second.timestamp, third.timestamp);
      expect(second.compareTo(first), lessThan(0));
      expect(third.compareTo(second), lessThan(0));
      expect(third.toString().compareTo(first.toString()), lessThan(0));
      expect(
        Pikaid.fromBinary(second.toBinary()).compareTo(first),
        lessThan(0),
      );
    });
  });

  group('sorting collections', () {
    test('sorting text and binary forms gives the same order', () {
      final random = _XorShift(0xBEEF);
      final ids = <Pikaid>[
        for (var i = 0; i < 100; i++) _randomId(random),
      ];
      final byValue = [...ids]..sort();
      final byText = [...ids]
        ..sort((a, b) => a.toString().compareTo(b.toString()));
      final byBinary = [...ids]
        ..sort((a, b) => _compareBytes(a.toBinary(), b.toBinary()));

      expect(
        byText.map((id) => id.toString()),
        byValue.map((id) => id.toString()),
      );
      expect(
        byBinary.map((id) => id.toString()),
        byValue.map((id) => id.toString()),
      );
    });

    test('ordering is stable for equal values', () {
      final a = Pikaid.parse('0s44we8002loz3po6mcf6vsn23');
      final b = Pikaid.parse('0s44we8002loz3po6mcf6vsn23');
      expect(a.compareTo(b), 0);
      expect(a.toString().compareTo(b.toString()), 0);
      expect(_compareBytes(a.toBinary(), b.toBinary()), 0);
    });
  });
}

int _sign(int value) => value.sign;

int _compareBytes(List<int> left, List<int> right) {
  for (var i = 0; i < left.length; i++) {
    final difference = left[i] - right[i];
    if (difference != 0) {
      return difference.sign;
    }
  }
  return left.length.compareTo(right.length);
}

Pikaid _randomId(_XorShift random) {
  final timestamp = _nextInt(random, Pikaid.maxTimestamp + 1);
  final entropy = Uint8List(12);
  for (var i = 0; i < entropy.length; i++) {
    entropy[i] = _nextInt(random, 256);
  }
  return Pikaid.fromComponents(timestamp: timestamp, randomness: entropy);
}

final class _DecreasingSource implements PikaidRandomSource {
  int _next = 0xff;

  @override
  void fillBytes(Uint8List destination) {
    for (var i = 0; i < destination.length; i++) {
      destination[i] = _next;
      _next = (_next - 1) & 0xff;
    }
  }
}

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
