"""
PROJECT: UNION SPILLOVERS
AUTHOR: LUIS GOMES
PROGRAM: COEFFICIENT PLOTS - BILATERAL CONNECTIVITY
INPUT: bilateral_regression_coefficients.csv (multivariate from Stata)
       bilateral_individual_coefficients.csv (individual regressions from Stata)
OUTPUT: 2 stacked coefficient plots per specification (proximity + dummies in each)
"""

import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
from pathlib import Path

# ==============================================================================
# PATHS
# ==============================================================================

PROJECT_ROOT = Path("/kellogg/proj/lgg3230/UnionSpill")
RAIS_AUX = PROJECT_ROOT / "Data" / "RAIS_aux"
GRAPHS = PROJECT_ROOT / "Graphs"

# Input files
COEF_FILE_MULTI = RAIS_AUX / "bilateral_regression_coefficients.csv"
COEF_FILE_INDIV = RAIS_AUX / "bilateral_individual_coefficients.csv"

# ==============================================================================
# VARIABLE LABELS
# ==============================================================================

VAR_LABELS = {
    "z_geo_proximity": "Spatial",
    "z_size_proximity": "Firm Size",
    "z_wage_proximity": "Wage",
    "z_female_proximity": "% Female",
    "z_nonwhite_proximity": "% Non-White",
    "z_educ_proximity": "% Higher Ed.",
    "z_hs_proximity": "% High School",
    "z_clauses_proximity": "CBA Clauses",
    "same_muni": "Municipality",
    "same_microregion": "Microregion",
    "same_union": "Union",
    "same_industry": "Industry",
    "same_industry_micro": "Industry × Microregion",
}

# Variables to EXCLUDE
EXCLUDE_VARS = ["z_nhs_proximity", "same_muni"]

# Variables to include
PROXIMITY_VARS = [
    "z_size_proximity",
    "z_hs_proximity",
    "z_female_proximity",
    "z_nonwhite_proximity",
    "z_wage_proximity",
    "z_educ_proximity",
    "z_clauses_proximity",
    "z_l_geo_proximity",
]

DUMMY_VARS_WITH_INTX = [
    "same_industry",
    "same_union",
    "same_microregion",
    "same_industry_micro",
]

DUMMY_VARS_WITHOUT_INTX = [
    "same_industry",
    "same_union",
    "same_microregion",
    "same_muni",
]


