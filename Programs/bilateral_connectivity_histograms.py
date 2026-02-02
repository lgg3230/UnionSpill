"""
PROJECT: UNION SPILLOVERS
AUTHOR: LUIS GOMES
PROGRAM: BILATERAL CONNECTIVITY HISTOGRAMS
INPUT: bilateral_connectivity_2007_2011.csv, bilateral_connectivity_2011_2016.csv
OUTPUT: Histograms with broken y-axis for zero spike
"""

import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
from pathlib import Path
from matplotlib.patches import ConnectionPatch

# ==============================================================================
# PATHS
# ==============================================================================

PROJECT_ROOT = Path("/gpfs/kellogg/proj/lgg3230/UnionSpill")
RAIS_AUX = PROJECT_ROOT / "Data" / "RAIS_aux"
GRAPHS = PROJECT_ROOT / "Graphs"

# ==============================================================================
# FUNCTIONS
# ==============================================================================


def load_bilateral_data(filepath, period="pre", use_full_pairs=True):
    """Load bilateral connectivity data and compute summary measure.

    For pre-treatment: Uses bilateral_pairs_descriptives.csv (27GB, all pairs)
    For post-treatment: Uses bilateral_pairs_descriptives_post.csv (all pairs) or
                        bilateral_connectivity_2011_2016.csv (only positive flows)
    """
    print(f"Loading {filepath}...")

    # For the large full pairs files, read in chunks
    if "bilateral_pairs_descriptives" in str(filepath):
        print("  Reading large file in chunks...")
        chunks = []
        chunk_size = 1000000  # 1M rows at a time
        for i, chunk in enumerate(pd.read_csv(filepath, chunksize=chunk_size,
                                               dtype={"identificad_i": str, "identificad_j": str})):
            chunks.append(chunk[["bilateral_conn_pw"]].copy())
            if (i + 1) % 10 == 0:
                print(f"    Processed {(i+1) * chunk_size:,} rows...")
        df = pd.concat(chunks, ignore_index=True)
        conn_var = "bilateral_conn_pw"
    else:
        df = pd.read_csv(filepath, dtype={"identificad_i": str, "identificad_j": str})

        if period == "pre":
            conn_var = "bilateral_conn_pw"
        else:
            # Post-treatment: compute average ratio across 2011-2015
            if "ratio_1112" in df.columns:
                df["bilateral_conn_pw"] = df[["ratio_1112", "ratio_1213", "ratio_1314", "ratio_1415"]].mean(axis=1)
            conn_var = "bilateral_conn_pw"

    # Fill NaN with 0 (missing = no flow = zero connectivity)
    df[conn_var] = df[conn_var].fillna(0)

    print(f"  Loaded {len(df):,} establishment pairs")
    print(f"  Non-zero connectivity: {(df[conn_var] > 0).sum():,} ({100*(df[conn_var] > 0).mean():.2f}%)")
    print(f"  Zero connectivity: {(df[conn_var] == 0).sum():,} ({100*(df[conn_var] == 0).mean():.2f}%)")

    return df, conn_var


