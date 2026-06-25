#!/usr/bin/env python3
"""
Histograms of raw connectivity-to-treated (totaltreat_pw_n). SEPARATE figures
for control and treated firms, each with median & mean lines + legend.

  - CONTROL: firms in the spillover log-wage e(sample) (in_spill==1, ~4,085).
  - TREATED: treated balanced-panel Lagos firms (in_treat==1).

Same uniform samples as the binscatters (listwise-complete on connectivity + the
8 characteristics).

Output: Graphs/conn_descriptives/hist_connectivity.pdf          (control)
        Graphs/conn_descriptives/hist_connectivity_treated.pdf   (treated)
Run with /opt/homebrew/bin/python3.
"""
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from pathlib import Path

BASE = Path("/Users/luisg/Library/CloudStorage/OneDrive-NorthwesternUniversity/"
            "4 - PhD/02_Research/Org_Econ BR/UnionSpillovers/Cluster/UnionSpill")
TBL = BASE / "Tables" / "descriptives"
GR  = BASE / "Graphs" / "conn_descriptives"
GR.mkdir(parents=True, exist_ok=True)
plt.rcParams["font.family"] = "serif"

XVAR = "totaltreat_pw_n"
CHARS = ["lr_remdezr_w", "l_firm_emp", "turnover", "hiring", "churn",
         "retention", "prop_female", "prop_non_white"]
ALLVARS = [XVAR] + CHARS
MED_C, MEAN_C = "black", "#B2182B"

raw = pd.read_csv(TBL / "firm_conn_scatter.csv").dropna(subset=ALLVARS)


def make_hist(mask, color, fname, title):
    x = raw.loc[mask, XVAR]
    n = len(x); zero = (x == 0).mean()
    med, mean = x.median(), x.mean()
    p90, p99 = x.quantile(.90), x.quantile(.99)
    body = x[(x > 0) & (x <= p99)]
    fig, ax = plt.subplots(figsize=(6.6, 4.3))
    ax.hist(body, bins=50, color=color, alpha=0.85, edgecolor="white", linewidth=0.3)
    lmed  = ax.axvline(med,  color=MED_C,  ls="--", lw=1.6)
    lmean = ax.axvline(mean, color=MEAN_C, ls="-.", lw=1.6)
    ax.set_xlabel("Connectivity to treated, raw (per-worker flows), totaltreat_pw_n", fontsize=9)
    ax.set_ylabel("Establishments", fontsize=9)
    ax.set_xlim(0, p99); ax.tick_params(labelsize=8)
    ax.legend([lmed, lmean], [f"Median = {med:.4f}", f"Mean = {mean:.4f}"],
              loc="upper right", frameon=True, fontsize=9, framealpha=0.95, title=title)
    ax.text(0.97, 0.66,
            f"N = {n:,}\nAt exactly 0: {zero*100:.1f}%\np90: {p90:.4f}\n"
            f"p99: {p99:.4f}\n(positive values ≤ p99 shown)",
            transform=ax.transAxes, ha="right", va="top", fontsize=8,
            bbox=dict(boxstyle="round,pad=0.4", fc="white", ec="0.7"))
    fig.tight_layout(); fig.savefig(GR / fname, bbox_inches="tight", dpi=150)
    plt.close(fig)
    print(f"{title}: N={n:,} %zero={zero*100:.1f} median={med:.5f} mean={mean:.5f}")


make_hist(raw.in_spill == 1, "#2166AC", "hist_connectivity.pdf",          "Control (spillover) sample")
make_hist(raw.in_treat == 1, "#E08214", "hist_connectivity_treated.pdf",  "Treated firms")
print("=== hist_connectivity.py done ===")
