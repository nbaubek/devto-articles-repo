"""The end-to-end pipeline (Part 3): raw -> curated (+ vault).

Three DuckDB files, standing in for three zones with very different access:

  raw.duckdb     the landing zone. Unmasked by definition — tightly scoped,
                 and short-lived (set a retention job, or don't keep it).
  curated.duckdb the analytics zone. Pseudonymized join keys, masked phones,
                 generalized quasi-identifiers (zip3, birth_year).
  vault.duckdb   the tokenization vault. Maps pseudonyms back to identities
                 for authorized reversal only. Compromise this and the
                 pseudonyms become plaintext; guard it accordingly.

Policy comes from src/pii/classifications.yaml (Part 1's output) and the
HMAC key comes from the environment (Part 2's decision).
"""

from __future__ import annotations

import csv
from pathlib import Path

import duckdb
import yaml

from .masking import load_hmac_key, mask_phone, pseudonymize

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CSV = REPO_ROOT / "data" / "customers.csv"
CLASSIFICATIONS = Path(__file__).resolve().parent / "classifications.yaml"

# tier -> action (the Part 2 decision table, encoded)
POLICY: dict[str, str] = {
    "direct": "pseudonymize-or-drop",
    "quasi": "generalize",
    "free_text": "keep-restricted",
    "non_pii": "pass-through",
}


def run_pipeline(
    csv_path: Path = DEFAULT_CSV,
    raw_db: Path = REPO_ROOT / "raw.duckdb",
    curated_db: Path = REPO_ROOT / "curated.duckdb",
    vault_db: Path = REPO_ROOT / "vault.duckdb",
    key: bytes | None = None,
) -> dict[str, int]:
    key = key or load_hmac_key()
    tiers = yaml.safe_load(CLASSIFICATIONS.read_text())["columns"]

    with csv_path.open() as fh:
        rows = list(csv.DictReader(fh))

    # -- raw zone: land everything, restricted by access, not by transform ---
    raw = duckdb.connect(str(raw_db))
    raw.execute(
        f"CREATE OR REPLACE TABLE raw_customers AS SELECT * FROM read_csv_auto('{csv_path}')"
    )

    # -- curated zone: apply policy per tier ---------------------------------
    curated = duckdb.connect(str(curated_db))
    curated.execute("DROP TABLE IF EXISTS curated_customers")
    curated.execute(
        """
        CREATE TABLE curated_customers (
            customer_id   VARCHAR,
            user_pseudo_id VARCHAR,   -- hmac(email): the join key
            contact_token VARCHAR,    -- hmac(contact_ref): same person, same key
            phone_masked  VARCHAR,
            zip3          VARCHAR,    -- generalized quasi-identifier
            birth_year    INT,        -- generalized quasi-identifier
            support_notes VARCHAR     -- kept for the support role, NULL in analyst views
        )
        """
    )
    curated_rows = [
        (
            row["customer_id"],
            pseudonymize(row["email"], key),
            pseudonymize(row["contact_ref"], key),
            mask_phone(row["phone"]),
            row["zip"][:3],
            int(row["dob"][:4]),
            row["support_notes"],
        )
        for row in rows
    ]
    curated.executemany("INSERT INTO curated_customers VALUES (?, ?, ?, ?, ?, ?, ?)", curated_rows)

    # -- vault: authorized reversibility -------------------------------------
    vault = duckdb.connect(str(vault_db))
    vault.execute("DROP TABLE IF EXISTS token_vault")
    vault.execute(
        """
        CREATE TABLE token_vault (
            token      VARCHAR PRIMARY KEY,
            email      VARCHAR,
            phone      VARCHAR,
            first_name VARCHAR,
            last_name  VARCHAR
        )
        """
    )
    vault.executemany(
        "INSERT INTO token_vault VALUES (?, ?, ?, ?, ?)",
        [
            (pseudonymize(row["email"], key), row["email"], row["phone"], row["first_name"], row["last_name"])
            for row in rows
        ],
    )

    joined = curated.execute(
        """
        SELECT count(*) FROM curated_customers
        WHERE user_pseudo_id = contact_token
          AND length(contact_token) = 16
        """
    ).fetchone()[0]
    con_raw = raw.execute("SELECT count(*) FROM raw_customers").fetchone()[0]
    con_cur = curated.execute("SELECT count(*) FROM curated_customers").fetchone()[0]
    for con in (raw, curated, vault):
        con.close()

    print(f"raw      : {con_raw} rows landed (restricted zone, add retention)")
    print(f"curated  : {con_cur} rows, {joined} with user_pseudo_id = contact_token")
    print(f"vault    : {con_cur} reversible tokens (guard this file)")
    print("joins survive pseudonymization: email and contact_ref -> same token")
    return {"raw": con_raw, "curated": con_cur, "joined": joined}


if __name__ == "__main__":
    run_pipeline()
