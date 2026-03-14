#!/usr/bin/env python3
"""
Script 08b: Produce LaTeX table of layer connectivity descriptives.

Reads Tables/layer_connectivity/layer_descriptives.csv (produced by 08a) and
writes Tables/layer_connectivity/layer_descriptives.tex.

Table structure:
    Row group per layer definition (multirow).
    One row per sub-layer with mean connectivity.
    Variance decomposition columns span the group via multirow.
"""

import os
import numpy as np
import pandas as pd

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
ROOT       = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TABLES_DIR = os.path.join(ROOT, "Tables", "layer_connectivity")
IN_CSV     = os.path.join(TABLES_DIR, "layer_descriptives.csv")
OUT_TEX    = os.path.join(TABLES_DIR, "layer_descriptives.tex")

# ---------------------------------------------------------------------------
# Load
# ---------------------------------------------------------------------------
df = pd.read_csv(IN_CSV)

# Layer def order
ORDER = ["edu", "edu2", "gender", "race"]
# Build explicit row order: layer_def order, then sub-layer order within each def
SUB_ORDER = {
    "edu":    ["0_no_hs", "1_hs", "2_higher"],
    "edu2":   ["no_hs", "has_hs"],
    "gender": ["female", "male"],
    "race":   ["nonwhite", "white"],
}
df["_def_order"] = df["layer_def"].map({v: i for i, v in enumerate(ORDER)})
df["_sub_order"] = df.apply(lambda r: SUB_ORDER[r["layer_def"]].index(r["layer_id"]), axis=1)
df = df.sort_values(["_def_order", "_sub_order"]).drop(columns=["_def_order", "_sub_order"])

# One row per (layer_def, sub_layer), variance cols are constant within group
groups = df.groupby("layer_def", sort=False)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def fmt_mean(x):
    """Mean connectivity: show 4 decimal places."""
    return f"{x:.4f}"

def fmt_var(x):
    """Variance: 5 decimal places."""
    return f"{x:.5f}"

def fmt_pct(x):
    """Percentage: 1 decimal place."""
    return f"{x:.1f}"

def mr(n, content, valign="c"):
    """LaTeX \\multirow."""
    if n == 1:
        return content
    return f"\\multirow{{{n}}}{{*}}{{{content}}}"

# ---------------------------------------------------------------------------
# Build table body lines
# ---------------------------------------------------------------------------
body_lines = []

for layer_def in ORDER:
    sub = df[df["layer_def"] == layer_def].reset_index(drop=True)
    k   = len(sub)

    # Values constant within group
    n_firms    = int(sub.loc[0, "n_firms"])
    var_total  = sub.loc[0, "var_total"]
    var_within = sub.loc[0, "var_within"]
    var_between= sub.loc[0, "var_between"]
    pct_within = sub.loc[0, "pct_within"]
    pct_between= sub.loc[0, "pct_between"]
    formal_def = sub.loc[0, "formal_def"]

    for i, row in sub.iterrows():
        is_first = (i == sub.index[0])
        is_last  = (i == sub.index[-1])

        # Col 1: layer definition name (multirow)
        col1 = mr(k, formal_def) if is_first else ""

        # Col 2: sub-layer label
        col2 = row["formal_layer"]

        # Col 3: mean connectivity
        col3 = fmt_mean(row["mean_conn"])

        # Cols 4–8: variance decomposition (multirow)
        if is_first:
            col4 = mr(k, f"\\num{{{n_firms:,}}}")
            col5 = mr(k, fmt_var(var_total))
            col6 = mr(k, fmt_var(var_within))
            col7 = mr(k, fmt_var(var_between))
            col8 = mr(k, fmt_pct(pct_within))
            col9 = mr(k, fmt_pct(pct_between))
        else:
            col4 = col5 = col6 = col7 = col8 = col9 = ""

        line = f"    {col1} & {col2} & {col3} & {col4} & {col5} & {col6} & {col7} & {col8} & {col9} \\\\"
        body_lines.append(line)

        if is_last and layer_def != ORDER[-1]:
            body_lines.append("    \\midrule")

# ---------------------------------------------------------------------------
# Tablenotes
# ---------------------------------------------------------------------------
notes = (
    "\\textit{Notes:} "
    "Sample restricted to untreated firms in the balanced panel that belong to the "
    "Lagos~(2025) connected sample (4,196 firms before layer availability; "
    "see $N$ column for counts with all sub-layers observed). "
    "\\textit{Layer connectivity} (\\texttt{layer\\_treat\\_pw\\_n}) measures "
    "the average pre-treatment worker flow from a focal firm's sub-layer to "
    "treated firms, per employee of that sub-layer, averaged across year-pairs "
    "2007--08, 2008--09, 2009--10, and 2010--11. "
    "Variance decomposition follows the ANOVA identity "
    "$\\mathrm{Var}(X) = \\mathrm{Var}_{\\mathrm{within}} + \\mathrm{Var}_{\\mathrm{between}}$, "
    "where both components are normalized by $N - 1$ (with $N = \\text{firms} \\times \\text{sub-layers}$) "
    "so that they sum exactly to total variance. "
    "\\textit{Within-firm} captures cross-layer dispersion in connectivity "
    "within a given firm; \\textit{between-firm} captures dispersion in "
    "firm-level average connectivity. "
    "\\textit{Education (tertile)} partitions workers into three groups by schooling: "
    "less than high school, high school diploma, and higher education. "
    "\\textit{Education (binary)} merges the top two groups. "
    "\\textit{Race} classifies workers as white (\\textit{branca}) "
    "or non-white (\\textit{parda} and \\textit{preta}); "
    "indigenous, Asian, and workers with missing race are excluded."
)

# ---------------------------------------------------------------------------
# Assemble full LaTeX
# ---------------------------------------------------------------------------
col_spec = "ll" + "c" * 7   # 2 text + 7 numeric

header1 = (
    "    \\multicolumn{3}{l}{} & "
    "\\multicolumn{5}{c}{\\textit{Variance decomposition}} \\\\"
)
cmidrule = "    \\cmidrule(lr){4-8}"

header2 = (
    "    Layer definition & Sub-layer & Mean & "
    "$N$ firms & Total & Within-firm & Between-firm & "
    "Within (\\%) & Between (\\%) \\\\"
)

tex = f"""%% Table: Within-firm variation in layer connectivity
%% Auto-generated by Programs/layer_connectivity/08_layer_descriptives_table.py
\\begin{{table}}[htbp]
  \\centering
  \\caption{{Within-Firm Variation in Layer Connectivity}}
  \\label{{tab:layer_descriptives}}
  \\small
  \\begin{{tabular}}{{{col_spec}}}
    \\toprule
{header1}
{cmidrule}
{header2}
    \\midrule
{chr(10).join(body_lines)}
    \\bottomrule
  \\end{{tabular}}
  \\begin{{tablenotes}}
    \\footnotesize
    {notes}
  \\end{{tablenotes}}
\\end{{table}}
"""

with open(OUT_TEX, "w") as f:
    f.write(tex)

print(f"Saved to {OUT_TEX}")
print()
print(tex)
