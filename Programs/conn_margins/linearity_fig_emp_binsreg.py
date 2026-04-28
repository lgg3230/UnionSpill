#!/usr/bin/env python3
"""
Appendix figure — nonparametric shape test for log employment vs connectivity.

Cross-section at year 2011. Covariate-adjusted binsreg (50 bins) following
Cattaneo et al. (2024); p-value from canonical Stata binstest stored in
linearity_binstest_panel.csv.

Output: Graphs/conn_margins/linearity_fig_emp_binsreg.pdf
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
root_dir   = script_dir.parent.parent
tables_dir = root_dir / "Tables" / "conn_margins"
graphs_dir = root_dir / "Graphs" / "conn_margins"
rais_firm  = root_dir / "Data" / "CBA_RAIS_firm_level"
rais_aux   = root_dir / "Data" / "RAIS_aux"
graphs_dir.mkdir(parents=True, exist_ok=True)

if Path(FONT_PATH).exists():
    fm.fontManager.addfont(FONT_PATH)
    plt.rcParams["font.family"] = "Libertinus Serif"

# ── Load panel ────────────────────────────────────────────────────────────────

cols = ["identificad", "year", "l_firm_emp",
        "lagos_sample_avg", "treat_ultra", "in_balanced_panel",
        "industry1", "mode_base_month", "microregion",
        "totaltreat_pw_norm"]

panel = pd.read_stata(rais_firm / "lagos_sample_sep24_pct_unionexp_ext_df2.dta",
                      columns=cols)
panel["identificad"] = panel["identificad"].astype(str).str.strip()

s_spill = (
    (panel["lagos_sample_avg"] == 1) &
    (panel["treat_ultra"] == 0) &
    (panel["in_balanced_panel"] == 1)
)

# ── Compute l_firm_emp_pre4: quartile bins of 2009-2011 mean employment ───────

pre_emp = (
    panel[s_spill & panel["year"].isin([2009, 2010, 2011])]
    .groupby("identificad")["l_firm_emp"]
    .mean()
    .rename("l_firm_emp_pre")
    .reset_index()
)
pre_emp["l_firm_emp_pre4"] = pd.qcut(
    pre_emp["l_firm_emp_pre"], q=4, labels=False, duplicates="drop"
)

# ── Load totalflows and compute totalflows_pw_pre_07_114 ──────────────────────

tf = pd.read_csv(rais_aux / "totalflows_wide_2007_2011.csv")
tf["identificad"] = tf["identificad"].apply(lambda x: str(int(x)).zfill(14))

yp_cols = ["totalflows_pw_07_08", "totalflows_pw_08_09",
           "totalflows_pw_09_10", "totalflows_pw_10_11"]
tf["tf_pre"] = tf[yp_cols].mean(axis=1, skipna=True)

# quartile bins (mirroring Stata: group(4), zero-fill missing)
valid = tf["tf_pre"].dropna()
tf["totalflows_pw_pre_07_114"] = pd.qcut(
    tf["tf_pre"], q=4, labels=False, duplicates="drop"
)
tf["totalflows_pw_pre_07_114"] = tf["totalflows_pw_pre_07_114"].fillna(0).astype(int)

# ── Cross-section at year 2011 ────────────────────────────────────────────────

df = panel[s_spill & (panel["year"] == 2011)].copy()
df = df.merge(pre_emp[["identificad", "l_firm_emp_pre4"]], on="identificad", how="left")
df = df.merge(tf[["identificad", "totalflows_pw_pre_07_114"]],  on="identificad", how="left")
df["totalflows_pw_pre_07_114"] = df["totalflows_pw_pre_07_114"].fillna(0).astype(int)
df = df.dropna(subset=["l_firm_emp", "totaltreat_pw_norm", "l_firm_emp_pre4"])

print(f"Firms: {len(df):,}")

x = df["totaltreat_pw_norm"].values.astype(float)
y = df["l_firm_emp"].values.astype(float)

x_lo = np.quantile(x, 0.01)
x_hi = np.quantile(x, 0.99)

# ── Build control matrix ──────────────────────────────────────────────────────

cat_cols = ["industry1", "mode_base_month", "microregion",
            "l_firm_emp_pre4", "totalflows_pw_pre_07_114"]
for col in cat_cols:
    df[col] = df[col].astype("category")

W = pd.get_dummies(df[cat_cols], drop_first=True, dtype=float)
print(f"Control matrix: {W.shape[1]} dummies")

# ── binsreg: covariate-adjusted, 50 bins, uniform CB ─────────────────────────

np.random.seed(42)
x_jitter = x + np.random.uniform(0, 1e-8, len(x))
df_bs = pd.DataFrame({"y": y, "x": x_jitter})
df_bs = pd.concat([df_bs, W.reset_index(drop=True)], axis=1)
w_cols = W.columns.tolist()

with warnings.catch_warnings():
    warnings.simplefilter("ignore")
    res = binsreg.binsreg("y", "x", w=w_cols, data=df_bs,
                          noplot=True, nbins=50, cb=(3, 3))

d    = res.data_plot[0]
dots = d.dots
cb   = d.cb
print(f"Bins: {len(dots)}")

# ── p-value from canonical Stata binstest ────────────────────────────────────

bt     = pd.read_csv(tables_dir / "linearity_binstest_panel.csv")
row    = bt[bt["outcome"] == "l_firm_emp"].iloc[0]
p_val  = float(row["pval"])
t_stat = float(row["stat_supt"])
print(f"Linearity test (Stata) — stat: {t_stat:.4f}, p-value: {p_val:.4f}")

# ── OLS with same controls ────────────────────────────────────────────────────

x_grid = np.linspace(x_lo, x_hi, 300)
Xmat   = sm.add_constant(np.column_stack([x] + [W[c].values for c in w_cols]))
mod    = sm.OLS(y, Xmat).fit()
slope  = mod.params[1]
print(f"OLS slope on connectivity: {slope:.4f}")

w_means = W.mean().values
Xg  = np.column_stack([np.ones(300), x_grid] +
                      [np.full(300, w_means[i]) for i in range(len(w_cols))])
pr      = mod.get_prediction(Xg)
ols_ci  = pr.conf_int()

# ── Plot ──────────────────────────────────────────────────────────────────────

fig, ax = plt.subplots(figsize=(7, 4.8))

ax.fill_between(cb["x"], cb["cb_l"], cb["cb_r"],
                color=BLUE, alpha=0.15, zorder=2,
                label="95\\% uniform confidence band (50 bins)")
ax.scatter(dots["x"], dots["fit"],
           s=20, color=BLUE, zorder=4, linewidths=0,
           label="Bin means")

ax.fill_between(x_grid, ols_ci[:, 0], ols_ci[:, 1],
                color=RED, alpha=0.12, zorder=1)
ax.plot(x_grid, pr.predicted_mean, color=RED, linewidth=1.8, zorder=5,
        label=f"OLS + 95\\% CI  (slope: {slope:.4f})")

ax.axvline(0, color="gray", linewidth=0.5, linestyle="--", alpha=0.4)
ax.set_xlim(right=7.6)

p_str = f"$p = {p_val:.3f}$" if p_val >= 0.001 else "$p < 0.001$"
ax.text(0.98, 0.97, f"Linearity test: {p_str}",
        transform=ax.transAxes, ha="right", va="top",
        fontsize=9, style="italic")

ax.set_xlabel("Connectivity to treated firms", fontsize=11)
ax.set_ylabel("Log employment (2011)", fontsize=11)
ax.tick_params(labelsize=10)
ax.spines["top"].set_visible(False)
ax.spines["right"].set_visible(False)
ax.legend(frameon=False, fontsize=9.5,
          loc="upper center", bbox_to_anchor=(0.5, -0.18), ncol=2)

fig.tight_layout(rect=[0, 0.06, 1, 1])

out = graphs_dir / "linearity_fig_emp_binsreg.pdf"
fig.savefig(out, bbox_inches="tight")
print(f"Saved: {out}")
