#!/usr/bin/env python
"""
honest_did_rm_2x2.py
Delta^RM (relative-magnitudes) sensitivity figures for the SPILLOVER and DIRECT
effects, first post-period target. For each effect this writes BOTH:
  - the combined 2x2 exhibit  (honest_did_rm_<effect>_2x2.pdf), and
  - one standalone PDF per outcome (honest_did_rm_<effect>_<outcome>.pdf),
    so the paper can compose the exhibit in LaTeX with four \\includegraphics
    (one per outcome) and keep/drop/reorder outcomes.

Robust CIs are the dense fine grid (honest_did_results_fine.csv, step 0.05 thinned
to 0.1) over Mbar in [0,1]; for the DIRECT effect the x-axis is extended to Mbar=2
by splicing in the coarser canonical grid (honest_did_results.csv, to Mbar=2) so the
direct breakdown values (which exceed 1, e.g. ~1.78) are visible as vertical lines.
Run: /opt/homebrew/bin/python3 Programs/honest_did/honest_did_rm_2x2.py
"""
from pathlib import Path
import numpy as np, pandas as pd
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
TBL  = ROOT / "Tables" / "honest_did"
GR   = ROOT / "Graphs" / "honest_did"; GR.mkdir(parents=True, exist_ok=True)
FINE = TBL / "honest_did_results_fine.csv"
CANON = TBL / "honest_did_results.csv"

try:
    import matplotlib.font_manager as fm
    fdir = HERE.parent / "fonts"
    if fdir.exists():
        for v in ["LibertinusSerif-Regular.otf","LibertinusSerif-Italic.otf","LibertinusSerif-Bold.otf"]:
            if (fdir/v).exists(): fm.fontManager.addfont(str(fdir/v))
        plt.rcParams["font.family"]="Libertinus Serif"
        plt.rcParams["mathtext.fontset"]="custom"
        plt.rcParams["mathtext.rm"]="Libertinus Serif"
        plt.rcParams["mathtext.it"]="Libertinus Serif:italic"
except Exception: pass

S = 1.45   # font scale
C_ORIG, C_ROBUST = "#2166AC", "#B2182B"
ORDER = ["lr_remdezr_w","lr_remdezr_h_w","l_firm_emp","numb_clauses"]
LABEL = {"lr_remdezr_w":"Log wages","lr_remdezr_h_w":"Log hourly wages",
         "l_firm_emp":"Log employment","numb_clauses":"# CBA clauses"}
XMAX = {"spill": 1.0, "direct": 2.0}   # per-effect x-axis cap

def load(path):
    d = pd.read_csv(path, on_bad_lines="skip")
    if "target" not in d.columns: d["target"]="p1"
    d = d[d["is_original"].astype(str)!="FAILED"].copy()
    for c in ["m","lb","ub","is_original"]: d[c]=pd.to_numeric(d[c],errors="coerce")
    return d

def breakdown(m, lb):
    o=np.argsort(m); m,lb=m[o],lb[o]
    if lb[0]<=0: return 0.0
    for i in range(1,len(m)):
        if lb[i]<=0: return m[i-1]+(m[i]-m[i-1])*lb[i-1]/(lb[i-1]-lb[i])
    return None  # survives whole grid

fine  = load(FINE)
canon = load(CANON)

def panel_series(effect, out, xmax):
    """(olb, oub, m, lb, ub): original OLS CI + robust display grid over [0, xmax].
    Dense fine grid (thinned to 0.1) for m<=1; canonical grid spliced in for 1<m<=xmax."""
    ff = fine[(fine.effect==effect)&(fine.restriction=="rm")&(fine.target=="p1")&(fine.outcome==out)]
    og = ff[ff.is_original==1]
    olb = float(og.lb.iloc[0]) if not og.empty else None
    oub = float(og.ub.iloc[0]) if not og.empty else None
    grid = ff[ff.is_original==0].sort_values("m")
    mf,lbf,ubf = grid.m.values, grid.lb.values, grid.ub.values
    keep = np.isclose((mf/0.1), np.round(mf/0.1), atol=1e-6) & (mf <= 1.0+1e-9)
    m,lb,ub = list(mf[keep]), list(lbf[keep]), list(ubf[keep])
    if xmax > 1.0+1e-9:
        cc = canon[(canon.effect==effect)&(canon.restriction=="rm")&(canon.target=="p1")
                   &(canon.outcome==out)&(canon.is_original==0)].sort_values("m")
        for _,r in cc.iterrows():
            if 1.0+1e-9 < r.m <= xmax+1e-9:
                m.append(r.m); lb.append(r.lb); ub.append(r.ub)
    return olb, oub, np.array(m), np.array(lb), np.array(ub)

