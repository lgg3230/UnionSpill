#!/home/lgg3230/.conda/envs/venv_python312/bin/python
"""
PROJECT: UNION SPILLOVERS
AUTHOR: LUIS GOMES
PROGRAM: COEFFICIENT PLOTS - PRETREATMENT BILATERAL CONNECTIVITY
PURPOSE: Visualize temporal persistence of bilateral connectivity within pretreatment
INPUT: bilateral_pretreatment_coefficients.csv (from 07d_bilateral_pretreatment.do)
OUTPUT: 2 coefficient plots (univariate/multivariate with stacked panels) + LaTeX figure

Note: R-squared is NOT displayed (per specification) to focus on coefficient magnitudes.
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

COEF_FILE = RAIS_AUX / "bilateral_pretreatment_coefficients.csv"

# ==============================================================================
# VARIABLE LABELS
# ==============================================================================

VAR_LABELS = {
    "z_geo_proximity": "Spatial",
    "z_size_proximity": "Size",
    "z_wage_proximity": "Wage",
    "z_female_proximity": "% Female",
    "z_nonwhite_proximity": "% Non-white",
    "z_educ_proximity": "% Higher ed.",
    "z_hs_proximity": "% High school",
    "z_nhs_proximity": "% Less than HS",
    "z_clauses_proximity": "# CBA clauses",
    "z_bilateral_conn_early_pre": "2007-2009 Connectivity",
    "same_muni": "Municipality",
    "same_microregion": "Microregion",
    "same_union": "Union",
    "same_industry": "Industry",
    "same_industry_micro": "Industry × microregion",
}

# Order for plotting (same order for both univariate and multivariate)
PROXIMITY_ORDER = [
    "z_bilateral_conn_early_pre",
    "z_geo_proximity",
    "z_clauses_proximity",
    "z_hs_proximity",
    "z_educ_proximity",
    "z_wage_proximity",
    "z_nonwhite_proximity",
    "z_female_proximity",
    "z_size_proximity",
]

DUMMY_ORDER = [
    "same_industry_micro",
    "same_microregion",
    "same_union",
    "same_industry",
]


def create_coefplot(df, var_list, output_path):
    """
    Create a coefficient plot with univariate (hollow blue) and multivariate (filled red)
    coefficients on the same horizontal line for each variable.

    Variables are ordered by univariate coefficient size (smallest at top, largest at bottom).
    """
    from matplotlib.lines import Line2D

    # Filter to relevant variables
    df_filtered = df[df["variable"].isin(var_list)].copy()

    if df_filtered.empty:
        print(f"  WARNING: No data found for {output_path}")
        return

    # =========================================================================
    # ORDER VARIABLES BY UNIVARIATE COEFFICIENT (smallest to largest, top to bottom)
    # =========================================================================
    univ_coefs = df_filtered[df_filtered["reg_type"] == "univariate"].set_index("variable")["coef"]
    # Sort ascending (smallest first = top of plot)
    ordered_vars = univ_coefs.reindex(var_list).dropna().sort_values(ascending=True).index.tolist()
    # Reverse because matplotlib plots bottom-up
    ordered_vars_reversed = list(reversed(ordered_vars))

    # =========================================================================
    # CREATE FIGURE
    # =========================================================================
    fig, ax = plt.subplots(figsize=(8, len(ordered_vars) * 0.6 + 1.0))

    # Y positions for variables (0 at bottom, n-1 at top)
    y_positions = {var: i for i, var in enumerate(ordered_vars_reversed)}

    # Plot settings
    colors = {"univariate": "#2166AC", "multivariate": "#B2182B"}  # Blue, Red

    # =========================================================================
    # ADD HORIZONTAL FADED LINES FOR VISUAL GUIDANCE
    # =========================================================================
    for i in range(len(ordered_vars)):
        ax.axhline(y=i, color="gray", linestyle="-", linewidth=0.5, alpha=0.2, zorder=0)

    # =========================================================================
    # PLOT EACH COEFFICIENT - ALIGNED HORIZONTALLY (no vertical offset)
    # =========================================================================
    for _, row in df_filtered.iterrows():
        var = row["variable"]
        if var not in y_positions:
            continue

        reg_type = row["reg_type"]
        y = y_positions[var]  # No offset - both on same line

        coef = row["coef"]
        ci_lower = row["ci_lower"]
        ci_upper = row["ci_upper"]

        # Plot confidence interval
        ax.plot([ci_lower, ci_upper], [y, y],
                color=colors[reg_type], linewidth=1.5, alpha=0.8, zorder=1)

        # Plot point estimate
        if reg_type == "univariate":
            # Hollow marker for univariate
            ax.plot(coef, y,
                    marker="o",
                    markersize=9,
                    markerfacecolor="white",
                    markeredgecolor=colors[reg_type],
                    markeredgewidth=2,
                    zorder=2)
            # Label above the marker
            ax.text(coef, y + 0.25, f"{coef:.3f}",
                    ha="center", va="bottom",
                    fontsize=8, color=colors[reg_type],
                    zorder=4)
        else:
            # Filled marker for multivariate
            ax.plot(coef, y,
                    marker="o",
                    markersize=9,
                    markerfacecolor=colors[reg_type],
                    markeredgecolor=colors[reg_type],
                    markeredgewidth=1.5,
                    zorder=3)
            # Label below the marker
            ax.text(coef, y - 0.25, f"{coef:.3f}",
                    ha="center", va="top",
                    fontsize=8, color=colors[reg_type],
                    zorder=4)

    # Add vertical line at zero
    ax.axvline(x=0, color="gray", linestyle="-", linewidth=0.8, alpha=0.5, zorder=0)

    # =========================================================================
    # SET Y-AXIS LABELS - BOLD
    # =========================================================================
    ax.set_yticks(range(len(ordered_vars)))
    ax.set_yticklabels(
        [VAR_LABELS.get(var, var) for var in ordered_vars_reversed],
        fontweight="bold"
    )

    # =========================================================================
    # LABELS AND FORMATTING
    # =========================================================================
    ax.set_xlabel("Coefficient", fontsize=11, fontweight="bold")

    # =========================================================================
    # CREATE LEGEND - UNDERNEATH THE GRAPH
    # =========================================================================
    legend_elements = [
        Line2D([0], [0], marker="o", color="white", markerfacecolor=colors["multivariate"],
               markeredgecolor=colors["multivariate"], markersize=9,
               markeredgewidth=1.5, linestyle="None", label="Multivariate"),
        Line2D([0], [0], marker="o", color="white", markerfacecolor="white",
               markeredgecolor=colors["univariate"], markersize=9,
               markeredgewidth=2, linestyle="None", label="Univariate"),
    ]
    ax.legend(
        handles=legend_elements,
        loc="upper center",
        bbox_to_anchor=(0.5, -0.18),
        ncol=2,
        frameon=False,
        fontsize=10
    )

    # Clean up
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.set_ylim(-0.5, len(ordered_vars) - 0.5)

    # Adjust x-axis to have some padding
    x_min, x_max = ax.get_xlim()
    x_range = x_max - x_min
    ax.set_xlim(x_min - 0.05 * x_range, x_max + 0.05 * x_range)

    plt.tight_layout()

    # Save
    fig.savefig(output_path, dpi=300, bbox_inches="tight", facecolor="white")
    plt.close(fig)

    print(f"  Saved: {output_path}")


def create_latex_figures(output_path, prox_path, dummy_path):
    """
    Create a LaTeX file with a single figure containing Panel A (proximity) and Panel B (dummies).
    """
    latex_content = r"""\begin{figure}[htbp]
