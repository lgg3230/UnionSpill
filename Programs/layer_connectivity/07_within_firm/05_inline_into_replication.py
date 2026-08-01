#!/usr/bin/env python3
"""Inline the six within-firm fragments into the replication document.

    ~/.conda/envs/venv_python312/bin/python 05_inline_into_replication.py [--dry-run]

Replaces the text between

    % BEGIN inlined <stem>.tex
    % END inlined <stem>.tex

in UnionSpill-paper/Replication/Replication_Wages vs Hourly.tex with the
current fragment from Tables/layer_connectivity/07_within_firm/<stem>.tex.

Markers are left in place, so this is idempotent and rerunnable after every
re-estimation. Paper mapping: Tables 11/12/13 (monthly) and 23/24/25 (hourly).

Writes into the paper repo, which is a separate Overleaf remote. It only ever
touches text between the markers.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
TABLE_DIR = ROOT / "Tables" / "layer_connectivity" / "07_within_firm"
TARGET = ROOT / "UnionSpill-paper" / "Replication" / "Replication_Wages vs Hourly.tex"

STEMS = [
    "t_layerdesc", "t_groupspecs", "t_horserace",
    "t_layerdesc_hw", "t_groupspecs_hw", "t_horserace_hw",
]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    if not TARGET.exists():
        sys.exit(f"missing target: {TARGET}")
    text = TARGET.read_text()
    original = text

    for stem in STEMS:
        frag = TABLE_DIR / f"{stem}.tex"
        if not frag.exists():
            sys.exit(f"missing fragment: {frag} -- run 02b_make_tables_all.py first")
        begin = f"% BEGIN inlined {stem}.tex"
        end = f"% END inlined {stem}.tex"
        pattern = re.compile(
            re.escape(begin) + r".*?" + re.escape(end), re.DOTALL)
        if not pattern.search(text):
            sys.exit(f"markers not found for {stem} in {TARGET.name}")
        body = frag.read_text().rstrip("\n")
        # re.sub would interpret backslashes in the LaTeX body as escapes
        text = pattern.sub(lambda _m, b=body: f"{begin}\n{b}\n{end}", text, count=1)
        print(f"inlined {stem}")

    if text == original:
        print("no change")
        return 0
    if args.dry_run:
        print(f"[dry-run] would rewrite {TARGET}")
        return 0
    TARGET.write_text(text)
    print(f"wrote {TARGET}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
