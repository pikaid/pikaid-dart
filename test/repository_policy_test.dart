@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

/// Enforces repository-level guarantees that no Dart API can express.
///
/// The `.ai/` directory holds local agent reports and must never be tracked or
/// packaged. It was previously excluded by an overbroad `/.??/` pattern that
/// also governed every other dotted directory; that is a regression trap, so
/// the explicit rule and the "not tracked" property are asserted here.
void main() {
  group('.gitignore', () {
    final lines = File('.gitignore')
        .readAsLinesSync()
        .map((line) => line.trim())
        .toList();

    test('excludes the local .ai/ directory explicitly', () {
      expect(lines, contains('/.ai/'));
    });

    test('does not rely on an overbroad dot-directory pattern', () {
      expect(lines, isNot(contains('/.??/')));
      expect(lines, isNot(contains('.??/')));
    });

    test('keeps generated tool output ignored', () {
      for (final pattern in <String>[
        '.dart_tool/',
        'build/',
        'coverage/',
        'doc/api/',
      ]) {
        expect(lines, contains(pattern));
      }
    });
  });

  group('.gitattributes', () {
    final file = File('.gitattributes');
    final lines = file.readAsLinesSync().map((line) => line.trim()).toList();

    test('normalizes text files to LF', () {
      expect(lines, contains('* text=auto eol=lf'));
    });

    test('marks the generated conformance tables as generated', () {
      expect(
        lines,
        contains('test/support/conformance_cases.dart linguist-generated=true'),
      );
      expect(
        lines,
        contains('test/support/official_cases.dart linguist-generated=true'),
      );
    });
  });

  group('.pubignore', () {
    final lines = File('.pubignore')
        .readAsLinesSync()
        .map((line) => line.trim())
        .toList();

    test('keeps test-only official conformance tooling out of the package', () {
      for (final path in <String>[
        'tool/official_conformance_adapter.dart',
        'tool/generate_official_cases.py',
        'test/official_corpus_test.dart',
        'test/support/official_cases.dart',
      ]) {
        expect(lines, contains(path));
      }
    });

    test('keeps the local .ai/ workspace out of the package', () {
      expect(lines, contains('.ai/'));
    });
  });

  group('CI workflow', () {
    final workflow = File('.github/workflows/ci.yml').readAsStringSync();

    test('runs the official suite on push to every branch', () {
      expect(workflow, contains('push:'));
      // A branch filter here would leave pushed commits on non-main branches
      // without any hosted validation run.
      expect(workflow, isNot(contains('branches:')));
      expect(workflow, contains('official-conformance:'));
    });

    test('pins the immutable official suite commit', () {
      expect(
        workflow,
        contains('059780cc0e5b113443812720d95c630649bf3aa3'),
      );
    });

    test('verifies suite integrity and release expectations', () {
      for (final fragment in <String>[
        'sha256sum -c SHA256SUMS',
        '--expect-status OFFICIAL',
        '--expect-package-revision 1.0.0',
        '--expect-spec-revision 1.0.4',
        '--automated-only',
      ]) {
        expect(workflow, contains(fragment));
      }
    });

    test('contains no failure-suppression escape hatches', () {
      expect(workflow, isNot(contains('continue-on-error')));
      expect(workflow, isNot(contains('|| true')));
    });
  });

  group('tracked file set', () {
    test('.ai/ contains no tracked file', () {
      final result = Process.runSync('git', <String>['ls-files', '.ai']);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect((result.stdout as String).trim(), isEmpty);
    });

    test('local .ai/ files are ignored by git', () {
      final result = Process.runSync(
        'git',
        <String>['check-ignore', '-q', '.ai/reports/probe.md'],
      );
      expect(result.exitCode, 0,
          reason: '.ai/reports/probe.md must be ignored');
    });

    test('published library and test files are not ignored', () {
      for (final path in <String>[
        'lib/pikaid.dart',
        'lib/src/pikaid.dart',
        'test/conformance_matrix_test.dart',
      ]) {
        final result = Process.runSync('git', <String>[
          'check-ignore',
          '-q',
          path,
        ]);
        expect(result.exitCode, 1, reason: '$path must not be ignored');
      }
    });
  });
}
