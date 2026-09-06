# pii-pipeline

Companion repo for the **Handling PII in Data Pipelines** article series (Dev.to):

1. **You Can't Protect What You Can't Find** — detection & classification
2. **Mask, Hash, Tokenize, or Encrypt?** — choosing a technique
3. **From Detection to Production** — the end-to-end pipeline

Everything runs locally: Python + DuckDB, no warehouse, no Docker, no accounts.

## Quickstart

```console
uv sync                          # deps + the small spacy model for Presidio
uv run pytest                    # the CI guardrail — should be green
```

The messy demo data ships in `data/customers.csv`. It is synthetic (Faker,
seed 42, reserved 555 phone range) — no real people. Regenerate it with
`uv run python -m pii.generate_data`.

## Module map

| Command | Article | What it shows |
| ------- | ------- | ------------- |
| `uv run python -m pii.heuristics` | Part 1 · rung 1 | column-name heuristics catch honest names, miss liars |
| `uv run python -m pii.profile_scan` | Part 1 · rung 2 | content profiling catches `contact_ref` (97% emails) |
| `uv run python -m pii.presidio_scan` | Part 1 · rung 3 | Presidio finds identities inside free text |
| `uv run python -m pii.validate_contract` | Part 1 | data contract vs. detection — undeclared PII fails the build |
| `uv run python -m pii.hashing_demo` | Part 2 | sha256 vs salted vs HMAC: the join-key dilemma |
| `uv run python -m pii.pipeline` | Part 3 | raw → curated (+ vault): pseudonymize, mask, generalize |
| `uv run python -m pii.serve` | Part 3 | role-based views (analyst vs support) |
| `uv run python -m pii.erasure jane.doe@example.com` | Part 3 | GDPR erasure propagated across all three zones |

## The three zones (Part 3)

| File | Zone | Access story |
| ---- | ---- | ------------ |
| `raw.duckdb` | landing | unmasked **by design** — restrict access, set retention |
| `curated.duckdb` | analytics | pseudonyms, masked phones, generalized quasi-identifiers |
| `vault.duckdb` | reversal | token → identity; compromise this and pseudonyms are plaintext |

Regenerate everything: `rm -f *.duckdb && uv run python -m pii.pipeline`.

## The key

`PII_HMAC_KEY` env var feeds the pseudonymization. Unset, the pipeline falls
back to a loudly-announced dev key. In production: secrets manager → env, and
version your keys (`tok_v2:abc123...`) so rotation doesn't orphan your joins.

## Honest limitations

Presidio scores are probabilistic; role "views" simulate warehouse masking
policies (Snowflake/BigQuery own that layer in production); erasure here
ignores backups — that's what crypto-shredding is for.
