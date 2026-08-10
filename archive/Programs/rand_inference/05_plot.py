#!/usr/bin/env python
"""Randomization inference — histograms of the placebo spillover distribution.
Primary = common-scale (fixed p90) normalization, medium CEM matching.
Writes titleless per-outcome PDFs (LaTeX composes captions) to Graphs/ and the paper."""
import numpy as np, json, shutil
from pathlib import Path
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.font_manager as fm

ROOT  = Path("/gpfs/kellogg/proj/lgg3230/UnionSpill")
OUT   = ROOT / "Data/rand_inference"
GR    = ROOT / "Graphs/rand_inference"; GR.mkdir(exist_ok=True)
TAB   = ROOT / "Tables/rand_inference"
PAPER = ROOT / "UnionSpill-paper/Figures/Main"

for p in ["/kellogg/proj/lgg3230/UnionSpill/Programs/fonts/LibertinusSerif-Regular.otf",
          "/usr/share/fonts/opentype/libertinus/LibertinusSerif-Regular.otf"]:
    if Path(p).exists():
        fm.fontManager.addfont(p); plt.rcParams["font.family"] = "Libertinus Serif"; break
plt.rcParams.update({"font.size": 11})

LAB  = {"lr_remdezr_w": "Log wages", "lr_remdezr_h_w": "Log hourly wages"}
BLUE, RED = "#2166AC", "#B2182B"

res = json.load(open(TAB / "perm_spillover_medium.json"))
for outcome in ["lr_remdezr_w", "lr_remdezr_h_w"]:
    dr = np.load(OUT / f"placebo_spillover_{outcome}_medium.npy")
    r  = res[outcome]
    d0, p, R = r["delta_obs"], r["p_two_sided"], r["R"]
    fig, ax = plt.subplots(figsize=(5.2, 3.6))
    ax.hist(dr, bins=45, color=BLUE, alpha=0.55, edgecolor="white", linewidth=0.4)
    ax.axvline(0,  color="gray", lw=0.8, ls=":")
    ax.axvline(d0, color=RED, lw=2)
    ymax = ax.get_ylim()[1]
    ax.text(d0, ymax*0.97, f"  observed $\\hat\\beta={d0:.4f}$",
            color=RED, fontsize=9, ha="left", va="top")
    ax.text(0.03, 0.97,
            f"$p={p:.3f}$ (two-sided)\n{R:,} placebo draws",
            transform=ax.transAxes, va="top", ha="left", fontsize=9)
    ax.set_xlabel("Placebo spillover coefficient $\\hat\\beta^{(r)}$")
    ax.set_ylabel("Frequency")
    for s in ["top", "right"]:
        ax.spines[s].set_visible(False)
    fig.tight_layout()
    f = GR / f"perm_hist_{outcome}.pdf"
    fig.savefig(f); plt.close(fig)
    if PAPER.exists():
        shutil.copy(f, PAPER / f"perm_hist_{outcome}.pdf")
    print("wrote", f)
