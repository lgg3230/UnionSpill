#!/usr/bin/env python3
"""
Raw scatterplots (with a binned overlay) of connectivity-to-treated vs.
pre-treatment firm characteristics. SEPARATE sets for control and treated firms.
The binned versions in firm_conn_binscatter.py are the recommended figures; these
raw clouds are kept for reference.

  - CONTROL: spillover log-wage e(sample) (in_spill==1, ~4,085 firms).
  - TREATED: treated balanced-panel Lagos firms (in_treat==1).

Output: Graphs/descriptives/scatter_conn_<var>.pdf / _combined.pdf  (control)
        Graphs/descriptives/scatter_conn_<var>_treated.pdf / _combined_treated.pdf
Run with /opt/homebrew/bin/python3.
"""
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
from pathlib import Path


def centered_grid(fig, n, ncol=3):
    gs = gridspec.GridSpec(int(np.ceil(n / ncol)), 2 * ncol, figure=fig)
    full_rows = n // ncol
    rem = n % ncol
    axes = []
    for i in range(n):
        row, cir = divmod(i, ncol)
        c0 = cir * 2 if (row < full_rows or rem == 0) else (2 * ncol - 2 * rem) // 2 + cir * 2
        axes.append(fig.add_subplot(gs[row, c0:c0 + 2]))
    return axes

BASE = Path("/Users/luisg/Library/CloudStorage/OneDrive-NorthwesternUniversity/"
            "4 - PhD/02_Research/Org_Econ BR/UnionSpillovers/Cluster/UnionSpill")
TBL = BASE / "Tables" / "descriptives"
GR  = BASE / "Graphs" / "descriptives"
GR.mkdir(parents=True, exist_ok=True)
plt.rcParams["font.family"] = "serif"

XVAR = "totaltreat_pw_n"
XLAB = "Connectivity to treated (per-worker flows)"
CHARS = {
    "lr_remdezr_w":   ("Log wages",                False),
    "l_firm_emp":     ("Log employment",           False),
    "turnover":       ("Separation rate",          True),
    "hiring":         ("Hiring rate",              True),
    "churn":          ("Churn rate (hires+seps)",  True),
    "retention":      ("Retention rate",           False),
    "prop_female":    ("Share female",             False),
    "prop_non_white": ("Share non-white",          False),
}
ALLVARS = [XVAR] + list(CHARS)
N_BINS = 20
RED = "#B2182B"

raw = pd.read_csv(TBL / "firm_conn_scatter.csv")


def prep(mask):
    d = raw[mask].dropna(subset=ALLVARS).copy()
    # display trim: drop top 1% of connectivity so the dense region is not squashed
    d = d[d[XVAR] <= d[XVAR].quantile(0.99)].copy()
    for v, (_, wins) in CHARS.items():
        if wins:
            d[v] = d[v].clip(upper=d[v].quantile(0.99))
    return d


def ols_slope_se(x, y):
    x = np.asarray(x, float); y = np.asarray(y, float); n = len(x)
    xb = x.mean(); Sxx = ((x - xb) ** 2).sum()
    b1 = ((x - xb) * (y - y.mean())).sum() / Sxx
    b0 = y.mean() - b1 * xb
    e = y - b0 - b1 * x
    se = np.sqrt((n / (n - 2)) * (((x - xb) ** 2) * e ** 2).sum() / Sxx ** 2)
    return b1, b0, se


def stars(b, se):
    if se == 0 or not np.isfinite(se):
        return ""
    t = abs(b / se)
    return "***" if t > 2.576 else "**" if t > 1.96 else "*" if t > 1.645 else ""


def binned(x, y, n=N_BINS):
    d = pd.DataFrame({"x": x, "y": y})
    d["b"] = pd.qcut(d["x"].rank(method="first"), q=n, labels=False)
    g = d.groupby("b")[["x", "y"]].mean()
    return g["x"].values, g["y"].values


def panel(ax, d, var, label, color):
    x, y = d[XVAR].values, d[var].values
    ax.scatter(x, y, s=5, alpha=0.12, color=color, edgecolors="none", rasterized=True)
    bx, by = binned(x, y)
    ax.scatter(bx, by, s=26, color=color, zorder=4, edgecolors="white", linewidths=0.6)
    b1, b0, se = ols_slope_se(x, y)
    xs = np.linspace(x.min(), x.max(), 200)
    ax.plot(xs, b0 + b1 * xs, color=RED, lw=2, zorder=5)
    ax.set_xlabel(XLAB, fontsize=9); ax.set_ylabel(label, fontsize=9)
    ax.text(0.97, 0.95, f"$\\beta$ = {b1:.3f}{stars(b1, se)}\n({se:.3f})",
            transform=ax.transAxes, ha="right", va="top",
            fontsize=8.5, bbox=dict(boxstyle="round,pad=0.3", fc="white", ec="0.7"))
    ax.tick_params(labelsize=8)


def make_set(mask, suffix, title, color):
    d = prep(mask); n = len(d)
    print(f"{title}: n={n:,}")
    for var, (label, _) in CHARS.items():
        fig, ax = plt.subplots(figsize=(5.2, 4.0)); panel(ax, d, var, label, color)
        fig.tight_layout(); fig.savefig(GR / f"scatter_conn_{var}{suffix}.pdf",
                                        bbox_inches="tight", dpi=150); plt.close(fig)
    fig = plt.figure(figsize=(13.5, 11))
    axes = centered_grid(fig, len(CHARS), ncol=3)
    for ax, (var, (label, _)) in zip(axes, CHARS.items()):
        panel(ax, d, var, label, color)
    fig.suptitle(f"{title} (raw; n = {n:,})", fontsize=11)
    fig.tight_layout(); fig.savefig(GR / f"scatter_conn_combined{suffix}.pdf",
                                    bbox_inches="tight", dpi=150); plt.close(fig)


make_set(raw.in_spill == 1, "",         "Control (spillover) sample", "#2166AC")
# Treated-firm connectivity graph deprecated in favor of the Task-2 balance table (balance_table_task2). Re-enable if needed.
# make_set(raw.in_treat == 1, "_treated", "Treated firms",              "#E08214")
print("=== firm_conn_scatter.py done ===")
