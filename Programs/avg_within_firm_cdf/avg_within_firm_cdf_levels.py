"""
avg_within_firm_cdf_levels.py
=============================
Plots the average within-firm empirical CDF of real wages (in levels) for
treated vs. control firms in the Lagos balanced-panel sample.

Uses remdezr (real December earnings deflated to Dec 2015 BRL) instead of
log wages. Everything else follows avg_within_firm_cdf.py exactly.

Reading the crosswalk lines
---------------------------
Dashed vertical lines mark selected percentiles of the treated distribution.
Each label reads "T pX = C pY": the wage at the Xth percentile among treated
firms corresponds to only the Yth percentile among control firms.
Y < X throughout, meaning control firms systematically pay less.

Outputs
-------
- Graphs/avg_within_firm_cdf/avg_within_firm_cdf_levels_<date>.pdf
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
OUT   = os.path.join(GRAPH_DIR, f"avg_within_firm_cdf_levels_{TODAY}.pdf")

WAGE_VAR = "remdezr"  # real December earnings, Dec 2015 BRL

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
# 2. Load worker wages (real December earnings in levels)
# ---------------------------------------------------------------------------
print("Loading worker panel (parquet)...")
con = duckdb.connect()
con.execute("PRAGMA threads=8")
con.execute("PRAGMA memory_limit='24GB'")

workers = con.execute(f"""
    SELECT identificad, year, {WAGE_VAR}
    FROM read_parquet('{PANEL_FILE}')
    WHERE {WAGE_VAR} IS NOT NULL AND {WAGE_VAR} > 0
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
w_lo, w_hi = workers[WAGE_VAR].quantile([0.005, 0.995])

periods = {
    "Pre-treatment (2009–2011)": (2009, 2011),
}

NBINS = 12

def avg_within_firm_hist(df, bins):
    """
    For a DataFrame with columns [identificad, WAGE_VAR],
    return the average within-firm histogram (density) evaluated over bins.
    Each firm contributes equally (unweighted).
    Returns (bin_centers, avg_density) where density sums to 1 across bins.
    """
    firms = df["identificad"].unique()
    hist_matrix = np.zeros((len(firms), len(bins) - 1), dtype=np.float32)
    wages_by_firm = df.groupby("identificad")[WAGE_VAR].apply(np.array)

    for k, fid in enumerate(firms):
        w = wages_by_firm[fid]
        counts, _ = np.histogram(w, bins=bins)
        total = counts.sum()
        hist_matrix[k, :] = counts / total if total > 0 else 0.0

    centers = 0.5 * (bins[:-1] + bins[1:])
    return centers, hist_matrix.mean(axis=0)


# ---------------------------------------------------------------------------
# 5. Quantile mapping (computed here so we can use it in the plot)
# ---------------------------------------------------------------------------
fine_grid = np.linspace(w_lo, w_hi, 2000)

sub_pre = workers[workers["year"].between(2009, 2011)]

def avg_within_firm_cdf_fine(df, grid):
    firms = df["identificad"].unique()
    cdf_matrix = np.zeros((len(firms), len(grid)), dtype=np.float32)
    wages_by_firm = df.groupby("identificad")[WAGE_VAR].apply(np.array)
    for k, fid in enumerate(firms):
        w = wages_by_firm[fid]
        cdf_matrix[k, :] = np.searchsorted(np.sort(w), grid, side="right") / len(w)
    return cdf_matrix.mean(axis=0)

cdf_treat   = avg_within_firm_cdf_fine(sub_pre[sub_pre["treat_ultra"] == 1][["identificad", WAGE_VAR]], fine_grid)
cdf_control = avg_within_firm_cdf_fine(sub_pre[sub_pre["treat_ultra"] == 0][["identificad", WAGE_VAR]], fine_grid)

REF_PCTS = [0.10, 0.25, 0.50, 0.75, 0.90]

# ---------------------------------------------------------------------------
# 6. Plot
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
w_lo, w_hi = workers[WAGE_VAR].quantile([0.005, 0.995])
bins = np.linspace(w_lo, w_hi, NBINS + 1)
bin_width = bins[1] - bins[0]
half_w = bin_width * 0.45

fig, ax = plt.subplots(1, 1, figsize=(10, 4.5))

period_label, (y0, y1) = list(periods.items())[0]
sub = workers[workers["year"].between(y0, y1)]

for offset, group, gval in [(-half_w / 2, "control", 0), (half_w / 2, "treated", 1)]:
    df_g = sub[sub["treat_ultra"] == gval][["identificad", WAGE_VAR]]
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
        label=LABELS[group],
    )

# Add vertical reference lines at treated percentiles (labels just above plot)
y_fracs = [1.01, 1.01, 1.01, 1.01, 1.01]
for i, pct in enumerate(REF_PCTS):
    idx = np.searchsorted(cdf_treat, pct)
    w_star = fine_grid[min(idx, len(fine_grid) - 1)]
    pct_in_control = np.interp(w_star, fine_grid, cdf_control) * 100

    ax.axvline(w_star, color="black", linestyle="--", linewidth=1.4)

    ax.text(
        w_star, y_fracs[i],
        f"T p{int(pct*100)}\n= C p{pct_in_control:.0f}",
        transform=ax.get_xaxis_transform(),
        ha="center", va="bottom", fontsize=10,
        color="black",
        clip_on=False,
    )

ax.set_xlabel("Real wages (Dec 2015 R$)", fontsize=12, fontweight="bold")
ax.set_ylabel("Avg. share of workers within firm\nin wage bin", fontsize=12, fontweight="bold")
ax.xaxis.set_major_formatter(mticker.FuncFormatter(lambda x, _: f"{x:,.0f}"))
ax.yaxis.set_major_formatter(mticker.PercentFormatter(xmax=1.0))
ax.grid(axis="y", linestyle="--", alpha=0.4)
ax.legend(loc="upper right", frameon=False, fontsize=11)
ax.spines["top"].set_visible(False)
ax.spines["right"].set_visible(False)

fig.tight_layout()
fig.savefig(OUT, bbox_inches="tight")
print(f"\nSaved: {OUT}")
plt.close(fig)

# ---------------------------------------------------------------------------
# 7. Quantile mapping table
# ---------------------------------------------------------------------------
print("\n--- Quantile mapping (pooled 2009-2011, pre-treatment) ---")

for pct in [0.10, 0.25, 0.50, 0.75, 0.90]:
    idx_ctrl = np.searchsorted(cdf_control, pct)
    idx_ctrl = min(idx_ctrl, len(fine_grid) - 1)
    w_ctrl   = fine_grid[idx_ctrl]
    pct_in_treat = np.interp(w_ctrl, fine_grid, cdf_treat)

    print(
        f"  Control p{int(pct*100):2d}: wage = R${w_ctrl:,.0f} "
        f"→ corresponds to treated p{pct_in_treat*100:.1f}"
    )

con.close()
print("\nDone.")
