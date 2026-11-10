import 'dart:math';
import 'dart:typed_data';

import 'pikaid_entropy_exception.dart';

/// A source of cryptographically secure random bytes.
///
/// {@template pikaid_random_source_contract}
/// Implementations must fill the whole destination buffer with independent,
/// uniformly distributed random bytes obtained from a cryptographically secure
/// generator, or throw. A source that cannot provide secure randomness must
/// never return partially filled or predictable data.
/// {@endtemplate}
///
/// The default implementation, [SecurePikaidRandomSource], uses
/// `dart:math`'s [Random.secure]. Injecting a [PikaidRandomSource] exists for
/// tests and for platforms that provide their own operating-system CSPRNG; it
/// must not be used to weaken entropy in production.
abstract interface class PikaidRandomSource {
  /// {@macro pikaid_random_source_contract}
  void fillBytes(Uint8List destination);
}

/// The default [PikaidRandomSource], backed by [Random.secure].
///
/// On the Dart VM this reads from the operating-system CSPRNG (`/dev/urandom`,
/// `getrandom(2)`, `arc4random_buf`, or `BCryptGenRandom`, depending on the
/// platform). On platforms without a secure source, `Random.secure` throws an
/// [UnsupportedError], which this class converts into a
/// [PikaidEntropyException].
final class SecurePikaidRandomSource implements PikaidRandomSource {
  /// Creates a source backed by [Random.secure].
  const SecurePikaidRandomSource();

  @override
  void fillBytes(Uint8List destination) {
    final Random random;
    try {
      random = Random.secure();
    } catch (error) {
      throw PikaidEntropyException(
        'no cryptographically secure random source is available on this '
        'platform',
        cause: error,
      );
    }
    try {
      for (var i = 0; i < destination.length; i++) {
        destination[i] = random.nextInt(256);
      }
    } catch (error) {
      // Fail closed: never let partially filled entropy escape.
      destination.fillRange(0, destination.length, 0);
      throw PikaidEntropyException(
        'the cryptographically secure random source failed while generating '
        'entropy',
        cause: error,
      );
    }
  }
}
