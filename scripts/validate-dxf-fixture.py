#!/usr/bin/env python3
"""Validate that an ASCII DXF fixture contains expected entity types.

Usage: python3 scripts/validate-dxf-fixture.py path/to/sample.dxf
"""
from __future__ import annotations

import sys

REQUIRED_ENTITIES = (
    "LINE",
    "CIRCLE",
    "ARC",
    "ELLIPSE",
    "LWPOLYLINE",
    "TEXT",
    "HATCH",
    "DIMENSION",
)


def read_pairs(path: str) -> list[tuple[int, str]]:
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        lines = [line.rstrip("\r\n") for line in fh]

    pairs: list[tuple[int, str]] = []
    i = 0
    while i + 1 < len(lines):
        code = int(lines[i].strip())
        pairs.append((code, lines[i + 1]))
        i += 2
    return pairs


def entity_types_in_entities_section(pairs: list[tuple[int, str]]) -> list[str]:
    in_entities = False
    types: list[str] = []

    for code, value in pairs:
        if code == 0 and value == "SECTION":
            in_entities = False
        elif code == 2 and value == "ENTITIES":
            in_entities = True
        elif code == 0 and value == "ENDSEC" and in_entities:
            in_entities = False
        elif in_entities and code == 0 and value not in {"SECTION", "ENDSEC"}:
            types.append(value)

    return types


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: python3 scripts/validate-dxf-fixture.py sample.dxf", file=sys.stderr)
        return 2

    path = sys.argv[1]
    try:
        pairs = read_pairs(path)
        found = entity_types_in_entities_section(pairs)
    except (OSError, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    missing = [name for name in REQUIRED_ENTITIES if name not in found]
    if missing:
        print(f"Missing entity type(s) in ENTITIES section of {path}: {', '.join(missing)}")
        print(f"Found: {', '.join(found)}")
        return 1

    print(f"OK: {path} contains all required entity types ({len(REQUIRED_ENTITIES)}).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
