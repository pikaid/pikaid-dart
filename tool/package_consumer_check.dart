// Verifies that the staged publish inventory works as an external dependency.
//
// The staged directory is treated as an immutable local package: a throwaway
// application outside the repository depends on it by path, resolves its own
// dependencies (there must be none), analyzes cleanly, and exercises the public
// API at runtime.
//
// Usage: dart run tool/package_consumer_check.dart build/package

import 'dart:io';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    _fail('Usage: dart run tool/package_consumer_check.dart <staged-package>');
  }
  final package = Directory(arguments.single).absolute;
  if (!File('${package.path}/pubspec.yaml').existsSync() ||
      !File('${package.path}/lib/pikaid.dart').existsSync()) {
    _fail('${package.path} is not a staged pikaid package.');
  }

  final consumer = Directory.systemTemp.createTempSync('pikaid_consumer_');
  try {
    File('${consumer.path}/pubspec.yaml').writeAsStringSync('''
name: pikaid_consumer_check
publish_to: none

environment:
  sdk: ^3.6.0

dependencies:
  pikaid:
    path: ${package.path}
''');
    final program = File('${consumer.path}/bin/main.dart')
      ..parent.createSync(recursive: true);
    program.writeAsStringSync(_consumerProgram);

    await _run(consumer, const ['pub', 'get']);
    final resolution = await _run(consumer, const ['pub', 'deps', '--json']);
    _require(
      resolution.stdout.toString().contains('"pikaid"'),
      'Resolved dependency graph does not contain pikaid.',
    );
    await _run(consumer, const ['analyze', '--fatal-infos']);
    final run = await _run(consumer, const ['run', 'bin/main.dart']);
    _require(
      run.stdout.toString().contains('CONSUMER_OK'),
      'Consumer program did not report success.',
    );
  } finally {
    consumer.deleteSync(recursive: true);
  }

  stdout.writeln('External consumer check passed against ${package.path}');
}

Future<ProcessResult> _run(
    Directory workingDirectory, List<String> args) async {
  stdout.writeln('> dart ${args.join(' ')}');
  final result = await Process.run(
    Platform.resolvedExecutable,
    args,
    workingDirectory: workingDirectory.path,
    runInShell: false,
  );
  if (result.stdout.toString().isNotEmpty) {
    stdout.write(result.stdout);
  }
  if (result.stderr.toString().isNotEmpty) {
    stderr.write(result.stderr);
  }
  if (result.exitCode != 0) {
    _fail('dart ${args.join(' ')} failed with exit ${result.exitCode}.');
  }
  return result;
}

void _require(bool condition, String message) {
  if (!condition) {
    _fail(message);
  }
}

Never _fail(String message) {
  stderr.writeln(message);
  exitCode = 1;
  exit(1);
}

const _consumerProgram = r'''
import 'dart:typed_data';

import 'package:pikaid/pikaid.dart';

void main() {
  void check(bool condition, String name) {
    if (!condition) {
      throw StateError('failed: $name');
    }
  }

  check(Pikaid.stringLength == 26, 'string length');
  check(Pikaid.binaryLength == 17, 'binary length');
  check(Pikaid.maxTimestamp == 78364164095, 'max timestamp');

  // Text and binary round trips through the public API.
  final id = Pikaid.generate();
  final text = id.toString();
  check(Pikaid.parse(text) == id, 'text parse round trip');
  check(Pikaid.tryParse(text) == id, 'tryParse round trip');
  check(Pikaid.isValid(text), 'isValid');
  check(Pikaid.isWellFormed(text), 'isWellFormed');

  final bytes = id.toBinary();
  check(bytes.length == 17, 'binary length');
  check(Pikaid.fromBinary(bytes) == id, 'binary round trip');
  check(id.randomness.length == 12, 'randomness length');
  check(id.randomnessHex.length == 24, 'randomness hex length');
  check(id.timestampUtc.isUtc, 'timestamp is UTC');

  // Mutating the returned buffers must not affect the value.
  bytes[0] ^= 0xFF;
  check(Pikaid.fromBinary(id.toBinary()) == id, 'binary output is a copy');
  final randomness = Uint8List.fromList(
    List<int>.generate(12, (index) => index + 1),
  );
  final copyProbe = Pikaid.fromComponents(
    timestamp: 7,
    randomness: randomness,
  );
  randomness.fillRange(0, randomness.length, 0);
  check(copyProbe.randomnessHex == '0102030405060708090a0b0c',
      'components copy randomness');

  var randomnessIsUnmodifiable = false;
  try {
    id.randomness[0] = 0xFF;
  } on UnsupportedError {
    randomnessIsUnmodifiable = true;
  }
  check(randomnessIsUnmodifiable, 'randomness view is unmodifiable');

  // Boundary values.
  final maximum = Pikaid.fromComponents(
    timestamp: Pikaid.maxTimestamp,
    randomness: Uint8List.fromList(List<int>.filled(12, 255)),
  );
  check(maximum.toString() == 'zzzzzzz7oiylpimjg5u2ca1ypr', 'maximum value');
  check(Pikaid.fromBinary(maximum.toBinary()) == maximum, 'maximum round trip');

  // Strict rejection: no trimming, coercion, truncation or wrapping.
  for (final invalid in <String>[
    '',
    '0000001000000000000000000',
    '000000100000000000000000001',
    '0000001000000000000000000Z',
    ' 00000100000000000000000001',
    '00000010000000000000000001 ',
    '0000000zzzzzzzzzzzzzzzzzzz',
    '00000007oiylpimjg5u2ca1yps',
    '00000000000000\u0000',
  ]) {
    var threw = false;
    try {
      Pikaid.parse(invalid);
    } on FormatException {
      threw = true;
    }
    check(threw, 'parse rejects: $invalid');
    check(Pikaid.tryParse(invalid) == null, 'tryParse rejects: $invalid');
    check(!Pikaid.isValid(invalid), 'isValid rejects: $invalid');
  }

  // Shape-only predicate is documented as weaker than semantic validity.
  check(Pikaid.isWellFormed('0000000zzzzzzzzzzzzzzzzzzz'),
      'shape-only predicate accepts overflow');
  check(!Pikaid.isValid('0000000zzzzzzzzzzzzzzzzzzz'),
      'semantic predicate rejects overflow');

  // Ordering is chronological, then unsigned randomness.
  final low = Pikaid.fromComponents(
    timestamp: 1,
    randomness: Uint8List.fromList(List<int>.filled(12, 0)),
  );
  final high = Pikaid.fromComponents(
    timestamp: 1,
    randomness: Uint8List.fromList(List<int>.filled(12, 255)),
  );
  check(low.compareTo(high) < 0, 'same-second ordering');
  check(low.toString().compareTo(high.toString()) < 0,
      'text ordering matches compareTo');

  // Generation with injected entropy is reproducible.
  final deterministic = Pikaid.generateAt(
    1700000000,
    randomSource: _ZeroSource(),
  );
  check(deterministic.toString() == '0s44we80000000000000000000',
      'deterministic generation');

  print('CONSUMER_OK');
}

final class _ZeroSource implements PikaidRandomSource {
  @override
  void fillBytes(Uint8List destination) =>
      destination.fillRange(0, destination.length, 0);
}
''';
