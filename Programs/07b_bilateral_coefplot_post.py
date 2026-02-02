"""
PROJECT: UNION SPILLOVERS
AUTHOR: LUIS GOMES
PROGRAM: COEFFICIENT PLOTS - POST-TREATMENT BILATERAL CONNECTIVITY
INPUT: bilateral_regression_coefficients_post.csv (from 07b_bilateral_regression_post.do)
OUTPUT: 4 coefficient plots (univariate/multivariate x proximity/dummies) + LaTeX figure file
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

COEF_FILE = RAIS_AUX / "bilateral_regression_coefficients_post.csv"

# ==============================================================================
# VARIABLE LABELS
# ==============================================================================

VAR_LABELS = {
    "z_geo_proximity": "Geographic",
    "z_size_proximity": "Firm Size",
    "z_wage_proximity": "Wage",
    "z_female_proximity": "% Female",
    "z_nonwhite_proximity": "% Non-White",
    "z_educ_proximity": "% Higher ed.",
    "z_hs_proximity": "% High school",
    "z_nhs_proximity": "% Less than HS",
    "z_clauses_proximity": "CBA Clauses",
    "z_bilateral_conn_pre": "Pre-treatment Bilateral Conn.",
    "same_muni": "Same Municipality",
    "same_microregion": "Same Microregion",
    "same_union": "Same Union",
    "same_industry": "Same Industry",
    "same_industry_micro": "Same Industry x Microregion",
}

# Order for plotting (bottom to top)
PROXIMITY_ORDER = [
    "z_bilateral_conn_pre",
     "z_geo_proximity",
    "z_clauses_proximity",
    "z_educ_proximity",
    "z_wage_proximity",
    "z_nonwhite_proximity",
     "z_female_proximity",
    "z_size_proximity",
]

# Proximity order without pre-treatment connectivity (for multivariate without pre control)
PROXIMITY_ORDER_NO_PRE = [
    "z_clauses_proximity",
    "z_nhs_proximity",
    "z_hs_proximity",
    "z_educ_proximity",
    "z_nonwhite_proximity",
    "z_female_proximity",
    "z_wage_proximity",
    "z_size_proximity",
    "z_geo_proximity",
]

DUMMY_ORDER = [
    "same_industry_micro",
    "same_microregion",
    "same_union",
    "same_industry",
]


def create_coefplot(df, var_order, output_path, title, color="#1f4e79", marker="o", is_univariate=False):
    """
    Create a horizontal coefficient plot.

    Parameters:
    -----------
    df : DataFrame with columns: variable, coef, se, ci_lower, ci_upper, r2
    var_order : list of variable names in order (bottom to top)
    output_path : Path to save the figure
    title : Plot title
    color : Marker and error bar color
    marker : Marker style
    is_univariate : bool
        If True, display R² next to each label (univariate regressions)
        If False, display R² as footnote (multivariate regression)
    """
    # Filter and order
    df_plot = df[df["variable"].isin(var_order)].copy()
    df_plot = df_plot.sort_values("coef", ascending=False).reset_index(drop=True)

    # Create figure
    n_vars = len(df_plot)
    fig_height = max(4, 0.5 * n_vars + 1.5)
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
        xerr=[df_plot["coef"] - df_plot["ci_lower"],
              df_plot["ci_upper"] - df_plot["coef"]],
        fmt=marker,
        color=color,
        ecolor=color,
        capsize=3,
        markersize=7,
        elinewidth=1.5,
        capthick=1.5,
        zorder=2,
    )

    # Add coefficient labels for proximity (above points)
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

    # Set y-axis labels with R² for univariate regressions
    if is_univariate and "r2" in df_plot.columns:
        labels = [f"{VAR_LABELS.get(v, v)} (R²={r2:.3f})"
                  for v, r2 in zip(df_plot["variable"], df_plot["r2"])]
    else:
        labels = [VAR_LABELS.get(v, v) for v in df_plot["variable"]]
    ax.set_yticks(y_pos)
    ax.set_yticklabels(labels, fontsize=11)

    # Labels and title
    ax.set_xlabel("Coefficient", fontsize=12)
    ax.set_title(title, fontsize=13)

    # Style
    ax.set_facecolor("white")
    fig.patch.set_facecolor("white")
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.set_ylim(-0.7, n_vars - 0.3)

    # Add R² as footnote for multivariate regressions
    if not is_univariate and "r2" in df_plot.columns and len(df_plot) > 0:
        r2_value = df_plot["r2"].iloc[0]  # All rows have same R² for multivariate
        fig.text(0.5, -0.02, f"R² = {r2_value:.3f}", ha="center", fontsize=10, style="italic")

    plt.tight_layout()
    plt.savefig(output_path, format="pdf", bbox_inches="tight", dpi=300)
    plt.close()

    print(f"Saved: {output_path}")


def create_latex_figures(output_path, univariate_prox, univariate_dummy,
                         multivariate_prox, multivariate_dummy):
    """
    Create a LaTeX file with two separate figure environments:
    one for univariate and one for multivariate analysis.
    """
    latex_content = r"""% Figure 1: Univariate Regressions
