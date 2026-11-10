#!/usr/bin/env python3
"""Generate the pinned official PikaID conformance corpus table.

The corpus is *transcribed* from the immutable official cross-language
conformance suite (https://github.com/pikaid/pikaid-specs) at the exact commit
pinned below. This script never imports or executes ``package:pikaid``. It
verifies the suite's manifest, per-file SHA-256 digests, counts and internal
case consistency before emitting, so a tampered or truncated checkout fails
instead of silently shrinking the corpus.

The generated Dart file is checked in, so the test suite does not need Python.
CI re-runs this script with ``--check`` against a fresh checkout of the pinned
commit, which fails if the committed table no longer matches the suite.

Run from the repository root:

    python3 tool/generate_official_cases.py
    python3 tool/generate_official_cases.py --check

Exit status 0 means the file was written, already up to date, or (with
``--check``) byte-identical to a fresh generation.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

SUITE_COMMIT = "059780cc0e5b113443812720d95c630649bf3aa3"
SUITE_NAME = "pikaid-cross-language-conformance"
PACKAGE_REVISION = "1.0.0"
SPEC_REVISION = "1.0.4"
SUITE_STATUS = "OFFICIAL"
MANDATORY_CAPABILITIES = [
    "generate_string",
    "text_to_binary",
    "binary_to_text",
]
REQUIRED_DIGESTS = [
    "cases/invalid-binary.json",
    "cases/invalid-string.json",
    "cases/ordering.json",
    "cases/valid.json",
    "manifest.json",
]
EXPECTED_COUNTS = {
    "cases/valid.json": 596,
    "cases/invalid-string.json": 258,
    "cases/invalid-binary.json": 33,
    "cases/ordering.json": 186,
}
ALPHABET = "0123456789abcdefghijklmnopqrstuvwxyz"
MAX_TIMESTAMP = 36**7 - 1
MAX_RANDOMNESS = 2**96 - 1
ASCII_PRINTABLE = set(range(0x20, 0x7F))
LINE_WIDTH = 80


class SuiteError(SystemExit):
    """A checked invariant of the official suite does not hold."""


def fail(message: str) -> "SuiteError":
    raise SuiteError(f"official suite verification failed: {message}")


def reject_duplicates(pairs: list[tuple[str, object]]) -> dict[str, object]:
    seen: dict[str, object] = {}
    for key, value in pairs:
        if key in seen:
            fail(f"duplicate JSON key {key!r}")
        seen[key] = value
    return seen


def read_json(path: Path) -> dict[str, object]:
    try:
        return json.loads(
            path.read_text(encoding="utf-8"),
            object_pairs_hook=reject_duplicates,
        )
    except (OSError, ValueError) as exc:
        fail(f"cannot read {path}: {exc}")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1 << 16), b""):
            digest.update(block)
    return digest.hexdigest()


def verify_commit(suite: Path, expected_commit: str) -> None:
    if expected_commit != SUITE_COMMIT:
        fail(
            f"--commit {expected_commit} does not match the pinned suite "
            f"commit {SUITE_COMMIT}"
        )
    try:
        head = subprocess.run(
            ["git", "-C", str(suite), "rev-parse", "HEAD"],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        # An exported tarball has no git metadata; the pinned commit is still
        # recorded in the generated file and enforced by the digest check.
        return
    if head != SUITE_COMMIT:
        fail(f"suite HEAD is {head}, expected {SUITE_COMMIT}")


def verify_checksums(suite: Path) -> dict[str, str]:
    sums_path = suite / "SHA256SUMS"
    if not sums_path.is_file():
        fail("SHA256SUMS is missing")
    digests: dict[str, str] = {}
    for line in sums_path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        match = re.fullmatch(r"([0-9a-f]{64})  (.+)", line)
        if not match:
            fail(f"malformed SHA256SUMS line: {line!r}")
        digest, relative = match.groups()
        if relative in digests:
            fail(f"duplicate SHA256SUMS entry for {relative}")
        digests[relative] = digest
    required = sorted(REQUIRED_DIGESTS)
    for relative in required:
        if relative not in digests:
            fail(f"SHA256SUMS does not cover {relative}")
        path = suite / relative
        if not path.is_file():
            fail(f"listed file {relative} is missing")
        actual = sha256_file(path)
        if actual != digests[relative]:
            fail(f"{relative} digest is {actual}, expected {digests[relative]}")
    return digests


def verify_manifest(manifest: dict[str, object]) -> None:
    expected: dict[str, object] = {
        "name": SUITE_NAME,
        "package_revision": PACKAGE_REVISION,
        "spec_revision": SPEC_REVISION,
        "status": SUITE_STATUS,
        "mandatory_capabilities": MANDATORY_CAPABILITIES,
    }
    for key, value in expected.items():
        if manifest.get(key) != value:
            fail(f"manifest {key} is {manifest.get(key)!r}, expected {value!r}")
    fixtures = manifest.get("fixtures")
    if not isinstance(fixtures, list):
        fail("manifest fixtures must be a list")
    declared = {
        fixture["path"]: fixture["cases"]
        for fixture in fixtures
        if isinstance(fixture, dict) and "path" in fixture
    }
    for relative, count in EXPECTED_COUNTS.items():
        if declared.get(relative) != count:
            fail(
                f"manifest declares {relative} with {declared.get(relative)!r} "
                f"cases, expected {count}"
            )


def decode_base36(value: str, width: int) -> int:
    if len(value) != width or any(char not in ALPHABET for char in value):
        fail(f"{value!r} is not {width} lowercase Base36 characters")
    total = 0
    for char in value:
        total = total * 36 + ALPHABET.index(char)
    return total


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def check_valid(cases: list[dict[str, object]]) -> None:
    for case in cases:
        name = case["id"]
        timestamp = case["timestamp_seconds"]
        randomness = case["randomness_hex"]
        pikaid = case["pikaid"]
        binary = case["binary_hex"]
        require(
            isinstance(timestamp, int) and 0 <= timestamp <= MAX_TIMESTAMP,
            f"valid/{name}: timestamp {timestamp!r} out of range",
        )
        require(
            isinstance(randomness, str)
            and re.fullmatch(r"[0-9a-f]{24}", randomness) is not None,
            f"valid/{name}: randomness_hex {randomness!r} is malformed",
        )
        require(
            isinstance(pikaid, str)
            and re.fullmatch(r"[0-9a-z]{26}", pikaid) is not None,
            f"valid/{name}: pikaid {pikaid!r} is malformed",
        )
        require(
            isinstance(binary, str)
            and re.fullmatch(r"[0-9a-f]{34}", binary) is not None,
            f"valid/{name}: binary_hex {binary!r} is malformed",
        )
        require(
            decode_base36(pikaid[:7], 7) == timestamp,
            f"valid/{name}: text timestamp prefix disagrees with fixture",
        )
        require(
            decode_base36(pikaid[7:], 19) == int(randomness, 16),
            f"valid/{name}: text randomness disagrees with randomness_hex",
        )
        require(
            int(randomness, 16) <= MAX_RANDOMNESS,
            f"valid/{name}: randomness exceeds 96 bits",
        )
        expected_binary = timestamp.to_bytes(5, "big").hex() + randomness
        require(
            binary == expected_binary,
            f"valid/{name}: binary_hex disagrees with timestamp and randomness",
        )
        require(
            int(binary[:10], 16) == timestamp,
            f"valid/{name}: binary timestamp prefix disagrees with fixture",
        )


def shape_only(value: str) -> bool:
    utf16_units = len(value.encode("utf-16-le")) // 2
    return utf16_units == 26 and all(char in ALPHABET for char in value)


def check_invalid_string(cases: list[dict[str, object]]) -> None:
    for case in cases:
        name = case["id"]
        value = case["input"]
        expected = case["expected"]
        require(isinstance(value, str), f"invalid-string/{name}: input not a string")
        require(
            all(not 0xD800 <= ord(char) <= 0xDFFF for char in value),
            f"invalid-string/{name}: input contains a lone surrogate",
        )
        require(
            expected.get("strict_conversion") == "reject",
            f"invalid-string/{name}: strict_conversion is not reject",
        )
        require(
            expected.get("boolean_validation") is False,
            f"invalid-string/{name}: boolean_validation is not false",
        )
        require(
            expected.get("format_only_if_supported") is shape_only(value),
            f"invalid-string/{name}: format_only_if_supported disagrees with "
            "the shape-only predicate",
        )


def check_invalid_binary(cases: list[dict[str, object]]) -> None:
    for case in cases:
        name = case["id"]
        value = case["input_hex"]
        require(
            isinstance(value, str)
            and len(value) % 2 == 0
            and re.fullmatch(r"[0-9a-f]*", value) is not None,
            f"invalid-binary/{name}: input_hex {value!r} is not even-length "
            "lowercase hexadecimal",
        )
        if len(value) == 34:
            # A 17-byte value is only invalid when its timestamp overflows.
            require(
                int(value[:10], 16) > MAX_TIMESTAMP,
                f"invalid-binary/{name}: a 17-byte value has an in-range "
                "timestamp and would be valid",
            )
        require(
            case["reason"] in {
                "binary_length",
                "timestamp_overflow",
            },
            f"invalid-binary/{name}: unexpected reason {case['reason']!r}",
        )
        require(
            case["expected"] == "reject",
            f"invalid-binary/{name}: expected is not reject",
        )


def compare_sign(left: str, right: str) -> int:
    return (left > right) - (left < right)


def check_ordering(cases: list[dict[str, object]]) -> None:
    for case in cases:
        name = case["id"]
        a_id, b_id = case["a_pikaid"], case["b_pikaid"]
        a_bin, b_bin = case["a_binary_hex"], case["b_binary_hex"]
        expected = case["expected_compare"]
        require(
            isinstance(a_id, str)
            and isinstance(b_id, str)
            and re.fullmatch(r"[0-9a-z]{26}", a_id) is not None
            and re.fullmatch(r"[0-9a-z]{26}", b_id) is not None,
            f"ordering/{name}: pikaid values are malformed",
        )
        require(
            isinstance(a_bin, str)
            and isinstance(b_bin, str)
            and re.fullmatch(r"[0-9a-f]{34}", a_bin) is not None
            and re.fullmatch(r"[0-9a-f]{34}", b_bin) is not None,
            f"ordering/{name}: binary hex values are malformed",
        )
        require(
            expected in (-1, 0, 1),
            f"ordering/{name}: expected_compare {expected!r} is invalid",
        )
        require(
            decode_base36(a_id[:7], 7) == int(a_bin[:10], 16)
            and decode_base36(b_id[:7], 7) == int(b_bin[:10], 16),
            f"ordering/{name}: text and binary timestamps disagree",
        )
        require(
            decode_base36(a_id[7:], 19) == int(a_bin[10:], 16)
            and decode_base36(b_id[7:], 19) == int(b_bin[10:], 16),
            f"ordering/{name}: text and binary randomness disagree",
        )
        require(
            compare_sign(a_id, b_id) == expected
            and compare_sign(a_bin, b_bin) == expected,
            f"ordering/{name}: expected_compare disagrees with the fixtures",
        )


def dart_literal(value: str) -> str:
    """Return a single-quoted Dart literal for [value]."""
    escaped = []
    for char in value:
        code = ord(char)
        if char == "\\":
            escaped.append("\\\\")
        elif char == "'":
            escaped.append("\\'")
        elif char == "$":
            escaped.append("\\$")
        elif code in ASCII_PRINTABLE:
            escaped.append(char)
        else:
            escaped.append(f"\\u{{{code:x}}}")
    return "'" + "".join(escaped) + "'"


def field(name: str, literal: str) -> str:
    """Emit one record field, moving an overlong literal to its own line.

    dart format never splits a string literal, so the only wrapping it can do
    is to put the value on a continuation line. Reproducing that here keeps
    generated output byte-identical to `dart format` without invoking Dart.
    """
    line = f"    {name}: {literal},"
    if len(line) > LINE_WIDTH:
        return f"    {name}:\n        {literal},"
    return line


def record(fields: list[str]) -> str:
    return "  (\n" + "\n".join(fields) + "\n  ),\n"


def valid_record(case: dict[str, object]) -> str:
    return record(
        [
            field("name", dart_literal(case["id"])),
            field("timestamp", str(case["timestamp_seconds"])),
            field("randomnessHex", dart_literal(case["randomness_hex"])),
            field("id", dart_literal(case["pikaid"])),
            field("binaryHex", dart_literal(case["binary_hex"])),
        ]
    )


def invalid_string_record(case: dict[str, object]) -> str:
    expected = case["expected"]
    return record(
        [
            field("name", dart_literal(case["id"])),
            field("value", dart_literal(case["input"])),
            field("valid", "false" if not expected["boolean_validation"] else "true"),
            field(
                "wellFormed",
                "true" if expected["format_only_if_supported"] else "false",
            ),
            field("reason", dart_literal(case["reason"])),
        ]
    )


def invalid_binary_record(case: dict[str, object]) -> str:
    return record(
        [
            field("name", dart_literal(case["id"])),
            field("value", dart_literal(case["input_hex"])),
            field("reason", dart_literal(case["reason"])),
        ]
    )


def ordering_record(case: dict[str, object]) -> str:
    return record(
        [
            field("name", dart_literal(case["id"])),
            field("aId", dart_literal(case["a_pikaid"])),
            field("bId", dart_literal(case["b_pikaid"])),
            field("aBinaryHex", dart_literal(case["a_binary_hex"])),
            field("bBinaryHex", dart_literal(case["b_binary_hex"])),
            field("expectedCompare", str(case["expected_compare"])),
        ]
    )


def header(digests: dict[str, str]) -> str:
    lines = [
        "// Generated by tool/generate_official_cases.py. Do not edit by hand.",
        "//",
        "// Transcribed from the official cross-language conformance suite at",
        f"// https://github.com/pikaid/pikaid-specs commit {SUITE_COMMIT}",
        f"// (package revision {PACKAGE_REVISION}, specification revision",
        f"// {SPEC_REVISION}, status {SUITE_STATUS}). The generator verifies the",
        "// suite manifest, SHA-256 digests and case consistency before writing,",
        "// and CI re-runs it with --check.",
        "//",
        "// This file is deliberately free of dart:io so the same corpus runs on",
        "// the VM, on dart2js in Node or a browser, and on dart2wasm.",
        "library;",
        "",
        "/// The exact official suite commit these cases were transcribed from.",
        f"const String officialSuiteCommit = '{SUITE_COMMIT}';",
        "",
        "/// Package revision reported by the official suite manifest.",
        f"const String officialPackageRevision = '{PACKAGE_REVISION}';",
        "",
        "/// Specification revision reported by the official suite manifest.",
        f"const String officialSpecRevision = '{SPEC_REVISION}';",
        "",
        "/// Publication status reported by the official suite manifest.",
        f"const String officialSuiteStatus = '{SUITE_STATUS}';",
        "",
        "/// SHA-256 digests of the corpus fixtures and manifest. The generator",
        "/// verifies every entry in the suite's `SHA256SUMS` before writing.",
        "const Map<String, String> officialFixtureSha256 = <String, String>{",
    ]
    for relative in sorted(REQUIRED_DIGESTS):
        entry = f"  '{relative}': '{digests[relative]}',"
        if len(entry) > LINE_WIDTH:
            lines.append(f"  '{relative}':")
            lines.append(f"      '{digests[relative]}',")
        else:
            lines.append(entry)
    lines.extend(
        [
            "};",
            "",
            "/// One canonical official case with both representations.",
            "typedef OfficialValidCase = ({",
            "  String name,",
            "  int timestamp,",
            "  String randomnessHex,",
            "  String id,",
            "  String binaryHex,",
            "});",
            "",
            "/// One text representation the official suite requires to be rejected.",
            "typedef OfficialInvalidStringCase = ({",
            "  String name,",
            "  String value,",
            "  bool valid,",
            "  bool wellFormed,",
            "  String reason,",
            "});",
            "",
            "/// One binary representation the official suite requires to be rejected.",
            "typedef OfficialInvalidBinaryCase = ({",
            "  String name,",
            "  String value,",
            "  String reason,",
            "});",
            "",
            "/// One official text/binary ordering case and its expected comparison.",
            "typedef OfficialOrderingCase = ({",
            "  String name,",
            "  String aId,",
            "  String bId,",
            "  String aBinaryHex,",
            "  String bBinaryHex,",
            "  int expectedCompare,",
            "});",
        ]
    )
    return "\n".join(lines)


def list_declaration(doc: str, type_name: str, variable: str) -> str:
    """Emit a list declaration, split the way dart format would split it."""
    joined = f"const List<{type_name}> {variable} = <{type_name}>["
    if len(joined) <= LINE_WIDTH:
        return f"/// {doc}\n{joined}"
    return f"/// {doc}\nconst List<{type_name}> {variable} =\n    <{type_name}>["


def footer(counts: dict[str, int]) -> str:
    return f"""/// Counts of the transcribed corpus, used to detect accidental truncation.