def create_histogram_broken_axis(data, title, output_path, color="#1f4e79", n_bins=50):
    """
    Create histogram with broken y-axis to handle the zero spike.

    The plot has two y-axis segments:
    - Bottom: Shows the distribution of positive values
    - Top: Shows the zero bar (truncated)
    """
    # Separate zeros and positives
    zeros = (data == 0).sum()
    positives = data[data > 0]

    # Create bins for positive values only
    if len(positives) > 0:
        bins_pos = np.linspace(positives.min(), positives.max(), n_bins)
        hist_pos, bin_edges = np.histogram(positives, bins=bins_pos)
    else:
        hist_pos = np.array([])
        bin_edges = np.array([0, 1])

    # Determine y-axis break points
    max_pos_count = hist_pos.max() if len(hist_pos) > 0 else 1

    # Create figure with two subplots (broken axis)
    fig, (ax_top, ax_bottom) = plt.subplots(
        2, 1,
        figsize=(10, 8),
        gridspec_kw={'height_ratios': [1, 3], 'hspace': 0.05}
    )

    # Top axis: zero bar only (truncated)
    bar_width = (bin_edges[1] - bin_edges[0]) if len(bin_edges) > 1 else 0.01
    ax_top.bar(0, zeros, width=bar_width, color=color, alpha=0.7, edgecolor='black', linewidth=0.5)
    ax_top.set_ylim(zeros * 0.9, zeros * 1.05)
    ax_top.set_xlim(-bar_width, bin_edges[-1] if len(bin_edges) > 1 else 1)
    ax_top.spines['bottom'].set_visible(False)
    ax_top.tick_params(axis='x', which='both', bottom=False, labelbottom=False)
    ax_top.set_ylabel('')

    # Add count label on top of zero bar
    ax_top.annotate(
        f'{zeros:,}\n({100*zeros/len(data):.1f}%)',
        xy=(0, zeros),
        xytext=(0, zeros * 1.02),
        ha='center',
        va='bottom',
        fontsize=10,
        fontweight='bold'
    )

    # Bottom axis: positive values histogram
    if len(hist_pos) > 0:
        bin_centers = (bin_edges[:-1] + bin_edges[1:]) / 2
        ax_bottom.bar(bin_centers, hist_pos, width=np.diff(bin_edges),
                     color=color, alpha=0.7, edgecolor='black', linewidth=0.5)

    # Also show zero bar in bottom (truncated view)
    ax_bottom.bar(0, min(zeros, max_pos_count * 1.5), width=bar_width,
                 color=color, alpha=0.7, edgecolor='black', linewidth=0.5)

    ax_bottom.set_ylim(0, max_pos_count * 1.15)
    ax_bottom.set_xlim(-bar_width, bin_edges[-1] if len(bin_edges) > 1 else 1)
    ax_bottom.spines['top'].set_visible(False)
    ax_bottom.set_xlabel('Bilateral Connectivity (flows per worker)', fontsize=12)

    # Add break marks
    d = 0.015
    kwargs = dict(transform=ax_top.transAxes, color='k', clip_on=False)
    ax_top.plot((-d, +d), (-d, +d), **kwargs)
    ax_top.plot((1 - d, 1 + d), (-d, +d), **kwargs)

    kwargs = dict(transform=ax_bottom.transAxes, color='k', clip_on=False)
    ax_bottom.plot((-d, +d), (1 - d, 1 + d), **kwargs)
    ax_bottom.plot((1 - d, 1 + d), (1 - d, 1 + d), **kwargs)

    # Common y-label
    fig.text(0.02, 0.5, 'Number of Establishment Pairs', va='center', rotation='vertical', fontsize=12)

    # Title
    ax_top.set_title(title, fontsize=14, fontweight='bold', pad=10)

    # Style
    for ax in [ax_top, ax_bottom]:
        ax.set_facecolor('white')
    fig.patch.set_facecolor('white')

    plt.savefig(output_path, format='pdf', bbox_inches='tight', dpi=300)
    plt.close()

    print(f"Saved: {output_path}")


def create_histogram_log_scale(data, title, output_path, color="#1f4e79", n_bins=50):
    """
    Alternative: Create histogram with log scale y-axis.
    """
    fig, ax = plt.subplots(figsize=(10, 6))

    # Create bins including zero
    data_clean = data.dropna()
    bins = np.concatenate([[-0.001], np.linspace(0.001, data_clean.max(), n_bins)])

    ax.hist(data_clean, bins=bins, color=color, alpha=0.7, edgecolor='black', linewidth=0.5)
    ax.set_yscale('log')

    ax.set_xlabel('Bilateral Connectivity (flows per worker)', fontsize=12)
    ax.set_ylabel('Number of Establishment Pairs (log scale)', fontsize=12)
    ax.set_title(title, fontsize=14, fontweight='bold')

    # Add annotation for zeros
    zeros = (data_clean == 0).sum()
    ax.annotate(
        f'Zero: {zeros:,} ({100*zeros/len(data_clean):.1f}%)',
        xy=(0.02, 0.95),
        xycoords='axes fraction',
        fontsize=11,
        bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5)
    )

    ax.set_facecolor('white')
    fig.patch.set_facecolor('white')
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)

    plt.tight_layout()
    plt.savefig(output_path, format='pdf', bbox_inches='tight', dpi=300)
    plt.close()

    print(f"Saved: {output_path}")


