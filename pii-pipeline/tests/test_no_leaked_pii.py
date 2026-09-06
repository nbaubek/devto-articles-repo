"""The CI guardrail (Part 3, tying back to Part 1's contracts).

If a pipeline change leaks direct PII into the curated zone, or an analyst
view exposes free text, or a new column appears without classification —
the build fails. Better: the PR, not the incident.
"""

from __future__ import annotations

import csv
import subprocess
import sys
from pathlib import Path

import duckdb
import yaml

REPO_ROOT = Path(__file__).resolve().parents[1]
SRC = REPO_ROOT / "src"

sys.path.insert(0, str(SRC))

from pii.pipeline import run_pipeline  # noqa: E402

EMAIL_RE = "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+[.][A-Za-z]{2,}"
PHONE_RE = "[0-9]{3}-[0-9]{3}-[0-9]{4}"
KEY = b"test-key"

# columns where pattern matches are expected by design (free text, kept
# only for the support role) — everything else must be clean
ALLOWLIST = {"support_notes"}


def _run_pipeline(tmp_path: Path) -> Path:
    run_pipeline(
        raw_db=tmp_path / "raw.duckdb",
        curated_db=tmp_path / "curated.duckdb",
        vault_db=tmp_path / "vault.duckdb",
        key=KEY,
    )
    return tmp_path / "curated.duckdb"


def test_curated_zone_has_no_direct_pii(tmp_path: Path) -> None:
    curated_db = _run_pipeline(tmp_path)
    con = duckdb.connect(str(curated_db), read_only=True)
    columns = [
        r[0] for r in con.execute("DESCRIBE curated_customers").fetchall()
        if r[0] not in ALLOWLIST
    ]
    for column in columns:
        for pattern in (EMAIL_RE, PHONE_RE):
            hits = con.execute(
                f"SELECT count(*) FROM curated_customers "
                f"WHERE regexp_matches(CAST({column} AS VARCHAR), '{pattern}')"
            ).fetchone()[0]
            assert hits == 0, f"{column} matches PII pattern {pattern} — leak!"


def test_analyst_view_exposes_no_free_text(tmp_path: Path) -> None:
    curated_db = _run_pipeline(tmp_path)
    sys.path.insert(0, str(SRC))
    from pii.serve import create_views

    create_views(curated_db)
    con = duckdb.connect(str(curated_db), read_only=True)
    nulls = con.execute(
        "SELECT count(*) FROM v_customers_analyst WHERE support_notes IS NOT NULL"
    ).fetchone()[0]
    assert nulls == 0


def test_pseudonymization_preserves_joins(tmp_path: Path) -> None:
    curated_db = _run_pipeline(tmp_path)
    con = duckdb.connect(str(curated_db), read_only=True)
    same = con.execute(
        "SELECT count(*) FROM curated_customers WHERE user_pseudo_id = contact_token"
    ).fetchone()[0]
    total = con.execute("SELECT count(*) FROM curated_customers").fetchone()[0]
    # 97% of contact_ref values are the same email -> same HMAC token
    assert same >= int(total * 0.9)


def test_every_column_is_classified() -> None:
    classifications = yaml.safe_load(
        (SRC / "pii" / "classifications.yaml").read_text()
    )["columns"]
    with (REPO_ROOT / "data" / "customers.csv").open() as fh:
        header = next(csv.reader(fh))
    missing = [c for c in header if c not in classifications]
    assert not missing, f"unclassified columns appeared: {missing} — update classifications.yaml"


def test_validate_contract_passes() -> None:
    result = subprocess.run(
        [sys.executable, "-m", "pii.validate_contract"],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, result.stdout + result.stderr