\centering
\caption{Predictors of Late-Pretreatment Bilateral Connectivity}
\label{fig:bilateral_coefplot_pretreat}

\begin{threeparttable}

\begin{subfigure}{\textwidth}
    \centering
    \caption{Panel A: Proximity Measures}
    \label{fig:bilateral_coefplot_pretreat_proximity}
    \includegraphics[width=0.85\textwidth]{""" + prox_path.name + r"""}
\end{subfigure}

\vspace{1em}

\begin{subfigure}{\textwidth}
    \centering
    \caption{Panel B: Categorical Indicators}
    \label{fig:bilateral_coefplot_pretreat_dummies}
    \includegraphics[width=0.85\textwidth]{""" + dummy_path.name + r"""}
\end{subfigure}

\begin{tablenotes}
\footnotesize
\item \textit{Notes:} This figure shows coefficients from regressions of late-pretreatment bilateral connectivity (2009--2011, based on year pairs 2009--10 and 2010--11) on establishment pair characteristics. Hollow blue markers show univariate regressions (each predictor separately); filled red markers show multivariate regressions (all predictors simultaneously, including early-pretreatment connectivity 2007--2009). All regressions control for establishment $i$ fixed effects. Bilateral connectivity is measured as the person-weighted average flow of workers between establishment pairs. Proximity measures are defined as the negative absolute difference between establishment characteristics (standardized), so higher values indicate greater similarity. Spatial proximity is measured as the negative log of distance between municipality centroids. CBA clauses proximity is based on the number of clauses in collective bargaining agreements. Same-category dummies equal one if both establishments share the indicated category. Establishment characteristics are based on 2009--2011 averages. Horizontal lines represent 95\% confidence intervals based on robust standard errors. All regressions include the universe of establishment pairs, including those with zero worker flows.
\end{tablenotes}

