"""
Generate publication-quality histograms of TFPE (connectivity) distribution.
Produces two separate PDF files:
  - tfpe_dist_full.pdf: Full analysis sample
  - tfpe_dist_untreated.pdf: Untreated firms only
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import os

# Paths
data_path = os.path.join(os.path.dirname(__file__), "..", "Data",
                         "CBA_rais_firm_level",
                         "lagos_sample_sep24_pct_unionexp_ext_df2.dta")
graphs_path = os.path.join(os.path.dirname(__file__), "..", "Graphs")

# Load and filter
print("Loading data...")
cols = ["year", "lagos_sample_avg", "in_balanced_panel", "totaltreat_pw_n", "treat_ultra"]
df = pd.read_stata(data_path, columns=cols)
sample = df[(df["year"] == 2009) &
            (df["lagos_sample_avg"] == 1) &
            (df["in_balanced_panel"] == 1)].copy()

print(f"Full sample: {len(sample)} firms")
untreated = sample[sample["treat_ultra"] == 0].copy()
print(f"Untreated: {len(untreated)} firms")

tfpe_full = sample["totaltreat_pw_n"].dropna()
tfpe_untr = untreated["totaltreat_pw_n"].dropna()

# Summary stats
for label, s in [("Full sample", tfpe_full), ("Untreated", tfpe_untr)]:
    print(f"\n--- {label} ---")
    print(f"  N={len(s)}, Mean={s.mean():.4f}, Median={s.median():.4f}")
    print(f"  Zero: {(s == 0).sum()} ({(s == 0).mean()*100:.1f}%)")
    print(f"  P25={s.quantile(.25):.4f}, P75={s.quantile(.75):.4f}, P99={s.quantile(.99):.4f}")

# ── Plot settings ──
plt.rcParams.update({
    "font.family": "serif",
    "font.size": 11,
    "axes.linewidth": 0.8,
    "xtick.major.width": 0.6,
    "ytick.major.width": 0.6,
})

datasets = [
    (tfpe_full, "tfpe_dist_full", "steelblue"),
    (tfpe_untr, "tfpe_dist_untreated", "indianred"),
]

for data, filename, color in datasets:
    fig, ax = plt.subplots(figsize=(5.5, 4))

    mean_val = data.mean()
    total = len(data)

    # Separate zero and positive mass
    n_zero = (data == 0).sum()
    positive = data[data > 0]

    # Bin edges for positive values: 0.005-width bins up to P99, then one overflow
    p99 = data.quantile(0.99)
    bin_width = 0.005
    pos_edges = np.arange(0, p99 + bin_width, bin_width)
    pos_edges = np.append(pos_edges, data.max() + bin_width)

    # Count positive values in bins
    pos_counts, _ = np.histogram(positive, bins=pos_edges)

    # Build bar chart: zero bar + positive bars
    bar_centers = [0]
    bar_heights = [n_zero]
    bar_widths = [bin_width]

    for i in range(len(pos_counts)):
        bar_centers.append((pos_edges[i] + pos_edges[i + 1]) / 2)
        bar_heights.append(pos_counts[i])
        bar_widths.append(pos_edges[i + 1] - pos_edges[i])

    # Convert to fractions
    bar_fracs = [h / total for h in bar_heights]

    ax.bar(bar_centers, bar_fracs, width=bar_widths, color=color,
           edgecolor="white", linewidth=0.3, alpha=0.85, align="center")

    # Mean line
    ax.axvline(mean_val, color="black", linestyle="--", linewidth=1.0)

    # Formatting
    ax.set_xlabel("Connectivity", fontsize=11)
    ax.set_ylabel("Fraction of Firms", fontsize=11)
    ax.set_xlim(-0.005, min(p99 * 1.3, 0.15))
    ax.yaxis.set_major_formatter(mticker.PercentFormatter(xmax=1, decimals=0))
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)

    # Force draw to get correct ylim
    fig.canvas.draw()
    ymax = ax.get_ylim()[1]

    # Zero mass label directly above the zero bar
    zero_frac = n_zero / total
    ax.text(0, zero_frac + ymax * 0.02, f"{zero_frac*100:.0f}%",
            fontsize=10, ha="center", va="bottom")

    # Mean label
    xoff = 0.008 if mean_val < 0.03 else 0.005
    ax.text(mean_val + xoff, ymax * 0.92, f"Mean = {mean_val:.3f}",
            fontsize=10, va="top")

    # Add a bit of headroom for the zero-bar label
    ax.set_ylim(0, ymax * 1.08)

    fig.tight_layout()

    out_pdf = os.path.join(graphs_path, f"{filename}.pdf")
    fig.savefig(out_pdf, bbox_inches="tight")
    print(f"Saved: {out_pdf}")

    out_png = os.path.join(graphs_path, f"{filename}.png")
    fig.savefig(out_png, bbox_inches="tight", dpi=200)
    print(f"Saved: {out_png}")

    plt.close()
