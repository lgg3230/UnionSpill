#!/usr/bin/env python3
"""
PROJECT: UNION SPILLOVERS
AUTHOR: LUIS GOMES
PROGRAM: COEFFICIENT PLOTS FOR BILATERAL CONNECTIVITY REGRESSIONS

Creates two coefficient plots:
1. Proximity measures (continuous variables)
2. Dummy variables (binary indicators)

Each plot shows univariate (hollow) and multivariate (filled) coefficients
on the same horizontal line for each variable.
"""

import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
from pathlib import Path

# Paths
BASE_DIR = Path("/kellogg/proj/lgg3230/UnionSpill")
RAIS_AUX = BASE_DIR / "Data" / "RAIS_aux"
GRAPHS = BASE_DIR / "Graphs"

# Input files
UNIV_FILE = RAIS_AUX / "bilateral_individual_coefficients.csv"
MULTI_FILE = RAIS_AUX / "bilateral_regression_coefficients.csv"

# Which multivariate spec to use (with_intx or without_intx)
MULTI_SPEC = "with_intx"

# Output files
OUTPUT_PROXIMITY = GRAPHS / "coefplot_bilateral_gravity_proximity.pdf"
OUTPUT_DUMMIES = GRAPHS / "coefplot_bilateral_gravity_dummies.pdf"

# Variable labels (display names) - NO "proximity" word, will be bolded in plot
VAR_LABELS = {
    # Proximity measures
    'z_geo_proximity': 'Spatial',
    'z_size_proximity': 'Size',
    'z_wage_proximity': 'Wage',
    'z_female_proximity': '% Female',
    'z_nonwhite_proximity': '% Non-white',
    'z_educ_proximity': '% Higher ed.',
    'z_hs_proximity': '% High school',
    'z_clauses_proximity': '# CBA clauses',
    # Dummies
    'same_microregion': 'Microregion',
    'same_union': 'Union',
    'same_industry': 'Industry',
    'same_industry_micro': 'Industry × microregion',
}

# Variables to include in each plot
PROXIMITY_VARS = [
    'z_geo_proximity',
    'z_size_proximity',
    'z_wage_proximity',
    'z_female_proximity',
    'z_nonwhite_proximity',
    'z_educ_proximity',
    'z_hs_proximity',
    'z_clauses_proximity',
]

DUMMY_VARS = [
    'same_microregion',
    'same_union',
    'same_industry',
    'same_industry_micro',
]


def load_coefficients():
    """Load univariate and multivariate coefficients."""

    # Load univariate
    univ_df = pd.read_csv(UNIV_FILE)
    univ_df['reg_type'] = 'univariate'

    # Load multivariate - filter to single spec to avoid duplicates
    multi_df = pd.read_csv(MULTI_FILE)
    multi_df = multi_df[multi_df['spec'] == MULTI_SPEC].copy()
    multi_df['reg_type'] = 'multivariate'

    # Combine
    df = pd.concat([univ_df, multi_df], ignore_index=True)

    return df


