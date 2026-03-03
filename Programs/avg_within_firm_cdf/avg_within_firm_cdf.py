"""
avg_within_firm_cdf.py
======================
Plots the average within-firm empirical CDF of log wages for treated vs.
control firms in the Lagos balanced-panel sample.

Approach
--------
For each firm i in group g:
    F_i(w) = fraction of workers in firm i with log-wage <= w
Average across firms:
    F̄_g(w) = (1/N_g) * sum_i F_i(w)

This is the within-firm analog of the distributional comparison: each
firm gets equal weight, and the between-firm variation does not inflate
the within-firm spread.

Outputs
-------
- Graphs/avg_within_firm_cdf/avg_within_firm_cdf_<date>.pdf   (pre vs. post, 2 panels)
"""

import os
import duckdb
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
from matplotlib import font_manager
from datetime import date

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
PROJECT    = "/kellogg/proj/lgg3230/UnionSpill"
PANEL_FILE = os.path.join(PROJECT, "Data/CBA_RAIS_firm_level/worker_panel_lagos.parquet")
FIRM_FILE  = os.path.join(PROJECT, "Data/CBA_RAIS_firm_level/cba_rais_firm_2009_2016_flows_1.dta")
GRAPH_DIR  = os.path.join(PROJECT, "Graphs/avg_within_firm_cdf")

TODAY = date.today().strftime("%-d_%b_%Y")
OUT   = os.path.join(GRAPH_DIR, f"avg_within_firm_cdf_{TODAY}.pdf")

# ---------------------------------------------------------------------------
# 1. Load treatment status from firm-level panel
# ---------------------------------------------------------------------------
print("Loading treatment status...")
firm_df = pd.read_stata(
    FIRM_FILE,
    columns=["identificad", "year", "treat_ultra", "lagos_sample_avg", "in_balanced_panel"],
    convert_categoricals=False,
)
firm_df = firm_df.dropna(subset=["year"])
firm_df["year"] = firm_df["year"].astype(int)
firm_df = firm_df.query("lagos_sample_avg == 1 & in_balanced_panel == 1").copy()
firm_df["identificad"] = firm_df["identificad"].astype(str).str.zfill(14)

# One row per firm (treatment status is time-invariant)
treat_status = (
    firm_df.groupby("identificad")["treat_ultra"]
    .max()
    .reset_index()
)
n_treat   = (treat_status["treat_ultra"] == 1).sum()
n_control = (treat_status["treat_ultra"] == 0).sum()
print(f"  Treated firms: {n_treat:,}  |  Control firms: {n_control:,}")

# ---------------------------------------------------------------------------
# 2. Load worker wages (log real December earnings)
# ---------------------------------------------------------------------------
print("Loading worker panel (parquet)...")
con = duckdb.connect()
con.execute("PRAGMA threads=8")
con.execute("PRAGMA memory_limit='24GB'")

workers = con.execute(f"""
    SELECT identificad, year, lr_remdezr
    FROM read_parquet('{PANEL_FILE}')
    WHERE lr_remdezr IS NOT NULL
""").fetch_arrow_table().to_pandas()

workers["identificad"] = workers["identificad"].astype(str).str.zfill(14)
workers["year"]        = workers["year"].astype(int)
print(f"  Worker-spells loaded: {len(workers):,}")

# ---------------------------------------------------------------------------
# 3. Merge treatment status
# ---------------------------------------------------------------------------
workers = workers.merge(treat_status, on="identificad", how="inner")
print(f"  After merge: {len(workers):,} rows")
print(f"  Years: {sorted(workers['year'].unique())}")

# ---------------------------------------------------------------------------
# 4. Compute average within-firm CDF
# ---------------------------------------------------------------------------
# Wage range: cover the 0.5th–99.5th percentile of the pooled distribution
w_lo, w_hi = workers["lr_remdezr"].quantile([0.005, 0.995])

periods = {
    "Pre-treatment (2009–2011)": (2009, 2011),
}

NBINS = 20

def avg_within_firm_hist(df, bins):
    """
    For a DataFrame with columns [identificad, lr_remdezr],
    return the average within-firm histogram (density) evaluated over bins.
    Each firm contributes equally (unweighted).
    Returns (bin_centers, avg_density) where density sums to 1 across bins.
    """
    firms = df["identificad"].unique()
    hist_matrix = np.zeros((len(firms), len(bins) - 1), dtype=np.float32)
    wages_by_firm = df.groupby("identificad")["lr_remdezr"].apply(np.array)

    for k, fid in enumerate(firms):
        w = wages_by_firm[fid]
        counts, _ = np.histogram(w, bins=bins)
        total = counts.sum()
        hist_matrix[k, :] = counts / total if total > 0 else 0.0

    centers = 0.5 * (bins[:-1] + bins[1:])
    return centers, hist_matrix.mean(axis=0)