def create_stacked_coefplot(
    df_prox, df_dummy, prox_var_order, dummy_var_order, output_path,
    prox_color="#1f4e79", dummy_color="#8b0000"
):
    """
    Create a stacked coefficient plot with proximity measures on top and dummies on bottom.
    Each subplot has an independent x-axis scale.

    Parameters:
    -----------
    df_prox : DataFrame with proximity coefficients
    df_dummy : DataFrame with dummy coefficients
    prox_var_order : list of proximity variable names in display order (top to bottom)
    dummy_var_order : list of dummy variable names in display order (top to bottom)
    output_path : Path to save the figure
    prox_color : Color for proximity subplot
    dummy_color : Color for dummy subplot
    """
    # Filter and order by the provided variable order (top to bottom)
    df_prox_plot = df_prox[df_prox["variable"].isin(prox_var_order)].copy()
    prox_order_map = {v: i for i, v in enumerate(reversed(prox_var_order))}
    df_prox_plot["sort_order"] = df_prox_plot["variable"].map(prox_order_map)
    df_prox_plot = df_prox_plot.sort_values("sort_order").reset_index(drop=True)

    df_dummy_plot = df_dummy[df_dummy["variable"].isin(dummy_var_order)].copy()
    dummy_order_map = {v: i for i, v in enumerate(reversed(dummy_var_order))}
    df_dummy_plot["sort_order"] = df_dummy_plot["variable"].map(dummy_order_map)
    df_dummy_plot = df_dummy_plot.sort_values("sort_order").reset_index(drop=True)

    n_prox = len(df_prox_plot)
    n_dummy = len(df_dummy_plot)

    # Create figure with two subplots (independent x-axes)
    fig, (ax_prox, ax_dummy) = plt.subplots(
        2, 1,
        figsize=(8, 10),
        gridspec_kw={"height_ratios": [n_prox, n_dummy], "hspace": 0.35},
    )

    # =========================================================================
    # TOP SUBPLOT: Proximity Measures
    # =========================================================================
    ax_prox.set_title("Proximity Measures", fontweight="bold", loc="center", fontsize=14, pad=10)

    y_pos_prox = np.arange(n_prox)

    # Horizontal grid lines
    for y in y_pos_prox:
        ax_prox.axhline(y=y, color="gray", linestyle="--", linewidth=0.5, alpha=0.3, zorder=0)

    # Plot coefficients with error bars
    ax_prox.errorbar(
        df_prox_plot["coef"],
        y_pos_prox,
        xerr=[
            df_prox_plot["coef"] - df_prox_plot["ci_lower"],
            df_prox_plot["ci_upper"] - df_prox_plot["coef"],
        ],
        fmt="o",
        color=prox_color,
        ecolor=prox_color,
        capsize=3,
        markersize=8,
        elinewidth=1.5,
        capthick=1.5,
        zorder=2,
    )

    # Add coefficient labels above points (bold)
    for i, row in df_prox_plot.iterrows():
        idx = df_prox_plot.index.get_loc(i)
        ax_prox.annotate(
            f"{row['coef']:.3f}",
            xy=(row["coef"], y_pos_prox[idx]),
            xytext=(row["coef"], y_pos_prox[idx] + 0.25),
            fontsize=11,
            fontweight="bold",
            color=prox_color,
            ha="center",
            va="bottom",
            zorder=3,
        )

    # Zero reference line
    ax_prox.axvline(x=0, color="gray", linestyle="-", linewidth=0.8, alpha=0.7, zorder=1)

    # Y-axis labels (bold)
    prox_labels = [VAR_LABELS.get(v, v) for v in df_prox_plot["variable"]]
    ax_prox.set_yticks(y_pos_prox)
    ax_prox.set_yticklabels(prox_labels, fontsize=12, fontweight="bold")

    # X-axis label (bold)
    ax_prox.set_xlabel("Coefficient", fontsize=12, fontweight="bold")

    # Style
    ax_prox.set_facecolor("white")
    ax_prox.spines["top"].set_visible(False)
    ax_prox.spines["right"].set_visible(False)
    ax_prox.set_ylim(-0.7, n_prox - 0.3)

    # =========================================================================
    # BOTTOM SUBPLOT: Same-Category Dummies
    # =========================================================================
    ax_dummy.set_title("Same-Category Dummies", fontweight="bold", loc="center", fontsize=14, pad=10)

    y_pos_dummy = np.arange(n_dummy)

    # Horizontal grid lines
    for y in y_pos_dummy:
        ax_dummy.axhline(y=y, color="gray", linestyle="--", linewidth=0.5, alpha=0.3, zorder=0)

    # Plot coefficients with error bars
    ax_dummy.errorbar(
        df_dummy_plot["coef"],
        y_pos_dummy,
        xerr=[
            df_dummy_plot["coef"] - df_dummy_plot["ci_lower"],
            df_dummy_plot["ci_upper"] - df_dummy_plot["coef"],
        ],
        fmt="s",
        color=dummy_color,
        ecolor=dummy_color,
        capsize=3,
        markersize=8,
        elinewidth=1.5,
        capthick=1.5,
        zorder=2,
    )

    # Add coefficient labels above points (bold)
    for i, row in df_dummy_plot.iterrows():
        idx = df_dummy_plot.index.get_loc(i)
        ax_dummy.annotate(
            f"{row['coef']:.3f}",
            xy=(row["coef"], y_pos_dummy[idx]),
            xytext=(row["coef"], y_pos_dummy[idx] + 0.25),
            fontsize=11,
            fontweight="bold",
            color=dummy_color,
            ha="center",
            va="bottom",
            zorder=3,
        )

    # Zero reference line
    ax_dummy.axvline(x=0, color="gray", linestyle="-", linewidth=0.8, alpha=0.7, zorder=1)

    # Y-axis labels (bold)
    dummy_labels = [VAR_LABELS.get(v, v) for v in df_dummy_plot["variable"]]
    ax_dummy.set_yticks(y_pos_dummy)
    ax_dummy.set_yticklabels(dummy_labels, fontsize=12, fontweight="bold")

    # X-axis label (bold)
    ax_dummy.set_xlabel("Coefficient", fontsize=12, fontweight="bold")

    # Style
    ax_dummy.set_facecolor("white")
    ax_dummy.spines["top"].set_visible(False)
    ax_dummy.spines["right"].set_visible(False)
    ax_dummy.set_ylim(-0.7, n_dummy - 0.3)

    # =========================================================================
    # Save figure
    # =========================================================================
    fig.patch.set_facecolor("white")
    plt.tight_layout()
    plt.savefig(output_path, format="pdf", bbox_inches="tight", dpi=300)
    plt.close()

    print(f"Saved: {output_path}")


