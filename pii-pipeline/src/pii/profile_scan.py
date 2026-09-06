"""Rung 2 — content profiling with DuckDB (Part 1 of the series).

Stop trusting column names and ask the data instead: for every column,
compute the fraction of non-null values that match a PII pattern, and flag
anything above FLAG_THRESHOLD. Catches `contact_ref`; still blind to PII
buried in free text at low rates.
"""

from __future__ import annotations

from pathlib import Path

import duckdb

DEFAULT_CSV = (Path(__file__).resolve().parents[2] / "data" / "customers.csv").resolve()

# Unanchored on purpose: a value "counts" if it contains a match anywhere.
PATTERNS: dict[str, str] = {
    "email": "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+[.][A-Za-z]{2,}",
    "phone": "[0-9]{3}-[0-9]{3}-[0-9]{4}",
    "ssn": "[0-9]{3}-[0-9]{2}-[0-9]{4}",
}

FLAG_THRESHOLD = 0.8

RATIO_QUERY = """
SELECT
  '{pattern_name}' AS pattern,
  round(avg(CASE WHEN regexp_matches(CAST("{column}" AS VARCHAR), '{pattern}')
                 THEN 1.0 ELSE 0.0 END), 2) AS ratio
FROM read_csv_auto('{csv_path}')
WHERE "{column}" IS NOT NULL
"""


def profile(csv_path: Path = DEFAULT_CSV) -> dict[str, dict[str, float]]:
    """Return {column: {pattern: ratio}} for every text column in the file."""
    con = duckdb.connect()
    columns = [
        r[0]
        for r in con.execute(f"DESCRIBE SELECT * FROM read_csv_auto('{csv_path}')").fetchall()
    ]
    results: dict[str, dict[str, float]] = {}
    for column in columns:
        ratios: dict[str, float] = {}
        for pattern_name, pattern in PATTERNS.items():
            query = RATIO_QUERY.format(
                pattern_name=pattern_name,
                pattern=pattern,
                column=column,
                csv_path=csv_path,
            )
            ratios[pattern_name] = con.execute(query).fetchone()[1] or 0.0
        results[column] = ratios
    con.close()
    return results


def flagged(profile_result: dict[str, dict[str, float]]) -> dict[str, list[str]]:
    return {
        column: [p for p, ratio in ratios.items() if ratio >= FLAG_THRESHOLD]
        for column, ratios in profile_result.items()
        if any(ratio >= FLAG_THRESHOLD for ratio in ratios.values())
    }


def main() -> None:
    result = profile()
    for column, ratios in result.items():
        pretty = "  ".join(f"{name}={ratio:.2f}" for name, ratio in ratios.items())
        flag = "  FLAGGED" if any(r >= FLAG_THRESHOLD for r in ratios.values()) else ""
        print(f"{column:<14} {pretty}{flag}")


if __name__ == "__main__":
    main()
