#!/usr/bin/env python
"""
honest_did_rm_spillover_2x2.py
2x2 figure of the Delta^RM (relative magnitudes) sensitivity for the SPILLOVER
effects only, first post-period target. Reads the FINE-grid results
(honest_did_results_fine.csv, Mbar grid 0(0.05)1). Robust CI shown as a shaded
band over Mbar in [0,1]; original OLS CI as a reference; breakdown marked.
Run: /opt/homebrew/bin/python3 Programs/honest_did/honest_did_rm_spillover_2x2.py
"""
from pathlib import Path
import numpy as np, pandas as pd
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
from matplotlib.patches import Patch

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
TBL  = ROOT / "Tables" / "honest_did"
GR   = ROOT / "Graphs" / "honest_did"; GR.mkdir(parents=True, exist_ok=True)
CSV  = TBL / "honest_did_results_fine.csv"

# Libertinus Serif if available (silent fallback)
try:
    import matplotlib.font_manager as fm
    fdir = HERE.parent / "fonts"
    if fdir.exists():
        for v in ["LibertinusSerif-Regular.otf","LibertinusSerif-Italic.otf",
                  "LibertinusSerif-Bold.otf"]:
            if (fdir/v).exists(): fm.fontManager.addfont(str(fdir/v))
        plt.rcParams["font.family"]="Libertinus Serif"
        plt.rcParams["mathtext.fontset"]="custom"
        plt.rcParams["mathtext.rm"]="Libertinus Serif"
        plt.rcParams["mathtext.it"]="Libertinus Serif:italic"
except Exception: pass

C_ORIG, C_ROBUST = "#2166AC", "#B2182B"
ORDER  = ["lr_remdezr_w","lr_remdezr_h_w","l_firm_emp","numb_clauses"]
LABEL  = {"lr_remdezr_w":"Log wages","lr_remdezr_h_w":"Log hourly wages",
          "l_firm_emp":"Log employment","numb_clauses":"# CBA clauses"}

def breakdown(m, lb):
    if lb[0] <= 0: return 0.0
    for i in range(1, len(m)):
        if lb[i] <= 0:
            return m[i-1] + (m[i]-m[i-1])*lb[i-1]/(lb[i-1]-lb[i])
    return None  # survives to grid max

def main():
    df = pd.read_csv(CSV, on_bad_lines="skip")   # CSV may still be appended-to
    if "target" not in df.columns: df["target"]="p1"
    df = df[df["is_original"].astype(str)!="FAILED"].copy()
    for c in ["m","lb","ub","is_original"]: df[c]=pd.to_numeric(df[c],errors="coerce")
    df = df[(df.effect=="spill") & (df.restriction=="rm") & (df.target=="p1")]

    fig, axes = plt.subplots(2, 2, figsize=(9.2, 7.0))
    x_og = -0.085
    for i, (ax, out) in enumerate(zip(axes.flat, ORDER)):
        g = df[df.outcome==out]
        og = g[g.is_original==1]; grid = g[g.is_original==0].sort_values("m")
        if grid.empty:
            ax.text(0.5,0.5,"n/a",ha="center",va="center",transform=ax.transAxes,color="gray")
            ax.set_title(LABEL[out], fontsize=11, fontweight="bold"); continue
        m, lb, ub = grid.m.values, grid.lb.values, grid.ub.values
        cen = 0.5*(lb+ub)
        # original OLS CI as a separate interval on the left
        if not og.empty:
            olb, oub = float(og.lb.iloc[0]), float(og.ub.iloc[0]); oc = 0.5*(olb+oub)
            ax.errorbar([x_og], [oc], yerr=[[oc-olb],[oub-oc]], fmt="none",
                        ecolor=C_ORIG, elinewidth=1.5, capsize=3, capthick=1.3, zorder=3)
            ax.axvline(-0.04, color="gray", lw=0.6, ls=":")
        # discrete robust CI: one interval per Mbar (no center marker)
        ax.errorbar(m, cen, yerr=[cen-lb, ub-cen], fmt="none", ecolor=C_ROBUST,
                    elinewidth=1.1, capsize=2, capthick=0.9, zorder=3)
        ax.axhline(0, color="black", lw=0.9, zorder=2)
        bd = breakdown(m, lb)
        if bd is not None and bd>0:
            ax.axvline(bd, color="black", lw=1.0, ls=":", zorder=4)
            ax.annotate(rf"$\bar M={bd:.2f}$", xy=(bd,0), xytext=(4,6),
                        textcoords="offset points", fontsize=9,
                        bbox=dict(boxstyle="round,pad=0.2", fc="white", ec="0.7", alpha=0.9))
        ax.set_title(LABEL[out], fontsize=11, fontweight="bold")
        ax.set_xlim(-0.13, 1.03)
        ax.set_xticks([x_og] + list(np.arange(0, 1.01, 0.2)))
        ax.set_xticklabels(["Orig."] + [f"{v:g}" for v in np.arange(0,1.01,0.2)])
        ax.tick_params(labelsize=8)
        if i >= 2: ax.set_xlabel(r"$\bar M$", fontsize=11)
        for s in ["top","right"]: ax.spines[s].set_visible(False)

    handles=[Line2D([0],[0],color=C_ROBUST,lw=1.6,label="Robust 95% CI (per $\\bar M$)"),
             Line2D([0],[0],color=C_ORIG,lw=1.6,label="Original OLS CI")]
    fig.legend(handles=handles, loc="lower center", ncol=2, frameon=False, bbox_to_anchor=(0.5,-0.02))
    fig.suptitle(r"Spillover effects: $\Delta^{RM}$ sensitivity to parallel-trends violations "
                 "(first post-period)", fontsize=12, y=1.0)
    fig.tight_layout(rect=[0,0.03,1,0.97])
    out_pdf = GR / "honest_did_rm_spillover_2x2.pdf"
    fig.savefig(out_pdf, bbox_inches="tight"); fig.savefig(out_pdf.with_suffix(".png"), dpi=150, bbox_inches="tight")
    plt.close(fig); print("wrote", out_pdf)

if __name__ == "__main__":
    main()
