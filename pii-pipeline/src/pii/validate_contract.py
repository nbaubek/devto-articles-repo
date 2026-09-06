"""Reconcile the data contract against detection reality (Part 1).

Three outcomes per column:
  - declared and detected      -> fine
  - declared direct, undetected -> warn: scans can't see it; trust but verify
  - detected, not declared      -> FAIL the build: undeclared PII
Columns missing from the contract entirely also fail the build.
"""

from __future__ import annotations

import sys
from pathlib import Path

import yaml

from .heuristics import read_header, scan_columns
from .profile_scan import flagged, profile

REPO_ROOT = Path(__file__).resolve().parents[2]
CONTRACT_PATH = REPO_ROOT / "contracts" / "customers.v1.yaml"
CSV_PATH = REPO_ROOT / "data" / "customers.csv"


def detect_pii() -> dict[str, set[str]]:
    """Merge rung 1 (names) and rung 2 (content) into {column: labels}."""
    detected: dict[str, set[str]] = {
        col: set(labels) for col, labels in scan_columns(read_header(CSV_PATH)).items()
    }
    for col, patterns in flagged(profile(CSV_PATH)).items():
        detected.setdefault(col, set()).update(patterns)
    return detected


def main() -> int:
    contract = yaml.safe_load(CONTRACT_PATH.read_text())
    declared = contract["columns"]
    detected = detect_pii()

    failures: list[str] = []
    warnings: list[str] = []

    for column in read_header():
        tier = declared.get(column, {}).get("pii_tier")
        labels = detected.get(column, set())

        if tier is None:
            failures.append(f"{column}: not declared in the contract at all")
        elif tier in ("quasi", "free_text"):
            # not machine-checkable by rungs 1-2; the declaration IS the control
            print(f"  ok       {column:<14} declared {tier} (declaration is the control)")
        elif tier == "direct":
            if labels:
                print(f"  ok       {column:<14} declared direct, detected: {sorted(labels)}")
            else:
                warnings.append(f"{column}: declared direct but scans see nothing — verify manually")
        elif tier == "non_pii" and labels:
            failures.append(f"{column}: declared non_pii but detected: {sorted(labels)}")

    for warning in warnings:
        print(f"  WARN     {warning}")
    for failure in failures:
        print(f"  FAIL     {failure}")

    if failures:
        print("\ncontract validation FAILED — undeclared PII detected")
        return 1
    print("\ncontract validation passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
