// Stages exactly the file set that `dart pub publish` would upload.
//
// `dart pub` has no `pack` subcommand, so the publish inventory cannot be
// obtained as a tarball. Instead this tool asks the SDK for the authoritative
// inventory (`dart pub publish --dry-run`), copies only those files to a
// target directory, and then re-publishes the staged copy in a temporary
// directory to prove that the staged set reproduces the identical inventory.
//
// Usage: dart run tool/stage_package.dart [target-directory]
//
// Exits non-zero on any mismatch, missing file, or forbidden archive entry.

import 'dart:io';

/// Paths that must never appear in a published archive.
const _forbiddenPrefixes = <String>[
  '.ai/',
  '.git/',
  '.dart_tool/',
  '.idea/',
  'build/',
  'coverage/',
  'doc/api/',
  'pubspec.lock',
  'opencode.jsonc',
];

/// Files that the package cannot work without.
const _requiredEntries = <String>[
  'pubspec.yaml',
  'README.md',
  'CHANGELOG.md',
  'LICENSE',
  'lib/pikaid.dart',
  'example/main.dart',
];

Future<void> main(List<String> arguments) async {
  final target = arguments.isEmpty ? 'build/package' : arguments.single;
  if (arguments.length > 1) {
    _fail('Usage: dart run tool/stage_package.dart [target-directory]');
  }

  final repository = Directory.current;
  final inventory = await _publishInventory(repository);
  _validateInventory(inventory);

  final targetDirectory = Directory(target);
  if (targetDirectory.existsSync()) {
    targetDirectory.deleteSync(recursive: true);
  }

  for (final path in inventory) {
    final source = File(path);
    if (!source.existsSync()) {
      _fail('Publish inventory lists a missing file: $path');
    }
    final destination = File('$target/$path')
      ..parent.createSync(recursive: true);
    destination.writeAsBytesSync(source.readAsBytesSync());
  }

  final stagedFiles = targetDirectory
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .map((file) => _normalize(file.path, targetDirectory.path))
      .toList()
    ..sort();
  final expected = [...inventory]..sort();
  if (!_sameList(stagedFiles, expected)) {
    _fail('Staged file set differs from the publish inventory.');
  }

  // Re-publish a copy of the staged set. `pub` writes `.dart_tool/` while
  // resolving, so the verification copy must live outside the staged tree.
  final verification = Directory.systemTemp.createTempSync('pikaid_staged_');
  try {
    await _copyTree(targetDirectory, verification);
    final republished = await _publishInventory(verification);
    final left = [...inventory]..sort();
    final right = [...republished]..sort();
    if (!_sameList(left, right)) {
      _fail('Re-publishing the staged set produced a different inventory:\n'
          '  only in original: ${left.where((p) => !right.contains(p)).toList()}\n'
          '  only in staged:   ${right.where((p) => !left.contains(p)).toList()}');
    }
  } finally {
    verification.deleteSync(recursive: true);
  }

  stdout.writeln('Staged ${inventory.length} files in $target');
  for (final path in inventory) {
    stdout.writeln('  $path');
  }
  stdout.writeln('Staged inventory matches the publish inventory exactly.');
}

Future<List<String>> _publishInventory(Directory workingDirectory) async {
  final result = await Process.run(
    Platform.resolvedExecutable,
    const ['pub', 'publish', '--dry-run'],
    workingDirectory: workingDirectory.path,
    runInShell: false,
  );
  final output = '${result.stdout}${result.stderr}';
  if (result.exitCode != 0) {
    stdout.writeln(output);
    _fail('dart pub publish --dry-run failed in '
        '${workingDirectory.path} (exit ${result.exitCode}).');
  }
  final inventory = parseInventory(output);
  if (inventory.isEmpty) {
    stdout.writeln(output);
    _fail('Could not parse a publish inventory from dart pub output.');
  }
  return inventory;
}

/// Extracts the file paths from the tree rendered by `dart pub publish`.
///
/// `dart pub` prints a size suffix for files (`(1 KB)`, `(<1 KB)`) and none for
/// directories, so entries without a size are treated as directory levels.
List<String> parseInventory(String output) {
  final entries = <String>[];
  final stack = <String>[];
  final linePattern = RegExp(r'^((?:│   |    )*)(?:├── |└── )(.*)$');
  final sizePattern = RegExp(r' \((?:<\s*)?\d+(?:\.\d+)?\s*[KMGT]?B\)$');

  for (final line in output.split('\n')) {
    final match = linePattern.firstMatch(line);
    if (match == null) {
      continue;
    }
    final depth = match.group(1)!.length ~/ 4;
    final label = match.group(2)!;
    final isFile = sizePattern.hasMatch(label);
    final name = label.replaceFirst(sizePattern, '');
    if (depth > stack.length) {
      // A file entry can never appear one level below its own directory.
      continue;
    }
    stack.removeRange(depth, stack.length);
    stack.add(name);
    if (isFile) {
      entries.add(stack.join('/'));
      stack.removeLast();
    }
  }
  return entries;
}

void _validateInventory(List<String> inventory) {
  for (final required in _requiredEntries) {
    if (!inventory.contains(required)) {
      _fail('Publish inventory is missing required entry: $required');
    }
  }
  for (final path in inventory) {
    for (final forbidden in _forbiddenPrefixes) {
      if (path == forbidden || path.startsWith(forbidden)) {
        _fail('Publish inventory contains forbidden entry: $path');
      }
    }
  }
  if (inventory.toSet().length != inventory.length) {
    _fail('Publish inventory contains duplicate entries.');
  }
}

Future<void> _copyTree(Directory source, Directory destination) async {
  await for (final entity in source.list(
    recursive: true,
    followLinks: false,
  )) {
    final relative = _normalize(entity.path, source.path);
    if (entity is Directory) {
      Directory('${destination.path}/$relative').createSync(recursive: true);
    } else if (entity is File) {
      final copy = File('${destination.path}/$relative')
        ..parent.createSync(recursive: true);
      copy.writeAsBytesSync(entity.readAsBytesSync());
    }
  }
}

String _normalize(String path, String root) {
  final normalizedRoot = root.endsWith('/') ? root : '$root/';
  final normalized = path.replaceAll(r'\', '/');
  if (normalized.startsWith(normalizedRoot)) {
    return normalized.substring(normalizedRoot.length);
  }
  if (normalized.startsWith('$root/')) {
    return normalized.substring(root.length + 1);
  }
  return normalized;
}

bool _sameList(List<String> left, List<String> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

Never _fail(String message) {
  stderr.writeln(message);
  exitCode = 1;
  exit(1);
}