# ---------------------------------------------------------------------------
# 5. Plot
# ---------------------------------------------------------------------------

# Register Libertinus Serif from project fonts/ directory
_font_dir = os.path.join(PROJECT, "fonts")
for _f in os.listdir(_font_dir):
    if _f.endswith(".ttf"):
        font_manager.fontManager.addfont(os.path.join(_font_dir, _f))
plt.rcParams["font.family"] = "Libertinus Serif"
plt.rcParams["font.weight"] = "bold"
plt.rcParams["font.size"] = 12
plt.rcParams["axes.labelweight"] = "bold"
plt.rcParams["axes.titleweight"] = "bold"

COLORS = {"treated": "#003366", "control": "#89BDD3"}  # navy, light blue
LABELS = {"treated": "Treated", "control": "Control"}

# Shared bins
w_lo, w_hi = workers["lr_remdezr"].quantile([0.005, 0.995])
bins = np.linspace(w_lo, w_hi, NBINS + 1)
bin_width = bins[1] - bins[0]
# Side-by-side offset: each group bar takes half the bin width
half_w = bin_width * 0.45

fig, ax = plt.subplots(1, 1, figsize=(7, 4.5))

period_label, (y0, y1) = list(periods.items())[0]
sub = workers[workers["year"].between(y0, y1)]

for offset, group, gval in [(-half_w / 2, "control", 0), (half_w / 2, "treated", 1)]:
    df_g = sub[sub["treat_ultra"] == gval][["identificad", "lr_remdezr"]]
    n_firms = df_g["identificad"].nunique()
    n_workers = len(df_g)
    print(f"  {period_label} | {group}: {n_firms:,} firms, {n_workers:,} worker-spells")

    centers, density = avg_within_firm_hist(df_g, bins)

    ax.bar(
        centers + offset,
        density,
        width=half_w,
        color=COLORS[group],
        alpha=0.85,
        label=f"{LABELS[group]} ({n_firms:,} firms)",
    )

ax.set_xlabel("Log wages (Dec 2015 R$)", fontsize=12, fontweight="bold")
ax.set_ylabel("Avg. share of workers within firm\nin wage bin", fontsize=12, fontweight="bold")
ax.xaxis.set_major_formatter(mticker.FormatStrFormatter("%.1f"))
ax.yaxis.set_major_formatter(mticker.PercentFormatter(xmax=1.0))
ax.grid(axis="y", linestyle="--", alpha=0.4)
ax.legend(loc="upper right", frameon=False, fontsize=11)

fig.tight_layout()
fig.savefig(OUT, bbox_inches="tight")
print(f"\nSaved: {OUT}")
plt.close(fig)

# ---------------------------------------------------------------------------
# 6. Quantile mapping table: where does control p75 land in treated?
# ---------------------------------------------------------------------------
print("\n--- Quantile mapping (pooled 2009-2011, pre-treatment) ---")
fine_grid = np.linspace(w_lo, w_hi, 2000)
fine_bins = np.linspace(w_lo, w_hi, 2001)

sub_pre = workers[workers["year"].between(2009, 2011)]

def avg_within_firm_cdf_fine(df, grid):
    firms = df["identificad"].unique()
    cdf_matrix = np.zeros((len(firms), len(grid)), dtype=np.float32)
    wages_by_firm = df.groupby("identificad")["lr_remdezr"].apply(np.array)
    for k, fid in enumerate(firms):
        w = wages_by_firm[fid]
        cdf_matrix[k, :] = np.searchsorted(np.sort(w), grid, side="right") / len(w)
    return cdf_matrix.mean(axis=0)

cdf_treat   = avg_within_firm_cdf_fine(sub_pre[sub_pre["treat_ultra"] == 1][["identificad", "lr_remdezr"]], fine_grid)
cdf_control = avg_within_firm_cdf_fine(sub_pre[sub_pre["treat_ultra"] == 0][["identificad", "lr_remdezr"]], fine_grid)

for pct in [0.10, 0.25, 0.50, 0.75, 0.90]:
    idx_ctrl = np.searchsorted(cdf_control, pct)
    idx_ctrl = min(idx_ctrl, len(fine_grid) - 1)
    w_ctrl   = fine_grid[idx_ctrl]
    pct_in_treat = np.interp(w_ctrl, fine_grid, cdf_treat)

    print(
        f"  Control p{int(pct*100):2d}: log-wage = {w_ctrl:.3f} "
        f"→ corresponds to treated p{pct_in_treat*100:.1f}"
    )

con.close()
print("\nDone.")
