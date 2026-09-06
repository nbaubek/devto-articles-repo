"""Serving layer (Part 3): role-based views over the curated zone.

DuckDB has no native masking policies, so we simulate the warehouse feature
with views — honestly labelled as a simulation. In production this is
Snowflake dynamic masking / BigQuery column-level security (see the article
for the production SQL).
"""

from __future__ import annotations

from pathlib import Path

import duckdb

REPO_ROOT = Path(__file__).resolve().parents[2]
CURATED_DB = REPO_ROOT / "curated.duckdb"


def create_views(curated_db: Path = CURATED_DB) -> None:
    con = duckdb.connect(str(curated_db))

    # analysts: the default surface. No free text, no direct identifiers.
    con.execute(
        """
        CREATE OR REPLACE VIEW v_customers_analyst AS
        SELECT
            customer_id,
            user_pseudo_id,
            phone_masked,
            zip3,
            birth_year,
            NULL AS support_notes      -- redact_on_read, from classifications.yaml
        FROM curated_customers
        """
    )

    # support: needs the free text to actually answer tickets.
    con.execute(
        """
        CREATE OR REPLACE VIEW v_customers_support AS
        SELECT
            customer_id,
            user_pseudo_id,
            phone_masked,
            support_notes
        FROM curated_customers
        """
    )
    con.close()


def main() -> None:
    create_views()
    con = duckdb.connect(str(CURATED_DB), read_only=True)

    print("analyst sees:")
    for row in con.execute("SELECT * FROM v_customers_analyst LIMIT 3").fetchall():
        print(f"  {row}")

    print("\nsupport sees:")
    for row in con.execute("SELECT * FROM v_customers_support WHERE support_notes LIKE '%@%' LIMIT 2").fetchall():
        print(f"  {row}")
    con.close()


if __name__ == "__main__":
    main()
