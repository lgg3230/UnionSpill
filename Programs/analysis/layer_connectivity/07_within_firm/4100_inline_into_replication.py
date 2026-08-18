#!/usr/bin/env python3
"""Inline the generated table fragments into the replication document.

    ~/.conda/envs/venv_python312/bin/python 4100_inline_into_replication.py [--dry-run]

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

ROOT = Path(__file__).resolve().parents[4]
TABLE_DIR = ROOT / "Tables" / "layer_connectivity" / "07_within_firm"
TARGET = ROOT / "UnionSpill-paper" / "Replication" / "Replication_Wages vs Hourly.tex"

# stem -> directory holding the generated fragment.
# Extended 2026-08-01 from the six within-firm stems to every fragment in the
# document, now that each has a generator (plan 2026-08-01).
WITHIN = ROOT / "Tables" / "layer_connectivity" / "07_within_firm"
SOURCES = {
    "t_layerdesc":     WITHIN,
    "t_groupspecs":    WITHIN,
    "t_horserace":     WITHIN,
    "t_layerdesc_hw":  WITHIN,
    "t_groupspecs_hw": WITHIN,
    "t_horserace_hw":  WITHIN,
    "t_direct":        ROOT / "Tables" / "main_results",
    "t_spill":         ROOT / "Tables" / "main_results",
    "t_clause":        ROOT / "Tables" / "clause_types",
    "t_union":         ROOT / "Tables" / "robustness",
    "t_union_hw":      ROOT / "Tables" / "robustness",
    "t_composition":   ROOT / "Tables" / "composition",
    "t_turnover":      ROOT / "Tables" / "turnover",
    "t_rob":           ROOT / "quality_reports" / "replication"
                            / "hourly_variant_currentconn" / "frag",
    "t_rob_hw":        ROOT / "quality_reports" / "replication"
                            / "hourly_variant_currentconn" / "frag",
}

# t_turnover was held out until 2026-08-02 while its provenance was unclear. It
# reproduces the published SPECIFICATION exactly -- same absorb list, same
# n=113,112, same p90 divisor (.0292579, the current measure) -- but the point
# estimates differ by <= 0.094 SE, which is convergence slack in a demeaning
# problem with microregion#year (3,560 categories) on top of 14,139 firm
# effects. Now inlined by decision: the printed numbers come from code that can
# be re-run, rather than from a deleted builder. One qualitative change: the
# Panel A churn pre-trend crosses into significance ($-$0.0498 -> $-$0.0528*).

STEMS = list(SOURCES)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    if not TARGET.exists():
        sys.exit(f"missing target: {TARGET}")
    text = TARGET.read_text()
    original = text

    for stem in STEMS:
        frag = SOURCES[stem] / f"{stem}.tex"
        if not frag.exists():
            sys.exit(f"missing fragment: {frag} -- run its generator first")
        begin = f"% BEGIN inlined {stem}.tex"
        end = f"% END inlined {stem}.tex"
        pattern = re.compile(
            re.escape(begin) + r".*?" + re.escape(end), re.DOTALL)
        if not pattern.search(text):
            sys.exit(f"markers not found for {stem} in {TARGET.name}")
        body = frag.read_text().rstrip("\n")
        # Replace EVERY occurrence, not just the first. Five fragments
        # (t_direct, t_spill, t_clause, t_turnover, t_composition) are inlined
        # twice -- once in the monthly half, once in the hourly half -- because
        # each already carries both wage columns. count=1 was correct only for
        # the six within-firm stems this script originally handled, and left the
        # hourly copies stale when it was generalized (fixed 2026-08-02).
        # re.sub would interpret backslashes in the LaTeX body as escapes
        n = len(pattern.findall(text))
        text = pattern.sub(lambda _m, b=body: f"{begin}\n{b}\n{end}", text)
        print(f"inlined {stem} ({n} occurrence{'s' if n != 1 else ''})")

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
