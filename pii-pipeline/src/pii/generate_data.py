"""Generate the deliberately messy demo dataset (data/customers.csv).

Seeded, so the numbers quoted in the articles are reproducible:
  - contact_ref   contains emails in 291/300 rows (97%)
  - support_notes contains embedded PII in 24/300 rows (8%)

All values are synthetic (Faker + reserved 555 phone range). No real humans.
"""

from __future__ import annotations

import csv
import random
from pathlib import Path

from faker import Faker

SEED = 42
ROWS = 300
EMAIL_FRACTION = 0.97  # of contact_ref
NOTES_PII_FRACTION = 0.08  # of support_notes

BORING_NOTES = [
    "Question about my last invoice.",
    "Thanks — this got resolved, closing.",
    "How do I change my billing address?",
    "The dashboard shows yesterday's orders twice?",
    "Please add VAT to our receipts.",
    "Just checking the return policy for damaged boxes.",
    "Can we get the invoice as PDF instead?",
    "Shipping took longer than the estimate, just FYI.",
]

DATA_DIR = Path(__file__).resolve().parents[2] / "data"
CSV_PATH = DATA_DIR / "customers.csv"

FIELDS = [
    "customer_id",
    "email",
    "phone",
    "first_name",
    "last_name",
    "zip",
    "dob",
    "contact_ref",
    "support_notes",
]


def build_rows() -> list[dict[str, str]]:
    Faker.seed(SEED)
    random.seed(SEED)
    fake = Faker("en_US")

    email_rows = set(random.sample(range(ROWS), round(ROWS * EMAIL_FRACTION)))
    pii_note_rows = set(random.sample(range(ROWS), round(ROWS * NOTES_PII_FRACTION)))

    rows: list[dict[str, str]] = []
    for i in range(ROWS):
        email = fake.unique.email(domain="example.com")
        first = fake.first_name()
        last = fake.last_name()
        phone = f"555-{fake.random_int(100, 999)}-{fake.random_int(1000, 9999)}"
        row = {
            "customer_id": str(fake.uuid4()),
            "email": email,
            "phone": phone,
            "first_name": first,
            "last_name": last,
            "zip": fake.zipcode(),
            "dob": fake.date_of_birth(minimum_age=18, maximum_age=90).isoformat(),
            # 97% of the time, "contact_ref" is just... the email. Lying column.
            "contact_ref": email if i in email_rows else f"CR-{fake.random_int(10000, 99999)}",
            "support_notes": (
                f"Hi, this is {first} {last} — order #{fake.random_int(1000, 9999)} never "
                f"arrived. I'm at {email}, or call me at {phone}. Billing zip is {fake.zipcode()}."
                if i in pii_note_rows
                else random.choice(BORING_NOTES)
            ),
        }
        rows.append(row)
    return rows


def main() -> None:
    DATA_DIR.mkdir(exist_ok=True)
    rows = build_rows()
    with CSV_PATH.open("w", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=FIELDS)
        writer.writeheader()
        writer.writerows(rows)
    print(f"wrote {len(rows)} rows -> {CSV_PATH}")
    print(f"  contact_ref emails : {sum('@' in r['contact_ref'] for r in rows)}/{len(rows)}")
    print(f"  notes with PII     : {sum('@' in r['support_notes'] for r in rows)}/{len(rows)}")


if __name__ == "__main__":
    main()
