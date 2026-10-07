#!/usr/bin/env python3
"""
4280_figure_pure_control_cutoff.py
==================================
Direct effect (Post x Treatment) against the comparison-group connectivity
cutoff, one figure per outcome. Cutoffs on the x axis in increasing order
(zero, P25, P33, 0.01, P50, P67, P75, P80, P90 of positive connectivity, then
all untreated). Each point is the coefficient with its 95% CI. The hollow
marker and the dashed line are the zero-connectivity baseline (published
Panel A).

No title and no legend: each figure is a panel of the 2x2 subfigure built by
4290_latex_figure_pure_control_cutoff.py, whose subcaptions name the outcome
and whose notes explain the markers. Sized 4.0 x 3.0 in, like the paper's
other subfigure panels (h_recentered_spill.pdf).

Input (written by 3162_pure_control_cutoff.do via 3161_pure_control_cutoff.do):
    Tables/pure_control_cutoff/pure_control_cutoff.csv
    Tables/pure_control_cutoff/pure_control_cutoff_cutoffs.csv

Output:
    Graphs/pure_control_cutoff/pure_control_cutoff_<outcome>.pdf  (+ .png copy)

Usage
-----
    python 4280_figure_pure_control_cutoff.py
"""

import csv
import math
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.font_manager as fm
import matplotlib.pyplot as plt
import numpy as np

PROJECT = Path(__file__).resolve().parents[3]
TAB_DIR = PROJECT / "Tables" / "pure_control_cutoff"
CSV_IN = TAB_DIR / "pure_control_cutoff.csv"
CUTS_IN = TAB_DIR / "pure_control_cutoff_cutoffs.csv"
OUT_DIR = PROJECT / "Graphs" / "pure_control_cutoff"
FONT_DIR = PROJECT / "Programs" / "fonts"

OUTCOMES = ["lr_remdezr_h_w", "lr_remdezr_w", "l_firm_emp", "numb_clauses"]
QUANTILE = {"q1_4": "P25", "t1_3": "P33", "q2_4": "P50", "t2_3": "P67",
            "q3_4": "P75", "p80": "P80", "p90": "P90"}

BLUE = "#2166AC"

for fp in FONT_DIR.glob("*.ttf"):
    fm.fontManager.addfont(str(fp))
plt.rcParams["font.family"] = "Libertinus Serif"
plt.rcParams["pdf.fonttype"] = 42
plt.rcParams["font.size"] = 10


def load():
    for p in (CSV_IN, CUTS_IN):
        if not p.exists():
            raise SystemExit(f"Missing input: {p}. Run 3161_pure_control_cutoff.do first.")
    data = {}
    with open(CSV_IN, newline="") as fh:
        for r in csv.DictReader(fh):
            v = r["value"].strip()
            data[(r["section"], r["outcome"], r["row_type"])] = (
                math.nan if v in ("", ".") else float(v))
    with open(CUTS_IN, newline="") as fh:
        cuts = {r["sample"]: r for r in csv.DictReader(fh)}
    return data, cuts


def ordered_samples(cuts):
    def key(s):
        v = cuts[s]["cutoff_raw"].strip()
        return math.inf if v in ("", ".") else float(v)
    return sorted(cuts, key=key)


def tick_label(s):
    if s == "zero":
        return "0"
    if s == "all":
        return "All"
    if s == "fixed_001":
        return "0.01"
    return QUANTILE[s]


def plot_outcome(data, samples, outcome):
    x = np.arange(len(samples))
    b = np.array([data[(s, outcome, "main")] for s in samples])
    se = np.array([data[(s, outcome, "main_se")] for s in samples])
    i0 = samples.index("zero")

    fig, ax = plt.subplots(figsize=(4.0, 3.0))
    ax.axhline(0, color="gray", linewidth=0.8, alpha=0.6)
    ax.axhline(b[i0], color=BLUE, linestyle="--", linewidth=1.0, alpha=0.6)
    ax.errorbar(x, b, yerr=1.96 * se, fmt="none", ecolor=BLUE,
                capsize=3, linewidth=1.2)
    others = [i for i in range(len(samples)) if i != i0]
    ax.plot(x[others], b[others], "o", color=BLUE, markersize=5)
    ax.plot(x[i0], b[i0], "o", markersize=6, markerfacecolor="white",
            markeredgecolor=BLUE, markeredgewidth=1.6)

    ax.set_xticks(x)
    ax.set_xticklabels([tick_label(s) for s in samples], fontsize=8.5)
    ax.set_xlim(-0.6, len(samples) - 0.4)
    ax.set_xlabel("Connectivity cutoff $c$", fontweight="bold")
    ax.set_ylabel("Coefficient", fontweight="bold")
    ax.grid(axis="y", alpha=0.2)
    fig.tight_layout()

    out = OUT_DIR / f"pure_control_cutoff_{outcome}.pdf"
    fig.savefig(out, bbox_inches="tight")
    fig.savefig(out.with_suffix(".png"), bbox_inches="tight", dpi=200)
    plt.close(fig)
    print(f"Wrote {out} (+ .png)")


def main():
    data, cuts = load()
    samples = ordered_samples(cuts)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for outcome in OUTCOMES:
        plot_outcome(data, samples, outcome)


if __name__ == "__main__":
    main()
