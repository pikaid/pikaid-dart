import 'package:pikaid/pikaid.dart';

/// Generates a pikaid and exercises its documented public API.
///
/// Run with `dart run example/main.dart`.
void main() {
  // Generate from the current UTC second and a CSPRNG.
  final id = Pikaid.generate();
  print('id:            $id');
  print(
      'timestamp:     ${id.timestamp} (${id.timestampUtc.toIso8601String()})');
  print('randomness:    ${id.randomnessHex}');
  print('binary (hex):  ${_hex(id.toBinary())}');
  print('round trip ok: ${Pikaid.parse(id.toString()) == id}');

  // Deterministic generation for tests, fixtures and migrations.
  final fixed = Pikaid.generateAt(1700000000);
  print('fixed second:  $fixed');

  // Strict parsing and the shape-only predicate.
  print('valid:         ${Pikaid.isValid('00000000000000000000000000')}');
  print('invalid:       ${Pikaid.isValid('0000000ZZZZZZZZZZZZZZZZZZZ')}');
  print('well formed:   ${Pikaid.isWellFormed('0000000zzzzzzzzzzzzzzzzzzz')}');
  print('tryParse:      ${Pikaid.tryParse('not-a-pikaid')}');

  // Binary storage and comparison.
  final restored = Pikaid.fromBinary(id.toBinary());
  print('binary round trip: ${restored == id}');
  print('sorts before a later second: '
      '${Pikaid.generateAt(1700000001).compareTo(id)}');
}

String _hex(List<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