\begin{figure}[htbp]
\centering
\caption{Predictors of Post-Treatment Bilateral Connectivity: Univariate Regressions}

\begin{threeparttable}
\label{fig:bilateral_coefplot_univariate}

\begin{subfigure}{0.49\textwidth}
    \includegraphics[width=\textwidth]{""" + str(univariate_prox.name) + r"""}
    \caption{Proximity Measures}
    \label{fig:bilateral_proximity_univariate}
\end{subfigure}
\begin{subfigure}{0.49\textwidth}
    \includegraphics[width=\textwidth]{""" + str(univariate_dummy.name) + r"""}
    \caption{Same-Category Dummies}
    \label{fig:bilateral_dummies_univariate}
\end{subfigure}

\begin{tablenotes}
\footnotesize
\item \textit{Notes:} Each coefficient is from a separate regression of post-treatment bilateral connectivity (2011--2015) on the indicated predictor, controlling for establishment $i$ fixed effects. Bilateral connectivity is measured as the person-weighted average flow of workers between establishment pairs across four consecutive year-pairs. Proximity measures are defined as the negative absolute difference between establishment characteristics (standardized), so higher values indicate greater similarity. Geographic proximity is measured as the negative log of distance between municipality centroids. CBA clauses proximity is based on the number of clauses in collective bargaining agreements. Same-category dummies equal one if both establishments share the indicated category. Establishment characteristics are based on 2009--2011 pre-treatment averages. Horizontal lines represent 95\% confidence intervals based on robust standard errors. All regressions include the universe of establishment pairs, including those with zero worker flows.
\end{tablenotes}

\end{threeparttable}
\end{figure}


% Figure 2: Multivariate Regression
\begin{figure}[htbp]
\centering
\caption{Predictors of Post-Treatment Bilateral Connectivity: Multivariate Regression}

\begin{threeparttable}
\label{fig:bilateral_coefplot_multivariate}

\begin{subfigure}{0.49\textwidth}
    \includegraphics[width=\textwidth]{""" + str(multivariate_prox.name) + r"""}
    \caption{Proximity Measures}
    \label{fig:bilateral_proximity_multivariate}
\end{subfigure}
\begin{subfigure}{0.49\textwidth}
    \includegraphics[width=\textwidth]{""" + str(multivariate_dummy.name) + r"""}
    \caption{Same-Category Dummies}
    \label{fig:bilateral_dummies_multivariate}
\end{subfigure}

\begin{tablenotes}
\footnotesize
\item \textit{Notes:} Coefficients from a single multivariate regression of post-treatment bilateral connectivity (2011--2015) on all predictors simultaneously, controlling for establishment $i$ fixed effects. Bilateral connectivity is measured as the person-weighted average flow of workers between establishment pairs across four consecutive year-pairs. Proximity measures are defined as the negative absolute difference between establishment characteristics (standardized), so higher values indicate greater similarity. Geographic proximity is measured as the negative log of distance between municipality centroids. Same-category dummies equal one if both establishments share the indicated category. Establishment characteristics are based on 2009--2011 pre-treatment averages. Horizontal lines represent 95\% confidence intervals based on robust standard errors. All regressions include the universe of establishment pairs, including those with zero worker flows.
\end{tablenotes}

