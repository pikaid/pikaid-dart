#!/usr/bin/env python3
"""Generate the pinned Dart conformance table.

This script is an *independent* reference implementation of the pikaid text
encoding from specification revision 1.0.4. It uses Python's arbitrary
precision integers and ``int.to_bytes`` and never imports or executes the Dart
package under test.

The values it writes to ``test/support/conformance_cases.dart`` are therefore
expected values, not observations of ``package:pikaid``. The generated file is
checked in; CI does not need Python. At test time a second, independent Dart
BigInt oracle (``test/support/reference.dart``) recomputes every expected value,
so a transcription mistake fails the suite.

Run from the repository root:

    python3 tool/generate_conformance_cases.py

Exit status 0 means the checked-in file was written or already up to date.
"""

from __future__ import annotations

import sys
from pathlib import Path

ALPHABET = "0123456789abcdefghijklmnopqrstuvwxyz"
TIMESTAMP_CHARS = 7
RANDOMNESS_CHARS = 19
RANDOMNESS_BYTES = 12
MAX_TIMESTAMP = 36**TIMESTAMP_CHARS - 1  # 78364164095
MAX_RANDOMNESS = 2 ** (8 * RANDOMNESS_BYTES) - 1


def base36(value: int, width: int) -> str:
    digits = []
    original = value
    while value:
        value, remainder = divmod(value, 36)
        digits.append(ALPHABET[remainder])
    text = "".join(reversed(digits)) or "0"
    if len(text) > width:
        raise ValueError(f"{original} does not fit in {width} Base36 characters")
    return text.rjust(width, "0")


# (name, timestamp, entropy_hex)
CASES = [
    ("all-zero", 0, "00" * 12),
    ("one-one", 1, "00" * 11 + "01"),
    ("max-values", MAX_TIMESTAMP, "ff" * 12),
    ("max-timestamp-zero-entropy", MAX_TIMESTAMP, "00" * 12),
    ("zero-timestamp-max-entropy", 0, "ff" * 12),
    ("sample-1700000000", 1700000000, "00112233445566778899aabb"),
    ("leading-zero-entropy", 42, "00" * 9 + "000ab3"),
    ("fixed-second-max-entropy", 1700000000, "ff" * 12),
    ("near-maximum", MAX_TIMESTAMP - 1, "ff" * 11 + "fe"),
    ("thirty-two-bit-timestamp", 2**32, "00" * 8 + "01020304"),
    ("power-of-36-timestamp", 36, "00" * 11 + "ff"),
    ("high-bit-entropy", 1337, "7f" + "ff" * 11),
    ("seeded-1", 1234567890, "0123456789abcdef01234567"),
    ("seeded-2", 987654321, "fedcba9876543210fedcba98"),
    ("seeded-3", 1672531200, "80" + "00" * 11),
    ("seeded-4", MAX_TIMESTAMP, "00" * 11 + "01"),
    ("seeded-5", 0, "ff" * 11 + "fe"),
    ("same-second-low", 1700000000, "00" * 12),
    ("same-second-high", 1700000000, "00" * 11 + "01"),
]


def dart_case(name: str, timestamp: int, entropy_hex: str) -> str:
    entropy = bytes.fromhex(entropy_hex)
    if len(entropy) != RANDOMNESS_BYTES:
        raise ValueError(f"{name}: entropy must be {RANDOMNESS_BYTES} bytes")
    if not 0 <= timestamp <= MAX_TIMESTAMP:
        raise ValueError(f"{name}: timestamp out of range")
    randomness = int.from_bytes(entropy, "big")
    if randomness > MAX_RANDOMNESS:
        raise ValueError(f"{name}: randomness out of range")
    identifier = base36(timestamp, TIMESTAMP_CHARS) + base36(
        randomness, RANDOMNESS_CHARS
    )
    binary_hex = timestamp.to_bytes(5, "big").hex() + entropy_hex
    return (
        "  (\n"
        f"    name: '{name}',\n"
        f"    timestamp: {timestamp},\n"
        f"    entropyHex: '{entropy_hex}',\n"
        f"    id: '{identifier}',\n"
        f"    binaryHex: '{binary_hex}',\n"
        "  ),\n"
    )


