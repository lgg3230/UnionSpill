#!/usr/bin/env python3
"""
Part A figure — panel DiD residualized linearity binscatter (NCA-style).

For each outcome, plots binsreg of residualized outcome (Ytilde) against
residualized treatment intensity (Dtilde = Conn x Post, FWL-residualized on the
same firm FE + year/x-year FE + controls as the main spec), with a uniform 95%
confidence band (Cattaneo et al. 2024). Overlays the OLS line whose slope equals
the linear DiD coefficient. The annotated p-value is the sup-norm linearity test
from the Stata binstest on the SAME residuals (linearity_did_test.csv).

Inputs:
  Tables/conn_margins/linearity_did_resid_<outcome>.csv
  Tables/conn_margins/linearity_did_test.csv
Outputs:
  Graphs/conn_margins/linearity_did_<outcome>.pdf
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
    "lr_remdezr_w":   "Residualized log December wage",
    "lr_remdezr_h_w": "Residualized log hourly wage",
    "l_firm_emp":     "Residualized log employment",
    "numb_clauses":   "Residualized \\# CBA clauses",
}

test = pd.read_csv(tables_dir / "linearity_did_test.csv")


def make_figure(outcome, ylab):
    f = tables_dir / f"linearity_did_resid_{outcome}.csv"
    if not f.exists():
        print(f"  skip {outcome}: no residual file")
        return
    df = pd.read_csv(f).dropna(subset=["yres", "dres"])
    y = df["yres"].values.astype(float)
    x = df["dres"].values.astype(float)
    cl = df["firm_num"].values
    print(f"{outcome}: {len(df):,} obs")

    # binsreg with uniform CB, clustered by firm
    np.random.seed(42)
    x_j = x + np.random.uniform(0, 1e-9, len(x))
    df_bs = pd.DataFrame({"y": y, "x": x_j, "cl": cl})
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        res = binsreg.binsreg("y", "x", data=df_bs, cluster="cl",
                              noplot=True, nbins=50, cb=(3, 3))
    d = res.data_plot[0]
    dots, cb = d.dots, d.cb
    nb = dots["x"].notna().sum()

    # p-value from Stata binstest on identical residuals
    row = test[test["outcome"] == outcome].iloc[0]
    p_val = float(row["pval"])

    # OLS line (slope == linear DiD coefficient by FWL)
    x_lo, x_hi = np.quantile(x, 0.01), np.quantile(x, 0.99)
    xg = np.linspace(x_lo, x_hi, 300)
    mod = sm.OLS(y, sm.add_constant(x)).fit(cov_type="cluster",
                                            cov_kwds={"groups": cl})
    slope = mod.params[1]
    pr = mod.get_prediction(sm.add_constant(xg))
    ci = pr.conf_int()

    fig, ax = plt.subplots(figsize=(7, 4.8))
    ax.fill_between(cb["x"], cb["cb_l"], cb["cb_r"], color=BLUE, alpha=0.15,
                    zorder=2, label=f"95% uniform confidence band ({nb} bins)")
    ax.scatter(dots["x"], dots["fit"], s=18, color=BLUE, zorder=4,
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

    ax.set_xlabel("Residualized connectivity $\\times$ post (treatment intensity)",
                  fontsize=11)
    ax.set_ylabel(ylab, fontsize=11)
    ax.tick_params(labelsize=10)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.legend(frameon=False, fontsize=9.5, loc="upper center",
              bbox_to_anchor=(0.5, -0.18), ncol=2)
    fig.tight_layout(rect=[0, 0.06, 1, 1])
    out = graphs_dir / f"linearity_did_{outcome}.pdf"
    fig.savefig(out, bbox_inches="tight")
    plt.close(fig)
    print(f"  saved {out}  (p={p_val:.3f}, slope={slope:.4f}, bins={nb})")


for oc, lab in OUTCOMES.items():
    make_figure(oc, lab)