def create_coefplot(df, var_list, output_path, title):
    """
    Create a coefficient plot with univariate (hollow) and multivariate (filled)
    coefficients on the same horizontal line for each variable.

    Variables are ordered by univariate coefficient size (smallest at top, largest at bottom).
    """

    # Filter to relevant variables
    df_filtered = df[df['variable'].isin(var_list)].copy()

    if df_filtered.empty:
        print(f"  WARNING: No data found for {title}")
        return

    # =========================================================================
    # ORDER VARIABLES BY UNIVARIATE COEFFICIENT (smallest to largest, top to bottom)
    # =========================================================================
    univ_coefs = df_filtered[df_filtered['reg_type'] == 'univariate'].set_index('variable')['coef']
    # Sort ascending (smallest first = top of plot)
    ordered_vars = univ_coefs.reindex(var_list).sort_values(ascending=True).index.tolist()
    # Reverse because matplotlib plots bottom-up
    ordered_vars_reversed = list(reversed(ordered_vars))

    # =========================================================================
    # CREATE FIGURE - extra space at bottom for legend
    # =========================================================================
    fig, ax = plt.subplots(figsize=(8, len(ordered_vars) * 0.6 + 1.0))

    # Y positions for variables (0 at bottom, n-1 at top)
    y_positions = {var: i for i, var in enumerate(ordered_vars_reversed)}

    # Plot settings
    colors = {'univariate': '#2166AC', 'multivariate': '#B2182B'}  # Blue, Red

    # =========================================================================
    # ADD HORIZONTAL FADED LINES FOR VISUAL GUIDANCE
    # =========================================================================
    for i in range(len(ordered_vars)):
        ax.axhline(y=i, color='gray', linestyle='-', linewidth=0.5, alpha=0.2, zorder=0)

    # =========================================================================
    # PLOT EACH COEFFICIENT - ALIGNED HORIZONTALLY (no vertical offset)
    # =========================================================================
    for _, row in df_filtered.iterrows():
        var = row['variable']
        if var not in y_positions:
            continue

        reg_type = row['reg_type']
        y = y_positions[var]  # No offset - both on same line

        coef = row['coef']
        ci_lower = row['ci_lower']
        ci_upper = row['ci_upper']

        # Plot confidence interval
        ax.plot([ci_lower, ci_upper], [y, y],
                color=colors[reg_type], linewidth=1.5, alpha=0.8, zorder=1)

        # Plot point estimate
        if reg_type == 'univariate':
            # Hollow marker for univariate
            ax.plot(coef, y,
                    marker='o',
                    markersize=9,
                    markerfacecolor='white',
                    markeredgecolor=colors[reg_type],
                    markeredgewidth=2,
                    zorder=2)
            # Label above the marker
            ax.text(coef, y + 0.25, f'{coef:.3f}',
                    ha='center', va='bottom',
                    fontsize=8, color=colors[reg_type],
                    zorder=4)
        else:
            # Filled marker for multivariate
            ax.plot(coef, y,
                    marker='o',
                    markersize=9,
                    markerfacecolor=colors[reg_type],
                    markeredgecolor=colors[reg_type],
                    markeredgewidth=1.5,
                    zorder=3)
            # Label below the marker
            ax.text(coef, y - 0.25, f'{coef:.3f}',
                    ha='center', va='top',
                    fontsize=8, color=colors[reg_type],
                    zorder=4)

    # Add vertical line at zero
    ax.axvline(x=0, color='gray', linestyle='-', linewidth=0.8, alpha=0.5, zorder=0)

    # =========================================================================
    # SET Y-AXIS LABELS - BOLD
    # =========================================================================
    ax.set_yticks(range(len(ordered_vars)))
    ax.set_yticklabels(
        [VAR_LABELS.get(var, var) for var in ordered_vars_reversed],
        fontweight='bold'
    )

    # =========================================================================
    # LABELS AND FORMATTING - no "Standardized", no title
    # =========================================================================
    ax.set_xlabel('Coefficient', fontsize=11, fontweight='bold')

    # =========================================================================
    # CREATE LEGEND - UNDERNEATH THE GRAPH
    # =========================================================================
    from matplotlib.lines import Line2D
    legend_elements = [
        Line2D([0], [0], marker='o', color='white', markerfacecolor=colors['multivariate'],
               markeredgecolor=colors['multivariate'], markersize=9,
               markeredgewidth=1.5, linestyle='None', label='Multivariate'),
        Line2D([0], [0], marker='o', color='white', markerfacecolor='white',
               markeredgecolor=colors['univariate'], markersize=9,
               markeredgewidth=2, linestyle='None', label='Univariate'),
    ]
    ax.legend(
        handles=legend_elements,
        loc='upper center',
        bbox_to_anchor=(0.5, -0.18),
        ncol=2,
        frameon=False,
        fontsize=10
    )

    # Clean up
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.set_ylim(-0.5, len(ordered_vars) - 0.5)

    # Adjust x-axis to have some padding
    x_min, x_max = ax.get_xlim()
    x_range = x_max - x_min
    ax.set_xlim(x_min - 0.05 * x_range, x_max + 0.05 * x_range)

    plt.tight_layout()

    # Save
    fig.savefig(output_path, dpi=300, bbox_inches='tight', facecolor='white')
    plt.close(fig)

    print(f"  Saved: {output_path}")


def main():
    print("=" * 60)
    print("CREATING COEFFICIENT PLOTS")
    print("=" * 60)

    # Load data
    print("\nLoading coefficients...")
    print(f"  Univariate: {UNIV_FILE}")
    print(f"  Multivariate: {MULTI_FILE}")

    df = load_coefficients()
    print(f"  Total rows: {len(df)}")
    print(f"  Variables: {df['variable'].unique().tolist()}")

    # Create proximity plot
    print("\nCreating proximity measures plot...")
    create_coefplot(
        df,
        PROXIMITY_VARS,
        OUTPUT_PROXIMITY,
        "Bilateral Connectivity: Proximity Measures"
    )

    # Create dummies plot
    print("\nCreating dummy variables plot...")
    create_coefplot(
        df,
        DUMMY_VARS,
        OUTPUT_DUMMIES,
        "Bilateral Connectivity: Categorical Indicators"
    )

    print("\n" + "=" * 60)
    print("COMPLETE")
    print("=" * 60)


if __name__ == "__main__":
    main()
