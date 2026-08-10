#!/usr/bin/env python3
"""
Heterogeneous effects scatter: firm-level DiD (avg_post_resid - avg_pre_resid)
vs. raw normalized connectivity (totaltreat_pw_norm). 200 equal-frequency bins,
averaging both x and y within each bin.

Input:  Tables/conn_margins/scatter_resid_wages_panel.csv
Output: Graphs/conn_margins/scatter_resid_wages_raw.{pdf,png}
"""

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.font_manager as fm
from statsmodels.nonparametric.smoothers_lowess import lowess
from pathlib import Path

FONT_PATH = "/kellogg/proj/lgg3230/UnionSpill/fonts/LibertinusSerif-Regular.otf"

script_dir = Path(__file__).resolve().parent
tables_dir = script_dir.parent.parent / "Tables" / "conn_margins"
graphs_dir = script_dir.parent.parent / "Graphs" / "conn_margins"
graphs_dir.mkdir(parents=True, exist_ok=True)

# ── Font ──────────────────────────────────────────────────────────────────────

if Path(FONT_PATH).exists():
    fm.fontManager.addfont(FONT_PATH)
    plt.rcParams["font.family"] = "Libertinus Serif"

# ── Load panel, build firm-level DiD ─────────────────────────────────────────

df = pd.read_csv(tables_dir / "scatter_resid_wages_panel.csv")
df = df.dropna(subset=["totaltreat_pw_norm", "e_lr_remdezr_w"])

pre  = df[df["year"] < 2012].groupby("identificad")[["totaltreat_pw_norm", "e_lr_remdezr_w"]].mean()
post = df[df["year"] >= 2012].groupby("identificad")[["totaltreat_pw_norm", "e_lr_remdezr_w"]].mean()

firms = pre.join(post, lsuffix="_pre", rsuffix="_post", how="inner")
firms["diff"] = firms["e_lr_remdezr_w_post"] - firms["e_lr_remdezr_w_pre"]
# totaltreat_pw_norm is time-invariant; take pre value
firms["conn_raw"] = firms["totaltreat_pw_norm_pre"]
firms = firms[["conn_raw", "diff"]].dropna()

# Trim x at p99
p99 = firms["conn_raw"].quantile(0.99)
firms = firms[firms["conn_raw"] <= p99]
print(f"Firms: {len(firms):,}  |  conn_raw p99 (trim): {p99:.4f}")

N_BINS = 200

# ── Bin and fit ───────────────────────────────────────────────────────────────

firms_s = firms.copy()
firms_s["bin"] = pd.qcut(firms_s["conn_raw"], q=N_BINS, labels=False, duplicates="drop")
binned = firms_s.groupby("bin")[["conn_raw", "diff"]].mean().reset_index()
bx = binned["conn_raw"].values
by = binned["diff"].values

# LOWESS
smoothed = lowess(by, bx, frac=0.4, return_sorted=True)

# OLS reference
ols_coef = np.polyfit(bx, by, 1)
x_fit    = np.linspace(bx.min(), bx.max(), 300)
y_ols    = np.polyval(ols_coef, x_fit)

print(f"OLS slope: {ols_coef[0]:.4f}")

# ── Plot ──────────────────────────────────────────────────────────────────────

fig, ax = plt.subplots(figsize=(7, 4.5))

ax.scatter(bx, by, s=18, color="#999999", alpha=1.0, zorder=2, linewidths=0,
           label="Binned avg (200 equal-freq. bins)")

ax.plot(smoothed[:, 0], smoothed[:, 1], color="#0072B2", linewidth=2.2,
        zorder=4, label="LOWESS")

ax.plot(x_fit, y_ols, color="#E69F00", linewidth=1.8, linestyle="--",
        zorder=3, label=f"OLS  (slope: {ols_coef[0]:.4f})")

ax.axhline(0, color="gray", linewidth=0.6, linestyle="--", alpha=0.4, zorder=1)
ax.axvline(0, color="gray", linewidth=0.6, linestyle="--", alpha=0.4, zorder=1)

ax.set_xlabel("Normalized connectivity to treated firms", fontsize=12)
ax.set_ylabel("Post \u2212 Pre residualized log wages", fontsize=12)
ax.tick_params(labelsize=11)
ax.spines["top"].set_visible(False)
ax.spines["right"].set_visible(False)

ax.legend(
    frameon=False,
    fontsize=11,
    loc="upper center",
    bbox_to_anchor=(0.5, -0.18),
    ncol=3,
)

fig.tight_layout(rect=[0, 0.08, 1, 1])

out_pdf = graphs_dir / "scatter_resid_wages_raw.pdf"
fig.savefig(out_pdf, bbox_inches="tight")
print(f"Saved: {out_pdf}")

out_png = graphs_dir / "scatter_resid_wages_raw.png"
fig.savefig(out_png, dpi=160, bbox_inches="tight")
print(f"Saved: {out_png}")