const int officialValidCaseCount = {counts['cases/valid.json']};
const int officialInvalidStringCaseCount = {counts['cases/invalid-string.json']};
const int officialInvalidBinaryCaseCount = {counts['cases/invalid-binary.json']};
const int officialOrderingCaseCount = {counts['cases/ordering.json']};
"""


def load_cases(suite: Path) -> dict[str, list[dict[str, object]]]:
    datasets: dict[str, list[dict[str, object]]] = {}
    for relative, count in EXPECTED_COUNTS.items():
        document = read_json(suite / relative)
        cases = document.get("cases")
        if not isinstance(cases, list) or len(cases) != count:
            fail(f"{relative} does not contain exactly {count} cases")
        datasets[relative] = cases
    return datasets


def generate(suite: Path) -> str:
    digests = verify_checksums(suite)
    manifest = read_json(suite / "manifest.json")
    verify_manifest(manifest)
    datasets = load_cases(suite)
    check_valid(datasets["cases/valid.json"])
    check_invalid_string(datasets["cases/invalid-string.json"])
    check_invalid_binary(datasets["cases/invalid-binary.json"])
    check_ordering(datasets["cases/ordering.json"])

    valid = "".join(valid_record(c) for c in datasets["cases/valid.json"])
    invalid_string = "".join(
        invalid_string_record(c) for c in datasets["cases/invalid-string.json"]
    )
    invalid_binary = "".join(
        invalid_binary_record(c) for c in datasets["cases/invalid-binary.json"]
    )
    ordering = "".join(ordering_record(c) for c in datasets["cases/ordering.json"])
    return (
        header(digests)
        + "\n\n"
        + list_declaration(
            "The official valid cross-representation corpus.",
            "OfficialValidCase",
            "officialValidCases",
        )
        + "\n"
        + valid
        + "];\n\n"
        + list_declaration(
            "Text representations the official suite requires to be rejected.",
            "OfficialInvalidStringCase",
            "officialInvalidStringCases",
        )
        + "\n"
        + invalid_string
        + "];\n\n"
        + list_declaration(
            "Binary representations the official suite requires to be rejected.",
            "OfficialInvalidBinaryCase",
            "officialInvalidBinaryCases",
        )
        + "\n"
        + invalid_binary
        + "];\n\n"
        + list_declaration(
            "Official text and binary ordering cases.",
            "OfficialOrderingCase",
            "officialOrderingCases",
        )
        + "\n"
        + ordering
        + "];\n\n"
        + footer(EXPECTED_COUNTS)
    )


def main() -> int:
    root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--suite",
        type=Path,
        default=root / ".ai/specs-pin/conformance",
        help="path to the pinned conformance directory",
    )
    parser.add_argument(
        "--commit",
        default=SUITE_COMMIT,
        help="required suite commit (must equal the pinned commit)",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=root / "test/support/official_cases.dart",
        help="generated Dart file",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="verify the committed file instead of writing it",
    )
    arguments = parser.parse_args()

    suite = arguments.suite.resolve()
    if not suite.is_dir():
        fail(f"suite directory {suite} does not exist")
    verify_commit(suite, arguments.commit)
    output = generate(suite)

    target = arguments.output
    if arguments.check:
        if not target.is_file():
            fail(f"{target} does not exist; run without --check")
        if target.read_text(encoding="utf-8") != output:
            fail(
                f"{target} does not match the pinned suite; regenerate it with "
                "python3 tool/generate_official_cases.py"
            )
        print(f"{target} matches official suite commit {SUITE_COMMIT}")
        return 0

    changed = not target.exists() or target.read_text(encoding="utf-8") != output
    if changed:
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(output, encoding="utf-8")
        print(f"wrote {target}")
    else:
        print(f"{target} is up to date")
    return 0


if __name__ == "__main__":
    sys.exit(main())