def create_latex_figure(output_path, uni_path, multi_path):
    """
    Create a LaTeX file with a single figure containing Panel A (univariate) and Panel B (multivariate).
    """
    latex_content = r"""\begin{figure}[htbp]
\centering
\caption{Predictors of Post-Treatment Bilateral Connectivity}
\label{fig:bilateral_coefplot}

\begin{threeparttable}

\begin{subfigure}{\textwidth}
    \centering
    \caption{Panel A: Univariate Regressions}
    \label{fig:bilateral_coefplot_univariate}
    \includegraphics[width=0.85\textwidth]{""" + uni_path.name + r"""}
\end{subfigure}

\vspace{1em}

\begin{subfigure}{\textwidth}
    \centering
    \caption{Panel B: Multivariate Regression}
    \label{fig:bilateral_coefplot_multivariate}
    \includegraphics[width=0.85\textwidth]{""" + multi_path.name + r"""}
\end{subfigure}

\begin{tablenotes}
\footnotesize
\item \textit{Notes:} Panel A shows coefficients from separate univariate regressions of post-treatment bilateral connectivity (2012--2016) on each indicated predictor. Panel B shows coefficients from a single multivariate regression including all predictors simultaneously. All regressions control for establishment $i$ fixed effects. Bilateral connectivity is measured as the person-weighted average flow of workers between establishment pairs. Proximity measures are defined as the negative absolute difference between establishment characteristics (standardized), so higher values indicate greater similarity. Spatial proximity is measured as the negative log of distance between municipality centroids. CBA clauses proximity is based on the number of clauses in collective bargaining agreements. Same-category dummies equal one if both establishments share the indicated category. Horizontal lines represent 95\% confidence intervals based on robust standard errors. All regressions include the universe of establishment pairs, including those with zero worker flows.
\end{tablenotes}

\end{threeparttable}
\end{figure}
"""

    with open(output_path, "w") as f:
        f.write(latex_content)

    print(f"Saved: {output_path}")