# (name, value, shape_well_formed)
#
# shape_well_formed records what `Pikaid.isWellFormed` must answer: the
# documented predicate is shape-only (26 characters from [0-9a-z]) and does not
# look at numeric meaning. Two entries below are 26 lowercase Base36 characters
# that decode beyond 96 bits of randomness: well formed, never valid.
INVALID_TEXT = [
    ("empty", "", False),
    ("25 characters", "0" * 25, False),
    ("27 characters", "0" * 27, False),
    ("1000 characters", "0" * 1000, False),
    ("uppercase timestamp", "000000A0000000000000000000", False),
    ("uppercase entropy", "0000000A000000000000000000", False),
    ("all uppercase", "Z" * 26, False),
    ("hyphen", "0000000-000000000000000000", False),
    ("underscore", "0000000_000000000000000000", False),
    ("space", "0000000 000000000000000000", False),
    ("leading space", " " + "0" * 25, False),
    ("trailing space", "0" * 25 + " ", False),
    ("CRLF suffix", "0" * 26 + "\r\n", False),
    ("LF suffix", "0" * 26 + "\n", False),
    ("NUL", "0000000" + "\u0000" + "0" * 18, False),
    ("zero width space", "0000000" + "\u200b" + "0" * 18, False),
    ("non-breaking space", "0000000" + "\u00a0" + "0" * 18, False),
    ("non-ASCII letter", "0000000" + "\u00e9" + "0" * 18, False),
    ("astral code points", "\U0001f600" * 13, False),
    (
        "randomness is exactly 2^96",
        base36(0, TIMESTAMP_CHARS) + base36(2**96, RANDOMNESS_CHARS),
        True,
    ),
    (
        "randomness is 36^19-1",
        base36(0, TIMESTAMP_CHARS) + "z" * RANDOMNESS_CHARS,
        True,
    ),
    ("randomness 36^19", base36(0, TIMESTAMP_CHARS) + base36(36**19, 20), False),
    ("timestamp overflow only", base36(36**7, TIMESTAMP_CHARS + 1) + "0" * 19, False),
]

# (name, hex_value)
INVALID_BINARY = [
    ("empty", ""),
    ("one byte", "00"),
    ("five byte timestamp only", "00" * 5),
    ("twelve byte entropy only", "00" * 12),
    ("16 bytes", "00" * 16),
    ("18 bytes", "00" * 18),
    ("34 bytes", "00" * 34),
    ("timestamp 2^37", (2**37).to_bytes(5, "big").hex() + "00" * 12),
    (
        "timestamp max + 1",
        (MAX_TIMESTAMP + 1).to_bytes(5, "big").hex() + "00" * 12,
    ),
    ("timestamp 2^40-1", "ff" * 5 + "00" * 12),
]


def dart_invalid_text(name: str, value: str, well_formed: bool) -> str:
    literal = dart_string(value)
    single = f"    value: {literal},"
    value_lines = (
        single if len(single) <= 80 else f"    value:\n        {literal},"
    )
    return (
        "  (\n"
        f"    name: '{name}',\n"
        + value_lines
        + "\n"
        f"    wellFormed: {str(well_formed).lower()},\n"
        "  ),\n"
    )


def dart_string(value: str) -> str:
    out = []
    for char in value:
        code = ord(char)
        if 0x20 <= code < 0x7F and char not in ("'", "\\", "$"):
            out.append(char)
        elif char == "'":
            out.append("\\'")
        elif char == "\\":
            out.append("\\\\")
        elif char == "$":
            out.append("\\$")
        elif code <= 0xFF:
            out.append(f"\\u{code:04x}")
        elif code <= 0xFFFF:
            out.append(f"\\u{code:04x}")
        else:
            out.append(f"\\u{{{code:x}}}")
    return "'" + "".join(out) + "'"