def draw_panel(ax, effect, out, xmax, show_xlabel):
    x_og = -0.09
    olb, oub, m, lb, ub = panel_series(effect, out, xmax)
    if len(m)==0:
        ax.text(0.5,0.5,"n/a",ha="center",va="center",transform=ax.transAxes,color="gray")
        ax.set_title(LABEL[out], fontsize=11*S, fontweight="bold"); return
    cen = 0.5*(lb+ub)
    if olb is not None:
        oc = 0.5*(olb+oub)
        ax.errorbar([x_og],[oc],yerr=[[oc-olb],[oub-oc]],fmt="none",ecolor=C_ORIG,
                    elinewidth=1.6,capsize=4,capthick=1.4,zorder=3)
        ax.axvline(-0.045,color="gray",lw=0.7,ls=":")
    ax.errorbar(m,cen,yerr=[cen-lb,ub-cen],fmt="none",ecolor=C_ROBUST,
                elinewidth=1.5,capsize=3,capthick=1.1,zorder=3)
    ax.axhline(0,color="black",lw=1.0,zorder=2)
    bd = breakdown(m, lb)
    if bd is not None and 0 < bd <= xmax+1e-9:
        ax.axvline(bd,color="black",lw=1.1,ls=":",zorder=4)
        ax.annotate(rf"$\bar M={bd:.2f}$",xy=(bd,0),xytext=(4,7),textcoords="offset points",
                    fontsize=9.5*S,bbox=dict(boxstyle="round,pad=0.2",fc="white",ec="0.7",alpha=0.9))
    ax.set_title(LABEL[out], fontsize=11*S, fontweight="bold")
    ax.set_xlim(-0.14, xmax+0.04)
    step = 0.5 if xmax > 1.0+1e-9 else 0.2
    ticks = np.round(np.arange(0, xmax+1e-9, step), 2)
    ax.set_xticks([x_og]+list(ticks))
    ax.set_xticklabels(["Orig."]+[f"{v:g}" for v in ticks])
    ax.tick_params(labelsize=8*S)
    if show_xlabel: ax.set_xlabel(r"$\bar M$", fontsize=11*S)
    for s in ["top","right"]: ax.spines[s].set_visible(False)

def make_2x2(effect, title, fname):
    xmax = XMAX[effect]
    fig, axes = plt.subplots(2, 2, figsize=(9.2, 7.0))
    for i,(ax,out) in enumerate(zip(axes.flat, ORDER)):
        draw_panel(ax, effect, out, xmax, show_xlabel=(i>=2))
    handles=[Line2D([0],[0],color=C_ROBUST,lw=1.8,label="Robust 95% CI (per $\\bar M$)"),
             Line2D([0],[0],color=C_ORIG,lw=1.8,label="Original OLS CI")]
    fig.legend(handles=handles,loc="lower center",ncol=2,frameon=False,
               bbox_to_anchor=(0.5,-0.02),fontsize=10*S)
    fig.suptitle(title, fontsize=12*S, y=1.0)
    fig.tight_layout(rect=[0,0.03,1,0.97])
    out=GR/fname; fig.savefig(out,bbox_inches="tight"); fig.savefig(out.with_suffix(".png"),dpi=150,bbox_inches="tight")
    plt.close(fig); print("wrote",out)

def make_panel(effect, out, fname):
    """One standalone per-outcome PDF (for LaTeX minipage composition)."""
    fig, ax = plt.subplots(figsize=(4.7, 3.7))
    draw_panel(ax, effect, out, XMAX[effect], show_xlabel=True)
    fig.tight_layout()
    o=GR/fname; fig.savefig(o,bbox_inches="tight"); fig.savefig(o.with_suffix(".png"),dpi=200,bbox_inches="tight")
    plt.close(fig); print("wrote",o)

# combined 2x2 (kept for back-compat / quick view)
make_2x2("spill","Spillover effects: $\\Delta^{RM}$ sensitivity to parallel-trends violations (first post-period)",
         "honest_did_rm_spillover_2x2.pdf")
make_2x2("direct","Direct effects: $\\Delta^{RM}$ sensitivity to parallel-trends violations (first post-period)",
         "honest_did_rm_direct_2x2.pdf")

# per-outcome standalone panels (for the minipage recomposition in Main_Results.tex)
for out in ORDER:
    make_panel("spill",  out, f"honest_did_rm_spillover_{out}.pdf")
    make_panel("direct", out, f"honest_did_rm_direct_{out}.pdf")
