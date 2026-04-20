#!/usr/bin/env python3
"""
Figure 2 — Residualized binscatter (main FWL shape defense).
y: DiD in residualized log wages (avg post e_lr_remdezr_w − avg pre e_lr_remdezr_w).
x: pre-period average of residualized connectivity (e_conn).
Both variables partialled out of industry×year, mode×year, microregion×year,
baseline wage/size/flows quartile×year; outcome also absorbs firm FE.

Optimal binsreg bins (Cattaneo et al.), tiny jitter for zero mass point,
OLS line + 95% CI.

Input:  Tables/conn_margins/scatter_resid_wages_panel.csv
Output: Graphs/conn_margins/linearity_fig2_resid.{pdf,png}
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
# e_conn is only in pre, so no suffix was added
firms = firms[["e_conn", "did"]].dropna()
print(f"Firms: {len(firms):,}")

x = firms["e_conn"].values.astype(float)
y = firms["did"].values.astype(float)

# ── binsreg (tiny jitter to break zero mass point) ────────────────────────────

np.random.seed(42)
x_jitter = x + np.random.uniform(0, 1e-8, len(x))
df_bs = pd.DataFrame({"y": y, "x": x_jitter})

with warnings.catch_warnings():
    warnings.simplefilter("ignore")
    res = binsreg.binsreg("y", "x", data=df_bs, noplot=True, nbins=100)
d      = res.data_plot[0]
n_bins = len(d.dots)
print(f"Optimal bin count: {n_bins}")

# ── OLS + 95% CI ─────────────────────────────────────────────────────────────

X     = sm.add_constant(x)
mod   = sm.OLS(y, X).fit()
xg    = np.linspace(-5, 7.5, 300)
pr    = mod.get_prediction(sm.add_constant(xg))
ci    = pr.conf_int()
slope = mod.params[1]
print(f"OLS slope: {slope:.4f}  (≈ DiD coefficient on e_conn)")

# ── Plot ─────────────────────────────────────────────────────────────────────

fig, ax = plt.subplots(figsize=(7, 4.8))

ax.scatter(d.dots["x"], d.dots["fit"],
           s=20, color="#444444", zorder=4, linewidths=0,
           label=f"Bin means ({n_bins} optimal bins, Cattaneo et al.)")
ax.fill_between(xg, ci[:, 0], ci[:, 1], color=RED, alpha=0.12, zorder=1)
ax.plot(xg, pr.predicted_mean, color=RED, linewidth=1.8, zorder=5,
        label=f"OLS + 95% CI  (slope: {slope:.4f})")

ax.axhline(0, color="gray", linewidth=0.5, linestyle="--", alpha=0.4)
ax.axvline(0, color="gray", linewidth=0.5, linestyle="--", alpha=0.4)
ax.set_xlim(-5, 7.5)

ax.set_xlabel("Residualized connectivity to treated firms", fontsize=11)
ax.set_ylabel("Post \u2212 Pre residualized log wages", fontsize=11)
ax.tick_params(labelsize=10)
ax.spines["top"].set_visible(False)
ax.spines["right"].set_visible(False)
ax.legend(frameon=False, fontsize=10,
          loc="upper center", bbox_to_anchor=(0.5, -0.18), ncol=2)

fig.tight_layout(rect=[0, 0.06, 1, 1])

out = graphs_dir / "linearity_fig2_resid.pdf"
fig.savefig(out, bbox_inches="tight")
print(f"Saved: {out}")
