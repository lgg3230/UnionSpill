#!/home/lgg3230/.conda/envs/venv_python312/bin/python
"""
Simple script to plot geo_distance vs cep_distance and report pair counts.
"""

import duckdb
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

# Paths
MAIN_PARQUET = "/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/bilateral_regression_data.parquet"
CEP_PARQUET = "/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/bilateral_cep_turnover.parquet"
OUTPUT_PATH = "/gpfs/kellogg/proj/lgg3230/UnionSpill/Graphs/geo_vs_cep_distance.pdf"

con = duckdb.connect()
con.execute("PRAGMA threads=8")
con.execute("PRAGMA memory_limit='32GB'")

# Count pairs with each variable
print("=" * 60)
print("PAIR COUNTS")
print("=" * 60)

# Total pairs in main data
total_main = con.execute(f"SELECT COUNT(*) FROM read_parquet('{MAIN_PARQUET}')").fetchone()[0]
print(f"Total pairs in main parquet: {total_main:,}")

# Pairs with geo_distance
geo_count = con.execute(f"""
    SELECT COUNT(*) FROM read_parquet('{MAIN_PARQUET}')
    WHERE geo_distance IS NOT NULL
""").fetchone()[0]
print(f"Pairs with geo_distance: {geo_count:,}")

# Total pairs in CEP data
total_cep = con.execute(f"SELECT COUNT(*) FROM read_parquet('{CEP_PARQUET}')").fetchone()[0]
print(f"Total pairs in CEP parquet: {total_cep:,}")

# Pairs with cep_distance
cep_count = con.execute(f"""
    SELECT COUNT(*) FROM read_parquet('{CEP_PARQUET}')
    WHERE cep_distance IS NOT NULL
""").fetchone()[0]
print(f"Pairs with cep_distance: {cep_count:,}")

# Join and count pairs with both
print("\nJoining datasets...")
both_count = con.execute(f"""
    SELECT COUNT(*)
    FROM read_parquet('{MAIN_PARQUET}') AS main
    JOIN read_parquet('{CEP_PARQUET}') AS cep
        ON main.identificad_i = cep.identificad_i
        AND main.identificad_j = cep.identificad_j
    WHERE main.geo_distance IS NOT NULL
      AND cep.cep_distance IS NOT NULL
""").fetchone()[0]
print(f"Pairs with BOTH geo_distance and cep_distance: {both_count:,}")

# Sample data for plotting (use a random sample to keep it manageable)
print("\nSampling data for plot...")
df = con.execute(f"""
    SELECT
        main.geo_distance,
        cep.cep_distance
    FROM read_parquet('{MAIN_PARQUET}') AS main
    JOIN read_parquet('{CEP_PARQUET}') AS cep
        ON main.identificad_i = cep.identificad_i
        AND main.identificad_j = cep.identificad_j
    WHERE main.geo_distance IS NOT NULL
      AND cep.cep_distance IS NOT NULL
    USING SAMPLE 100000
""").df()

print(f"Sampled {len(df):,} pairs for plotting")

# Compute correlation
corr = df['geo_distance'].corr(df['cep_distance'])
print(f"\nCorrelation: {corr:.4f}")

# Summary stats
print("\n" + "=" * 60)
print("SUMMARY STATISTICS")
print("=" * 60)
print(f"\ngeo_distance:")
print(f"  Mean: {df['geo_distance'].mean():.2f}")
print(f"  Median: {df['geo_distance'].median():.2f}")
print(f"  Std: {df['geo_distance'].std():.2f}")
print(f"  Min: {df['geo_distance'].min():.2f}")
print(f"  Max: {df['geo_distance'].max():.2f}")

print(f"\ncep_distance:")
print(f"  Mean: {df['cep_distance'].mean():.2f}")
print(f"  Median: {df['cep_distance'].median():.2f}")
print(f"  Std: {df['cep_distance'].std():.2f}")
print(f"  Min: {df['cep_distance'].min():.2f}")
print(f"  Max: {df['cep_distance'].max():.2f}")

# Create binned scatter plot
print("\n" + "=" * 60)
print("CREATING BINNED SCATTER PLOT")
print("=" * 60)

fig, ax = plt.subplots(figsize=(8, 8))

# Create bins for geo_distance
n_bins = 50
df['geo_bin'] = pd.cut(df['geo_distance'], bins=n_bins)

# Calculate mean and std of cep_distance for each bin
binned = df.groupby('geo_bin', observed=True).agg(
    geo_mean=('geo_distance', 'mean'),
    cep_mean=('cep_distance', 'mean'),
    cep_std=('cep_distance', 'std'),
    count=('cep_distance', 'count')
).reset_index()

# Filter bins with enough observations
binned = binned[binned['count'] >= 10]

# Plot binned means with error bars (95% CI)
ax.errorbar(
    binned['geo_mean'],
    binned['cep_mean'],
    yerr=1.96 * binned['cep_std'] / np.sqrt(binned['count']),
    fmt='o',
    markersize=6,
    color='steelblue',
    ecolor='steelblue',
    elinewidth=1,
    capsize=2,
    alpha=0.8,
    label='Bin mean (95% CI)'
)

# Add 45-degree line
max_val = max(df['geo_distance'].max(), df['cep_distance'].max())
ax.plot([0, max_val], [0, max_val], 'r--', linewidth=1.5, label='45-degree line')

# Labels
ax.set_xlabel('Geographic Distance (municipality centroids, km)', fontsize=11, fontweight='bold')
ax.set_ylabel('CEP Distance (postal code centroids, km)', fontsize=11, fontweight='bold')

# Add correlation text
ax.text(0.05, 0.95, f'Correlation: {corr:.3f}\nn = {both_count:,} pairs\n{n_bins} bins',
        transform=ax.transAxes, fontsize=10, verticalalignment='top',
        bbox=dict(boxstyle='round', facecolor='white', alpha=0.8))

ax.legend(loc='lower right')
ax.set_aspect('equal', adjustable='box')

# Set axis limits
ax.set_xlim(0, max_val * 1.02)
ax.set_ylim(0, max_val * 1.02)

plt.tight_layout()
fig.savefig(OUTPUT_PATH, dpi=300, bbox_inches='tight', facecolor='white')
plt.close(fig)

print(f"\nSaved: {OUTPUT_PATH}")
