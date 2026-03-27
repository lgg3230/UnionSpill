#!/usr/bin/env python3
"""
main_results_es_plot.py
Event study plots for the main spillover regression.

Reads: Tables/main_results/es_spill_{outcome}.csv
Outputs: Graphs/main_results/es_spill_{outcome}.pdf/.png
"""

import csv
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from pathlib import Path

script_dir  = Path(__file__).resolve().parent
tables_dir  = script_dir.parent.parent / "Tables"  / "main_results"
graphs_dir  = script_dir.parent.parent / "Graphs"  / "main_results"
graphs_dir.mkdir(parents=True, exist_ok=True)

# ── Outcome labels ─────────────────────────────────────────────────────────────

OUTCOME_LABELS = {
    "lr_remdezr_w":   "Log December wages",
    "lr_remdezr_h_w": "Log hourly wages",
    "l_firm_emp":     "Log employment",
}

# ── Plot function ──────────────────────────────────────────────────────────────

def load_es(outcome):
    path = tables_dir / f"es_spill_{outcome}.csv"
    if not path.exists():
        print(f"  WARNING: {path.name} not found — skipping")
        return None
    rows = []
    with open(path) as f:
        reader = csv.DictReader(f)
        for r in reader:
            rows.append({
                "year":     int(r["year"]),
                "coef":     float(r["coef"]),
                "ci_lower": float(r["ci_lower"]),
                "ci_upper": float(r["ci_upper"]),
            })
    rows.sort(key=lambda x: x["year"])
    return rows


def plot_es(outcome):
    rows = load_es(outcome)
    if rows is None:
        return

    years    = [r["year"]     for r in rows]
    coefs    = [r["coef"]     for r in rows]
    ci_lower = [r["ci_lower"] for r in rows]
    ci_upper = [r["ci_upper"] for r in rows]

    err_lo = [c - l for c, l in zip(coefs, ci_lower)]
    err_hi = [u - c for c, u in zip(coefs, ci_upper)]

    fig, ax = plt.subplots(figsize=(8, 4.5))

    ax.axhline(0, color="black", linewidth=0.8, linestyle="-")
    ax.axvline(2011.5, color="gray", linewidth=0.8, linestyle="--", alpha=0.7)

    ax.errorbar(
        years, coefs,
        yerr=[err_lo, err_hi],
        fmt="o",
        color="#2166AC",
        markerfacecolor="white",
        markeredgecolor="#2166AC",
        markeredgewidth=2,
        markersize=7,
        ecolor="#2166AC",
        elinewidth=1.5,
        capsize=4,
        capthick=1.5,
        linewidth=1.2,
        zorder=3,
    )

    ax.set_xlabel("Year", fontsize=11)
    ax.set_ylabel("Coefficient × Connectivity", fontsize=11)
    ax.set_xticks(years)
    ax.set_xticklabels([str(y) for y in years], fontsize=9)

    label = OUTCOME_LABELS.get(outcome, outcome)
    ax.set_title(label, fontsize=12)

    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)

    fig.tight_layout()

    for ext in ("pdf", "png"):
        out = graphs_dir / f"es_spill_{outcome}.{ext}"
        fig.savefig(out, dpi=180, bbox_inches="tight")
        print(f"  Saved: {out}")

    plt.close(fig)


# ── Main ───────────────────────────────────────────────────────────────────────

outcomes = ["lr_remdezr_w", "lr_remdezr_h_w", "l_firm_emp"]

for outcome in outcomes:
    print(f"Plotting: {outcome}")
    plot_es(outcome)

print("Done.")