def create_histogram_positive_only(data, title, output_path, color="#1f4e79", n_bins=50):
    """
    Create histogram showing only positive values with inset for zero count.
    """
    fig, ax = plt.subplots(figsize=(10, 6))

    # Separate zeros and positives
    data_clean = data.dropna()
    zeros = (data_clean == 0).sum()
    positives = data_clean[data_clean > 0]

    # Plot positive values
    if len(positives) > 0:
        ax.hist(positives, bins=n_bins, color=color, alpha=0.7, edgecolor='black', linewidth=0.5)

    ax.set_xlabel('Bilateral Connectivity (flows per worker)', fontsize=12)
    ax.set_ylabel('Number of Establishment Pairs', fontsize=12)
    ax.set_title(f'{title}\n(Positive Values Only)', fontsize=14, fontweight='bold')

    # Add text box with zero info
    textstr = f'Zero connectivity pairs:\n{zeros:,} ({100*zeros/len(data_clean):.1f}%)\n\nPositive connectivity pairs:\n{len(positives):,} ({100*len(positives)/len(data_clean):.1f}%)'
    props = dict(boxstyle='round', facecolor='wheat', alpha=0.8)
    ax.text(0.97, 0.97, textstr, transform=ax.transAxes, fontsize=10,
            verticalalignment='top', horizontalalignment='right', bbox=props)

    ax.set_facecolor('white')
    fig.patch.set_facecolor('white')
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)

    plt.tight_layout()
    plt.savefig(output_path, format='pdf', bbox_inches='tight', dpi=300)
    plt.close()

    print(f"Saved: {output_path}")


def create_combined_histogram(data, title, output_path, color="#1f4e79", n_bins=50):
    """
    Create a two-panel histogram:
    - Left: Bar chart showing zero vs positive count
    - Right: Histogram of positive values only
    """
    fig, (ax_left, ax_right) = plt.subplots(1, 2, figsize=(14, 5),
                                             gridspec_kw={'width_ratios': [1, 2.5]})

    # Separate zeros and positives
    data_clean = data.dropna()
    zeros = (data_clean == 0).sum()
    positives = data_clean[data_clean > 0]
    n_pos = len(positives)

    # Left panel: Zero vs Positive bar chart
    categories = ['Zero\nConnectivity', 'Positive\nConnectivity']
    counts = [zeros, n_pos]
    percentages = [100*zeros/len(data_clean), 100*n_pos/len(data_clean)]

    bars = ax_left.bar(categories, counts, color=[color, '#2ecc71'], alpha=0.7,
                       edgecolor='black', linewidth=1)

    # Add count labels
    for bar, count, pct in zip(bars, counts, percentages):
        ax_left.annotate(f'{count:,}\n({pct:.1f}%)',
                        xy=(bar.get_x() + bar.get_width()/2, bar.get_height()),
                        xytext=(0, 5), textcoords='offset points',
                        ha='center', va='bottom', fontsize=11, fontweight='bold')

    ax_left.set_ylabel('Number of Establishment Pairs', fontsize=12)
    ax_left.set_title('Connectivity Status', fontsize=12, fontweight='bold')
    ax_left.spines['top'].set_visible(False)
    ax_left.spines['right'].set_visible(False)

    # Right panel: Histogram of positive values
    if len(positives) > 0:
        ax_right.hist(positives, bins=n_bins, color='#2ecc71', alpha=0.7,
                     edgecolor='black', linewidth=0.5)

    ax_right.set_xlabel('Bilateral Connectivity (flows per worker)', fontsize=12)
    ax_right.set_ylabel('Number of Establishment Pairs', fontsize=12)
    ax_right.set_title('Distribution of Positive Connectivity', fontsize=12, fontweight='bold')
    ax_right.spines['top'].set_visible(False)
    ax_right.spines['right'].set_visible(False)

    # Summary stats for positive values
    if len(positives) > 0:
        stats_text = f'Mean: {positives.mean():.4f}\nMedian: {positives.median():.4f}\nStd: {positives.std():.4f}'
        ax_right.text(0.97, 0.97, stats_text, transform=ax_right.transAxes, fontsize=10,
                     verticalalignment='top', horizontalalignment='right',
                     bbox=dict(boxstyle='round', facecolor='white', alpha=0.8))

    # Overall title
    fig.suptitle(title, fontsize=14, fontweight='bold', y=1.02)

    for ax in [ax_left, ax_right]:
        ax.set_facecolor('white')
    fig.patch.set_facecolor('white')

    plt.tight_layout()
    plt.savefig(output_path, format='pdf', bbox_inches='tight', dpi=300)
    plt.close()

    print(f"Saved: {output_path}")


