#!/home/lgg3230/.conda/envs/venv_python312/bin/python
"""
COMPARISON: Early Connectivity coefficient under ONE-WAY vs TWO-WAY FE

Simple figure showing just the early connectivity coefficient across
4 specifications:
  - Univariate, one-way FE (firm i only, 135M undirected)
  - Univariate, two-way FE (firm i + j, 271M directed)
  - Multivariate, one-way FE
  - Multivariate, two-way FE

Input:
  - bilateral_pretreatment_coefficients_univariate.csv        (two-way)
  - bilateral_pretreatment_coefficients_multivariate.csv      (two-way)
  - bilateral_pretreatment_coefficients_univariate_oneway.csv (one-way)
  - bilateral_pretreatment_coefficients_multivariate_oneway.csv (one-way)

Output: Graphs/coefplot_bilateral_fe_comparison.pdf
"""

import pandas as pd
import matplotlib.pyplot as plt
import matplotlib as mpl
from pathlib import Path
from matplotlib.lines import Line2D

mpl.rcParams['font.family'] = 'serif'
mpl.rcParams['font.serif'] = ['TeX Gyre Pagella', 'TeXGyrePagella', 'DejaVu Serif']
mpl.rcParams['pdf.fonttype'] = 42
mpl.rcParams['ps.fonttype'] = 42

# ==============================================================================
# PATHS
# ==============================================================================

BASE_DIR = Path("/kellogg/proj/lgg3230/UnionSpill")
RAIS_AUX = BASE_DIR / "Data" / "RAIS_aux"
GRAPHS = BASE_DIR / "Graphs"

TWOWAY_UNIV = RAIS_AUX / "bilateral_pretreatment_coefficients_univariate.csv"
TWOWAY_MULTI = RAIS_AUX / "bilateral_pretreatment_coefficients_multivariate.csv"
ONEWAY_UNIV = RAIS_AUX / "bilateral_pretreatment_coefficients_univariate_oneway.csv"
ONEWAY_MULTI = RAIS_AUX / "bilateral_pretreatment_coefficients_multivariate_oneway.csv"

OUTPUT_FILE = GRAPHS / "coefplot_bilateral_fe_comparison.pdf"

VAR = 'z_bilateral_conn_early_pre'

# Colors
C_ONEWAY = '#2166AC'    # blue
C_TWOWAY = '#B2182B'    # red


# ==============================================================================
# DATA LOADING
# ==============================================================================

def load_early_conn(path, label):
    """Extract early connectivity row from a coefficient CSV."""
    if not path.exists():
        print(f"  WARNING: {path.name} not found")
        return None
    df = pd.read_csv(path)
    row = df[df['variable'] == VAR]
    if row.empty:
        print(f"  WARNING: {VAR} not in {path.name}")
        return None
    r = row.iloc[0]
    print(f"  {label:40s} coef={r['coef']:.4f}  se={r['se']:.4f}  n={int(r['n']):,}")
    return r


# ==============================================================================
# MAIN
# ==============================================================================

