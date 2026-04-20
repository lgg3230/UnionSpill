#!/usr/bin/env python3
"""
Figure 1 — Raw relationship (sanity check).
Binscatter of raw log wages (lr_remdezr_w) vs normalized connectivity.
Two panels: pre-treatment (2009–2011) and post-treatment (2012–2016).
Optimal binsreg bins (Cattaneo et al.), tiny jitter to handle zero mass point,
OLS line + 95% CI, LOWESS. No FE or covariate controls.

Input:  Data/CBA_RAIS_firm_level/lagos_sample_sep24_pct_unionexp_ext_df2.dta
Output: Graphs/conn_margins/linearity_fig1_raw.{pdf,png}
"""

import warnings
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.font_manager as fm
import statsmodels.api as sm
import binsreg
from scipy.interpolate import LSQUnivariateSpline
from pathlib import Path

FONT_PATH = "/kellogg/proj/lgg3230/UnionSpill/fonts/LibertinusSerif-Regular.otf"
BLUE = "#2166AC"
RED  = "#B2182B"

script_dir = Path(__file__).resolve().parent
data_dir   = script_dir.parent.parent / "Data" / "CBA_RAIS_firm_level"
graphs_dir = script_dir.parent.parent / "Graphs" / "conn_margins"
graphs_dir.mkdir(parents=True, exist_ok=True)

if Path(FONT_PATH).exists():
    fm.fontManager.addfont(FONT_PATH)
    plt.rcParams["font.family"] = "Libertinus Serif"

# ── Load and filter ───────────────────────────────────────────────────────────

cols = ["identificad", "year", "lr_remdezr_w", "totaltreat_pw_n",
        "lagos_sample_avg", "treat_ultra", "in_balanced_panel"]
raw = pd.read_stata(data_dir / "lagos_sample_sep24_pct_unionexp_ext_df2.dta", columns=cols)

spill = (raw["lagos_sample_avg"] == 1) & (raw["treat_ultra"] == 0) & \
        (raw["in_balanced_panel"] == 1) & (raw["year"] >= 2009)
df = raw[spill].copy()
print(f"Spillover sample: {len(df):,} firm-years, {df['identificad'].nunique():,} firms")

# ── Normalize connectivity (p90 among spillover sample in 2009) ───────────────

p90 = df.loc[df["year"] == 2009, "totaltreat_pw_n"].quantile(0.90)
df["conn_norm"] = df["totaltreat_pw_n"] / p90
print(f"p90 connectivity (2009): {p90:.6f}")

# ── Firm-level pre/post averages ──────────────────────────────────────────────

pre_df = df[df["year"].between(2009, 2011)].groupby("identificad").agg(
    raw_wage=("lr_remdezr_w", "mean"),
    conn    =("conn_norm",    "mean"),
).reset_index().dropna()

post_df = df[df["year"].between(2012, 2016)].groupby("identificad").agg(
    raw_wage=("lr_remdezr_w", "mean"),
).reset_index().dropna()

firms_pre  = pre_df.copy()
firms_post = pre_df[["identificad", "conn"]].merge(post_df, on="identificad", how="inner")
print(f"Firms — pre: {len(firms_pre):,}  |  post: {len(firms_post):,}")


# ── OLS + 95% CI helper ───────────────────────────────────────────────────────

def ols_with_ci(x, y, n_grid=300, x_lo=None, x_hi=None):
    X   = sm.add_constant(x)
    mod = sm.OLS(y, X).fit()
    xg  = np.linspace(x_lo if x_lo is not None else x.min(),
                      x_hi if x_hi is not None else x.max(), n_grid)
    pr  = mod.get_prediction(sm.add_constant(xg))
    ci  = pr.conf_int()
    return xg, pr.predicted_mean, ci[:, 0], ci[:, 1], mod.params[1]


# OLS colors per panel — different hues, both distinguishable in B&W via line style
OLS_COLORS = [RED, "#1A9850"]   # pre: red, post: green
SPLINE_COLOR = "#333333"        # dark gray dashed — B&W safe

# ── Plot ─────────────────────────────────────────────────────────────────────

fig, axes = plt.subplots(1, 2, figsize=(11, 4.5), sharey=False)