def main():
    """Main function."""

    print("=" * 70)
    print("BILATERAL CONNECTIVITY HISTOGRAMS")
    print("=" * 70)

    GRAPHS.mkdir(parents=True, exist_ok=True)

    # =========================================================================
    # Load data
    # =========================================================================

    # Pre-treatment (2007-2011) - use the full 27GB file with ALL pairs
    pre_file_full = RAIS_AUX / "bilateral_pairs_descriptives.csv"
    pre_file_small = RAIS_AUX / "bilateral_connectivity_2007_2011.csv"

    if pre_file_full.exists():
        print("\n--- Loading PRE-TREATMENT data (full pairs file) ---")
        df_pre, conn_var_pre = load_bilateral_data(pre_file_full, period="pre")
        data_pre = df_pre[conn_var_pre]
    elif pre_file_small.exists():
        print("\n--- Loading PRE-TREATMENT data (positive flows only) ---")
        print("WARNING: Using small file - zeros not included!")
        df_pre, conn_var_pre = load_bilateral_data(pre_file_small, period="pre")
        data_pre = df_pre[conn_var_pre]
    else:
        print(f"WARNING: Pre-treatment file not found")
        data_pre = None

    # Post-treatment (2011-2015) - prefer full pairs file if available
    post_file_full = RAIS_AUX / "bilateral_pairs_descriptives_post.csv"
    post_file_small = RAIS_AUX / "bilateral_connectivity_2011_2016.csv"

    if post_file_full.exists():
        print("\n--- Loading POST-TREATMENT data (full pairs file) ---")
        df_post, conn_var_post = load_bilateral_data(post_file_full, period="post")
        data_post = df_post[conn_var_post]
    elif post_file_small.exists():
        print("\n--- Loading POST-TREATMENT data (positive flows only) ---")
        print("WARNING: Using small file - zeros not included!")
        print("         Run 07b_bilateral_descriptives_post.py to generate full pairs file.")
        df_post, conn_var_post = load_bilateral_data(post_file_small, period="post")
        data_post = df_post[conn_var_post]
    else:
        print(f"WARNING: Post-treatment file not found")
        data_post = None

    # =========================================================================
    # Create histograms
    # =========================================================================

    print("\n" + "=" * 70)
    print("CREATING HISTOGRAMS")
    print("=" * 70)

    # Pre-treatment histograms
    if data_pre is not None:
        print("\n--- Pre-treatment (2007-2011) ---")

        # Combined histogram (recommended)
        create_combined_histogram(
            data_pre,
            "Pre-Treatment Bilateral Connectivity (2007-2011)",
            GRAPHS / "histogram_bilateral_connectivity_pre.pdf",
            color="#1f4e79"
        )

        # Log scale version
        create_histogram_log_scale(
            data_pre,
            "Pre-Treatment Bilateral Connectivity (2007-2011)",
            GRAPHS / "histogram_bilateral_connectivity_pre_log.pdf",
            color="#1f4e79"
        )

        # Positive only version
        create_histogram_positive_only(
            data_pre,
            "Pre-Treatment Bilateral Connectivity (2007-2011)",
            GRAPHS / "histogram_bilateral_connectivity_pre_positive.pdf",
            color="#1f4e79"
        )

    # Post-treatment histograms
    if data_post is not None:
        print("\n--- Post-treatment (2011-2015) ---")

        # Combined histogram (recommended)
        create_combined_histogram(
            data_post,
            "Post-Treatment Bilateral Connectivity (2011-2015)",
            GRAPHS / "histogram_bilateral_connectivity_post.pdf",
            color="#8b0000"
        )

        # Log scale version
        create_histogram_log_scale(
            data_post,
            "Post-Treatment Bilateral Connectivity (2011-2015)",
            GRAPHS / "histogram_bilateral_connectivity_post_log.pdf",
            color="#8b0000"
        )

        # Positive only version
        create_histogram_positive_only(
            data_post,
            "Post-Treatment Bilateral Connectivity (2011-2015)",
            GRAPHS / "histogram_bilateral_connectivity_post_positive.pdf",
            color="#8b0000"
        )

    # =========================================================================
    # Summary statistics
    # =========================================================================

    print("\n" + "=" * 70)
    print("SUMMARY STATISTICS")
    print("=" * 70)

    if data_pre is not None:
        print("\nPre-treatment (2007-2011):")
        print(f"  Total pairs: {len(data_pre):,}")
        print(f"  Zero connectivity: {(data_pre == 0).sum():,} ({100*(data_pre == 0).mean():.2f}%)")
        print(f"  Positive connectivity: {(data_pre > 0).sum():,} ({100*(data_pre > 0).mean():.2f}%)")
        pos_pre = data_pre[data_pre > 0]
        if len(pos_pre) > 0:
            print(f"  Mean (positive only): {pos_pre.mean():.6f}")
            print(f"  Median (positive only): {pos_pre.median():.6f}")
            print(f"  Std (positive only): {pos_pre.std():.6f}")
            print(f"  Min (positive): {pos_pre.min():.6f}")
            print(f"  Max: {pos_pre.max():.6f}")

    if data_post is not None:
        print("\nPost-treatment (2011-2015):")
        print(f"  Total pairs: {len(data_post):,}")
        print(f"  Zero connectivity: {(data_post == 0).sum():,} ({100*(data_post == 0).mean():.2f}%)")
        print(f"  Positive connectivity: {(data_post > 0).sum():,} ({100*(data_post > 0).mean():.2f}%)")
        pos_post = data_post[data_post > 0]
        if len(pos_post) > 0:
            print(f"  Mean (positive only): {pos_post.mean():.6f}")
            print(f"  Median (positive only): {pos_post.median():.6f}")
            print(f"  Std (positive only): {pos_post.std():.6f}")
            print(f"  Min (positive): {pos_post.min():.6f}")
            print(f"  Max: {pos_post.max():.6f}")

    print("\n" + "=" * 70)
    print("COMPLETE")
    print("=" * 70)
    print("\nOutput files:")
    print("  Pre-treatment:")
    print(f"    - {GRAPHS / 'histogram_bilateral_connectivity_pre.pdf'}")
    print(f"    - {GRAPHS / 'histogram_bilateral_connectivity_pre_log.pdf'}")
    print(f"    - {GRAPHS / 'histogram_bilateral_connectivity_pre_positive.pdf'}")
    print("  Post-treatment:")
    print(f"    - {GRAPHS / 'histogram_bilateral_connectivity_post.pdf'}")
    print(f"    - {GRAPHS / 'histogram_bilateral_connectivity_post_log.pdf'}")
    print(f"    - {GRAPHS / 'histogram_bilateral_connectivity_post_positive.pdf'}")


if __name__ == "__main__":
    main()
