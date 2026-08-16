#!/usr/bin/env python
"""
Tier F: copy generated figures into UnionSpill-paper/Replication/Figures/.

Replaces the undocumented hand-copy-with-renaming that Docs/pipeline/INVENTORY.md section C
describes ("populated by hand-copy with renaming; no script writes into it").
Because the renaming was never recorded anywhere, a regenerated figure could
never be traced back to the published name it was supposed to land under.

DRY RUN BY DEFAULT. Nothing under UnionSpill-paper/ is touched unless --apply
is passed, and every replacement is reported with both md5s first. This is a
deliberate guard: these files are the paper's figures.

    python 6010_copy_figures_to_paper.py            # report what would change
    python 6010_copy_figures_to_paper.py --apply    # actually copy

The four honest-DiD figures that INVENTORY section C lists are NOT here. They
appear nowhere in Draft.tex (`grep -i honest Draft.tex` is empty), so they are
phase-2 material, not part of the paper's figure set.
"""

from __future__ import annotations

import argparse
import hashlib
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
GRAPHS = ROOT / "Graphs"
DEST = ROOT / "UnionSpill-paper" / "Replication" / "Figures"

# published name -> source, relative to Graphs/.
# A source ending in "*" is a glob; the most recently modified match wins,
# which is how the event studies work -- 4012_pct_tfpw.do stamps
# the run date into the filename (es_..._directA__1_Aug_2026.pdf).
FIGURE_MAP: dict[str, str] = {
    # connectivity / descriptives
    "bilateral_coefplot.pdf": "connectivity/coefplot_bilateral_combined.pdf",
    "distro_region.pdf":      "descriptives/distro_region.pdf",
    "distro_industry.pdf":    "descriptives/distro_broad_industry.pdf",
    "distro_month.pdf":       "descriptives/distro_mode_base_month.pdf",
    "conn_hist.pdf":          "conn_descriptives/hist_connectivity.pdf",
    # main event studies (date-stamped -> glob)
    "m_dir_es.pdf":           "pct_tfpw_cc/es_lr_remdezr_w_directA__*.pdf",
    "m_spill_es.pdf":         "pct_tfpw_cc/es_lr_remdezr_w_spill__*.pdf",
    "h_dir_es.pdf":           "pct_tfpw_cc/es_lr_remdezr_h_w_directA__*.pdf",
    "h_spill_es.pdf":         "pct_tfpw_cc/es_lr_remdezr_h_w_spill__*.pdf",
    # recentered event studies
    "m_recentered_spill.pdf": "rand_inference/es_spill_lr_remdezr_w.pdf",
    "m_recentered_cf.pdf":    "rand_inference/es_counterfactual_lr_remdezr_w.pdf",
    "h_recentered_spill.pdf": "rand_inference/es_spill_lr_remdezr_h_w.pdf",
    "h_recentered_cf.pdf":    "rand_inference/es_counterfactual_lr_remdezr_h_w.pdf",
    # binscatters
    "binscatter_wage.pdf":    "rand_inference/binscatter_lr_remdezr_w_raw.pdf",
    "binscatter_hwage.pdf":   "rand_inference/binscatter_lr_remdezr_h_w_raw.pdf",
    "binscatter_emp.pdf":     "rand_inference/binscatter_l_firm_emp_raw.pdf",
    "binscatter_clauses.pdf": "rand_inference/binscatter_numb_clauses_raw.pdf",
}


def md5(path: Path) -> str:
    h = hashlib.md5()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def resolve(pattern: str) -> Path | None:
    """Resolve a map entry to a concrete file; newest match wins for globs."""
    if "*" in pattern:
        matches = sorted(GRAPHS.glob(pattern), key=lambda p: p.stat().st_mtime)
        return matches[-1] if matches else None
    candidate = GRAPHS / pattern
    return candidate if candidate.exists() else None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true",
                    help="actually copy; without it this is a dry run")
    args = ap.parse_args()

    missing, identical, changed, new = [], [], [], []

    for published, pattern in sorted(FIGURE_MAP.items()):
        src = resolve(pattern)
        if src is None:
            missing.append((published, pattern))
            continue
        dst = DEST / published
        if not dst.exists():
            new.append((published, src))
        elif md5(src) == md5(dst):
            identical.append((published, src))
        else:
            changed.append((published, src, md5(dst), md5(src)))

    print(f"destination: {DEST}")
    print(f"mapped figures: {len(FIGURE_MAP)}\n")

    if identical:
        print(f"UNCHANGED ({len(identical)}) -- source already matches the paper")
        for pub, src in identical:
            print(f"  {pub:<26} <- {src.relative_to(GRAPHS)}")
        print()

    if new:
        print(f"NEW ({len(new)}) -- not currently in the paper")
        for pub, src in new:
            print(f"  {pub:<26} <- {src.relative_to(GRAPHS)}")
        print()

    if changed:
        print(f"WOULD REPLACE ({len(changed)}) -- content differs")
        for pub, src, old, newmd5 in changed:
            print(f"  {pub:<26} <- {src.relative_to(GRAPHS)}")
            print(f"      paper  md5 {old}")
            print(f"      source md5 {newmd5}")
        print()

    if missing:
        print(f"MISSING SOURCE ({len(missing)}) -- cannot be regenerated yet")
        for pub, pattern in missing:
            print(f"  {pub:<26} <- {pattern}   NOT FOUND")
        print()

    if not args.apply:
        n = len(changed) + len(new)
        print(f"DRY RUN. {n} file(s) would be written. Re-run with --apply to copy.")
        return 0

    DEST.mkdir(parents=True, exist_ok=True)
    for pub, src in new:
        shutil.copy2(src, DEST / pub)
        print(f"copied  {pub}")
    for pub, src, _old, _new in changed:
        shutil.copy2(src, DEST / pub)
        print(f"replaced {pub}")
    print(f"\ndone: {len(new)} new, {len(changed)} replaced, "
          f"{len(identical)} unchanged, {len(missing)} missing")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
