/// A deterministic [PikaidRandomSource] for tests.
///
/// This is **not** a cryptographic source and must never be used to generate
/// identifiers outside a test: it is a 32-bit xorshift generator so the same
/// seed produces the same identifier on the VM, dart2js and dart2wasm.
library;

import 'dart:typed_data';

import 'package:pikaid/pikaid.dart';

/// A reproducible byte source driven by a 32-bit xorshift state.
final class DeterministicRandomSource implements PikaidRandomSource {
  /// Creates a source from [seed]; a zero seed is replaced by a fixed constant
  /// because xorshift32 cannot escape the all-zero state.
  DeterministicRandomSource([int seed = 0x9e3779b9])
      : _state = seed == 0 ? 0x9e3779b9 : seed & 0xffffffff {
    if (seed != 0 && _state == 0) {
      _state = 0x9e3779b9;
    }
  }

  int _state;

  @override
  void fillBytes(Uint8List destination) {
    for (var i = 0; i < destination.length; i++) {
      destination[i] = _nextByte();
    }
  }

  int _nextByte() {
    var x = _state;
    x ^= (x << 13) & 0xffffffff;
    x ^= x >> 17;
    x ^= (x << 5) & 0xffffffff;
    _state = x & 0xffffffff;
    return _state & 0xff;
  }
}
