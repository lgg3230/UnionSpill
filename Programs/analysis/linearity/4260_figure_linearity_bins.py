#!/usr/bin/env python3
"""
4260_figure_linearity_bins.py
===================================
Coefficient plots for the binned-connectivity spillover DiD: one PDF per
outcome x breakdown (k = 2: median split, 3: terciles, 4: quartiles of positive
connectivity), with no title, so that LaTeX can arrange them as subfigures
(one figure per breakdown, one subfigure per outcome) and caption each one.
A separate legend PDF is placed under the subfigures.

Each group's Post coefficient is plotted with its 95% confidence interval at the
group's mean connectivity (normalized, 1 = 90th percentile). The zero-
connectivity baseline sits at the origin. The dashed line is the effect implied
by the linear specification (3012 PART D), beta_linear x connectivity, with its
95% band, so departures from linearity are visible.

Input (written by 3152_linearity_bins.do via 3151_linearity_bins.do):
    Tables/linearity/linearity_bins.csv

Output (each with a .png copy):
    Graphs/linearity/linearity_bins_k<k>_<outcome>.pdf   12 plots, k = 2, 3, 4
    Graphs/linearity/linearity_bins_legend.pdf           shared legend

Usage
-----
    python 4260_figure_linearity_bins.py
"""

import csv
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.font_manager as fm
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.lines import Line2D
from matplotlib.patches import Patch

PROJECT = Path(__file__).resolve().parents[3]
CSV_IN = PROJECT / "Tables" / "linearity" / "linearity_bins.csv"
OUT_DIR = PROJECT / "Graphs" / "linearity"
FONT_DIR = PROJECT / "Programs" / "fonts"

OUTCOMES = ["lr_remdezr_w", "lr_remdezr_h_w", "l_firm_emp", "numb_clauses"]
PANELS = [
    (2, "Panel A: Median split"),
    (3, "Panel B: Terciles"),
    (4, "Panel C: Quartiles"),
]

BLUE = "#2166AC"   # group coefficients
RED = "#B2182B"    # linear specification

for fp in FONT_DIR.glob("*.ttf"):
    fm.fontManager.addfont(str(fp))
plt.rcParams["font.family"] = "Libertinus Serif"
plt.rcParams["pdf.fonttype"] = 42
plt.rcParams["font.size"] = 12


def load_csv(path):
    if not path.exists():
        raise SystemExit(f"Missing input: {path}. Run 3151_linearity_bins.do first.")
    out = {}
    with open(path, newline="") as fh:
        for r in csv.DictReader(fh):
            out.setdefault((r["outcome"], int(r["breakdown"])), []).append(r)
    for rows in out.values():
        rows.sort(key=lambda r: int(r["group"]))
    return out


def num(raw):
    raw = raw.strip()
    return np.nan if raw in ("", ".") else float(raw)


def plot_one(data, outcome, k):
    rows = data.get((outcome, k))
    if not rows:
        raise SystemExit(f"No rows for {outcome}, {k} groups in {CSV_IN.name}.")
    x = np.array([num(r["mean_conn"]) for r in rows])
    b = np.array([num(r["coef"]) for r in rows])
    se = np.array([num(r["se"]) for r in rows])
    b_lin, se_lin = num(rows[0]["beta_linear"]), num(rows[0]["se_linear"])

    fig, ax = plt.subplots(figsize=(5.0, 3.6))

    # Linear specification: beta x conn with its 95% band, from 0 to the
    # largest group mean
    grid = np.linspace(0, np.nanmax(x) * 1.05, 100)
    ax.fill_between(grid, (b_lin - 1.96 * se_lin) * grid,
                    (b_lin + 1.96 * se_lin) * grid,
                    color=RED, alpha=0.12, linewidth=0)
    ax.plot(grid, b_lin * grid, color=RED, linestyle="--", linewidth=1.5)

    ax.axhline(0, color="gray", linewidth=0.8, alpha=0.6)

    # Baseline group (zero connectivity) at the origin, hollow
    ax.plot(x[0], 0, marker="o", markersize=8, markerfacecolor="white",
            markeredgecolor=BLUE, markeredgewidth=2, linestyle="none")

    # Group coefficients with 95% CIs
    ax.errorbar(x[1:], b[1:], yerr=1.96 * se[1:], fmt="o", color=BLUE,
                markersize=7, capsize=4, linewidth=1.5)

    ax.set_xlabel("Mean connectivity in group", fontweight="bold")
    ax.set_ylabel("Coefficient", fontweight="bold")
    ax.grid(axis="y", alpha=0.2)
    fig.tight_layout()

    out = OUT_DIR / f"linearity_bins_k{k}_{outcome}.pdf"
    fig.savefig(out, bbox_inches="tight")
    # PNG copy so the figure opens in any editor without a PDF viewer
    fig.savefig(out.with_suffix(".png"), bbox_inches="tight", dpi=200)
    plt.close(fig)
    print(f"Wrote {out} (+ .png)")


def plot_legend():
    """Legend alone, to sit under the subfigures of each figure."""
    handles = [
        Line2D([], [], marker="o", color=BLUE, linestyle="none", markersize=7,
               label="Group coefficient (95% CI)"),
        Line2D([], [], marker="o", markerfacecolor="white", markeredgecolor=BLUE,
               markeredgewidth=2, linestyle="none", markersize=8,
               label="Zero connectivity (baseline)"),
        Line2D([], [], color=RED, linestyle="--", linewidth=1.5,
               label="Linear specification"),
        Patch(facecolor=RED, alpha=0.12, label="Linear specification, 95% CI"),
    ]
    fig = plt.figure(figsize=(10, 0.4))
    fig.legend(handles=handles, loc="center", ncol=4, frameon=False)
    out = OUT_DIR / "linearity_bins_legend.pdf"
    fig.savefig(out, bbox_inches="tight")
    fig.savefig(out.with_suffix(".png"), bbox_inches="tight", dpi=200)
    plt.close(fig)
    print(f"Wrote {out} (+ .png)")


def main():
    data = load_csv(CSV_IN)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for k, _ in PANELS:
        for outcome in OUTCOMES:
            plot_one(data, outcome, k)
    plot_legend()


if __name__ == "__main__":
    main()
