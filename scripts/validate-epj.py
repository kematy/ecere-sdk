#!/usr/bin/env python3
"""Validate that all Ecere project files (.epj) are well-formed JSON.

Usage: python3 scripts/validate-epj.py [root]

Exits non-zero and prints the offending files if any .epj file fails to parse.
"""
import json
import os
import sys


def main() -> int:
    root = sys.argv[1] if len(sys.argv) > 1 else "."
    failures = []
    checked = 0
    legacy = []

    for dirpath, _dirnames, filenames in os.walk(root):
        if os.sep + ".git" in dirpath:
            continue
        for name in filenames:
            if not name.endswith(".epj"):
                continue
            path = os.path.join(dirpath, name)
            try:
                with open(path, "r", encoding="utf-8") as fh:
                    content = fh.read()
            except OSError as exc:
                failures.append((path, str(exc)))
                continue

            # Modern .epj projects (version 0.2+) are JSON and start with '{'.
            # Older projects use a legacy text format; skip those.
            if not content.lstrip().startswith("{"):
                legacy.append(path)
                continue

            checked += 1
            try:
                json.loads(content)
            except ValueError as exc:
                failures.append((path, str(exc)))

    print(f"Checked {checked} JSON .epj file(s).")
    if legacy:
        print(f"Skipped {len(legacy)} legacy-format .epj file(s):")
        for path in legacy:
            print(f"  {path}")
    if failures:
        print(f"{len(failures)} invalid .epj file(s):")
        for path, err in failures:
            print(f"  {path}: {err}")
        return 1

    print("All JSON .epj files are valid.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
