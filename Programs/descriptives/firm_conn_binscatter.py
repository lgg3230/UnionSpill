#!/usr/bin/env python3
"""
Binned scatterplots (binscatter) of connectivity-to-treated vs. pre-treatment
firm characteristics. SEPARATE sets for control and treated firms (not overlaid).

  - CONTROL set: firms in the headline spillover log-wage e(sample) (in_spill==1),
    i.e. the ~4,085-firm spillover estimation sample.
  - TREATED set: treated firms in the balanced Lagos panel (in_treat==1).

Within each set: a uniform sample (listwise-complete on connectivity + the 8
characteristics). The zero-connectivity firms form one large point; positive
firms are split into equal-frequency bins. Heavy-tailed rate vars (separation,
hiring, churn) are winsorized at p99. OLS line + Pearson r on firm-level data.

Output: Graphs/descriptives/binscatter_conn_<var>.pdf / _combined.pdf  (control)
        Graphs/descriptives/binscatter_conn_<var>_treated.pdf / _combined_treated.pdf
        Tables/descriptives/firm_conn_correlations.csv
Run with /opt/homebrew/bin/python3.
"""
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
from pathlib import Path


def centered_grid(fig, n, ncol=3):
    """Axes for n panels in `ncol` columns, with the (incomplete) last row
    centered. Each panel spans 2 of 2*ncol columns; a short last row is offset
    by the leftover half-columns so it sits centered under the full rows."""
    gs = gridspec.GridSpec(int(np.ceil(n / ncol)), 2 * ncol, figure=fig)
    full_rows = n // ncol
    rem = n % ncol
    axes = []
    for i in range(n):
        row, cir = divmod(i, ncol)
        if row < full_rows or rem == 0:
            c0 = cir * 2
        else:
            c0 = (2 * ncol - 2 * rem) // 2 + cir * 2   # centre the last row
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
CHARS = {  # var -> (label, winsorize_y?)
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
N_POS_BINS = 18

raw = pd.read_csv(TBL / "firm_conn_scatter.csv")
print(f"Loaded {len(raw):,} firms (in_spill={int(raw.in_spill.sum()):,}, "
      f"in_treat={int(raw.in_treat.sum()):,})")


def prep(mask):
    d = raw[mask].dropna(subset=ALLVARS).copy()
    # display trim: drop the top 1% of connectivity so the dense low-connectivity
    # region is not squashed into the far left of the axis. The matched sample is
    # still the spillover e(sample); this only affects the descriptive plots.
    d = d[d[XVAR] <= d[XVAR].quantile(0.99)].copy()
    for v, (_, wins) in CHARS.items():
        if wins:
            d[v] = d[v].clip(upper=d[v].quantile(0.99))
    return d


def ols_slope_se(x, y):
    """Univariate OLS slope of y on connectivity, with HC1 robust SE."""
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


def binpoints(x, y, n_pos=N_POS_BINS):
    x = np.asarray(x); y = np.asarray(y)
    z = x == 0
    bx, by, sz = [], [], []
    if z.any():
        bx.append(0.0); by.append(y[z].mean()); sz.append(z.mean())
    xp, yp = x[~z], y[~z]
    if len(xp):
        d = pd.DataFrame({"x": xp, "y": yp})
        d["b"] = pd.qcut(d["x"].rank(method="first"), q=min(n_pos, len(d)), labels=False)
        g = d.groupby("b")[["x", "y"]].mean()
        cnt = d.groupby("b").size() / len(x)
        bx += list(g["x"]); by += list(g["y"]); sz += list(cnt)
    return np.array(bx), np.array(by), np.array(sz)


def panel(ax, d, var, label, color, fitcolor):
    x, y = d[XVAR].values, d[var].values
    bx, by, sz = binpoints(x, y)
    ax.scatter(bx, by, s=30 + 600 * sz, color=color, edgecolors="white",
               linewidths=0.6, zorder=4)
    b1, b0, se = ols_slope_se(x, y)
    xs = np.linspace(x.min(), x.max(), 200)
    ax.plot(xs, b0 + b1 * xs, color=fitcolor, lw=2, zorder=3)
    ax.set_xlabel(XLAB, fontsize=9); ax.set_ylabel(label, fontsize=9)
    ax.text(0.97, 0.95, f"$\\beta$ = {b1:.3f}{stars(b1, se)}\n({se:.3f})",
            transform=ax.transAxes, ha="right", va="top", fontsize=8.5,
            bbox=dict(boxstyle="round,pad=0.3", fc="white", ec="0.7"))
    ax.tick_params(labelsize=8)
    return b1, se


def make_set(mask, suffix, title, color, fitcolor):
    d = prep(mask)
    n = len(d)
    print(f"{title}: uniform n = {n:,}")
    rows = []
    for var, (label, _) in CHARS.items():
        fig, ax = plt.subplots(figsize=(5.2, 4.0))
        b1, se = panel(ax, d, var, label, color, fitcolor)
        fig.tight_layout()
        fig.savefig(GR / f"binscatter_conn_{var}{suffix}.pdf", bbox_inches="tight", dpi=150)
        plt.close(fig)
        rows.append(dict(variable=var, label=label, set=title, n=n, slope=b1, se=se,
                         t=b1 / se if se else np.nan))
    fig = plt.figure(figsize=(13.5, 11))
    axes = centered_grid(fig, len(CHARS), ncol=3)
    for ax, (var, (label, _)) in zip(axes, CHARS.items()):
        panel(ax, d, var, label, color, fitcolor)
    fig.suptitle(f"{title}  (binned; n = {n:,}; marker size ∝ bin share; "
                 f"line = OLS on firm data)", fontsize=11)
    fig.tight_layout()
    fig.savefig(GR / f"binscatter_conn_combined{suffix}.pdf", bbox_inches="tight", dpi=150)
    plt.close(fig)
    return rows


BLUE, ORANGE, RED = "#2166AC", "#E08214", "#B2182B"
rows  = make_set(raw.in_spill == 1, "",         "Control (spillover) sample", BLUE,   RED)
rows += make_set(raw.in_treat == 1, "_treated", "Treated firms",              ORANGE, RED)

res = pd.DataFrame(rows)
res.to_csv(TBL / "firm_conn_slopes.csv", index=False)
print("\nOLS slopes (y on connectivity, HC1 SE):")
print(res[["set", "label", "slope", "se", "t", "n"]].round(4).to_string(index=False))
print("=== firm_conn_binscatter.py done ===")
