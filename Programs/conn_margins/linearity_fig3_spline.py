#!/usr/bin/env python3
"""
Figure 3 — Spline overlay vs OLS + CI (linearity test).
Same residualized DiD data as Figure 2.
Shows: optimal bin means (gray), OLS + 95% CI (red),
natural cubic spline + 95% bootstrap CI (blue).

Spline: 3 interior knots at p25/p50/p75 of residualized connectivity.
Bootstrap CI: B=300 firm-level resamples.

Input:  Tables/conn_margins/scatter_resid_wages_panel.csv
Output: Graphs/conn_margins/linearity_fig3_spline.{pdf,png}
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
N_GRID = 300

script_dir = Path(__file__).resolve().parent
tables_dir = script_dir.parent.parent / "Tables" / "conn_margins"
graphs_dir = script_dir.parent.parent / "Graphs" / "conn_margins"
graphs_dir.mkdir(parents=True, exist_ok=True)

if Path(FONT_PATH).exists():
    fm.fontManager.addfont(FONT_PATH)
    plt.rcParams["font.family"] = "Libertinus Serif"

# ── Load panel and build firm-level DiD (same as Figure 2) ───────────────────

df = pd.read_csv(tables_dir / "scatter_resid_wages_panel.csv")
df = df.dropna(subset=["e_conn", "e_lr_remdezr_w"])

pre  = df[df["year"] < 2012].groupby("identificad")[["e_conn", "e_lr_remdezr_w"]].mean()
post = df[df["year"] >= 2012].groupby("identificad")[["e_lr_remdezr_w"]].mean()

firms = pre.join(post, lsuffix="_pre", rsuffix="_post", how="inner")
firms["did"] = firms["e_lr_remdezr_w_post"] - firms["e_lr_remdezr_w_pre"]
# e_conn is only in pre, so no suffix was added
firms = firms[["e_conn", "did"]].dropna()
print(f"Firms: {len(firms):,}")

x = firms["e_conn"].values.astype(float)
y = firms["did"].values.astype(float)
# Clip display range to p1/p99 to avoid off-support extrapolation
x_lo   = np.quantile(x, 0.01)
x_hi   = np.quantile(x, 0.99)
x_grid = np.linspace(x_lo, x_hi, N_GRID)

# ── binsreg dots (no CI — kept clean for the overlay) ────────────────────────

np.random.seed(42)
x_jitter = x + np.random.uniform(0, 1e-8, len(x))
df_bs = pd.DataFrame({"y": y, "x": x_jitter})

with warnings.catch_warnings():
    warnings.simplefilter("ignore")
    res = binsreg.binsreg("y", "x", data=df_bs, noplot=True, nbins=100)
d      = res.data_plot[0]
n_bins = len(d.dots)
print(f"Optimal bin count: {n_bins}")

# ── OLS + analytical 95% CI ───────────────────────────────────────────────────

X     = sm.add_constant(x)
mod   = sm.OLS(y, X).fit()
pr    = mod.get_prediction(sm.add_constant(x_grid))
ols_ci = pr.conf_int()
slope  = mod.params[1]
print(f"OLS slope: {slope:.4f}")

# ── Natural cubic spline (3 interior knots at p25/p50/p75) ───────────────────

knots = np.quantile(x, [0.25, 0.50, 0.75])


def fit_spline(xv, yv, xg, t):
    idx = np.argsort(xv)
    sp  = LSQUnivariateSpline(xv[idx], yv[idx], t=t, k=3)
    return sp(xg)


y_spline = fit_spline(x, y, x_grid, knots)

# Bootstrap CI (B=300 firm-level resamples)
B = 300
np.random.seed(42)
boots = np.full((B, N_GRID), np.nan)
for b in range(B):
    idx_b   = np.random.choice(len(x), len(x), replace=True)
    xb, yb  = x[idx_b], y[idx_b]
    knots_b = np.quantile(xb, [0.25, 0.50, 0.75])
    try:
        boots[b] = fit_spline(xb, yb, x_grid, knots_b)
    except Exception:
        pass

sp_ci_lo = np.nanpercentile(boots, 2.5,  axis=0)
sp_ci_hi = np.nanpercentile(boots, 97.5, axis=0)
print("Bootstrap CI computed.")

# ── Plot ─────────────────────────────────────────────────────────────────────

fig, ax = plt.subplots(figsize=(7, 4.8))

# Bin means (gray, no error bars — clean for overlay)
ax.scatter(d.dots["x"], d.dots["fit"],
           s=20, color="#888888", zorder=4, linewidths=0,
           label=f"Bin means ({n_bins} optimal bins)")

# OLS + CI
ax.fill_between(x_grid, ols_ci[:, 0], ols_ci[:, 1],
                color=RED, alpha=0.12, zorder=1)
ax.plot(x_grid, pr.predicted_mean, color=RED, linewidth=1.8, zorder=5,
        label=f"OLS + 95% CI  (slope: {slope:.4f})")

# Spline + bootstrap CI
ax.fill_between(x_grid, sp_ci_lo, sp_ci_hi,
                color=BLUE, alpha=0.12, zorder=2)
ax.plot(x_grid, y_spline, color=BLUE, linewidth=2.0, linestyle="--",
        zorder=6,
        label="Natural cubic spline + 95% CI  (knots at p25/p50/p75)")

ax.axhline(0, color="gray", linewidth=0.5, linestyle="--", alpha=0.4)
ax.axvline(0, color="gray", linewidth=0.5, linestyle="--", alpha=0.4)
ax.set_xlim(x_lo, x_hi)

ax.set_xlabel("Residualized connectivity to treated firms", fontsize=11)
ax.set_ylabel("Post \u2212 Pre residualized log wages", fontsize=11)
ax.tick_params(labelsize=10)
ax.spines["top"].set_visible(False)
ax.spines["right"].set_visible(False)
ax.legend(frameon=False, fontsize=9.5,
          loc="upper center", bbox_to_anchor=(0.5, -0.18), ncol=2)

fig.tight_layout(rect=[0, 0.06, 1, 1])

out = graphs_dir / "linearity_fig3_spline.pdf"
fig.savefig(out, bbox_inches="tight")
print(f"Saved: {out}")
