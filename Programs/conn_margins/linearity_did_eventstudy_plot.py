#!/usr/bin/env python3
"""
Part B figure — linear vs binned (nonparametric-in-connectivity) DiD.

For each calendar outcome, a two-panel figure:
  Left  : binned event study. Coefficients theta_{b,k} from
          Y = sum_b sum_k theta_{b,k} 1{Conn in b} 1{t=k} + FE + controls,
          one path per connectivity quintile b=2..5 (relative to bin 1, ref 2011).
          Shows whether higher-connectivity firms have larger post effects, and
          whether the ordering is monotone over event time.
  Right : dose-response linearity check. Pooled post-effect per bin theta_b
          (relative to bin 1) vs bin-mean connectivity, with the linear-DiD
          restriction theta(c) = beta_lin * (c - c_1) overlaid. Binned points
          tracking the line => the linear-in-connectivity restriction is adequate.

Inputs (Tables/conn_margins/):
  linearity_did_es_binned_<outcome>.csv
  linearity_did_dose_<outcome>.csv
Outputs:
  Graphs/conn_margins/linearity_did_eventstudy_<outcome>.pdf
"""

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.font_manager as fm
from pathlib import Path

FONT_PATH = "/kellogg/proj/lgg3230/UnionSpill/fonts/LibertinusSerif-Regular.otf"
RED = "#B2182B"

script_dir = Path(__file__).resolve().parent
tables_dir = script_dir.parent.parent / "Tables" / "conn_margins"
graphs_dir = script_dir.parent.parent / "Graphs" / "conn_margins"
graphs_dir.mkdir(parents=True, exist_ok=True)

if Path(FONT_PATH).exists():
    fm.fontManager.addfont(FONT_PATH)
    plt.rcParams["font.family"] = "Libertinus Serif"

OUTCOMES = {
    "lr_remdezr_w":   "Log December wage",
    "lr_remdezr_h_w": "Log hourly wage",
    "l_firm_emp":     "Log employment",
}
# sequential blues for quintiles 2..5
BIN_COLORS = {2: "#9ecae1", 3: "#4292c6", 4: "#2171b5", 5: "#084594"}


def make_figure(outcome, title):
    esb = pd.read_csv(tables_dir / f"linearity_did_es_binned_{outcome}.csv")
    dose = pd.read_csv(tables_dir / f"linearity_did_dose_{outcome}.csv")

    fig, (axL, axR) = plt.subplots(1, 2, figsize=(11, 4.6))

    # ── Left: binned event study ──────────────────────────────────────────────
    for b in [2, 3, 4, 5]:
        s = esb[esb["bin"] == b].sort_values("year")
        axL.errorbar(s["year"], s["coef"], yerr=1.96 * s["se"],
                     marker="o", markersize=4, linewidth=1.3, capsize=2,
                     color=BIN_COLORS[b], label=f"Quintile {b} vs Q1")
    axL.axhline(0, color="gray", linewidth=0.6)
    axL.axvline(2011.5, color="gray", linewidth=0.6, linestyle="--", alpha=0.6)
    axL.set_xlabel("Year", fontsize=11)
    axL.set_ylabel(f"{title}: bin $\\times$ year coefficient", fontsize=11)
    axL.set_title("Binned event study", fontsize=11)
    axL.tick_params(labelsize=9)
    axL.spines["top"].set_visible(False)
    axL.spines["right"].set_visible(False)
    axL.legend(frameon=False, fontsize=8, loc="best")

    # ── Right: dose-response linearity check ──────────────────────────────────
    dose = dose.sort_values("bin")
    c = dose["conn_mean"].values
    theta = dose["theta"].values
    se = dose["se"].values
    beta = float(dose["beta_lin"].iloc[0])
    c1 = c[0]

    axR.errorbar(c, theta, yerr=1.96 * se, fmt="o", markersize=7,
                 color="#084594", capsize=3, zorder=4, label="Binned post-effect")
    cg = np.linspace(c.min(), c.max(), 100)
    axR.plot(cg, beta * (cg - c1), color=RED, linewidth=1.8, zorder=3,
             label=f"Linear DiD restriction (slope {beta:.4f})")
    for cb_, tb_, bn in zip(c, theta, dose["bin"].values):
        axR.annotate(f"Q{int(bn)}", (cb_, tb_), textcoords="offset points",
                     xytext=(6, 6), fontsize=8, color="#084594")
    axR.axhline(0, color="gray", linewidth=0.6)
    axR.set_xlabel("Bin-mean connectivity (normalized)", fontsize=11)
    axR.set_ylabel("Post $-$ pre effect vs Q1", fontsize=11)
    axR.set_title("Dose-response: binned vs linear", fontsize=11)
    axR.tick_params(labelsize=9)
    axR.spines["top"].set_visible(False)
    axR.spines["right"].set_visible(False)
    axR.legend(frameon=False, fontsize=8.5, loc="best")

    fig.tight_layout()
    out = graphs_dir / f"linearity_did_eventstudy_{outcome}.pdf"
    fig.savefig(out, bbox_inches="tight")
    plt.close(fig)
    print(f"saved {out}")


for oc, t in OUTCOMES.items():
    make_figure(oc, t)
