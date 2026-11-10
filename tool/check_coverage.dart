// Reads an LCOV report and fails when statement coverage of `lib/` is below
// the threshold required for the official implementation.
//
// Usage:
//   dart test --coverage=coverage
//   dart run coverage:format_coverage --lcov --in=coverage \
//       --out=coverage/lcov.info --report-on=lib
//   dart run tool/check_coverage.dart coverage/lcov.info
import 'dart:io';

const double minimumPercent = 90.0;

void main(List<String> arguments) {
  final path = arguments.isEmpty ? 'coverage/lcov.info' : arguments.first;
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('coverage report not found: $path');
    exitCode = 2;
    return;
  }

  var linesFound = 0;
  var linesHit = 0;
  final uncovered = <String>[];
  var currentFile = '';

  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      currentFile = line.substring(3);
    } else if (line.startsWith('LF:')) {
      linesFound += int.parse(line.substring(3));
    } else if (line.startsWith('LH:')) {
      linesHit += int.parse(line.substring(3));
    } else if (line.startsWith('DA:')) {
      final parts = line.substring(3).split(',');
      final lineNumber = parts[0];
      final hits = int.parse(parts[1]);
      if (hits == 0) {
        uncovered.add('$currentFile:$lineNumber');
      }
    }
  }

  if (linesFound == 0) {
    stderr.writeln('coverage report contains no line records: $path');
    exitCode = 2;
    return;
  }

  final percent = 100 * linesHit / linesFound;
  stdout.writeln(
    'statement coverage: ${percent.toStringAsFixed(2)}% '
    '($linesHit/$linesFound lines)',
  );
  if (uncovered.isNotEmpty) {
    stdout.writeln('uncovered lines: ${uncovered.join(', ')}');
  }
  if (percent < minimumPercent) {
    stderr.writeln(
      'coverage ${percent.toStringAsFixed(2)}% is below the required '
      '${minimumPercent.toStringAsFixed(0)}%',
    );
    exitCode = 1;
  }
}