def main():
    """Main function to generate stacked coefficient plots."""

    print("=" * 70)
    print("BILATERAL CONNECTIVITY COEFFICIENT PLOTS")
    print("=" * 70)

    # Create output directory if needed
    GRAPHS.mkdir(parents=True, exist_ok=True)

    # =========================================================================
    # INDIVIDUAL REGRESSION PLOTS (to determine variable ordering)
    # =========================================================================

    if not COEF_FILE_INDIV.exists():
        print(f"\nERROR: Individual coefficient file not found: {COEF_FILE_INDIV}")
        print("Please run 06_bilateral_regression.do first to generate the coefficients.")
        return

    print(f"\nLoading individual regression coefficients from: {COEF_FILE_INDIV}")
    df_indiv = pd.read_csv(COEF_FILE_INDIV)

    print(f"Loaded {len(df_indiv)} coefficient rows")
    print(f"Specifications: {df_indiv['spec'].unique()}")
    print(f"Variable types: {df_indiv['var_type'].unique()}")

    # Get univariate data for ordering (exclude specified variables)
    df_uni_prox = df_indiv[
        (df_indiv["spec"] == "individual")
        & (df_indiv["var_type"] == "proximity")
        & (~df_indiv["variable"].isin(EXCLUDE_VARS))
    ].copy()
    df_uni_dummy = df_indiv[
        (df_indiv["spec"] == "individual")
        & (df_indiv["var_type"] == "dummy")
        & (~df_indiv["variable"].isin(EXCLUDE_VARS))
    ].copy()

    # Determine order from univariate coefficients (smallest at top, largest at bottom)
    prox_var_order = df_uni_prox.sort_values("coef", ascending=True)["variable"].tolist()
    dummy_var_order = df_uni_dummy.sort_values("coef", ascending=True)["variable"].tolist()

    print(f"\nProximity order (from univariate, smallest to largest):")
    for v in prox_var_order:
        coef = df_uni_prox[df_uni_prox["variable"] == v]["coef"].values[0]
        print(f"  {v}: {coef:.4f}")

    print(f"\nDummy order (from univariate, smallest to largest):")
    for v in dummy_var_order:
        coef = df_uni_dummy[df_uni_dummy["variable"] == v]["coef"].values[0]
        print(f"  {v}: {coef:.4f}")

    # =========================================================================
    # Figure 1: Individual (Univariate) Regressions
    # =========================================================================
    print("\n--- Creating univariate stacked plot ---")

    output_indiv = GRAPHS / "coefplot_bilateral_univariate.pdf"
    create_stacked_coefplot(
        df_uni_prox,
        df_uni_dummy,
        prox_var_order,
        dummy_var_order,
        output_indiv,
        prox_color="#1f4e79",
        dummy_color="#8b0000",
    )

    # =========================================================================
    # MULTIVARIATE REGRESSION PLOTS
    # =========================================================================

    if COEF_FILE_MULTI.exists():
        print(f"\nLoading multivariate coefficients from: {COEF_FILE_MULTI}")
        df_multi = pd.read_csv(COEF_FILE_MULTI)

        print(f"Loaded {len(df_multi)} coefficient rows")
        print(f"Specifications: {df_multi['spec'].unique()}")

        # =====================================================================
        # Figure 2: Multivariate WITH interaction
        # =====================================================================
        print("\n--- Creating multivariate (with interaction) stacked plot ---")

        df_multi_prox_intx = df_multi[
            (df_multi["spec"] == "with_intx")
            & (df_multi["var_type"] == "proximity")
            & (~df_multi["variable"].isin(EXCLUDE_VARS))
        ].copy()
        df_multi_dummy_intx = df_multi[
            (df_multi["spec"] == "with_intx")
            & (df_multi["var_type"] == "dummy")
            & (~df_multi["variable"].isin(EXCLUDE_VARS))
        ].copy()

        # Filter dummy order to match what's in the data
        dummy_var_order_intx = [v for v in dummy_var_order if v in df_multi_dummy_intx["variable"].values]
        # Add any missing dummies that are in the data
        for v in df_multi_dummy_intx["variable"].values:
            if v not in dummy_var_order_intx:
                dummy_var_order_intx.append(v)

        output_multi_intx = GRAPHS / "coefplot_bilateral_multivariate.pdf"
        create_stacked_coefplot(
            df_multi_prox_intx,
            df_multi_dummy_intx,
            prox_var_order,  # Same order as univariate
            dummy_var_order_intx,
            output_multi_intx,
            prox_color="#2e8b57",
            dummy_color="#8b4513",
        )

        # =====================================================================
        # Figure 3: Multivariate WITHOUT interaction
        # =====================================================================
        print("\n--- Creating multivariate (without interaction) stacked plot ---")

        df_multi_prox_no_intx = df_multi[
            (df_multi["spec"] == "without_intx")
            & (df_multi["var_type"] == "proximity")
            & (~df_multi["variable"].isin(EXCLUDE_VARS))
        ].copy()
        df_multi_dummy_no_intx = df_multi[
            (df_multi["spec"] == "without_intx")
            & (df_multi["var_type"] == "dummy")
            & (~df_multi["variable"].isin(EXCLUDE_VARS))
        ].copy()

        # Filter dummy order to match what's in the data
        dummy_var_order_no_intx = [v for v in dummy_var_order if v in df_multi_dummy_no_intx["variable"].values]
        # Add any missing dummies that are in the data
        for v in df_multi_dummy_no_intx["variable"].values:
            if v not in dummy_var_order_no_intx:
                dummy_var_order_no_intx.append(v)

        output_multi_no_intx = GRAPHS / "coefplot_bilateral_multivariate_no_intx.pdf"
        create_stacked_coefplot(
            df_multi_prox_no_intx,
            df_multi_dummy_no_intx,
            prox_var_order,  # Same order as univariate
            dummy_var_order_no_intx,
            output_multi_no_intx,
            prox_color="#2e8b57",
            dummy_color="#8b4513",
        )

        # =====================================================================
        # LaTeX figure file
        # =====================================================================
        print("\n--- Creating LaTeX figure file ---")

        latex_output = GRAPHS / "figure_bilateral_coefplot.tex"
        create_latex_figure(latex_output, output_indiv, output_multi_intx)

    else:
        print(f"\nWARNING: Multivariate coefficient file not found: {COEF_FILE_MULTI}")

    # =========================================================================
    # SUMMARY
    # =========================================================================

    print("\n" + "=" * 70)
    print("COMPLETE")
    print("=" * 70)
    print("\nOutput files:")
    print(f"  - {GRAPHS / 'coefplot_bilateral_univariate.pdf'}")
    print(f"  - {GRAPHS / 'coefplot_bilateral_multivariate.pdf'}")
    print(f"  - {GRAPHS / 'coefplot_bilateral_multivariate_no_intx.pdf'}")
    print(f"  - {GRAPHS / 'figure_bilateral_coefplot.tex'}")


if __name__ == "__main__":
    main()
