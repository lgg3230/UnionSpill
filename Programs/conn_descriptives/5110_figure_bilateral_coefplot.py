#!/home/lgg3230/.conda/envs/venv_python312/bin/python
"""
PROJECT: UNION SPILLOVERS
AUTHOR: LUIS GOMES
PROGRAM: COMBINED COEFFICIENT PLOTS - GRAVITY + PRETREATMENT

Creates a single 2x2 figure comparing gravity (post-treatment) and pretreatment specifications:
  - Top row: Proximity measures (left=gravity, right=pretreat)
  - Bottom row: Dummy variables (left=gravity, right=pretreat)

Key features:
  - Top-aligned: gravity (8 vars) aligns with top 8 of pretreat (9 vars)
  - Shared x-axis scales within each row for easy coefficient comparison
  - Single legend at bottom of figure
"""

import pandas as pd
import matplotlib.pyplot as plt
import matplotlib as mpl
import numpy as np
from pathlib import Path
from matplotlib.lines import Line2D

# Set TeX Gyre Pagella font
mpl.rcParams['font.family'] = 'serif'
mpl.rcParams['font.serif'] = ['TeX Gyre Pagella', 'TeXGyrePagella', 'DejaVu Serif']

# Use TrueType fonts for crisp text in PDFs
mpl.rcParams['pdf.fonttype'] = 42
mpl.rcParams['ps.fonttype'] = 42

# ==============================================================================
# PATHS
# ==============================================================================

BASE_DIR = Path("/kellogg/proj/lgg3230/UnionSpill")
RAIS_AUX = BASE_DIR / "Data" / "RAIS_aux"
GRAPHS = BASE_DIR / "Graphs" / "connectivity"

# 06 regression: predicting pre-treatment connectivity with gravity measures (split files)
GRAVITY_UNIV_FILE = RAIS_AUX / "coef_connectivity_univ.csv"
GRAVITY_MULTI_FILE = RAIS_AUX / "coef_connectivity_multi.csv"

# 07d regression: predicting late-pre connectivity with early connectivity + proximity (split files)
PRETREAT_UNIV_FILE = RAIS_AUX / "coef_late_connectivity_univ.csv"
PRETREAT_MULTI_FILE = RAIS_AUX / "coef_late_connectivity_multi.csv"

# Output
OUTPUT_FILE = GRAPHS / "coefplot_bilateral_combined.pdf"

# ==============================================================================
# VARIABLE DEFINITIONS
# ==============================================================================

VAR_LABELS = {
    # Proximity measures
    "z_cep_proximity": "Spatial",
    "z_geo_proximity": "Spatial",  # Keep for backward compatibility
    "z_turnover_proximity": "Turnover",
    "z_size_proximity": "Size",
    "z_wage_proximity": "Wage",
    "z_female_proximity": "% Female",
    "z_nonwhite_proximity": "% Non-white",
    "z_educ_proximity": "% Higher ed.",
    "z_hs_proximity": "% High school",
    "z_clauses_proximity": "# CBA clauses",
    "z_bilateral_conn_early_pre": "Early Conn.",
    # Dummies
    "same_microregion": "Microregion",
    "same_union": "Union",
    "same_industry": "Industry",
    "same_industry_micro": "Industry ×\nmicroregion",
}

# Gravity variables (8 proximity, 4 dummies)
GRAVITY_PROXIMITY_VARS = [
    "z_cep_proximity",
    "z_turnover_proximity",
    "z_size_proximity",
    "z_wage_proximity",
    "z_female_proximity",
    "z_nonwhite_proximity",
    "z_educ_proximity",
    "z_hs_proximity",
    "z_clauses_proximity",
]

# Pretreat variables (9 proximity including early connectivity, 4 dummies)
PRETREAT_PROXIMITY_VARS = [
    "z_bilateral_conn_early_pre",
    "z_cep_proximity",
    "z_turnover_proximity",
    "z_size_proximity",
    "z_wage_proximity",
    "z_female_proximity",
    "z_nonwhite_proximity",
    "z_educ_proximity",
    "z_hs_proximity",
    "z_clauses_proximity",
]

