#!/usr/bin/env python3
"""Compare numeric ENTITIES section values between two ASCII DXF files.

Compares numeric group codes within each ENTITIES record (LINE, SPLINE, etc.)
so mixed entity types (DIMENSION vs SPLINE sharing group 11/21/31) compare correctly.

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


def extract_entity_blocks(pairs: list[tuple[int, str]]) -> list[tuple[str, list[tuple[int, float]]]]:
    in_entities = False
    blocks: list[tuple[str, list[tuple[int, float]]]] = []
    current_type = ""
    current_values: list[tuple[int, float]] = []

    def flush() -> None:
        nonlocal current_type, current_values
        if current_type:
            blocks.append((current_type, current_values))
        current_type = ""
        current_values = []

    for code, value in pairs:
        if code == 0 and value == "SECTION":
            in_entities = False
        elif code == 2 and value == "ENTITIES":
            in_entities = True
        elif code == 0 and value == "ENDSEC" and in_entities:
            flush()
            in_entities = False
        elif in_entities and code == 0:
            flush()
            current_type = value
        elif in_entities and current_type and code in NUMERIC_CODES:
            try:
                current_values.append((code, float(value)))
            except ValueError as exc:
                raise ValueError(f"non-numeric ENTITIES value for code {code}: {value!r}") from exc

    if in_entities:
        flush()

    return blocks


def extract_entities_numbers(pairs: list[tuple[int, str]]) -> list[tuple[int, float]]:
    values: list[tuple[int, float]] = []
    for _entity_type, block in extract_entity_blocks(pairs):
        values.extend(block)
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
        original_pairs = read_pairs(original_path)
        roundtrip_pairs = read_pairs(roundtrip_path)
        original_blocks = extract_entity_blocks(original_pairs)
        roundtrip_blocks = extract_entity_blocks(roundtrip_pairs)
        original_values = extract_entities_numbers(original_pairs)
        roundtrip_values = extract_entities_numbers(roundtrip_pairs)
    except (OSError, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    if len(original_blocks) != len(roundtrip_blocks):
        print(
            f"warning: entity count mismatch "
            f"(original={len(original_blocks)}, roundtrip={len(roundtrip_blocks)})"
        )

    entity_compare = min(len(original_blocks), len(roundtrip_blocks))
    max_diff = 0.0
    max_entity = ""
    max_index = -1
    max_pair = (0, 0.0, 0.0)
    compare_count = 0

    for entity_index in range(entity_compare):
        type_a, block_a = original_blocks[entity_index]
        type_b, block_b = roundtrip_blocks[entity_index]
        if type_a != type_b:
            print(f"warning: entity type mismatch at index {entity_index}: {type_a} vs {type_b}")

        block_compare = min(len(block_a), len(block_b))
        if len(block_a) != len(block_b):
            print(
                f"warning: numeric count mismatch for {type_a} #{entity_index} "
                f"(original={len(block_a)}, roundtrip={len(block_b)})"
            )

        for index in range(block_compare):
            code_a, value_a = block_a[index]
            code_b, value_b = block_b[index]
            compare_count += 1
            if code_a != code_b:
                print(
                    f"warning: group code mismatch in {type_a} #{entity_index} at {index}: "
                    f"{code_a} vs {code_b}"
                )
            diff = abs(value_a - value_b)
            if diff > max_diff:
                max_diff = diff
                max_entity = type_a
                max_index = index
                max_pair = (code_a, value_a, value_b)

    if len(original_values) != len(roundtrip_values):
        print(
            f"warning: total value count mismatch "
            f"(original={len(original_values)}, roundtrip={len(roundtrip_values)})"
        )

    print(f"Compared {compare_count} numeric ENTITIES value(s) across {entity_compare} entity record(s).")
    print(f"Max absolute difference: {max_diff:.15g}")
    if max_index >= 0:
        code, original_value, roundtrip_value = max_pair
        print(
            f"  in {max_entity} at value index {max_index} (group {code}): "
            f"{original_value:.15g} vs {roundtrip_value:.15g}"
        )

    if args.fail_above is not None and max_diff > args.fail_above:
        print(f"FAIL: max difference {max_diff:.15g} exceeds tolerance {args.fail_above:.15g}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
