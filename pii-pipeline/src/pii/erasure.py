"""GDPR erasure, propagated (Part 3).

Deleting "a user" is not one DELETE. The same person lives in three places:
the vault (identity), the curated zone (pseudonym), and raw (plaintext).
Usage: uv run python -m pii.erasure jane.doe@example.com
"""

from __future__ import annotations

import sys
from pathlib import Path

import duckdb

from .masking import load_hmac_key, pseudonymize

REPO_ROOT = Path(__file__).resolve().parents[2]


def erase(email: str, repo_root: Path = REPO_ROOT, key: bytes | None = None) -> dict[str, int]:
    key = key or load_hmac_key()
    token = pseudonymize(email, key)

    vault = duckdb.connect(str(repo_root / "vault.duckdb"))
    curated = duckdb.connect(str(repo_root / "curated.duckdb"))
    raw = duckdb.connect(str(repo_root / "raw.duckdb"))

    deleted = {
        "vault": vault.execute("DELETE FROM token_vault WHERE token = ?", [token]).fetchone()[0],
        "curated": curated.execute(
            "DELETE FROM curated_customers WHERE user_pseudo_id = ?", [token]
        ).fetchone()[0],
        "raw": raw.execute("DELETE FROM raw_customers WHERE email = ?", [email]).fetchone()[0],
    }
    for con in (vault, curated, raw):
        con.close()
    return deleted


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit("usage: uv run python -m pii.erasure <email>")
    email = sys.argv[1]
    deleted = erase(email)
    for zone, count in deleted.items():
        print(f"{zone:<8} deleted {count} row(s)")
    print("\nbackups: not covered here — that's what crypto-shredding is for.")


if __name__ == "__main__":
    main()
