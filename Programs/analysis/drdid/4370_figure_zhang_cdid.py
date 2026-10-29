#!/usr/bin/env python3
"""
ATT(d) curves from 3261_zhang_cdid.py, drawn in the style of Zhang (2026),
Figure 2: estimate in blue, 95% pointwise CI in gray, 95% bootstrap uniform band
dashed black, zero line dashed red.

Reads  Tables/drdid/zhang_cdid_att.csv
Writes Graphs/drdid/zhang_cdid_<outcome>.pdf   one panel, no title (for subfigures)
       Graphs/drdid/zhang_cdid.pdf             2x2 panel of all outcomes

Usage: python 4370_figure_zhang_cdid.py
"""

from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd
from matplotlib.ticker import FixedLocator, NullLocator

ROOT = Path(__file__).resolve().parents[3]
LABELS = {"lr_remdezr_w": "Log Wages", "lr_remdezr_h_w": "Log Hourly Wages",
          "l_firm_emp": "Log Employment", "numb_clauses": "# CBA Clauses"}
XLABEL = "Connectivity to Treated Firms (scaled to 90th percentile)"
TICKS = [0.05, 0.1, 0.25, 0.5, 1, 2, 4]

# Zhang's figures: seaborn "ticks" style in the "paper" context, ticks pointing in.
plt.rcParams.update({"xtick.direction": "in", "ytick.direction": "in",
                     "axes.spines.top": True, "axes.spines.right": True,
                     "axes.grid": False, "font.size": 10})


def draw(ax, t, legend=True):
    x = t.dose
    ax.plot(x, t.att, "-", color="blue", linewidth=1.5, label=r"$\widehat{ATT}(d)$")
    ax.plot(x, t.lo, "-", color="gray", linewidth=1, label="95% Pointwise CI")
    ax.plot(x, t.hi, "-", color="gray", linewidth=1)
    ax.plot(x, t.lo_unif, "--", color="black", linewidth=1, label="95% Bootstrap Uniform CI")
    ax.plot(x, t.hi_unif, "--", color="black", linewidth=1)
    ax.axhline(y=0, color="red", linewidth=1, linestyle="--", alpha=0.8)
    ax.fill_between(x, t.lo, t.hi, alpha=0.02)
    ax.fill_between(x, t.lo_unif, t.hi_unif, alpha=0.02)
    ax.set_xscale("log")
    ticks = [v for v in TICKS if x.min() <= v <= x.max()]
    ax.xaxis.set_major_locator(FixedLocator(ticks))
    ax.xaxis.set_minor_locator(NullLocator())
    ax.set_xticklabels([f"{v:g}" for v in ticks])
    ax.set_xlim(x.min(), x.max())
    ax.set_xlabel(XLABEL, fontsize=10, labelpad=8)
    ax.set_ylabel("Effect Size", fontsize=10, labelpad=3)
    ax.tick_params(axis="both", which="major", labelsize=10)
    if legend:
        ax.legend(fontsize=8, loc="best", frameon=False)


def main():
    res = pd.read_csv(ROOT / "Tables" / "drdid" / "zhang_cdid_att.csv")
    out = ROOT / "Graphs" / "drdid"
    out.mkdir(parents=True, exist_ok=True)
    outcomes = [y for y in LABELS if y in set(res.outcome)]

    for y in outcomes:
        fig, ax = plt.subplots(figsize=(6, 4))
        draw(ax, res[res.outcome == y])
        fig.savefig(out / f"zhang_cdid_{y}.pdf", bbox_inches="tight")
        plt.close(fig)

    fig, axs = plt.subplots(2, 2, figsize=(10, 10))
    for ax, y in zip(axs.flat, outcomes):
        draw(ax, res[res.outcome == y])
        ax.set_title(LABELS[y], fontsize=10)
    for ax in list(axs.flat)[len(outcomes):]:
        ax.set_visible(False)
    plt.tight_layout(rect=[0, 0, 1, 0.96])
    plt.subplots_adjust(hspace=0.3)
    fig.savefig(out / "zhang_cdid.pdf", bbox_inches="tight")
    plt.close(fig)
    print(f"Generated ATT(d) figures in {out}")


if __name__ == "__main__":
    main()
