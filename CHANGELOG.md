# Changelog

All notable changes to the official Dart implementation of pikaid are
documented in this file.

The pikaid identifier format is immutable and unversioned. This changelog
tracks the Dart package only.

## 1.0.1 — 2026-11-10

- Package release metadata corrected to version 1.0.1; no changes to the
  public Dart API or PikaID identifier format.
- Automated pub.dev publication now checks the Git tag against the declared
  package version and requires the full Dart CI and security workflows to pass.
- GitHub Actions dependencies are pinned to reviewed commit SHAs, and checkout
  credentials are not persisted between steps.

## 1.0.0 — 2026-11-07

First stable release, targeting pikaid specification revision 1.0.4. No public
API changes from 0.1.0.

- Local `.ai/` working artifacts are ignored by an explicit root `/.ai/` rule,
  are no longer tracked, and cannot appear in the Git tree or a published
  package archive; `test/repository_policy_test.dart` enforces this. A broad
  `/.??/` pattern previously replaced that rule and was removed because it
  would also hide a new top-level `.github/` or other dot-directory from
  `git status`.
- Repository files are pinned to LF line endings with `.gitattributes`.
- A pinned 1.0.4 conformance matrix adds 19 valid, 23 invalid text and 10
  invalid binary cases with an independent Python BigInt generator and a
  second independent BigInt oracle that recomputes every expected value during
  the test run.
- `test/api_parity_test.dart` maps every normative operation of specification
  1.0.4 to a public entrypoint, exercises each one through
  `package:pikaid/pikaid.dart`, and pins the exact public member set so new
  public API cannot be added without a parity entry.
- Official fixture copies are checked against pinned SHA-256 digests.
- `dart pub publish --dry-run` completes with zero warnings and the package
  archive excludes `.ai/` while retaining all source, tests, fixtures,
  documentation and license files. CI stages the exact publish inventory and
  runs an external application against it.
- CI additionally enforces dart2wasm execution, a staged archive hygiene check,
  the documented example, and the full conformance matrix on dart2js (Node and
  Chrome) and dart2wasm.
- Repository metadata is prepared for version 1.0.0; publication is still
  pending a public source repository and pub.dev publishing credentials.

## 0.1.0 — 2026-11-06

Initial implementation, targeting pikaid specification revision 1.0.4.

- `Pikaid` immutable value type for the 26-character text form and the
  17-byte binary form.
- Strict parsing (`parse`, `tryParse`), semantic validation (`isValid`) and
  shape-only validation (`isWellFormed`).
- CSPRNG generation from `Random.secure()`, including explicit-timestamp
  variants and direct binary generation.
- Injectable `PikaidRandomSource` with fail-closed `PikaidEntropyException`.
- Lossless text/binary round trips, timestamp and randomness accessors,
  equality and chronological comparison.
- Conformance suite covering official and independent known-answer vectors,
  boundary and overflow cases, malformed input, round trips, ordering,
  generation and entropy failure.
- Portable conformance suite executed on the VM, dart2js in Node and dart2js in
  a real headless browser.
- `Pikaid.fromBinary` copies and validates its input once, so a stateful or
  concurrently mutated `List<int>` cannot change bytes between validation and
  decoding.
- MIT license, API documentation, example, coverage gate and GitHub Actions CI.
