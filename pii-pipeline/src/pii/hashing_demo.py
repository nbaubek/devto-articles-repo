"""The join-key dilemma, demonstrated (Part 2).

Five customer phone numbers are "leaked" as hashes. An attacker with a
precomputed dictionary of 20,000 candidate phone numbers tries to reverse
them three ways:

  1. plain sha256(phone)   -> dictionary wins. Low-entropy fields fall.
  2. sha256(salt + phone)  -> dictionary loses... but so do your JOINs: the
                              same phone now yields a different digest every
                              time, so joins and distinct counts break.
  3. hmac(key, phone)      -> dictionary loses, JOINs survive. The workhorse.
"""

from __future__ import annotations

import hashlib
import hmac
import random

SEED = 42
DICTIONARY_SIZE = 20_000
LEAKED_COUNT = 5
SECRET_KEY = b"rotate-me-quarterly"  # in production: secrets manager -> env


def make_dictionary() -> list[str]:
    rng = random.Random(SEED)
    return [f"555-{rng.randint(100, 999)}-{rng.randint(1000, 9999)}" for _ in range(DICTIONARY_SIZE)]


def sha256_plain(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()[:16]


def sha256_salted(value: str, salt: str) -> str:
    return hashlib.sha256((salt + value).encode()).hexdigest()[:16]


def hmac_keyed(value: str, key: bytes) -> str:
    return hmac.new(key, value.encode(), hashlib.sha256).hexdigest()[:16]


def main() -> None:
    dictionary = make_dictionary()
    leaked = dictionary[:LEAKED_COUNT]
    rng = random.Random(SEED)
    key = SECRET_KEY

    # the attacker precomputes a lookup table from the dictionary
    rainbow = {sha256_plain(p): p for p in dictionary}

    print(f"leaked: {LEAKED_COUNT} phone numbers, each appearing twice (as if in two tables)")
    print(f"attacker: precomputed dictionary of {DICTIONARY_SIZE:,} candidate phones\n")

    # 1. plain sha256 — deterministic, unkeyed
    cracked_plain = sum(sha256_plain(p) in rainbow for p in leaked)
    print(f"1. sha256(phone)")
    print(f"   cracked by dictionary : {cracked_plain}/{LEAKED_COUNT}")
    print(f"   same phone, same digest (joins work): YES — for the attacker too\n")

    # 2. per-row random salt — the "obvious fix"
    salted = [sha256_salted(p, f"{rng.randrange(2**32):08x}") for p in leaked for _ in range(2)]
    cracked_salted = sum(h in rainbow for h in salted)
    print(f"2. sha256(salt + phone)")
    print(f"   cracked by dictionary : {cracked_salted}/{LEAKED_COUNT * 2}")
    print(f"   same phone, same digest (joins work): NO — broken for everyone\n")

    # 3. HMAC — keyed, deterministic
    hmacs = [hmac_keyed(p, key) for p in leaked]
    cracked_hmac = sum(h in rainbow for h in hmacs)
    stable = hmac_keyed(leaked[0], key) == hmac_keyed(leaked[0], key)
    print(f"3. hmac(key, phone)")
    print(f"   cracked by dictionary : {cracked_hmac}/{LEAKED_COUNT} (key unknown)")
    print(f"   same phone, same digest (joins work): {'YES' if stable else 'NO'} — attacker needs the key")


if __name__ == "__main__":
    main()
