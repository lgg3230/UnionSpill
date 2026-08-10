#!/usr/bin/env python
"""
Binscatters of the balance regressions: each 2011 characteristic on connectivity,
across untreated (spillover) firms, in a raw (univariate) and a residualized
version. Residualized = both variables partialled out on industry, negotiation
month, and microregion fixed effects. Both axes standardized so the two panels
are directly comparable; dots are 20 equal-width bins with area proportional to
the number of firms in the bin; the OLS slope and its robust SE are annotated.

Outputs 8 PDFs (4 outcomes x {raw, resid}) to Graphs/rand_inference/ and copies
to the paper Figures/Main.
"""
import numpy as np, pandas as pd, shutil
from pathlib import Path
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.font_manager as fm
from pyfixest.estimation.demean_ import demean

ROOT = Path("/gpfs/kellogg/proj/lgg3230/UnionSpill")
OUT  = ROOT / "Data/rand_inference"
GR   = ROOT / "Graphs/rand_inference"; GR.mkdir(exist_ok=True)
PAPER = ROOT / "UnionSpill-paper/Figures/Main"
for p in ["/kellogg/proj/lgg3230/UnionSpill/Programs/fonts/LibertinusSerif-Regular.otf",
          "/kellogg/proj/lgg3230/UnionSpill/fonts/LibertinusSerif-Regular.otf"]:
    if Path(p).exists():
        fm.fontManager.addfont(p); plt.rcParams["font.family"] = "Libertinus Serif"; break
plt.rcParams.update({"font.size": 12})
BLUE, RED = "#2166AC", "#B2182B"

OUTC = {"lr_remdezr_w": "Log wages", "lr_remdezr_h_w": "Log hourly wages",
        "l_firm_emp": "Log employment", "numb_clauses": "CBA clauses"}
FE = ["industry1", "microregion", "mode_base_month"]

frame = pd.read_stata(OUT / "spill_frame.dta")
o11 = frame[frame.year == 2011].set_index("identificad")
inv = frame.groupby("identificad").agg(
    treat_ultra=("treat_ultra", "first"), totaltreat_pw_norm=("totaltreat_pw_norm", "first"),
    industry1=("industry1", "first"), microregion=("microregion", "first"),
    mode_base_month=("mode_base_month", "first"))
df = inv.join(o11[list(OUTC)]).reset_index()
df = df[df.treat_ultra == 0].dropna(subset=FE)

def demean_on(v, codes):
    res, ok = demean(np.ascontiguousarray(v[:, None], np.float64),
                     np.ascontiguousarray(codes, np.int64), np.ones(len(v))); assert ok
    return res[:, 0]

def z(v): s = v.std(); return (v - v.mean()) / (s if s else 1)

def slope_se(yz, xz):
    b = (xz @ yz) / (xz @ xz)
    e = yz - b * xz
    se = np.sqrt(np.sum(xz ** 2 * e ** 2)) / (xz @ xz)   # HC0
    return b, se

def binscatter(ax, xz, yz, color, b, se):
    lo, hi = np.percentile(xz, [1, 99])                  # trim sparse extremes for display
    edges = np.linspace(lo, hi, 21); mids = 0.5 * (edges[:-1] + edges[1:])
    idx = np.clip(np.digitize(xz, edges) - 1, 0, 19)
    mx, my, cnt = [], [], []
    for k in range(20):
        m = idx == k
        if m.sum() == 0: continue
        mx.append(xz[m].mean()); my.append(yz[m].mean()); cnt.append(m.sum())
    cnt = np.array(cnt, float)
    ax.scatter(mx, my, s=25 + 400 * cnt / cnt.max(), color=color, alpha=0.55, edgecolor="white", linewidth=0.5, zorder=3)
    xx = np.array([lo, hi]); ax.plot(xx, b * xx, color=color, lw=2, zorder=2)
    ax.axhline(0, color="gray", lw=0.5, ls=":"); ax.axvline(0, color="gray", lw=0.5, ls=":")
    ax.text(0.04, 0.96, f"slope $={b:.3f}$\n(se ${se:.3f}$)", transform=ax.transAxes,
            va="top", ha="left", fontsize=10, color=color)
    ax.set_xlim(lo, hi)
    for s in ["top", "right"]: ax.spines[s].set_visible(False)

made = []
for oc, lab in OUTC.items():
    d = df[df[oc].notna() & df.totaltreat_pw_norm.notna()].copy()
    codes = np.column_stack([d[c].astype("category").cat.codes.values.astype(np.int64) for c in FE])
    conn = d.totaltreat_pw_norm.values.astype(float); y = d[oc].values.astype(float)
    # raw (univariate) and residualized
    versions = {"raw": (z(conn), z(y), BLUE, "Connectivity (standardized)", f"{lab} (standardized)"),
                "resid": (z(demean_on(conn, codes)), z(demean_on(y, codes)), RED,
                          "Connectivity, residualized (std.)", f"{lab}, residualized (std.)")}
    for ver, (xz, yz, col, xlab, ylab) in versions.items():
        b, se = slope_se(yz, xz)
        fig, ax = plt.subplots(figsize=(5.2, 3.5))
        binscatter(ax, xz, yz, col, b, se)
        ax.set_xlabel(xlab); ax.set_ylabel(ylab)
        fig.tight_layout()
        f = GR / f"binscatter_{oc}_{ver}.pdf"
        fig.savefig(f); plt.close(fig)
        if PAPER.exists(): shutil.copy(f, PAPER / f.name)
        made.append(f.name)
print("wrote:", ", ".join(made))
