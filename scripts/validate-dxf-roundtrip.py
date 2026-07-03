#!/usr/bin/env python3
"""Compare numeric ENTITIES section values between two ASCII DXF files.

Extracts group codes 10, 11, 20, 21, 30, 31, 40, 50, 51, and 42 from the
ENTITIES section of each file and reports the maximum absolute difference
between corresponding values (in file order).

Usage: python3 scripts/validate-dxf-roundtrip.py original.dxf roundtrip.dxf [--fail-above TOLERANCE]
"""
from __future__ import annotations

import argparse
import sys

NUMERIC_CODES = {10, 11, 20, 21, 30, 31, 40, 50, 51, 42}


def read_pairs(path: str) -> list[tuple[int, str]]:
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        lines = [line.rstrip("\r\n") for line in fh]

    pairs: list[tuple[int, str]] = []
    i = 0
    while i + 1 < len(lines):
        try:
            code = int(lines[i].strip())
        except ValueError as exc:
            raise ValueError(f"{path}: invalid group code at line {i + 1}: {lines[i]!r}") from exc
        pairs.append((code, lines[i + 1]))
        i += 2
    return pairs


def extract_entities_numbers(pairs: list[tuple[int, str]]) -> list[tuple[int, float]]:
    in_entities = False
    values: list[tuple[int, float]] = []

    for code, value in pairs:
        if code == 0 and value == "SECTION":
            in_entities = False
        elif code == 2 and value == "ENTITIES":
            in_entities = True
        elif code == 0 and value == "ENDSEC" and in_entities:
            in_entities = False
        elif in_entities and code in NUMERIC_CODES:
            try:
                values.append((code, float(value)))
            except ValueError as exc:
                raise ValueError(f"non-numeric ENTITIES value for code {code}: {value!r}") from exc

    return values


def main() -> int:
    parser = argparse.ArgumentParser(description="Compare numeric ENTITIES values between two ASCII DXF files.")
    parser.add_argument("original", help="Original DXF path")
    parser.add_argument("roundtrip", help="Round-trip DXF path")
    parser.add_argument(
        "--fail-above",
        type=float,
        default=None,
        help="Exit with code 1 if max absolute difference exceeds this tolerance",
    )
    args = parser.parse_args()

    original_path, roundtrip_path = args.original, args.roundtrip

    try:
        original_values = extract_entities_numbers(read_pairs(original_path))
        roundtrip_values = extract_entities_numbers(read_pairs(roundtrip_path))
    except (OSError, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    if len(original_values) != len(roundtrip_values):
        print(
            f"warning: value count mismatch "
            f"(original={len(original_values)}, roundtrip={len(roundtrip_values)})"
        )

    compare_count = min(len(original_values), len(roundtrip_values))
    max_diff = 0.0
    max_index = -1
    max_pair = (0, 0.0, 0.0)

    for index in range(compare_count):
        code_a, value_a = original_values[index]
        code_b, value_b = roundtrip_values[index]
        if code_a != code_b:
            print(
                f"warning: group code mismatch at index {index}: "
                f"{code_a} vs {code_b}"
            )
        diff = abs(value_a - value_b)
        if diff > max_diff:
            max_diff = diff
            max_index = index
            max_pair = (code_a, value_a, value_b)

    print(f"Compared {compare_count} numeric ENTITIES value(s).")
    print(f"Max absolute difference: {max_diff:.15g}")
    if max_index >= 0:
        code, original_value, roundtrip_value = max_pair
        print(
            f"  at index {max_index} (group {code}): "
            f"{original_value:.15g} vs {roundtrip_value:.15g}"
        )

    if args.fail_above is not None and max_diff > args.fail_above:
        print(f"FAIL: max difference {max_diff:.15g} exceeds tolerance {args.fail_above:.15g}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