def main():
    print("=" * 70)
    print("EARLY CONNECTIVITY: ONE-WAY FE vs TWO-WAY FE")
    print("=" * 70)

    print("\nLoading early connectivity coefficients...")
    ow_u = load_early_conn(ONEWAY_UNIV,  "One-way FE, univariate")
    ow_m = load_early_conn(ONEWAY_MULTI, "One-way FE, multivariate")
    tw_u = load_early_conn(TWOWAY_UNIV,  "Two-way FE, univariate")
    tw_m = load_early_conn(TWOWAY_MULTI, "Two-way FE, multivariate")

    specs = [
        (ow_u, "Univariate",   C_ONEWAY, "One-way FE"),
        (ow_m, "Multivariate", C_ONEWAY, "One-way FE"),
        (tw_u, "Univariate",   C_TWOWAY, "Two-way FE"),
        (tw_m, "Multivariate", C_TWOWAY, "Two-way FE"),
    ]

    # Filter to available results
    specs = [(r, reg, c, fe) for r, reg, c, fe in specs if r is not None]

    if len(specs) < 2:
        print("\nERROR: Need at least 2 specifications to compare.")
        print("Run the one-way regressions first:")
        print("  ~/.conda/envs/venv_python312/bin/python Programs/07d_bilateral_pretreatment_oneway.py")
        return

    # ----- Build the figure -----
    fig, ax = plt.subplots(figsize=(8, 3.5))

    # Y positions: group by FE spec, within each show univ/multi
    # Layout (top to bottom):
    #   y=3: One-way FE, Univariate
    #   y=2: One-way FE, Multivariate
    #   y=1: Two-way FE, Univariate
    #   y=0: Two-way FE, Multivariate
    positions = {
        ("One-way FE", "Univariate"):   3,
        ("One-way FE", "Multivariate"): 2,
        ("Two-way FE", "Univariate"):   1,
        ("Two-way FE", "Multivariate"): 0,
    }

    # Guide lines
    for y in positions.values():
        ax.axhline(y=y, color='gray', linestyle='-', linewidth=0.5, alpha=0.2, zorder=0)

    # Divider between FE groups
    ax.axhline(y=1.5, color='gray', linestyle='--', linewidth=1.0, alpha=0.4, zorder=0)

    # Zero line
    ax.axvline(x=0, color='gray', linestyle='-', linewidth=0.8, alpha=0.5, zorder=0)

    for row, reg_type, color, fe_label in specs:
        y = positions[(fe_label, reg_type)]
        coef = row['coef']
        ci_lo = row['ci_lower']
        ci_hi = row['ci_upper']

        # CI
        ax.plot([ci_lo, ci_hi], [y, y], color=color, linewidth=2.0, alpha=0.7, zorder=1)

        # Marker
        if reg_type == "Univariate":
            ax.plot(coef, y, marker='D', markersize=12,
                    markerfacecolor='white', markeredgecolor=color,
                    markeredgewidth=2.5, zorder=2)
        else:
            ax.plot(coef, y, marker='o', markersize=13,
                    markerfacecolor=color, markeredgecolor=color,
                    markeredgewidth=1.5, zorder=2)

        # Coefficient label
        ax.text(coef, y + 0.3, f'{coef:.3f}',
                ha='center', va='bottom', fontsize=11, fontweight='bold', color=color)

    # Y-axis labels
    y_labels = {
        3: "Univariate",
        2: "Multivariate",
        1: "Univariate",
        0: "Multivariate",
    }
    ax.set_yticks(list(y_labels.keys()))
    ax.set_yticklabels([y_labels[y] for y in sorted(y_labels.keys(), reverse=False)],
                        fontweight='bold', fontsize=12)
    ax.set_ylim(-0.6, 3.6)

    # Group labels on the right
    ax.text(ax.get_xlim()[1] * 1.02, 2.5, "One-way FE\n(firm i, 135M obs)",
            ha='left', va='center', fontsize=10, fontstyle='italic',
            transform=ax.get_yaxis_transform())
    ax.text(ax.get_xlim()[1] * 1.02, 0.5, "Two-way FE\n(firm i+j, 271M obs)",
            ha='left', va='center', fontsize=10, fontstyle='italic',
            transform=ax.get_yaxis_transform())

    ax.set_xlabel("Coefficient on Early Connectivity", fontsize=13, fontweight='bold')

    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)

    # Legend
    legend_elements = [
        Line2D([0], [0], marker='D', color='white',
               markerfacecolor='white', markeredgecolor='gray',
               markersize=10, markeredgewidth=2, linestyle='None',
               label='Univariate'),
        Line2D([0], [0], marker='o', color='white',
               markerfacecolor='gray', markeredgecolor='gray',
               markersize=10, markeredgewidth=1.5, linestyle='None',
               label='Multivariate'),
    ]
    ax.legend(handles=legend_elements, loc='lower left', frameon=False,
              fontsize=11, prop={'weight': 'bold'})

    plt.tight_layout()

    GRAPHS.mkdir(parents=True, exist_ok=True)
    fig.savefig(OUTPUT_FILE, dpi=1000, bbox_inches='tight', facecolor='white')
    plt.close(fig)

    print(f"\nSaved: {OUTPUT_FILE}")
    print("=" * 70)


if __name__ == "__main__":
    main()
