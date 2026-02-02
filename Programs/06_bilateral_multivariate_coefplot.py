"""
PROJECT: UNION SPILLOVERS
AUTHOR: LUIS GOMES
PROGRAM: COEFFICIENT PLOTS - PRE-TREATMENT BILATERAL CONNECTIVITY (MULTIVARIATE)
INPUT: bilateral_multivariate_coefficients_pre.csv (from 06_bilateral_multivariate.do)
OUTPUT: 2 coefficient plots (continuous/dummies) + LaTeX figure file
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

COEF_FILE = RAIS_AUX / "bilateral_multivariate_coefficients_pre.csv"

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

# Order for plotting (bottom to top)
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


def create_coefplot(df, var_order, output_path, color="#1f4e79", marker="o"):
    """
    Create a horizontal coefficient plot for multivariate regression.
    Displays R² as a footnote.

    Parameters:
    -----------
    df : DataFrame with columns: variable, coef, se, ci_lower, ci_upper, r2
    var_order : list of variable names in order (bottom to top)
    output_path : Path to save the figure
    color : Marker and error bar color
    marker : Marker style
    """
    # Filter and order
    df_plot = df[df["variable"].isin(var_order)].copy()
    df_plot = df_plot.sort_values("coef", ascending=False).reset_index(drop=True)

    # Create figure
    n_vars = len(df_plot)
    fig_height = max(4, 0.6 * n_vars + 1)
    fig, ax = plt.subplots(figsize=(8, fig_height))

    # Y positions
    y_pos = np.arange(n_vars)

    # Add horizontal lines
    for y in y_pos:
        ax.axhline(y=y, color="gray", linestyle="--", linewidth=0.5, alpha=0.3, zorder=0)

    # Plot coefficients with error bars
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

    # Add coefficient labels above points
    for i, row in df_plot.iterrows():
        idx = df_plot.index.get_loc(i)
        y_offset = 0.25
        ax.annotate(
            f"{row['coef']:.3f}",
            xy=(row["coef"], y_pos[idx]),
            xytext=(row["coef"], y_pos[idx] + y_offset),
            fontsize=10,
            color=color,
            ha="center",
            va="bottom",
            zorder=3,
        )

    # Add vertical line at zero
    ax.axvline(x=0, color="gray", linestyle="-", linewidth=0.8, alpha=0.7, zorder=1)

    # Set y-axis labels
    labels = [VAR_LABELS.get(v, v) for v in df_plot["variable"]]
    ax.set_yticks(y_pos)
    ax.set_yticklabels(labels, fontsize=11)

    # Labels
    ax.set_xlabel("Standardized Coefficient", fontsize=12)

    # Style
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


def create_latex_figure(output_path, continuous_path, dummy_path):
    """
    Create a LaTeX file with figure environment for both plots.
    """
    latex_content = r"""\begin{figure}[htbp]
\centering
\caption{Predictors of Pre-Treatment Bilateral Connectivity: Multivariate Regression}

\begin{threeparttable}
\label{fig:bilateral_coefplot_pre_multivariate}

\begin{subfigure}{0.49\textwidth}
    \includegraphics[width=\textwidth]{""" + continuous_path.name + r"""}
    \caption{Continuous Proximity Measures}
    \label{fig:bilateral_continuous_pre}
\end{subfigure}
\begin{subfigure}{0.49\textwidth}
    \includegraphics[width=\textwidth]{""" + dummy_path.name + r"""}
    \caption{Same-Category Dummies}
    \label{fig:bilateral_dummies_pre}
\end{subfigure}

\begin{tablenotes}
\footnotesize
\item \textit{Notes:} Coefficients from a single multivariate regression of pre-treatment bilateral connectivity (2007--2011) on all predictors simultaneously, controlling for establishment $i$ fixed effects. Bilateral connectivity is measured as the person-weighted average flow of workers between establishment pairs across four consecutive year-pairs. Proximity measures are defined as the negative absolute difference between establishment characteristics (standardized), so higher values indicate greater similarity. Geographic proximity is measured as the negative log of distance between municipality centroids. CBA clauses proximity is based on the number of clauses in collective bargaining agreements. Same-category dummies equal one if both establishments share the indicated category. Establishment characteristics are based on 2009 pre-treatment values. Horizontal lines represent 95\% confidence intervals based on robust standard errors. All regressions include the universe of establishment pairs, including those with zero worker flows.
\end{tablenotes}

\end{threeparttable}
\end{figure}
"""

    with open(output_path, "w") as f:
        f.write(latex_content)

    print(f"Saved: {output_path}")


def main():
    """Main function."""

    print("=" * 60)
    print("BILATERAL CONNECTIVITY COEFFICIENT PLOTS (PRE-TREATMENT)")
    print("=" * 60)

    GRAPHS.mkdir(parents=True, exist_ok=True)

    if not COEF_FILE.exists():
        print(f"ERROR: Coefficient file not found: {COEF_FILE}")
        print("Please run 06_bilateral_multivariate.do first.")
        return

    print(f"\nLoading coefficients from: {COEF_FILE}")
    df = pd.read_csv(COEF_FILE)

    print(f"Loaded {len(df)} coefficient rows")
    print(f"Specifications: {df['spec'].unique()}")
    print(f"Variable types: {df['var_type'].unique()}")

    # =========================================================================
    # Figure 1: Continuous proximity measures
    # =========================================================================
    print("\n--- Creating continuous proximity plot ---")
    df_continuous = df[df["var_type"] == "continuous"].copy()

    output_continuous = GRAPHS / "coefplot_bilateral_continuous_pre_multi.pdf"
    create_coefplot(
        df_continuous,
        CONTINUOUS_ORDER,
        output_continuous,
        color="#1f4e79",  # Navy
        marker="o",
    )

    # =========================================================================
    # Figure 2: Dummy variables
    # =========================================================================
    print("\n--- Creating dummies plot ---")
    df_dummy = df[df["var_type"] == "dummy"].copy()

    output_dummy = GRAPHS / "coefplot_bilateral_dummies_pre_multi.pdf"
    create_coefplot(
        df_dummy,
        DUMMY_ORDER,
        output_dummy,
        color="#8b0000",  # Maroon
        marker="s",
    )

    # =========================================================================
    # LaTeX figure file
    # =========================================================================
    print("\n--- Creating LaTeX figure file ---")
    latex_output = GRAPHS / "figure_bilateral_coefplot_pre_multi.tex"
    create_latex_figure(latex_output, output_continuous, output_dummy)

    print("\n" + "=" * 60)
    print("COMPLETE")
    print("=" * 60)
    print("\nOutput files:")
    print(f"  - {output_continuous}")
    print(f"  - {output_dummy}")
    print(f"  - {latex_output}")


if __name__ == "__main__":
    main()
