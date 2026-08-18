#!/usr/bin/env python3
"""
Histogram of raw connectivity-to-treated (totaltreat_pw_n) over the FULL
spillover sample, with normalized (relative-frequency) bars plus median & mean
lines.

Sample (full spillover, built directly from the firm-level .dta):
    year == 2011 & treat_ultra == 0 & in_balanced_panel == 1
    & lagos_sample_avg == 1, with non-missing totaltreat_pw_n.
This is the set of untreated balanced-panel Lagos establishments for which
connectivity to treated firms is defined (the headline spillover e(sample)),
NOT the listwise-complete scatter subset used by the binscatters.

Bars show the share of establishments per bin (heights sum to 1). Display is
trimmed to [0, p99] of totaltreat_pw_n; the stats box reports mean, median, p90.

Output: Graphs/conn_descriptives/hist_connectivity.pdf
Run with ~/.conda/envs/venv_python312/bin/python.
"""
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.font_manager as fm
from pathlib import Path

# -- Paths ---------------------------------------------------------------------

ROOT      = Path(__file__).resolve().parent.parent.parent.parent
DATA_DIR  = ROOT / "Data" / "CBA_RAIS_firm_level"
FONTS_DIR = ROOT / "Programs" / "fonts"
GR        = ROOT / "Graphs" / "conn_descriptives"
GR.mkdir(parents=True, exist_ok=True)

# -- Font (Libertinus Serif) ---------------------------------------------------

for ttf in FONTS_DIR.glob("LibertinusSerif-*.ttf"):
    fm.fontManager.addfont(str(ttf))
_prop = fm.FontProperties(fname=str(FONTS_DIR / "LibertinusSerif-Regular.ttf"))
plt.rcParams["font.family"] = _prop.get_name()

XVAR = "totaltreat_pw_n"
MED_C, MEAN_C = "black", "#B2182B"

# -- Load full spillover sample ------------------------------------------------

COLS = ["year", "treat_ultra", "in_balanced_panel", "lagos_sample_avg", XVAR]
df = pd.read_stata(DATA_DIR / "lagos_sample_sep24_pct_unionexp_ext_df2.dta",
                   columns=COLS)

mask = (df["year"] == 2011) & (df["treat_ultra"] == 0) & \
       (df["in_balanced_panel"] == 1) & (df["lagos_sample_avg"] == 1)
x = df.loc[mask, XVAR].dropna()

n    = len(x)
zero = (x == 0).mean()
med, mean = x.median(), x.mean()
p90, p99  = x.quantile(.90), x.quantile(.99)
print(f"Full spillover sample: N={n:,}  %zero={zero*100:.1f}  "
      f"median={med:.5f}  mean={mean:.5f}  p90={p90:.5f}  p99={p99:.5f}")

# -- Histogram (normalized bars, p99-trimmed display) --------------------------

body = x[(x > 0) & (x <= p99)]
# Weights so bar heights are the share of ALL sample establishments per bin.
weights = np.full(len(body), 1.0 / n)

fig, ax = plt.subplots(figsize=(6.6, 4.3))

# Positive part: share of the FULL sample per bin.
heights, _, _ = ax.hist(body, bins=50, weights=weights, color="#2166AC",
                        alpha=0.85, edgecolor="white", linewidth=0.3, zorder=2)
ymax_pos = float(heights.max())

# Zero mass point: leftmost bar, same colour/scheme as the rest. Its true share
# (`zero`) far exceeds the positive bars, so the y-axis is truncated just above
# the positive part and the bar is labelled with its share.
binw = p99 / 50.0
ax.bar(-binw / 2.0, zero, width=binw, color="#2166AC", alpha=0.85,
       edgecolor="white", linewidth=0.3, zorder=2)

top = ymax_pos * 1.15
ax.set_ylim(0, top)
ax.set_xlim(-binw * 1.05, p99)

# Report the zero share on top of the (truncated) bar.
ax.text(-binw / 2.0, top * 0.55, f"{zero*100:.0f}%", ha="center", va="center",
        rotation=90, fontsize=8, fontweight="bold", color="white", zorder=5)

# Broken y-axis marks (signal the truncation).
d, yb = 0.012, 0.93
brk = dict(transform=ax.transAxes, color="k", clip_on=False, lw=1.0)
ax.plot((-d, d), (yb - d, yb + d), **brk)
ax.plot((-d, d), (yb - d + 0.03, yb + d + 0.03), **brk)

lmed  = ax.axvline(med,  color=MED_C,  ls="--", lw=1.6, zorder=3)
lmean = ax.axvline(mean, color=MEAN_C, ls="-.", lw=1.6, zorder=3)

ax.set_xlabel("Connectivity to treated, raw (per-worker flows), totaltreat_pw_n",
              fontsize=9)
ax.set_ylabel("Share of establishments", fontsize=9)
ax.tick_params(labelsize=8)

ax.legend([lmed, lmean], [f"Median = {med:.4f}", f"Mean = {mean:.4f}"],
          loc="upper right", frameon=True, fontsize=9, framealpha=0.95,
          title="Full spillover sample")
ax.text(0.97, 0.66,
        f"N = {n:,}\nAt exactly 0: {zero*100:.1f}%\np90: {p90:.4f}\n"
        f"(positive values ≤ p99 shown)",
        transform=ax.transAxes, ha="right", va="top", fontsize=8,
        bbox=dict(boxstyle="round,pad=0.4", fc="white", ec="0.7"))

fig.tight_layout()
out = GR / "hist_connectivity.pdf"
fig.savefig(out, bbox_inches="tight", dpi=150)
plt.close(fig)
print(f"Saved: {out}")
print("=== 4140_figure_conn_hist.py done ===")