def dart_invalid_binary(name: str, value: str) -> str:
    single = f"  (name: '{name}', value: '{value}'),"
    if len(single) <= 80:
        return single + "\n"
    # Mirrors the layout `dart format` produces for an over-long entry. The
    # string literal deliberately has no trailing comma; adding one would make
    # the formatter choose a different (non-idempotent) layout.
    return (
        "  (\n"
        f"    name: '{name}',\n"
        "    value:\n"
        f"        '{value}'\n"
        "  ),\n"
    )


HEADER = """// Generated by tool/generate_conformance_cases.py. Do not edit by hand.
//
// Expected values come from an independent Python BigInt implementation of
// pikaid specification revision 1.0.4 (pinned commit
// 17014d76f568c3ac9f9ce2927c1a018fdbc36d1d), never from package:pikaid.
//
// This file is deliberately free of dart:io and dart:mirrors so the same
// fixtures run on the VM, dart2js in Node and dart2js in a real browser.
library;

/// One canonical (timestamp, randomness) pair and its two representations.
typedef ConformanceCase = ({
  String name,
  int timestamp,
  String entropyHex,
  String id,
  String binaryHex,
});

/// One text representation that `Pikaid.parse` must reject.
///
/// [wellFormed] is the answer `Pikaid.isWellFormed` must give. The documented
/// predicate is shape-only, so a 26-character lowercase Base36 string whose
/// randomness decodes beyond 2^96-1 is well formed but never valid.
typedef InvalidTextCase = ({String name, String value, bool wellFormed});

/// One binary representation that `Pikaid.fromBinary` must reject.
typedef InvalidBinaryCase = ({String name, String value});

/// The pinned cross-representation conformance matrix.
const List<ConformanceCase> conformanceCases = <ConformanceCase>[
"""

MIDDLE = """];

/// Text representations that must never parse.
const List<InvalidTextCase> invalidConformanceText = <InvalidTextCase>[
"""

MIDDLE_TWO = """];

/// Binary representations that must never parse.
const List<InvalidBinaryCase> invalidConformanceBinary = <InvalidBinaryCase>[
"""

FOOTER = """];

/// Counts used by tests to detect accidental truncation of this table.
const int conformanceCaseCount = 19;
const int invalidTextCaseCount = 23;
const int invalidBinaryCaseCount = 10;
"""


def main() -> int:
    valid = "".join(dart_case(*case) for case in CASES)
    invalid_text = "".join(dart_invalid_text(*case) for case in INVALID_TEXT)
    invalid_binary = "".join(dart_invalid_binary(*case) for case in INVALID_BINARY)
    for name, value, well_formed in INVALID_TEXT:
        dart_length = len(value.encode("utf-16-le")) // 2
        shape = dart_length == 26 and all(char in ALPHABET for char in value)
        if shape != well_formed:
            raise SystemExit(
                f"{name}: wellFormed flag {well_formed} disagrees with shape {shape}"
            )
    output = HEADER + valid + MIDDLE + invalid_text + MIDDLE_TWO + invalid_binary + FOOTER
    if len(CASES) != 19 or len(INVALID_TEXT) != 23 or len(INVALID_BINARY) != 10:
        raise SystemExit("update the pinned counts in FOOTER before generating")
    root = Path(__file__).resolve().parent.parent
    target = root / "test/support/conformance_cases.dart"
    changed = not target.exists() or target.read_text() != output
    if changed:
        target.write_text(output)
        print(f"wrote {target.relative_to(root)}")
    else:
        print(f"{target.relative_to(root)} is up to date")
    return 0


if __name__ == "__main__":
    sys.exit(main())
