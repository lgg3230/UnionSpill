#!/usr/bin/env python3
"""
Figure 4 — Binned-coefficient plot (Facebook ties / JLE 2017 approach).
Bins connectivity into groups (zero bin + 9 positive-connectivity deciles),
regresses firm-level DiD on bin dummies, plots coefficients + 95% CI vs bin
midpoints. A linear fit through the coefficients tests whether the dose-response
is "positive and generally linear" (Gee, Jones & Burke 2017).

Input:  Tables/conn_margins/scatter_resid_wages.csv
Output: Graphs/conn_margins/linearity_fig4_bincoef.{pdf}
"""

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.font_manager as fm
import statsmodels.api as sm
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

# ── Load firm-level data and build DiD ────────────────────────────────────────

df = pd.read_csv(tables_dir / "scatter_resid_wages.csv")
df = df.dropna(subset=["conn_firm", "e_pre", "e_post"])
df["did"] = df["e_post"] - df["e_pre"]
print(f"Firms: {len(df):,}")

# ── Bin connectivity: zero bin + 9 positive-connectivity deciles ──────────────

df["conn_bin"] = 0
pos = df["conn_firm"] > 0
df.loc[pos, "conn_bin"] = pd.qcut(
    df.loc[pos, "conn_firm"], q=9, labels=range(1, 10), duplicates="drop"
).astype(int)

n_bins = df["conn_bin"].nunique()
print(f"Bins: {n_bins}  (bin 0 = zero connectivity, bins 1–9 = positive deciles)")

# Bin midpoints (mean connectivity within each bin)
bin_mid = df.groupby("conn_bin")["conn_firm"].mean().sort_index()
bin_n   = df.groupby("conn_bin")["did"].count()

# ── OLS: DiD ~ bin dummies (reference = bin 0) ───────────────────────────────

dummies = pd.get_dummies(df["conn_bin"], prefix="bin", drop_first=False).astype(float)
dummies = dummies.drop(columns=["bin_0"])          # bin 0 is reference
X       = sm.add_constant(dummies)
mod     = sm.OLS(df["did"], X).fit(cov_type="HC1")

coefs   = mod.params.drop("const")
ci      = mod.conf_int().drop("const")
ci_lo   = ci.iloc[:, 0].values
ci_hi   = ci.iloc[:, 1].values
coef_v  = coefs.values
x_pts   = bin_mid.iloc[1:].values   # midpoints for bins 1–9

# Reference bin effect = 0 (by construction); prepend for linear fit
x_all   = np.concatenate([[bin_mid.iloc[0]], x_pts])
y_all   = np.concatenate([[0.0], coef_v])

# Linear fit through all bin effects (incl. reference)
ols_c   = np.polyfit(x_all, y_all, 1)
x_fit   = np.linspace(x_all.min(), x_all.max(), 300)
y_fit   = np.polyval(ols_c, x_fit)

print(f"Linear slope through bin coefs: {ols_c[0]:.4f}")

# ── Plot ─────────────────────────────────────────────────────────────────────

fig, ax = plt.subplots(figsize=(7, 4.8))

# Reference bin (= 0 by construction)
ax.scatter(bin_mid.iloc[0], 0, s=50, color="#888888", zorder=5,
           marker="D", linewidths=0, label="Reference bin (zero connectivity)")

# Bin coefficients + 95% CI
ax.scatter(x_pts, coef_v, s=50, color=BLUE, zorder=5, linewidths=0,
           label="Bin coefficient (DiD, relative to zero-connectivity firms)")
ax.errorbar(x_pts, coef_v,
            yerr=[coef_v - ci_lo, ci_hi - coef_v],
            fmt="none", ecolor=BLUE, elinewidth=1.0, capsize=3, zorder=4)

# Linear fit through all bin effects
ax.plot(x_fit, y_fit, color=RED, linewidth=1.8, linestyle="-", zorder=3,
        label=f"Linear fit  (slope: {ols_c[0]:.4f})")

ax.axhline(0, color="gray", linewidth=0.5, linestyle="--", alpha=0.5)

ax.set_xlabel("Connectivity to treated firms (normalized, bin mean)", fontsize=11)
ax.set_ylabel("Post \u2212 Pre residualized log wages", fontsize=11)
ax.tick_params(labelsize=10)
ax.spines["top"].set_visible(False)
ax.spines["right"].set_visible(False)
ax.legend(frameon=False, fontsize=9.5,
          loc="upper center", bbox_to_anchor=(0.5, -0.18), ncol=2)

fig.tight_layout(rect=[0, 0.06, 1, 1])

out = graphs_dir / "linearity_fig4_bincoef.pdf"
fig.savefig(out, bbox_inches="tight")
print(f"Saved: {out}")