panels = [
    (firms_pre,  "Pre-treatment (2009\u20132011)", axes[0]),
    (firms_post, "Post-treatment (2012\u20132016)", axes[1]),
]

np.random.seed(42)
slopes = []

for (firms, title, ax), ols_color in zip(panels, OLS_COLORS):
    x = firms["conn"].values.astype(float)
    y = firms["raw_wage"].values.astype(float)

    # Tiny jitter breaks the mass point at zero for binsreg binning only
    x_jitter = x + np.random.uniform(0, 1e-8, len(x))
    df_bs = pd.DataFrame({"y": y, "x": x_jitter})

    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        res = binsreg.binsreg("y", "x", data=df_bs, noplot=True, nbins=100)
    d      = res.data_plot[0]
    n_bins = len(d.dots)

    ax.scatter(d.dots["x"], d.dots["fit"],
               s=20, color="#444444", zorder=4, linewidths=0)

    xg, y_ols, ci_lo, ci_hi, slope = ols_with_ci(x, y, x_lo=-0.1, x_hi=4.5)
    slopes.append(slope)
    ax.fill_between(xg, ci_lo, ci_hi, color=ols_color, alpha=0.12, zorder=1)
    ax.plot(xg, y_ols, color=ols_color, linewidth=1.8, zorder=5)

    knots = np.quantile(x[x > 0], [0.10, 0.25, 0.50, 0.75, 0.90])
    idx   = np.argsort(x)
    xg_sp = np.linspace(-0.1, 4.5, 300)
    sp    = LSQUnivariateSpline(x[idx], y[idx], t=knots, k=3)

    B = 300
    boots = np.full((B, len(xg_sp)), np.nan)
    for b in range(B):
        ib      = np.random.choice(len(x), len(x), replace=True)
        xb, yb  = x[ib], y[ib]
        kb      = np.quantile(xb[xb > 0], [0.10, 0.25, 0.50, 0.75, 0.90])
        try:
            sb = LSQUnivariateSpline(xb[np.argsort(xb)], yb[np.argsort(xb)], t=kb, k=3)
            boots[b] = sb(xg_sp)
        except Exception:
            pass
    sp_lo = np.nanpercentile(boots, 2.5,  axis=0)
    sp_hi = np.nanpercentile(boots, 97.5, axis=0)

    ax.fill_between(xg_sp, sp_lo, sp_hi, color=SPLINE_COLOR, alpha=0.12, zorder=2)
    ax.plot(xg_sp, sp(xg_sp), color=SPLINE_COLOR, linewidth=2.0,
            linestyle="--", zorder=6)

    ax.axhline(0, color="gray", linewidth=0.5, linestyle="--", alpha=0.4)
    ax.set_xlim(-0.1, 4.5)
    ax.set_ylim(7.2, 8)
    ax.set_title(title, fontsize=11, pad=6)
    ax.set_xlabel("Connectivity to treated firms (normalized)", fontsize=10)
    ax.set_ylabel("Log wages", fontsize=10)
    ax.tick_params(labelsize=9)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)

# Single shared legend — custom handles to show both slopes
from matplotlib.lines import Line2D
from matplotlib.patches import Patch
legend_elements = [
    Line2D([0], [0], marker="o", color="w", markerfacecolor="#444444",
           markersize=6, label=f"Bin means ({n_bins} bins)"),
    Line2D([0], [0], color=OLS_COLORS[0], linewidth=1.8,
           label=f"OLS pre (slope: {slopes[0]:.4f})"),
    Line2D([0], [0], color=OLS_COLORS[1], linewidth=1.8,
           label=f"OLS post (slope: {slopes[1]:.4f})"),
    Line2D([0], [0], color=SPLINE_COLOR, linewidth=2.0,
           linestyle="--", label="Natural cubic spline + 95% CI (5 knots)"),
]
fig.legend(handles=legend_elements, frameon=False, fontsize=9,
           loc="lower center", bbox_to_anchor=(0.5, 0.01), ncol=4)

fig.subplots_adjust(bottom=0.2)

out = graphs_dir / "linearity_fig1_raw.pdf"
fig.savefig(out, bbox_inches="tight")
print(f"Saved: {out}")
