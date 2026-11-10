<p align="center">
  <a href="https://github.com/pikaid/pikaid-specs">
    <img src="https://raw.githubusercontent.com/pikaid/pikaid-specs/v1.0.4/logo.png" alt="pikaid" width="300">
  </a>
</p>

<p align="center">
  <strong>Small · Sortable · Secure ID generator</strong>
</p>

<div align="center">

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Dart](https://img.shields.io/badge/language-Dart-0175C2.svg)](https://github.com/pikaid/pikaid-dart)
[![CI](https://github.com/pikaid/pikaid-dart/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/pikaid/pikaid-dart/actions/workflows/ci.yml)
[![Official implementation](https://img.shields.io/badge/official-implementation-2e7d32.svg)](https://github.com/pikaid/pikaid-specs)
[![Specification 1.0.4](https://img.shields.io/badge/spec-1.0.4-4b56a6.svg)](https://github.com/pikaid/pikaid-specs/tree/v1.0.4)

</div>

**pikaid** is the **official Dart implementation** of a compact, chronologically sortable, collision-resistant identifier format for databases, APIs, and distributed systems.

This is the immutable, unversioned [pikaid format](https://github.com/pikaid/pikaid-specs/tree/v1.0.4), documented in specification revision **1.0.4**.

## ✨ Why pikaid?

- **Short:** Compact, readable IDs for URLs, logs, and API resources.
- **Sortable:** Lexicographically ordered by timestamp, with **one-second precision**.
- **Collision-resistant:** 96 bits of cryptographic randomness make collisions extremely unlikely, never impossible.
- **Storage-friendly:** Use `BINARY(17)` or readable `CHAR(26)`.
- **Distributed-friendly:** No central sequence generator or coordination required.

## 🧬 Identifier format

A pikaid contains **26 lowercase Base36 characters**: a **7-character Unix-seconds timestamp** followed by **19 characters encoding 96 bits of cryptographic randomness**. Its binary form is **17 bytes**: 5 unsigned big-endian timestamp bytes followed by 12 randomness bytes.

![Identifier structure](https://raw.githubusercontent.com/pikaid/pikaid-specs/v1.0.4/structure.svg)

> **Ordering:** Different seconds sort chronologically. Within the same second, randomness—not issuance order—decides the order.

> **Security:** These are identifiers, **not secrets**, session credentials, authentication tokens, or API keys.

## ⚙️ Requirements

Dart SDK 3.6 or newer.

## 📦 Installation

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

Then run `dart pub get`. Save the example below as `bin/main.dart`, then execute `dart run bin/main.dart`. The minimum supported SDK is Dart **3.6.0**.

## 🚀 Basic Usage

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

## 💡 Example Use Case

Use pikaid to identify **users, orders, invoices, uploads, events, and API resources**. Independent services can generate compact IDs without a shared counter, while timestamp-based ordering helps with indexing, sorting, and logs.

## 📚 Canonical specification

The normative specification revision 1.0.4 is pinned to commit `17014d76f568c3ac9f9ce2927c1a018fdbc36d1d` in the API parity checks.

- [Canonical specification](https://github.com/pikaid/pikaid-specs)
- [Revision 1.0.4](https://github.com/pikaid/pikaid-specs/tree/v1.0.4)

Specification revisions describe the format; they do not change the encoded identifiers.

## 🧩 API Reference

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

## 🔄 Order Guarantee

`compareTo` compares the timestamp first and the 12 randomness bytes second.
This matches ASCII lexicographic order of the text form and unsigned bytewise
order of the binary form.

- Values with **different** timestamps sort chronologically.
- Values generated within the **same second** sort by their random suffix, not by
  generation order. pikaid is **not** a monotonic sequence generator, and its
  timestamp has one-second precision.

## 🛢 Storage Recommendations

| Representation | Size | Recommended for |
| --- | ---: | --- |
| **BINARY(17)** | 17 bytes | Compact primary keys and indexes |
| **CHAR(26)** | 26 characters | Readable SQL, debugging, URLs, and logs |

Use an **ASCII bytewise/binary collation** for text columns (for example, `ascii_bin` on MariaDB/MySQL). Case-insensitive or locale-aware sorting is not a substitute for canonical bytewise comparison.

## ✅ Verification and release status

The [CI workflow](https://github.com/pikaid/pikaid-dart/actions/workflows/ci.yml) runs native tests, pinned automated conformance checks, and language-specific quality gates. To run the native checks locally from a checkout: `dart test`.

**Automated passing tests are not a security certification.** The independent CSPRNG source and failure-path audits (`P-GENERATE-RNG-SOURCE` and `P-GENERATE-RNG-FAILURE`) still require separate human evidence.

<details>
<summary>Platform, tooling, and conformance details</summary>

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

</details>

Registry publication is not implied by a green CI: use the installation method documented above.

## 🤝 Contributing

Contributions are always welcome! 💙

Whether you're fixing a typo, improving documentation, adding tests, or making pikaid even better, every contribution is appreciated.

**Want to help? Here's how:**

- 🐛 **Found a bug?** [Open an issue](https://github.com/pikaid/pikaid-dart/issues) with clear reproduction steps.
- 💡 **Have an idea?** Start with an issue before making major changes.
- 🛠️ **Ready to contribute?** Open a pull request explaining your changes.
- 🧪 **Keep it tested.** Add meaningful regression tests for behavior changes and follow the existing conventions.
- ✅ **Make sure CI passes.** All required checks must be green before a pull request is merged. No shortcuts!

**One important rule:** pikaid's identifier format is immutable. Contributions must preserve the [canonical specification (revision 1.0.4)](https://github.com/pikaid/pikaid-specs/tree/v1.0.4).

🔐 **Found a security vulnerability?** Report it privately using GitHub's security reporting (when available), or [contact the maintainer](mailto:larananas.dev@proton.me)—not through a public issue.

**Every improvement matters, big or small. Thanks for helping make pikaid better!** 🐇

## 📄 License

The implementation is available under the [MIT License](LICENSE).

## ✉️ Contact

For licensing or project-related questions: [larananas.dev@proton.me](mailto:larananas.dev@proton.me).

