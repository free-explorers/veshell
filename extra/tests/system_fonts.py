#!/usr/bin/env python3
"""Check distribution fonts in the runtime's Fontconfig environment.

Run from any directory with Python 3 and fc-match. No font downloads or font
parsing dependencies. Flutter unit tests cannot verify host font availability.
"""

import json
from pathlib import Path
import subprocess
import sys
import unicodedata

FAMILIES = (
    "Roboto",
    "Noto Sans",
    "Noto Sans Arabic",
    "Noto Sans Bengali",
    "Noto Sans Devanagari",
    "Noto Sans CJK SC",
    "Noto Sans CJK TC",
    "Noto Sans CJK JP",
    "Noto Sans CJK KR",
)
WEIGHTS = ("regular", "medium", "bold")
CATALOGS = Path(__file__).resolve().parents[2] / "src/shell/lib/l10n"


def charset(value):
    characters = set()
    for token in value.split():
        bounds = token.split("-")
        start = int(bounds[0], 16)
        end = int(bounds[-1], 16)
        characters.update(range(start, end + 1))
    return characters


def main():
    errors = []
    coverage = {weight: set() for weight in WEIGHTS}
    for family in FAMILIES:
        for weight in WEIGHTS:
            result = subprocess.run(
                ["fc-match", "--format=%{family}\n%{charset}\n", f"{family}:weight={weight}"],
                check=True,
                capture_output=True,
                text=True,
            )
            lines = result.stdout.splitlines()
            if len(lines) < 2:
                errors.append(f"{family} ({weight}): no Fontconfig match/charset")
                continue
            if family not in lines[0].split(","):
                errors.append(f"{family} ({weight}): substituted with {lines[0]}")
                continue
            coverage[weight].update(charset(lines[1]))

    catalogs = sorted(CATALOGS.glob("app_*.arb"))
    if not catalogs:
        errors.append(f"No translation catalogs in {CATALOGS}")
    for path in catalogs:
        catalog = json.loads(path.read_text(encoding="utf-8"))
        characters = {
            ord(character)
            for key, value in catalog.items()
            if not key.startswith("@")
            for character in value
            if unicodedata.category(character) not in ("Cc", "Cf")
        }
        for weight, available in coverage.items():
            missing = characters - available
            if missing:
                codes = ", ".join(f"U+{code:04X}" for code in sorted(missing))
                errors.append(f"{path.name} ({weight}): missing {codes}")

    if errors:
        print("System font check failed:", file=sys.stderr)
        for error in errors:
            print(f"  {error}", file=sys.stderr)
        print("Install the runtime packages in docs/dependencies.md.", file=sys.stderr)
        return 1
    print(f"All {len(FAMILIES)} system families resolve; {len(catalogs)} catalogs covered at all weights.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, subprocess.CalledProcessError) as error:
        print(f"Cannot run system font check: {error}", file=sys.stderr)
        sys.exit(1)
