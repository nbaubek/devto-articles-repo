"""Protection primitives (Part 2), used by the pipeline (Part 3).

Three flavors, one theme: choose deliberately, not by default.
  - masking         : irreversible, format-preserving-ish, for display
  - hashing / HMAC  : irreversible, deterministic -> join keys that survive
  - (tokenization   : reversible via the vault, shown in pipeline.py)
"""

from __future__ import annotations

import hashlib
import hmac
import os

DEV_KEY = b"dev-only-key-do-not-use-in-production"


def load_hmac_key() -> bytes:
    """Read the pseudonymization key from the environment.

    Set PII_HMAC_KEY in production (secrets manager -> env). The dev fallback
    exists so the demo runs out of the box, and it announces itself loudly.
    """
    key = os.environ.get("PII_HMAC_KEY")
    if key:
        return key.encode()
    print("warning: PII_HMAC_KEY not set — using the dev-only key. Fine for the")
    print("warning: demo, a firing offence in production.")
    return DEV_KEY


def mask_email(value: str) -> str:
    """jane.doe@example.com -> j***@example.com (irreversible, display-safe)."""
    user, _, domain = value.partition("@")
    return f"{user[:1]}***@{domain}" if user and domain else "***"


def mask_phone(value: str) -> str:
    """555-010-8899 -> ***-***-8899 (keeps the suffix support teams need)."""
    return f"***-***-{value[-4:]}"


def pseudonymize(value: str, key: bytes) -> str:
    """HMAC-SHA256, truncated. Deterministic (joins survive), keyed (rainbow
    tables and dictionary attacks need your secret), irreversible (the vault
    is what gives you reversibility — see pipeline.py)."""
    return hmac.new(key, value.encode(), hashlib.sha256).hexdigest()[:16]