DUMMY_VARS = [
    "same_microregion",
    "same_union",
    "same_industry",
    "same_industry_micro",
]

# Plot colors
COLORS = {"univariate": "#2166AC", "multivariate": "#B2182B"}


# ==============================================================================
# DATA LOADING
# ==============================================================================

def load_gravity_data():
    """Load gravity coefficients (06 regression: pre-treatment connectivity)."""
    # Combine univariate and multivariate from split files
    univ = pd.read_csv(GRAVITY_UNIV_FILE)
    multi = pd.read_csv(GRAVITY_MULTI_FILE)
    return pd.concat([univ, multi], ignore_index=True)


def load_pretreat_data():
    """Load pretreatment coefficients."""
    # Combine univariate and multivariate from split files
    univ = pd.read_csv(PRETREAT_UNIV_FILE)
    multi = pd.read_csv(PRETREAT_MULTI_FILE)
    return pd.concat([univ, multi], ignore_index=True)


# ==============================================================================
# PLOTTING HELPER
# ==============================================================================

def get_ordered_vars(df, var_list):
    """Order variables by univariate coefficient (smallest to largest)."""
    univ_coefs = df[df["reg_type"] == "univariate"].set_index("variable")["coef"]
    ordered = univ_coefs.reindex(var_list).dropna().sort_values(ascending=True).index.tolist()
    return list(reversed(ordered))  # Reversed for matplotlib (bottom-up)


def plot_coefficients(ax, df, var_list, y_offset=0, max_y_vars=None, swap_vars=None, forced_order=None):
    """
    Plot coefficients on a single axis.

    Parameters:
    -----------
    ax : matplotlib axis
    df : DataFrame with coefficient data
    var_list : list of variables to plot (in display order, top to bottom)
    y_offset : int, offset for y-positions (for top-alignment)
    max_y_vars : int, total number of y-positions (for consistent y-limits)
    swap_vars : tuple of two variable names to swap positions after ordering
    forced_order : list of variable names to use as ordering (overrides get_ordered_vars)
    """
    df_filtered = df[df["variable"].isin(var_list)].copy()
    if df_filtered.empty:
        return

    # Get ordered variables
    if forced_order is not None:
        # Use forced order, keeping only vars present in var_list and data
        available = set(df_filtered["variable"].unique())
        ordered_vars = [v for v in forced_order if v in available and v in var_list]
        # Append any remaining vars not in forced_order at the end
        for v in var_list:
            if v in available and v not in ordered_vars:
                ordered_vars.append(v)
    else:
        ordered_vars = get_ordered_vars(df_filtered, var_list)

    # Swap two variables if requested
    if swap_vars is not None:
        var1, var2 = swap_vars
        if var1 in ordered_vars and var2 in ordered_vars:
            idx1 = ordered_vars.index(var1)
            idx2 = ordered_vars.index(var2)
            ordered_vars[idx1], ordered_vars[idx2] = ordered_vars[idx2], ordered_vars[idx1]

    n_vars = len(ordered_vars)

    if max_y_vars is None:
        max_y_vars = n_vars

    # Y positions: offset from bottom if fewer vars than max
    y_positions = {var: i + y_offset for i, var in enumerate(ordered_vars)}

    # Horizontal guide lines (only for positions with actual coefficients)
    for i in range(y_offset, y_offset + n_vars):
        ax.axhline(y=i, color="gray", linestyle="-", linewidth=0.5, alpha=0.2, zorder=0)

    # Plot coefficients
    for _, row in df_filtered.iterrows():
        var = row["variable"]
        if var not in y_positions:
            continue

        reg_type = row["reg_type"]
        y = y_positions[var]
        coef = row["coef"]
        ci_lower = row["ci_lower"]
        ci_upper = row["ci_upper"]

        # Confidence interval
        ax.plot([ci_lower, ci_upper], [y, y],
                color=COLORS[reg_type], linewidth=1.5, alpha=0.8, zorder=1)

        # Point estimate
        if reg_type == "univariate":
            ax.plot(coef, y, marker="D", markersize=11,
                    markerfacecolor="white", markeredgecolor=COLORS[reg_type],
                    markeredgewidth=2, zorder=2)
        else:
            ax.plot(coef, y, marker="o", markersize=12,
                    markerfacecolor=COLORS[reg_type], markeredgecolor=COLORS[reg_type],
                    markeredgewidth=1.5, zorder=3)

    # Zero line
    ax.axvline(x=0, color="gray", linestyle="-", linewidth=0.8, alpha=0.5, zorder=0)

    # Y-axis labels
    yticks = [i + y_offset for i in range(n_vars)]
    yticklabels = [VAR_LABELS.get(var, var) for var in ordered_vars]
    ax.set_yticks(yticks)
    ax.set_yticklabels(yticklabels, fontweight="bold", fontsize=11)

    # Y-limits (consistent across aligned plots)
    ax.set_ylim(-0.5, max_y_vars - 0.5)

    # Clean up spines
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)

    return ordered_vars


