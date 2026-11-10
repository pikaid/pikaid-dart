@TestOn('vm')
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:pikaid/pikaid.dart';
import 'package:test/test.dart';

import 'support/api_parity.dart';

/// Verifies the public API against the operations of specification 1.0.4.
///
/// Every entry in [apiParityMap] is exercised through the exported
/// `package:pikaid/pikaid.dart` surface. The map is also checked for
/// completeness against the declarations in `lib/src/pikaid.dart`, so a new
/// public member cannot be added without a parity entry, and the README API
/// table cannot drift away from the map.
void main() {
  final source = File('lib/src/pikaid.dart').readAsStringSync();
  final library = File('lib/pikaid.dart').readAsStringSync();
  final readme = File('README.md').readAsStringSync();

  group('API parity map', () {
    test('pins the exact public member set of Pikaid', () {
      final extracted = extractPublicPikaidMembers(source);
      expect(
        extracted,
        equals(pinnedPikaidPublicMembers),
        reason: 'A public member was added, removed or renamed. Update '
            'pinnedPikaidPublicMembers and add a parity entry.',
      );
    });

    test('maps every public member to at least one entrypoint', () {
      for (final member in pinnedPikaidPublicMembers) {
        final coverage = apiParityMap.where(
          (entry) => _mentionsName(entry.dartEntrypoint, member),
        );
        expect(
          coverage,
          isNotEmpty,
          reason: 'Public member "$member" is not in the API parity map.',
        );
      }
    });

    test('names every operation once', () {
      final operations = apiParityMap
          .map((entry) => '${entry.specSection} ${entry.specOperation}')
          .toList();
      expect(operations.toSet(), hasLength(operations.length));
    });

    test('attributes every entry to a normative section', () {
      for (final entry in apiParityMap) {
        expect(
            entry.specSection,
            matches(RegExp(r'^§\d+(\.\d+| rule \d+)?'
                r'(, §\d+(\.\d+| rule \d+)?)*$')));
        expect(entry.specOperation.trim(), isNotEmpty);
        expect(entry.dartEntrypoint.trim(), isNotEmpty);
      }
    });

    test('exercises every mapped public entrypoint', () {
      for (final entry in apiParityMap) {
        expect(
          entry.verify,
          returnsNormally,
          reason: '${entry.specSection} ${entry.specOperation} via '
              '${entry.dartEntrypoint}',
        );
      }
    });

    test('documents every mapped API row in README', () {
      for (final entry in apiParityMap) {
        final row = entry.readmeRow;
        if (row != null) {
          expect(
            readme,
            contains(row),
            reason: 'README is missing the row for ${entry.dartEntrypoint}.',
          );
        }
      }
      for (final constant in <String>[
        'Pikaid.stringLength',
        'Pikaid.binaryLength',
        'Pikaid.timestampLength',
        'Pikaid.randomnessLength',
        'Pikaid.randomnessBytes',
        'Pikaid.maxTimestamp',
      ]) {
        expect(readme, contains(constant));
      }
    });

    test('README audits the pinned specification revision', () {
      expect(readme, contains('specification revision 1.0.4'));
      expect(readme, contains('17014d76f568c3ac9f9ce2927c1a018fdbc36d1d'));
    });
  });

  group('public library surface', () {
    test('exports exactly the audited symbols', () {
      final exports = <String>[];
      final statements = RegExp(
        r"^export '([^']+)'\s+show\s+([^;]+);",
        multiLine: true,
      ).allMatches(library);
      for (final statement in statements) {
        final source = statement.group(1)!;
        for (final symbol in statement.group(2)!.split(',')) {
          exports.add('$source → ${symbol.trim()}');
        }
      }
      expect(exports, hasLength(4));
      expect(
        exports,
        unorderedEquals(<String>[
          'src/pikaid.dart → Pikaid',
          'src/pikaid_entropy_exception.dart → PikaidEntropyException',
          'src/random_source.dart → PikaidRandomSource',
          'src/random_source.dart → SecurePikaidRandomSource',
        ]),
      );
    });

    test('every exported symbol is covered by the parity map', () {
      for (final symbol in <String>[
        'Pikaid',
        'PikaidEntropyException',
        'PikaidRandomSource',
        'SecurePikaidRandomSource',
      ]) {
        expect(
          apiParityMap
              .any((entry) => _mentionsName(entry.dartEntrypoint, symbol)),
          isTrue,
          reason: 'Exported symbol $symbol is not mapped.',
        );
      }
    });

    test('the documented entrypoint works from a clean import', () {
      final zero = Pikaid.generateAt(
        1700000000,
        randomSource: _ZeroSource(),
      );
      expect(zero.toString(), '0s44we80000000000000000000');
      expect(Pikaid.parse(zero.toString()), zero);
    });
  });
}

/// Whether [text] mentions the identifier [name] as a whole token.
bool _mentionsName(String text, String name) => RegExp(
      '(?<![A-Za-z0-9_])${RegExp.escape(name)}(?![A-Za-z0-9_])',
    ).hasMatch(text);

final class _ZeroSource implements PikaidRandomSource {
  @override
  void fillBytes(Uint8List destination) =>
      destination.fillRange(0, destination.length, 0);
}
