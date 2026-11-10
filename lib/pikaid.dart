/// Official Dart implementation of [pikaid][spec]: compact, chronologically
/// sortable identifiers.
///
/// A pikaid is exactly 26 lowercase Base36 characters — a 7-character
/// whole-second Unix timestamp followed by 19 characters holding 96 bits of
/// cryptographic randomness — with an equivalent 17-byte binary form. The
/// identifier format is immutable and unversioned.
///
/// ```dart
/// import 'package:pikaid/pikaid.dart';
///
/// void main() {
///   final id = Pikaid.generate();
///   print(id); // e.g. 0s44we8002loz3po6mcf6vsn23
///   print(id.timestamp); // whole Unix seconds
///   print(id.randomnessHex); // 24 lowercase hex characters
///   print(id.toBinary().length); // 17
///   print(Pikaid.parse(id.toString()) == id); // true
/// }
/// ```
///
/// See the `README.md` for ordering, storage and security notes.
///
/// [spec]: https://github.com/pikaid/pikaid-specs/tree/v1.0.4
library;

export 'src/pikaid.dart' show Pikaid;
export 'src/pikaid_entropy_exception.dart' show PikaidEntropyException;
export 'src/random_source.dart'
    show PikaidRandomSource, SecurePikaidRandomSource;