def sync_xlim(ax1, ax2, padding=0.05):
    """Synchronize x-limits across two axes with padding."""
    x1_min, x1_max = ax1.get_xlim()
    x2_min, x2_max = ax2.get_xlim()

    x_min = min(x1_min, x2_min)
    x_max = max(x1_max, x2_max)
    x_range = x_max - x_min

    new_min = x_min - padding * x_range
    new_max = x_max + padding * x_range

    ax1.set_xlim(new_min, new_max)
    ax2.set_xlim(new_min, new_max)


# ==============================================================================
# MAIN
# ==============================================================================

def main():
    print("=" * 70)
    print("CREATING COMBINED COEFFICIENT PLOT (GRAVITY + PRETREAT)")
    print("=" * 70)

    # Load data
    print("\nLoading data...")
    gravity_df = load_gravity_data()
    pretreat_df = load_pretreat_data()
    print(f"  Gravity: {len(gravity_df)} rows")
    print(f"  Pretreat: {len(pretreat_df)} rows")

    # Create 2x2 figure with height ratios proportional to number of variables
    # Top row: 10 proximity vars (pretreat), Bottom row: 4 dummy vars
    fig, axes = plt.subplots(2, 2, figsize=(14, 10),
                              gridspec_kw={'height_ratios': [10, 4]})

    # Subplot references
    ax_grav_prox = axes[0, 0]  # Top-left: Gravity proximity
    ax_pre_prox = axes[0, 1]   # Top-right: Pretreat proximity
    ax_grav_dum = axes[1, 0]   # Bottom-left: Gravity dummies
    ax_pre_dum = axes[1, 1]    # Bottom-right: Pretreat dummies

    # =========================================================================
    # TOP ROW: Proximity measures (top-aligned)
    # =========================================================================
    print("\nPlotting proximity measures...")

    # Pretreat has 10 vars, gravity has 9 -> gravity needs offset of 1
    n_prox_max = len(PRETREAT_PROXIMITY_VARS)  # 10
    n_grav_prox = len(GRAVITY_PROXIMITY_VARS)  # 9
    grav_prox_offset = n_prox_max - n_grav_prox  # 1

    # Plot gravity proximity (with offset for top alignment)
    grav_order = plot_coefficients(ax_grav_prox, gravity_df, GRAVITY_PROXIMITY_VARS,
                                   y_offset=grav_prox_offset, max_y_vars=n_prox_max)

    # Build pretreat order: Early Conn. at bottom (y=0), then same as gravity above
    pretreat_order = ["z_bilateral_conn_early_pre"] + list(grav_order)

    # Plot pretreat proximity (no offset, forced to match gravity order)
    plot_coefficients(ax_pre_prox, pretreat_df, PRETREAT_PROXIMITY_VARS,
                      y_offset=0, max_y_vars=n_prox_max,
                      forced_order=pretreat_order)

    # Synchronize x-limits for proximity row
    sync_xlim(ax_grav_prox, ax_pre_prox)

    # =========================================================================
    # BOTTOM ROW: Dummy variables (same vars, no offset needed)
    # =========================================================================
    print("Plotting dummy variables...")

    n_dum = len(DUMMY_VARS)

    dum_order = plot_coefficients(ax_grav_dum, gravity_df, DUMMY_VARS,
                                   y_offset=0, max_y_vars=n_dum)

    plot_coefficients(ax_pre_dum, pretreat_df, DUMMY_VARS,
                      y_offset=0, max_y_vars=n_dum,
                      forced_order=dum_order)

    # Synchronize x-limits for dummies row
    sync_xlim(ax_grav_dum, ax_pre_dum)

    # =========================================================================
    # COLUMN TITLES (at very top, with panel labels)
    # =========================================================================
    fig.text(0.28, 0.99, "(A) Dep. Var.: Connectivity",
             fontsize=15, fontweight="bold", fontvariant="small-caps",
             ha="center", va="top")
    fig.text(0.72, 0.99, "(B) Dep. Var.: Late Connectivity",
             fontsize=15, fontweight="bold", fontvariant="small-caps",
             ha="center", va="top")

    # =========================================================================
    # ROW SUBTITLES (above each plot)
    # =========================================================================
    ax_grav_prox.set_title("Continuous Proximity Measures", fontsize=13, fontweight="bold", pad=8)
    ax_pre_prox.set_title("Continuous Proximity Measures", fontsize=13, fontweight="bold", pad=8)
    ax_grav_dum.set_title("Same-Category Dummies", fontsize=13, fontweight="bold", pad=8)
    ax_pre_dum.set_title("Same-Category Dummies", fontsize=13, fontweight="bold", pad=8)

    # =========================================================================
    # X-AXIS LABELS (on both rows)
    # =========================================================================
    ax_grav_prox.set_xlabel("Coefficient", fontsize=12, fontweight="bold")
    ax_pre_prox.set_xlabel("Coefficient", fontsize=12, fontweight="bold")
    ax_grav_dum.set_xlabel("Coefficient", fontsize=12, fontweight="bold")
    ax_pre_dum.set_xlabel("Coefficient", fontsize=12, fontweight="bold")

    # =========================================================================
    # SINGLE LEGEND (below entire figure)
    # =========================================================================
    legend_elements = [
        Line2D([0], [0], marker="o", color="white",
               markerfacecolor=COLORS["multivariate"],
               markeredgecolor=COLORS["multivariate"],
               markersize=12, markeredgewidth=1.5,
               linestyle="None", label="Multivariate"),
        Line2D([0], [0], marker="D", color="white",
               markerfacecolor="white",
               markeredgecolor=COLORS["univariate"],
               markersize=11, markeredgewidth=2,
               linestyle="None", label="Univariate"),
    ]

    fig.legend(
        handles=legend_elements,
        loc="lower center",
        bbox_to_anchor=(0.5, -0.02),
        ncol=2,
        frameon=False,
        fontsize=16,
        prop={'weight': 'bold'}
    )

    # =========================================================================
    # LAYOUT AND SAVE
    # =========================================================================
    plt.tight_layout()
    plt.subplots_adjust(bottom=0.08, top=0.90, hspace=0.35)  # Room for legend, column titles, and row spacing

    GRAPHS.mkdir(parents=True, exist_ok=True)
    fig.savefig(OUTPUT_FILE, dpi=1000, bbox_inches="tight", facecolor="white")
    plt.close(fig)

    print(f"\nSaved: {OUTPUT_FILE}")
    print("\n" + "=" * 70)
    print("COMPLETE")
    print("=" * 70)


if __name__ == "__main__":
    main()
