/// Thrown when generation cannot obtain cryptographically secure randomness.
///
/// pikaid generation fails closed: it never falls back to a non-cryptographic
/// generator, a counter, a hash of predictable input, or a partially filled
/// entropy buffer. Callers that catch this error should surface it rather than
/// retrying with a weaker source.
final class PikaidEntropyException implements Exception {
  /// Creates an entropy failure with a human-readable [message] and the
  /// underlying [cause], when one is available.
  const PikaidEntropyException(this.message, {this.cause});

  /// A human-readable description of the failure.
  final String message;

  /// The underlying error, if the platform or custom source raised one.
  final Object? cause;

  @override
  String toString() => 'PikaidEntropyException: $message';
}
