#!/usr/bin/env python3
"""
Binned scatter: raw log wages vs. normalized connectivity.
Two panels: pre-treatment (2009-2011) and post-treatment (2012-2016).
200 equal-frequency bins; fitted OLS line.
"""

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from pathlib import Path

script_dir = Path(__file__).resolve().parent
tables_dir = script_dir.parent.parent / "Tables" / "conn_margins"
graphs_dir = script_dir.parent.parent / "Graphs" / "conn_margins"
graphs_dir.mkdir(parents=True, exist_ok=True)

# ── Load firm-level data ───────────────────────────────────────────────────────

df = pd.read_csv(tables_dir / "scatter_resid_wages.csv")
df = df.dropna(subset=["conn_firm", "raw_pre", "raw_post"])
print(f"Firms loaded: {len(df):,}")

N_BINS = 200


# ── Helpers ───────────────────────────────────────────────────────────────────

def make_bins(x, y, n_bins):
    """Equal-frequency binning. Returns (bin_x_mean, bin_y_mean)."""
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

fig, axes = plt.subplots(1, 2, figsize=(10, 4.2))

panels = [
    ("raw_pre",  "Pre-treatment (2009\u20132011)", axes[0]),
    ("raw_post", "Post-treatment (2012\u20132016)", axes[1]),
]

BLUE = "#2166AC"
RED  = "#B2182B"

for y_col, title, ax in panels:
    bx, by = make_bins(df["conn_firm"].values, df[y_col].values, N_BINS)

    # Scatter
    ax.scatter(bx, by, s=18, color=BLUE, alpha=0.75, zorder=3, linewidths=0)

    # OLS line
    x_fit, y_fit, coef = ols_line(bx, by)
    ax.plot(x_fit, y_fit, color=RED, linewidth=1.8, zorder=4,
            label=f"Slope: {coef[0]:.4f}")

    ax.set_title(title, fontsize=11, pad=6)
    ax.set_xlabel("Normalized connectivity", fontsize=10)
    ax.set_ylabel("Log wages (raw)", fontsize=10)
    ax.legend(frameon=False, fontsize=9, loc="upper left")
    ax.tick_params(labelsize=9)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)

fig.tight_layout(pad=1.5)

out = graphs_dir / "scatter_raw_wages_vs_conn.pdf"
fig.savefig(out, bbox_inches="tight")
print(f"Saved: {out}")

out_png = graphs_dir / "scatter_raw_wages_vs_conn.png"
fig.savefig(out_png, dpi=160, bbox_inches="tight")
print(f"Saved: {out_png}")
