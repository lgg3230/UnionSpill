#!/usr/bin/env python3
"""
Binned scatter: residualized log wages vs. residualized connectivity.
Both variables are FWL-residualized on the same controls (wages also on firm FE;
connectivity on everything except firm FE since it is time-invariant).
Firm-level averages are used; pre/post clouds overlaid.
The slope difference should closely approximate the DiD coefficient.

Input:  Tables/conn_margins/scatter_resid_wages_panel.csv
Output: Graphs/conn_margins/scatter_resid_wages_did.{pdf,png}
"""

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.font_manager as fm
from pathlib import Path

FONT_PATH = "/kellogg/proj/lgg3230/fonts/LibertinusSerif-Regular.otf"

script_dir = Path(__file__).resolve().parent
tables_dir = script_dir.parent.parent / "Tables" / "conn_margins"
graphs_dir = script_dir.parent.parent / "Graphs" / "conn_margins"
graphs_dir.mkdir(parents=True, exist_ok=True)

# ── Font ──────────────────────────────────────────────────────────────────────

if Path(FONT_PATH).exists():
    fm.fontManager.addfont(FONT_PATH)
    plt.rcParams["font.family"] = "Libertinus Serif"

# ── Load panel, collapse to firm-level averages ───────────────────────────────

df = pd.read_csv(tables_dir / "scatter_resid_wages_panel.csv")
df = df.dropna(subset=["e_conn", "e_lr_remdezr_w"])

pre  = df[df["year"] < 2012].groupby("identificad")[["e_conn", "e_lr_remdezr_w"]].mean().reset_index()
post = df[df["year"] >= 2012].groupby("identificad")[["e_conn", "e_lr_remdezr_w"]].mean().reset_index()

# Trim x-axis at p99 of residualized connectivity (pooled)
p99 = df["e_conn"].quantile(0.99)
pre  = pre[pre["e_conn"]  <= p99]
post = post[post["e_conn"] <= p99]

print(f"Pre firms:  {len(pre):,}  |  Post firms: {len(post):,}")
print(f"e_conn p99 (trim): {p99:.4f}")

N_BINS = 200

ORANGE = "#E69F00"
BLUE   = "#0072B2"


# ── Helpers ───────────────────────────────────────────────────────────────────

def make_bins(x, y, n_bins):
    df_tmp = pd.DataFrame({"x": x, "y": y}).dropna()
    df_tmp["bin"] = pd.qcut(df_tmp["x"], q=n_bins, labels=False, duplicates="drop")
    agg = df_tmp.groupby("bin")[["x", "y"]].mean().reset_index()
    return agg["x"].values, agg["y"].values


def ols_line(x, y):
    coef = np.polyfit(x, y, 1)
    x_fit = np.linspace(x.min(), x.max(), 300)
    y_fit = np.polyval(coef, x_fit)
    return x_fit, y_fit, coef


# ── Plot ───────────────────────────────────────────────────────────────────────

fig, ax = plt.subplots(figsize=(7, 4.5))

periods = [
    (pre,  "Pre-treatment (2009\u20132011)", ORANGE, "o"),
    (post, "Post-treatment (2012\u20132016)", BLUE,   "^"),
]

slopes = {}
for subset, label, color, marker in periods:
    bx, by = make_bins(subset["e_conn"].values, subset["e_lr_remdezr_w"].values, N_BINS)

    ax.scatter(bx, by, s=16, color=color, alpha=1.0, zorder=3,
               linewidths=0, marker=marker)

    x_fit, y_fit, coef = ols_line(bx, by)
    ax.plot(x_fit, y_fit, color=color, linewidth=2.0, zorder=4,
            label=f"{label}  (slope: {coef[0]:.4f})")
    slopes[label] = coef[0]

diff = list(slopes.values())[1] - list(slopes.values())[0]
print(f"Slope pre:  {list(slopes.values())[0]:.4f}")
print(f"Slope post: {list(slopes.values())[1]:.4f}")
print(f"Difference: {diff:.4f}  (should ≈ DiD coefficient)")

ax.axhline(0, color="gray", linewidth=0.6, linestyle="--", alpha=0.4, zorder=2)
ax.axvline(0, color="gray", linewidth=0.6, linestyle="--", alpha=0.4, zorder=2)

ax.set_xlabel("Residualized connectivity to treated firms", fontsize=10)
ax.set_ylabel("Residualized log wages (firm avg)", fontsize=10)
ax.tick_params(labelsize=9)
ax.spines["top"].set_visible(False)
ax.spines["right"].set_visible(False)

ax.legend(
    frameon=False,
    fontsize=9,
    loc="upper center",
    bbox_to_anchor=(0.5, -0.18),
    ncol=1,
)

fig.tight_layout(rect=[0, 0.08, 1, 1])

out_pdf = graphs_dir / "scatter_resid_wages_did.pdf"
fig.savefig(out_pdf, bbox_inches="tight")
print(f"Saved: {out_pdf}")

out_png = graphs_dir / "scatter_resid_wages_did.png"
fig.savefig(out_png, dpi=160, bbox_inches="tight")
print(f"Saved: {out_png}")
