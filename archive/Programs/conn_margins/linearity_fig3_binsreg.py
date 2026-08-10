#!/usr/bin/env python3
"""
Figure 3 — binsreg nonparametric shape test.
50 optimal bins with pointwise 95% CIs (Cattaneo et al.).
OLS line overlaid. Wide CIs encompassing the OLS line support
the interpretation that we lack power to reject linearity.

Input:  Tables/conn_margins/scatter_resid_wages_panel.csv
Output: Graphs/conn_margins/linearity_fig3_binsreg.pdf
"""

import warnings
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.font_manager as fm
import statsmodels.api as sm
import binsreg
from pathlib import Path

FONT_PATH = "/kellogg/proj/lgg3230/UnionSpill/fonts/LibertinusSerif-Regular.otf"
BLUE = "#2166AC"
RED  = "#B2182B"

script_dir = Path(__file__).resolve().parent
tables_dir = script_dir.parent.parent / "Tables" / "conn_margins"
graphs_dir = script_dir.parent.parent / "Graphs" / "conn_margins"
graphs_dir.mkdir(parents=True, exist_ok=True)

if Path(FONT_PATH).exists():
    fm.fontManager.addfont(FONT_PATH)
    plt.rcParams["font.family"] = "Libertinus Serif"

# ── Load panel and build firm-level DiD ───────────────────────────────────────

df = pd.read_csv(tables_dir / "scatter_resid_wages_panel.csv")
df = df.dropna(subset=["e_conn", "e_lr_remdezr_w"])

pre  = df[df["year"] < 2012].groupby("identificad")[["e_conn", "e_lr_remdezr_w"]].mean()
post = df[df["year"] >= 2012].groupby("identificad")[["e_lr_remdezr_w"]].mean()

firms = pre.join(post, lsuffix="_pre", rsuffix="_post", how="inner")
firms["did"] = firms["e_lr_remdezr_w_post"] - firms["e_lr_remdezr_w_pre"]
firms = firms[["e_conn", "did"]].dropna()
print(f"Firms: {len(firms):,}")

x = firms["e_conn"].values.astype(float)
y = firms["did"].values.astype(float)

x_lo = np.quantile(x, 0.01)
x_hi = np.quantile(x, 0.99)

# ── binsreg: 50 bins with pointwise 95% CIs ──────────────────────────────────

np.random.seed(42)
x_jitter = x + np.random.uniform(0, 1e-8, len(x))
df_bs = pd.DataFrame({"y": y, "x": x_jitter})

with warnings.catch_warnings():
    warnings.simplefilter("ignore")
    res = binsreg.binsreg("y", "x", data=df_bs, noplot=True, nbins=50, cb=(3, 3))
    tst = binsreg.binstest("y", "x", data=df_bs,
                           testmodelpoly=1, nsims=2000, simsseed=42, simsgrid=50)
d = res.data_plot[0]

dots = d.dots
ci   = d.cb
print(f"Bins: {len(dots)}")

p_val = float(tst.testpoly.pval[0])
t_stat = float(tst.testpoly.stat[0])
print(f"Linearity test — stat: {t_stat:.4f}, p-value: {p_val:.4f}")

# ── OLS + analytical 95% CI ───────────────────────────────────────────────────

x_grid = np.linspace(x_lo, x_hi, 300)
X      = sm.add_constant(x)
mod    = sm.OLS(y, X).fit()
pr     = mod.get_prediction(sm.add_constant(x_grid))
ols_ci = pr.conf_int()
slope  = mod.params[1]
print(f"OLS slope: {slope:.4f}")

# ── Plot ─────────────────────────────────────────────────────────────────────

fig, ax = plt.subplots(figsize=(7, 4.8))

# binsreg uniform confidence band (dense x grid) + dots
ax.fill_between(ci["x"], ci["cb_l"], ci["cb_r"],
                color=BLUE, alpha=0.15, zorder=2,
                label="95% uniform confidence band (50 bins)")
ax.scatter(dots["x"], dots["fit"],
           s=20, color=BLUE, zorder=4, linewidths=0,
           label="Bin means")

# OLS + CI
ax.fill_between(x_grid, ols_ci[:, 0], ols_ci[:, 1],
                color=RED, alpha=0.12, zorder=1)
ax.plot(x_grid, pr.predicted_mean, color=RED, linewidth=1.8, zorder=5,
        label=f"OLS + 95% CI  (slope: {slope:.4f})")

ax.axhline(0, color="gray", linewidth=0.5, linestyle="--", alpha=0.4)
ax.axvline(0, color="gray", linewidth=0.5, linestyle="--", alpha=0.4)
ax.set_xlim(x_lo, x_hi)

p_str = f"$p = {p_val:.3f}$" if p_val >= 0.001 else "$p < 0.001$"
ax.text(0.98, 0.97, f"Linearity test: {p_str}",
        transform=ax.transAxes, ha="right", va="top",
        fontsize=9, style="italic")

ax.set_xlabel("Residualized connectivity to treated firms", fontsize=11)
ax.set_ylabel("Post \u2212 Pre residualized log wages", fontsize=11)
ax.tick_params(labelsize=10)
ax.spines["top"].set_visible(False)
ax.spines["right"].set_visible(False)
ax.legend(frameon=False, fontsize=9.5,
          loc="upper center", bbox_to_anchor=(0.5, -0.18), ncol=2)

fig.tight_layout(rect=[0, 0.06, 1, 1])

out = graphs_dir / "linearity_fig3_binsreg.pdf"
fig.savefig(out, bbox_inches="tight")
print(f"Saved: {out}")
