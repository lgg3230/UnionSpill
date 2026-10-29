#!/usr/bin/env python3
"""
Event-study figures for the doubly robust DiD exercise (3252_drdid.do).

For each design (dA, dC, sAny) and outcome, overlays the improved doubly robust
DiD event study on the TWFE event study with the paper's controls, both on the
DRDID sample, relative to 2011 (CBA period 2 for clauses).

Reads  Tables/drdid/results_drdid.csv
Writes Graphs/drdid/es_drdid_<design>_<outcome>.pdf   one panel, no title (for subfigures)
       Graphs/drdid/es_drdid_<design>.pdf             2x2 preview with panel labels

Usage: python 4360_figure_drdid_es.py [tables_dir] [graphs_dir]
"""

import csv
import math
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D

DESIGNS = ["dA", "dC", "sAny"]
OUTCOMES = ["lr_remdezr_w", "lr_remdezr_h_w", "l_firm_emp", "numb_clauses"]
LABELS = {"lr_remdezr_w": "Log wages", "lr_remdezr_h_w": "Log hourly wages",
          "l_firm_emp": "Log employment", "numb_clauses": "# CBA clauses"}
YEARS = ["2009", "2010", "2011", "2012", "2013", "2014", "2015", "2016"]
CBA = ["1", "2", "3", "4", "5", "6"]
CBA_TICKS = ["2009", "2010-12", "2013", "2014", "2015", "2016"]
TWFE_C, DR_C = "#2166AC", "#B2182B"
INK, MUTED = "#222222", "#666666"
IPT_TOL = 1e-4
OFFSET = 0.12

plt.rcParams.update({"font.family": "serif", "font.size": 10, "axes.edgecolor": MUTED,
                     "axes.linewidth": 0.8, "xtick.color": INK, "ytick.color": INK})


def load(path):
    rows = {}
    with open(path, newline="") as f:
        for r in csv.DictReader(f, delimiter=";"):
            def fl(s):
                try:
                    return float(s)
                except ValueError:
                    return float("nan")
            rows[(r["design"], r["outcome"], r["estimand"], r["estimator"])] = (fl(r["b"]), fl(r["se"]))
    return rows


def series(rows, ds, y, mth, periods, base):
    """[(x, b, se, converged)] with the base period at zero."""
    out = []
    for i, p in enumerate(periods):
        if p == base:
            out.append((i, 0.0, 0.0, True))
            continue
        r = rows.get((ds, y, f"es_{p}", mth))
        if r is None or math.isnan(r[0]):
            continue
        ok = True
        if mth == "dr_drimp":
            imb = rows.get((ds, y, f"es_{p}", "ipt_imbalance"))
            ok = imb is None or not (imb[0] > IPT_TOL)
        out.append((i, r[0], r[1], ok))
    return out


def draw(ax, rows, ds, y):
    clauses = y == "numb_clauses"
    periods, base = (CBA, "2") if clauses else (YEARS, "2011")
    ticks = CBA_TICKS if clauses else YEARS

    ax.axhline(0, color=MUTED, lw=0.8)
    ax.axvline(periods.index(base) + 0.5, color=MUTED, lw=0.8, ls="--")
    for mth, col, dx, face in [("twfe_paper_bin", TWFE_C, -OFFSET, "white"),
                               ("dr_drimp", DR_C, OFFSET, DR_C)]:
        for x, b, se, ok in series(rows, ds, y, mth, periods, base):
            if not ok:
                ax.annotate("n.c.", (x + dx, 0), textcoords="offset points", xytext=(0, 6),
                            ha="center", fontsize=7, color=MUTED)
                continue
            ax.errorbar(x + dx, b, yerr=1.96 * se, fmt="o", ms=5, color=col, mfc=face,
                        mec=col, mew=1.5, elinewidth=1.2, capsize=2.5)
    ax.set_xticks(range(len(periods)))
    ax.set_xticklabels(ticks, fontsize=8)
    ax.set_xlim(-0.6, len(periods) - 0.4)
    ax.tick_params(axis="y", labelsize=8)
    ax.set_ylabel("Effect relative to " + ("CBA period 2" if clauses else "2011"), fontsize=9)
    for side in ("top", "right"):
        ax.spines[side].set_visible(False)

    p_tw = rows.get((ds, y, "pretrend_p", "twfe_paper_bin"), (float("nan"),))[0]
    p_dr = rows.get((ds, y, "pretrend_p", "dr_drimp"), (float("nan"),))[0]
    fmt = lambda p: "--" if math.isnan(p) else f"{p:.2f}"
    ax.text(0.02, 0.97, f"Pre-trend p: TWFE {fmt(p_tw)}, DR {fmt(p_dr)}",
            transform=ax.transAxes, ha="left", va="top", fontsize=7.5, color=MUTED, zorder=5,
            bbox=dict(facecolor="white", edgecolor="none", pad=1.5))


def legend(fig, ncol=2, y=0.0):
    handles = [Line2D([], [], marker="o", ls="", color=TWFE_C, mfc="white", mew=1.5,
                      label="TWFE, paper controls"),
               Line2D([], [], marker="o", ls="", color=DR_C, mfc=DR_C,
                      label="Improved doubly robust DiD")]
    fig.legend(handles=handles, loc="lower center", ncol=ncol, frameon=False,
               bbox_to_anchor=(0.5, y), fontsize=9)


def main():
    root = Path(__file__).resolve().parents[3]
    tables_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else root / "Tables" / "drdid"
    graphs_dir = Path(sys.argv[2]) if len(sys.argv) > 2 else root / "Graphs" / "drdid"
    graphs_dir.mkdir(parents=True, exist_ok=True)
    rows = load(tables_dir / "results_drdid.csv")

    for ds in DESIGNS:
        for y in OUTCOMES:
            fig, ax = plt.subplots(figsize=(5, 3.4))
            draw(ax, rows, ds, y)
            fig.subplots_adjust(bottom=0.24, left=0.15, right=0.97, top=0.97)
            legend(fig)
            fig.savefig(graphs_dir / f"es_drdid_{ds}_{y}.pdf")
            plt.close(fig)

        fig, axes = plt.subplots(2, 2, figsize=(9, 6.4))
        for i, (ax, y) in enumerate(zip(axes.flat, OUTCOMES)):
            draw(ax, rows, ds, y)
            ax.set_xlabel(f"({'abcd'[i]}) {LABELS[y]}", fontsize=9.5, color=INK)
        fig.tight_layout(rect=(0, 0.05, 1, 1))
        legend(fig)
        fig.savefig(graphs_dir / f"es_drdid_{ds}.pdf")
        plt.close(fig)
    print(f"Generated event-study figures in {graphs_dir}")


if __name__ == "__main__":
    main()
