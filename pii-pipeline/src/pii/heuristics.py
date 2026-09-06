"""Rung 1 — column-name heuristics (Part 1 of the series).

Regex over schema names: cheapest detection there is, runs in CI on every
schema change, and completely defeated by lying or cryptic column names.
"""

from __future__ import annotations

import csv
import re
from pathlib import Path

PATTERNS: dict[str, str] = {
    "email": r"e[-_]?mail",
    "phone": r"\bphone\b|\bmobile\b|\btel\b",
    "ssn": r"\bssn\b|social",
    "dob": r"\bdob\b|birth",
    "name": r"first[-_ ]?name|last[-_ ]?name|full[-_ ]?name",
}

DEFAULT_CSV = Path(__file__).resolve().parents[2] / "data" / "customers.csv"


def scan_column(name: str) -> list[str]:
    return [
        label
        for label, pattern in PATTERNS.items()
        if re.search(pattern, name, flags=re.IGNORECASE)
    ]


def scan_columns(names: list[str]) -> dict[str, list[str]]:
    return {name: scan_column(name) for name in names}


def read_header(csv_path: Path = DEFAULT_CSV) -> list[str]:
    with csv_path.open() as fh:
        return next(csv.reader(fh))


def main() -> None:
    flags = scan_columns(read_header())
    for column, labels in flags.items():
        print(f"{column:<14} → {labels}")


if __name__ == "__main__":
    main()
