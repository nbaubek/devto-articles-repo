"""Rung 3 — free-text scanning with Presidio (Part 1 of the series).

Regexes die in prose; Presidio (Microsoft, open source) reads free text with
NER + pattern recognizers and returns scored entity spans.

Note on the model: the default Presidio engine expects the *large* spacy
model (~800 MB). We wire it to en_core_web_sm (~12 MB) so `uv sync` is all
the setup a reader needs. NER quality drops slightly; fine for a demo.
"""

from __future__ import annotations

import csv
from pathlib import Path

from presidio_analyzer import AnalyzerEngine
from presidio_analyzer.nlp_engine import NlpEngineProvider

DEFAULT_CSV = Path(__file__).resolve().parents[2] / "data" / "customers.csv"

NLP_CONFIG = {
    "nlp_engine_name": "spacy",
    "models": [{"lang_code": "en", "model_name": "en_core_web_sm"}],
}


def get_analyzer() -> AnalyzerEngine:
    provider = NlpEngineProvider(nlp_configuration=NLP_CONFIG)
    return AnalyzerEngine(nlp_engine=provider.create_engine())


def scan_text(analyzer: AnalyzerEngine, text: str) -> list[tuple[str, str, float]]:
    return [
        (hit.entity_type, text[hit.start : hit.end], round(hit.score, 2))
        for hit in analyzer.analyze(text=text, language="en")
    ]


def main() -> None:
    analyzer = get_analyzer()
    with DEFAULT_CSV.open() as fh:
        notes = [row["support_notes"] for row in csv.DictReader(fh)]

    scanned = 0
    for note in notes:
        if "@" not in note:  # only scan notes that plausibly contain PII
            continue
        hits = scan_text(analyzer, note)
        if not hits:
            continue
        print(f"\n{note[:72]}...")
        for entity_type, value, score in hits:
            print(f"  {entity_type:<14} {value:<28} {score}")
        scanned += 1
        if scanned == 3:
            break


if __name__ == "__main__":
    main()
