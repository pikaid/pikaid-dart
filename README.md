<p align="center">
  <img src="https://raw.githubusercontent.com/pikaid/pikaid-specs/v1.0.4/logo.png" alt="pikaid" width="300" />
</p>

<p align="center">
  <strong>Small · Sortable · Secure IDs</strong>
</p>

# pikaid — Official Dart Implementation

[![Dart](https://img.shields.io/badge/Dart-%E2%89%A53.6-0175C2?logo=dart)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

The official Dart implementation of [pikaid](https://github.com/pikaid): compact,
chronologically sortable identifiers with 96 bits of cryptographic randomness.

A pikaid is exactly **26 lowercase Base36 characters** — a 7-character
whole-second Unix timestamp followed by 19 characters encoding 96 bits of
randomness — with an equivalent **17-byte binary representation**. The
identifier format is immutable and unversioned; specification revisions do not
change the identifiers.

## Status

The implementation, conformance suite and CI configuration in this repository
target [pikaid specification revision 1.0.4][spec] (commit
`17014d76f568c3ac9f9ce2927c1a018fdbc36d1d`). The package is **not yet
published on pub.dev**; install it from Git or from a local checkout. Version
1.0.0 is prepared for the first stable release once a public source repository
and pub.dev publishing credentials are available.

[spec]: https://github.com/pikaid/pikaid-specs/tree/v1.0.4

## Conformance status

This package is validated against the official cross-language conformance suite
at commit `059780cc0e5b113443812720d95c630649bf3aa3` (suite package revision
`1.0.0`, specification revision `1.0.4`, status `OFFICIAL`). The test-only
adapter `tool/official_conformance_adapter.dart` delegates every operation to
`package:pikaid/pikaid.dart`; all expected values come from the suite fixtures,
never from this package. The adapter is excluded from the published archive.

Automated conformance is not certification:

- `tools/run_adapter.py --automated-only` runs the automated cases and exits
  `0` when they pass. Its status is
  `AUTOMATED_PASS_AUDIT_NOT_PERFORMED`; it is **not** a conformance
  certification.
- A run without `--automated-only` exits `3`
  (`AUTOMATED_PASS_AUDIT_REQUIRED`) while the two manual CSPRNG security audits,
  `P-GENERATE-RNG-SOURCE` and `P-GENERATE-RNG-FAILURE`, have no recorded human
  evidence.
- Those two audits remain **outstanding** (`MANUAL_EVIDENCE_REQUIRED`) for this
  repository. No certification is claimed; only the automated runs in the
  pinned-suite CI job and the local audit reports have passed.

## Installation

Until the package is published, add a Git dependency:

```yaml
dependencies:
  pikaid:
    git:
      url: https://github.com/pikaid/pikaid-dart.git
      ref: main
```

or a path dependency for a local checkout:

```yaml
dependencies:
  pikaid:
    path: ../pikaid-dart
```

Then run `dart pub get`. The minimum supported SDK is Dart **3.6.0**.

## Quick start

```dart
import 'package:pikaid/pikaid.dart';

void main() {
  final id = Pikaid.generate();

  print(id);                     // e.g. 0s44we8002loz3po6mcf6vsn23
  print(id.timestamp);           // whole Unix seconds
  print(id.timestampUtc);        // DateTime in UTC, one-second precision
  print(id.randomnessHex);       // 24 lowercase hex characters
  print(id.toBinary().length);   // 17

  final parsed = Pikaid.parse(id.toString());
  print(parsed == id);           // true
}
```

`Pikaid` is an immutable value type. `toString()` always returns the canonical
26-character form, and `==`/`hashCode` compare the full timestamp and all 12
randomness bytes.

## Format

| Field      | Text offsets | Text width | Binary offsets | Binary width | Meaning                                   |
| ---------- | -----------: | ---------: | -------------: | -----------: | ----------------------------------------- |
| Timestamp  |         `0–6` |  7 chars   |          `0–4` |      5 bytes | Unix seconds since `1970-01-01T00:00:00Z` |
| Randomness |        `7–25` | 19 chars   |         `5–16` |     12 bytes | Uniform CSPRNG randomness (96 bits)       |
| **Total**  |       `0–25` |  **26**    |         `0–16` | **17 bytes** |                                           |

Both fields are unsigned, big-endian and left-zero-padded in the text form.
The alphabet is exactly `0123456789abcdefghijklmnopqrstuvwxyz`. Uppercase
letters, separators, prefixes, suffixes and checksums are not part of the
format.

Representable ranges:

- Timestamp: `0 .. 36^7 − 1` = `0 .. 78,364,164,095`
  (maximum `4453-04-05T15:21:35Z`).
- Randomness: `0 .. 2^96 − 1`.

Nineteen Base36 characters can encode values above `2^96 − 1`; such suffixes
are **invalid**, even though their length and alphabet are correct. Likewise, a
17-byte buffer whose timestamp exceeds `36^7 − 1` is invalid.

## Usage

### Parsing and validation

```dart
final id = Pikaid.parse('00000010000000000000000001');
assert(id.timestamp == 1);
assert(id.randomnessHex == '000000000000000000000001');

// Strict parsing: invalid input throws FormatException.
try {
  Pikaid.parse('0000000ZZZZZZZZZZZZZZZZZZZ');
} on FormatException catch (error) {
  print(error.message);
}

// Non-throwing alternatives.
print(Pikaid.tryParse('not-a-pikaid'));           // null
print(Pikaid.isValid('00000000000000000000000000')); // true
print(Pikaid.isValid('0000000zzzzzzzzzzzzzzzzzzz')); // false

// Shape-only check: length and alphabet, not semantic range.
print(Pikaid.isWellFormed('0000000zzzzzzzzzzzzzzzzzzz')); // true
```

`isWellFormed` deliberately checks only the shape (exactly 26 characters from
`[0-9a-z]`). A well-formed value is not necessarily valid; use `isValid` or
`parse` for full validation. Invalid input is never trimmed, lowercased,
padded or truncated.

### Binary representation

```dart
final id = Pikaid.fromComponents(
  timestamp: 1700000000,
  randomness: List<int>.filled(12, 0),
);

print(id);                        // 0s44we80000000000000000000
print(id.toBinary());             // 17 bytes
print(Pikaid.fromBinary(id.toBinary()) == id); // true
```

`toBinary()` returns a fresh, modifiable 17-byte `Uint8List`.
`Pikaid.fromBinary` copies its input, so later changes to the caller's buffer
cannot affect the value. `randomness` is exposed as an unmodifiable view.

Generation can also write the binary form directly:

```dart
final bytes = Pikaid.generateBinary();
final atFixedSecond = Pikaid.generateBinaryAt(1700000000);
```

### Explicit timestamps

```dart
final id = Pikaid.generateAt(1700000000);
```

Caller-supplied timestamps are still range-checked and randomness still comes
from a CSPRNG; entropy is never derived from the timestamp. This is intended for
tests, fixtures and migrations, not for replacing the current time in normal
generation.

### Deterministic values and custom random sources

`PikaidRandomSource` is injectable. Implementations must fill the entire buffer
with cryptographically secure bytes or throw; generation fails closed and never
falls back to a weaker source.

```dart
import 'dart:typed_data';
import 'package:pikaid/pikaid.dart';

final class ZeroRandomSource implements PikaidRandomSource {
  const ZeroRandomSource();

  @override
  void fillBytes(Uint8List destination) => destination.fillRange(0, destination.length, 0);
}

void main() {
  final id = Pikaid.generateAt(1700000000, randomSource: const ZeroRandomSource());
  print(id); // 0s44we80000000000000000000
}
```

Use a custom source only for tests or for a platform CSPRNG that is at least as
strong as `Random.secure()`. `SecurePikaidRandomSource` is the default and is
backed by `Random.secure()`.

## API

| Member | Description |
| ------ | ----------- |
| `Pikaid.generate({randomSource})` | Generate for the current UTC second. |
| `Pikaid.generateAt(timestamp, {randomSource})` | Generate with an explicit, range-checked timestamp. |
| `Pikaid.generateBinary({randomSource})` | Generate directly as 17 bytes. |
| `Pikaid.generateBinaryAt(timestamp, {randomSource})` | Generate 17 bytes with an explicit timestamp. |
| `Pikaid.fromComponents({timestamp, randomness})` | Rebuild from a timestamp and exactly 12 randomness bytes. |
| `Pikaid.parse(String)` | Strict text parsing; throws `FormatException`. |
| `Pikaid.tryParse(String)` | Strict text parsing; returns `null` on invalid input. |
| `Pikaid.isValid(String)` | Full semantic validity predicate. |
| `Pikaid.isWellFormed(String)` | Length and alphabet only. |
| `Pikaid.fromBinary(List<int>)` | Strict 17-byte decoding; throws `FormatException`. |
| `id.toBinary()` | Fresh 17-byte `Uint8List`. |
| `id.timestamp` | Whole Unix seconds in `0..maxTimestamp`. |
| `id.timestampUtc` | UTC `DateTime` with one-second precision. |
| `id.randomness` | Unmodifiable 12-byte view. |
| `id.randomnessHex` | 24 lowercase hexadecimal characters. |
| `id.compareTo(other)` | Timestamp first, then unsigned randomness bytes. |
| `id == other`, `id.hashCode` | Full value equality. |

Constants: `Pikaid.stringLength` (26), `Pikaid.binaryLength` (17),
`Pikaid.timestampLength` (7), `Pikaid.randomnessLength` (19),
`Pikaid.randomnessBytes` (12) and `Pikaid.maxTimestamp`
(78,364,164,095).

### Errors

| Operation | Invalid input | Error |
| --------- | ------------- | ----- |
| `Pikaid.parse`, `Pikaid.fromBinary` | Wrong length, alphabet, byte range or out-of-range field | `FormatException` |
| `Pikaid.fromComponents` | Timestamp or randomness byte out of range | `RangeError` |
| `Pikaid.fromComponents` | `randomness.length != 12` | `ArgumentError` |
| `Pikaid.generate`, `Pikaid.generateAt` | Timestamp or system clock outside `0..maxTimestamp` | `RangeError` |
| Any generation with the default secure source | CSPRNG unavailable or throws | `PikaidEntropyException` |
| Generation with a custom random source | The source throws | That error, propagated unchanged; generation never falls back to weaker entropy |

`tryParse` and `isValid` convert `FormatException` into `null` / `false`.

## Ordering

`compareTo` compares the timestamp first and the 12 randomness bytes second.
This matches ASCII lexicographic order of the text form and unsigned bytewise
order of the binary form.

- Values with **different** timestamps sort chronologically.
- Values generated within the **same second** sort by their random suffix, not by
  generation order. pikaid is **not** a monotonic sequence generator, and its
  timestamp has one-second precision.

## Database storage

| Representation | Recommended column | Comparison requirement |
| -------------- | ------------------ | ---------------------- |
| Binary | `BINARY(17)` or an equivalent fixed-width binary type | Unsigned bytewise |
| Text | `CHAR(26)` / `VARCHAR(26)` | Binary or another verified ASCII-compatible collation |

Database default collations are not automatically safe for bytewise ordering
and equality. For example, MySQL/MariaDB text columns should use a binary
collation rather than a case-insensitive default.

## Security

- Every generated suffix contains **96 bits** of CSPRNG randomness
  (`2^96 ≈ 7.92 × 10^28` values).
- Generation uses `Random.secure()`. There is no non-cryptographic fallback,
  counter or timestamp-derived entropy; a failure raises
  `PikaidEntropyException`.
- Collisions are not impossible. For `n` identifiers within one timestamp
  bucket, the approximate collision probability is
  `1 − exp(−n(n−1) / (2 × 2^96))`; the roughly 50% threshold is about
  `3.31 × 10^14` identifiers in the same second. Applications should enforce
  uniqueness where required.
- The timestamp is readable from every identifier. pikaid values are **not
  secrets**, authentication tokens or authorization evidence.
- There is no checksum: a transcription error can produce another valid
  identifier. Validate references against real data when error detection
  matters.

## Platform support

The conversion code avoids `BigInt` and 64-bit-only arithmetic, using byte
arrays with small intermediates. The package itself uses only `dart:typed_data`
and `dart:math`, with no runtime dependencies.

Verification status:

- **Dart VM** — full suite on Dart 3.6.0 (minimum) and Dart 3.13.7 (stable),
  in CI and locally.
- **dart2js (Node)** — the portable conformance suite runs with
  `dart test -p node`, including the default-CSPRNG test, and the compiled
  example runs under Node, in CI. `test/support/node_web_crypto.dart` restores
  the genuine Node Web Crypto object behind a Node-only guard so the test
  preamble's non-global `self` can reach it; the shim is inert on the VM and in
  browsers and generates no entropy of its own.
- **dart2js (real browser)** — the portable conformance suite runs in headless
  Chrome with `dart test -p chrome`, in CI.
- **dart2wasm** — the compiled example and the portable conformance suites run
  with `dart compile wasm` and `dart test -p chrome --compiler dart2wasm` under
  Node 22 and headless Chrome, in CI. This includes text/binary round trips and
  the full valid/invalid conformance corpora.

## Development

```bash
dart pub get
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
dart test
dart run example/main.dart
```

Coverage (threshold enforced at 90% by `tool/check_coverage.dart`):

```bash
dart test --coverage=coverage
dart run coverage:format_coverage \
  --lcov --in=coverage --out=coverage/lcov.info --report-on=lib
dart run tool/check_coverage.dart coverage/lcov.info
```

Package and consumer validation:

```bash
dart pub publish --dry-run
dart run tool/stage_package.dart build/package
dart run tool/package_consumer_check.dart build/package
```

`stage_package.dart` derives the file set from the authoritative publish
inventory, copies only those files, and re-publishes the staged copy in a
temporary directory to prove the inventories match. `package_consumer_check.dart`
then creates a throwaway application outside the repository that depends on the
staged package by path, resolves its dependencies, analyzes cleanly and
exercises the public API at runtime.

The suite contains 415 tests: official and independent known-answer vectors,
the published PHP v1.2.0 fixtures (used as independent fixtures, not as the
normative source), boundary and overflow checks, malformed-input rejection,
round trips, generation and entropy-failure behavior, ordering and API contracts.
`test/api_parity_test.dart` maps every normative operation of specification
1.0.4 to a public Dart entrypoint, exercises each through
`package:pikaid/pikaid.dart`, pins the exact public member set of `Pikaid`, and
fails if a public member, exported symbol or documented README row is added
without a parity entry.

The conformance matrix (`test/support/conformance_cases.dart`) pins 19 valid,
23 invalid text and 10 invalid binary cases. It is generated by
`tool/generate_conformance_cases.py`, an independent Python BigInt
implementation, and every expected value is recomputed at test time by a second
independent BigInt oracle (`test/support/reference.dart`), so a transcription
mistake fails the suite. Generated cases include timestamp `2^37`, randomness
exactly `2^96` and `36^19 − 1` (shape-valid but semantically invalid), and both
maximum fields. Fixture SHA-256 digests are pinned in
`test/fixture_integrity_test.dart`, and `test/repository_policy_test.dart`
enforces the explicit root `/.ai/` ignore rule, LF line endings and the absence
of tracked `.ai/` files.

Current line coverage of `lib/` is **98.52% (200/203 lines)**; the three
uncovered lines are unreachable CSPRNG failure branches. CI runs the suite on
Dart 3.6.0 (the minimum supported SDK) and stable, on dart2js under Node and
headless Chrome, on dart2wasm, the coverage gate, and the package/consumer job.
Local results are validated on Dart 3.6.0 and Dart 3.13.7.

## License

MIT. See [LICENSE](LICENSE).

## Links

- [pikaid specification revision 1.0.4][spec]
- [pikaid organization](https://github.com/pikaid)
- [Issue tracker](https://github.com/pikaid/pikaid-dart/issues)
