"""
PROJECT: UNION SPILLOVERS
AUTHOR: LUIS GOMES
PROGRAM: COEFFICIENT PLOTS - PRE-TREATMENT BILATERAL CONNECTIVITY (RAW DV)
INPUT: bilateral_multivariate_coefficients_pre_raw.csv
OUTPUT: Coefficient plots with raw bilateral connectivity as dependent variable
NOTE: Coefficients show effect of 1 SD change in regressor on raw bilateral connectivity
"""

import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
from pathlib import Path

# ==============================================================================
# PATHS
# ==============================================================================

PROJECT_ROOT = Path("/gpfs/kellogg/proj/lgg3230/UnionSpill")
RAIS_AUX = PROJECT_ROOT / "Data" / "RAIS_aux"
GRAPHS = PROJECT_ROOT / "Graphs"

COEF_FILE = RAIS_AUX / "bilateral_multivariate_coefficients_pre_raw.csv"

# ==============================================================================
# VARIABLE LABELS
# ==============================================================================

VAR_LABELS = {
    "z_geo_proximity": "Geographic",
    "z_size_proximity": "Firm Size",
    "z_wage_proximity": "Wage",
    "z_female_proximity": "% Female",
    "z_nonwhite_proximity": "% Non-White",
    "z_educ_proximity": "% Higher Ed.",
    "z_hs_proximity": "% High School",
    "z_clauses_proximity": "CBA Clauses",
    "same_microregion": "Same Microregion",
    "same_union": "Same Union",
    "same_industry": "Same Industry",
    "same_industry_micro": "Same Industry x Microregion",
}

CONTINUOUS_ORDER = [
    "z_size_proximity",
    "z_hs_proximity",
    "z_female_proximity",
    "z_nonwhite_proximity",
    "z_wage_proximity",
    "z_educ_proximity",
    "z_clauses_proximity",
    "z_geo_proximity",
]

DUMMY_ORDER = [
    "same_industry",
    "same_union",
    "same_microregion",
    "same_industry_micro",
]


def create_coefplot(df, var_order, output_path, color="#1f4e79", marker="o", xlabel="Coefficient"):
    """Create a horizontal coefficient plot for multivariate regression. Displays R² as footnote."""
    df_plot = df[df["variable"].isin(var_order)].copy()
    df_plot = df_plot.sort_values("coef", ascending=False).reset_index(drop=True)

    n_vars = len(df_plot)
    fig_height = max(4, 0.6 * n_vars + 1)
    fig, ax = plt.subplots(figsize=(8, fig_height))

    y_pos = np.arange(n_vars)

    for y in y_pos:
        ax.axhline(y=y, color="gray", linestyle="--", linewidth=0.5, alpha=0.3, zorder=0)

    ax.errorbar(
        df_plot["coef"],
        y_pos,
        xerr=[
            df_plot["coef"] - df_plot["ci_lower"],
            df_plot["ci_upper"] - df_plot["coef"],
        ],
        fmt=marker,
        color=color,
        ecolor=color,
        capsize=3,
        markersize=7,
        elinewidth=1.5,
        capthick=1.5,
        zorder=2,
    )

    # Format coefficient labels based on magnitude
    for i, row in df_plot.iterrows():
        idx = df_plot.index.get_loc(i)
        y_offset = 0.25
        coef_val = row['coef']
        # Use scientific notation for very small coefficients
        if abs(coef_val) < 0.001:
            label = f"{coef_val:.2e}"
        else:
            label = f"{coef_val:.5f}"
        ax.annotate(
            label,
            xy=(row["coef"], y_pos[idx]),
            xytext=(row["coef"], y_pos[idx] + y_offset),
            fontsize=9,
            color=color,
            ha="center",
            va="bottom",
            zorder=3,
        )

    ax.axvline(x=0, color="gray", linestyle="-", linewidth=0.8, alpha=0.7, zorder=1)

    labels = [VAR_LABELS.get(v, v) for v in df_plot["variable"]]
    ax.set_yticks(y_pos)
    ax.set_yticklabels(labels, fontsize=11)

    ax.set_xlabel(xlabel, fontsize=12)

    ax.set_facecolor("white")
    fig.patch.set_facecolor("white")
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.set_ylim(-0.7, n_vars - 0.3)

    # Add R² as footnote (multivariate regression)
    if "r2" in df_plot.columns and len(df_plot) > 0:
        r2_value = df_plot["r2"].iloc[0]  # All rows have same R² for multivariate
        fig.text(0.5, -0.02, f"R² = {r2_value:.3f}", ha="center", fontsize=10, style="italic")

    plt.tight_layout()
    plt.savefig(output_path, format="pdf", bbox_inches="tight", dpi=300)
    plt.close()

    print(f"Saved: {output_path}")


def main():
    """Main function."""

    print("=" * 60)
    print("BILATERAL CONNECTIVITY COEFFICIENT PLOTS (RAW DV)")
    print("=" * 60)

    GRAPHS.mkdir(parents=True, exist_ok=True)

    if not COEF_FILE.exists():
        print(f"ERROR: Coefficient file not found: {COEF_FILE}")
        print("Please run 06_bilateral_multivariate.do first.")
        return

    print(f"\nLoading coefficients from: {COEF_FILE}")
    df = pd.read_csv(COEF_FILE)

    print(f"Loaded {len(df)} coefficient rows")
    print("\nCoefficients (raw DV - flows per worker):")
    print(df[["variable", "coef", "se"]].to_string(index=False))

    # Figure 1: Continuous proximity measures
    print("\n--- Creating continuous proximity plot (raw DV) ---")
    df_continuous = df[df["var_type"] == "continuous"].copy()

    output_continuous = GRAPHS / "coefplot_bilateral_continuous_pre_raw.pdf"
    create_coefplot(
        df_continuous,
        CONTINUOUS_ORDER,
        output_continuous,
        color="#1f4e79",
        marker="o",
        xlabel="Effect on Bilateral Connectivity (flows per worker)"
    )

    # Figure 2: Dummy variables
    print("\n--- Creating dummies plot (raw DV) ---")
    df_dummy = df[df["var_type"] == "dummy"].copy()

    output_dummy = GRAPHS / "coefplot_bilateral_dummies_pre_raw.pdf"
    create_coefplot(
        df_dummy,
        DUMMY_ORDER,
        output_dummy,
        color="#8b0000",
        marker="s",
        xlabel="Effect on Bilateral Connectivity (flows per worker)"
    )

    print("\n" + "=" * 60)
    print("COMPLETE")
    print("=" * 60)
    print("\nOutput files:")
    print(f"  - {output_continuous}")
    print(f"  - {output_dummy}")
    print("\nNote: Coefficients show the change in bilateral connectivity")
    print("(flows per worker) for a 1 SD increase in each proximity measure.")


if __name__ == "__main__":
    main()