\end{threeparttable}
\end{figure}
"""

    with open(output_path, "w") as f:
        f.write(latex_content)

    print(f"  Saved: {output_path}")


def main():
    """Main function."""

    print("=" * 70)
    print("BILATERAL CONNECTIVITY COEFFICIENT PLOTS (PRETREATMENT)")
    print("=" * 70)

    GRAPHS.mkdir(parents=True, exist_ok=True)

    if not COEF_FILE.exists():
        print(f"ERROR: Coefficient file not found: {COEF_FILE}")
        print("Please run 07d_bilateral_pretreatment.do first.")
        return

    print(f"\nLoading coefficients from: {COEF_FILE}")
    df = pd.read_csv(COEF_FILE)

    print(f"Loaded {len(df)} coefficient rows")
    print(f"Specifications: {df['spec'].unique()}")
    print(f"Regression types: {df['reg_type'].unique()}")
    print(f"Variables: {df['variable'].unique().tolist()}")

    # =========================================================================
    # Figure 1: Proximity Measures (univariate + multivariate on same plot)
    # =========================================================================
    print("\n--- Creating proximity measures plot ---")

    output_prox = GRAPHS / "coefplot_bilateral_pretreat_proximity.pdf"
    create_coefplot(df, PROXIMITY_ORDER, output_prox)

    # =========================================================================
    # Figure 2: Dummy Variables (univariate + multivariate on same plot)
    # =========================================================================
    print("\n--- Creating dummy variables plot ---")

    output_dummy = GRAPHS / "coefplot_bilateral_pretreat_dummies.pdf"
    create_coefplot(df, DUMMY_ORDER, output_dummy)

    # =========================================================================
    # LaTeX figure file
    # =========================================================================
    print("\n--- Creating LaTeX figure file ---")

    latex_output = GRAPHS / "figure_bilateral_coefplot_pretreat.tex"
    create_latex_figures(latex_output, output_prox, output_dummy)

    # =========================================================================
    # Summary
    # =========================================================================
    print("\n" + "=" * 70)
    print("COMPLETE")
    print("=" * 70)
    print("\nOutput files:")
    print(f"  - {output_prox}")
    print(f"  - {output_dummy}")
    print(f"  - {latex_output}")


if __name__ == "__main__":
    main()