\end{threeparttable}
\end{figure}
"""

    with open(output_path, 'w') as f:
        f.write(latex_content)

    print(f"Saved: {output_path}")


def main():
    """Main function."""

    print("=" * 60)
    print("BILATERAL CONNECTIVITY COEFFICIENT PLOTS (POST-TREATMENT)")
    print("=" * 60)

    GRAPHS.mkdir(parents=True, exist_ok=True)

    if not COEF_FILE.exists():
        print(f"ERROR: Coefficient file not found: {COEF_FILE}")
        print("Please run 07b_bilateral_regression_post.do first.")
        return

    print(f"\nLoading coefficients from: {COEF_FILE}")
    df = pd.read_csv(COEF_FILE)

    print(f"Loaded {len(df)} coefficient rows")
    print(f"Specifications: {df['spec'].unique()}")
    print(f"Regression types: {df['reg_type'].unique()}")

    # =========================================================================
    # Figure 1: Univariate - Proximity measures (R² next to each label)
    # =========================================================================
    print("\n--- Creating univariate proximity plot ---")
    df_uni_prox = df[(df["reg_type"] == "univariate") &
                     (df["spec"] == "post") &
                     (df["variable"].isin(PROXIMITY_ORDER))].copy()

    output_uni_prox = GRAPHS / "coefplot_bilateral_proximity_univariate.pdf"
    create_coefplot(
        df_uni_prox,
        PROXIMITY_ORDER,
        output_uni_prox,
        title="",
        color="#1f4e79",
        marker="o",
        is_univariate=True
    )

    # =========================================================================
    # Figure 2: Univariate - Dummy variables (R² next to each label)
    # =========================================================================
    print("\n--- Creating univariate dummies plot ---")
    df_uni_dummy = df[(df["reg_type"] == "univariate") &
                      (df["spec"] == "post") &
                      (df["variable"].isin(DUMMY_ORDER))].copy()

    output_uni_dummy = GRAPHS / "coefplot_bilateral_dummies_univariate.pdf"
    create_coefplot(
        df_uni_dummy,
        DUMMY_ORDER,
        output_uni_dummy,
        title="",
        color="#8b0000",
        marker="s",
        is_univariate=True
    )

    # =========================================================================
    # Figure 3: Multivariate - Proximity measures (R² as footnote)
    # =========================================================================
    print("\n--- Creating multivariate proximity plot ---")
    df_multi_prox = df[(df["reg_type"] == "multivariate") &
                       (df["spec"] == "post") &
                       (df["variable"].isin(PROXIMITY_ORDER_NO_PRE))].copy()

    output_multi_prox = GRAPHS / "coefplot_bilateral_proximity_multivariate.pdf"
    create_coefplot(
        df_multi_prox,
        PROXIMITY_ORDER_NO_PRE,
        output_multi_prox,
        title="Proximity Measures (Multivariate)",
        color="#2e8b57",
        marker="D",
        is_univariate=False
    )

    # =========================================================================
    # Figure 4: Multivariate - Dummy variables (R² as footnote)
    # =========================================================================
    print("\n--- Creating multivariate dummies plot ---")
    df_multi_dummy = df[(df["reg_type"] == "multivariate") &
                        (df["spec"] == "post") &
                        (df["variable"].isin(DUMMY_ORDER))].copy()

    output_multi_dummy = GRAPHS / "coefplot_bilateral_dummies_multivariate.pdf"
    create_coefplot(
        df_multi_dummy,
        DUMMY_ORDER,
        output_multi_dummy,
        title="Same-Category Dummies (Multivariate)",
        color="#8b4513",
        marker="^",
        is_univariate=False
    )

    # =========================================================================
    # LaTeX figure files
    # =========================================================================
    print("\n--- Creating LaTeX figure file ---")
    latex_output = GRAPHS / "figure_bilateral_coefplot_post.tex"
    create_latex_figures(
        latex_output,
        output_uni_prox,
        output_uni_dummy,
        output_multi_prox,
        output_multi_dummy
    )

    print("\n" + "=" * 60)
    print("COMPLETE")
    print("=" * 60)
    print("\nOutput files:")
    print(f"  - {output_uni_prox}")
    print(f"  - {output_uni_dummy}")
    print(f"  - {output_multi_prox}")
    print(f"  - {output_multi_dummy}")
    print(f"  - {latex_output}")


if __name__ == "__main__":
    main()
