import 'dart:convert';
import 'dart:io';

/// One valid vector from the shared conformance fixture.
typedef ValidVector = ({
  String name,
  int timestamp,
  String entropyHex,
  String id,
  String binHex,
});

/// One invalid text vector from the shared conformance fixture.
typedef InvalidStringVector = ({String name, String id});

/// One invalid binary vector from the shared conformance fixture.
typedef InvalidBinaryVector = ({String name, String binHex});

/// The parsed shared conformance fixture.
typedef OfficialVectors = ({
  Map<String, Object?> meta,
  List<ValidVector> valid,
  List<InvalidStringVector> invalidStrings,
  List<InvalidBinaryVector> invalidBinary,
});

/// Loads `test/fixtures/pikaid-v1.json`, copied from `pikaid/pikaid-php`
/// v1.2.0 (commit `e3f843edeb5157a5d2d25196cac0d69580810a95`).
///
/// The loader fails loudly on any shape mismatch so a corrupted fixture can
/// never silently turn into a smaller test suite.
OfficialVectors loadOfficialVectors([
  String path = 'test/fixtures/pikaid-v1.json',
]) {
  final file = File(path);
  if (!file.existsSync()) {
    throw StateError('conformance fixture not found at ${file.absolute.path}');
  }
  final Object? decoded = jsonDecode(file.readAsStringSync());
  final root = _map(decoded, 'fixture root');
  final validJson = _list(root['valid'], 'valid');
  final invalidJson = _map(root['invalid'], 'invalid');

  return (
    meta: _map(root['meta'], 'meta'),
    valid: [
      for (final entry in validJson) _validVector(_map(entry, 'valid[]')),
    ],
    invalidStrings: [
      for (final entry in _list(invalidJson['string'], 'invalid.string'))
        (
          name: _string(_map(entry, 'invalid.string[]'), 'name'),
          id: _string(_map(entry, 'invalid.string[]'), 'id'),
        ),
    ],
    invalidBinary: [
      for (final entry in _list(invalidJson['binary'], 'invalid.binary'))
        (
          name: _string(_map(entry, 'invalid.binary[]'), 'name'),
          binHex: _string(_map(entry, 'invalid.binary[]'), 'bin_hex'),
        ),
    ],
  );
}

ValidVector _validVector(Map<String, Object?> map) => (
      name: _string(map, 'name'),
      timestamp: _int(map, 'timestamp'),
      entropyHex: _string(map, 'entropy_hex'),
      id: _string(map, 'id'),
      binHex: _string(map, 'bin_hex'),
    );

Map<String, Object?> _map(Object? value, String context) {
  if (value is Map<String, Object?>) {
    return value;
  }
  throw StateError('$context must be a JSON object');
}

List<Object?> _list(Object? value, String context) {
  if (value is List<Object?>) {
    return value;
  }
  throw StateError('$context must be a JSON array');
}

String _string(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is String) {
    return value;
  }
  throw StateError('"$key" must be a string');
}

int _int(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is int) {
    return value;
  }
  throw StateError('"$key" must be an integer');
}
