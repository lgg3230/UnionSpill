#!/usr/bin/env python3
"""
First-difference linearity figure — binsreg with INTERNAL covariate adjustment.

For each outcome, plots a covariate-adjusted binscatter of the firm-level first
difference dY_j = mean(Y, 2012-16) - mean(Y, 2009-11) against connectivity, with
a 95% uniform confidence band (Cattaneo et al. 2024). Controls enter binsreg via
w (the semi-linear partial-mean estimator, eq. 3) -- NO pre-residualization. The
firm fixed effect of the panel DiD is removed exactly by the differencing.

The annotated p-value is the sup-norm linearity test from the Stata binstest on
the SAME cross-section (linearity_did_fd_test.csv).

Inputs:
  Tables/conn_margins/linearity_did_fd_<outcome>.csv
  Tables/conn_margins/linearity_did_fd_test.csv
Outputs:
  Graphs/conn_margins/linearity_did_fd_<outcome>.pdf
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

OUTCOMES = {
    "lr_remdezr_w":   "Post − Pre log December wage",
    "lr_remdezr_h_w": "Post − Pre log hourly wage",
    "l_firm_emp":     "Post − Pre log employment",
    "numb_clauses":   "Post − Pre \\# CBA clauses",
}

CAT_COLS = ["industry1", "mode_base_month", "microregion",
            "outcome_pre4", "l_firm_emp_pre4", "totalflows_pw_pre_07_114"]

test = pd.read_csv(tables_dir / "linearity_did_fd_test.csv")


def make_figure(outcome, ylab):
    f = tables_dir / f"linearity_did_fd_{outcome}.csv"
    if not f.exists():
        print(f"  skip {outcome}: no cross-section file")
        return
    df = pd.read_csv(f).dropna(subset=["outcome_fd", "totaltreat_pw_norm"])
    y = df["outcome_fd"].values.astype(float)
    x = df["totaltreat_pw_norm"].values.astype(float)
    print(f"{outcome}: {len(df):,} firms")

    # Internal covariate adjustment: build w dummies, pass to binsreg.
    # For l_firm_emp the outcome bin IS the employment bin (same column),
    # so use whichever control columns are actually present.
    cat_cols = [c for c in CAT_COLS if c in df.columns]
    for c in cat_cols:
        df[c] = df[c].astype("category")
    W = pd.get_dummies(df[cat_cols], drop_first=True, dtype=float)
    w_cols = W.columns.tolist()

    # masspoints="nolocalcheck" mirrors the Stata binstest option, so the figure
    # collapses the conn=0 mass into the same bins the test uses (no jitter).
    df_bs = pd.concat([pd.DataFrame({"y": y, "x": x}),
                       W.reset_index(drop=True)], axis=1)
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        res = binsreg.binsreg("y", "x", w=w_cols, data=df_bs,
                              noplot=True, nbins=50, cb=(3, 3),
                              masspoints="nolocalcheck")
    d = res.data_plot[0]
    dots, cb = d.dots, d.cb
    nb = dots["x"].notna().sum()

    # p-value from Stata binstest on the same cross-section
    row = test[test["outcome"] == outcome].iloc[0]
    p_val = float(row["pval"])

    # OLS line (slope == linear DiD coefficient) with W at means
    x_lo, x_hi = np.quantile(x, 0.01), np.quantile(x, 0.99)
    xg = np.linspace(x_lo, x_hi, 300)
    Xmat = sm.add_constant(np.column_stack([x] + [W[c].values for c in w_cols]))
    mod = sm.OLS(y, Xmat).fit(cov_type="HC1")
    slope = mod.params[1]
    wm = W.mean().values
    Xg = np.column_stack([np.ones(300), xg] +
                         [np.full(300, wm[i]) for i in range(len(w_cols))])
    pr = mod.get_prediction(Xg)
    ci = pr.conf_int()

    fig, ax = plt.subplots(figsize=(7, 4.8))
    ax.fill_between(cb["x"], cb["cb_l"], cb["cb_r"], color=BLUE, alpha=0.15,
                    zorder=2, label=f"95% uniform confidence band ({nb} bins)")
    ax.scatter(dots["x"], dots["fit"], s=20, color=BLUE, zorder=4,
               linewidths=0, label="Bin means")
    ax.fill_between(xg, ci[:, 0], ci[:, 1], color=RED, alpha=0.12, zorder=1)
    ax.plot(xg, pr.predicted_mean, color=RED, linewidth=1.8, zorder=5,
            label=f"OLS + 95% CI  (slope: {slope:.4f})")

    ax.axhline(0, color="gray", linewidth=0.5, linestyle="--", alpha=0.4)
    ax.axvline(0, color="gray", linewidth=0.5, linestyle="--", alpha=0.4)
    ax.set_xlim(x_lo, x_hi)

    p_str = f"$p = {p_val:.3f}$" if p_val >= 0.001 else "$p < 0.001$"
    ax.text(0.98, 0.97, f"Linearity test: {p_str}", transform=ax.transAxes,
            ha="right", va="top", fontsize=9, style="italic")

    ax.set_xlabel("Connectivity to treated firms (normalized)", fontsize=11)
    ax.set_ylabel(ylab, fontsize=11)
    ax.tick_params(labelsize=10)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.legend(frameon=False, fontsize=9.5, loc="upper center",
              bbox_to_anchor=(0.5, -0.18), ncol=2)
    fig.tight_layout(rect=[0, 0.06, 1, 1])
    out = graphs_dir / f"linearity_did_fd_{outcome}.pdf"
    fig.savefig(out, bbox_inches="tight")
    plt.close(fig)
    print(f"  saved {out}  (p={p_val:.3f}, slope={slope:.4f}, bins={nb})")


for oc, lab in OUTCOMES.items():
    make_figure(oc, lab)
