#!/usr/bin/env python3
"""
Script 08b: Produce LaTeX table of layer connectivity descriptives.

Reads Tables/layer_connectivity/layer_descriptives.csv (produced by 08a) and
writes Tables/layer_connectivity/layer_descriptives.tex.

Three panels: Panel A (all firms), Panel B (small), Panel C (large).
Small = avg employment 2009-2011 < median; Large = >= median.
"""

import os
import pandas as pd

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
ROOT       = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TABLES_DIR = os.path.join(ROOT, "Tables", "layer_connectivity")
IN_CSV     = os.path.join(TABLES_DIR, "layer_descriptives.csv")
OUT_TEX    = os.path.join(TABLES_DIR, "layer_descriptives.tex")

# ---------------------------------------------------------------------------
# Load & sort
# ---------------------------------------------------------------------------
df = pd.read_csv(IN_CSV)

ORDER = ["edu", "edu2", "gender", "race"]
SUB_ORDER = {
    "edu":    ["0_no_hs", "1_hs", "2_higher"],
    "edu2":   ["no_hs", "has_hs"],
    "gender": ["female", "male"],
    "race":   ["nonwhite", "white"],
}
GROUP_ORDER = ["all", "small", "large"]

df["_def_order"] = df["layer_def"].map({v: i for i, v in enumerate(ORDER)})
df["_sub_order"] = df.apply(lambda r: SUB_ORDER[r["layer_def"]].index(r["layer_id"]), axis=1)
df["_grp_order"] = df["group"].map({v: i for i, v in enumerate(GROUP_ORDER)})
df = df.sort_values(["_grp_order", "_def_order", "_sub_order"]).drop(
    columns=["_def_order", "_sub_order", "_grp_order"]
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def mr(n, content):
    if n == 1:
        return content
    return f"\\multirow{{{n}}}{{*}}{{{content}}}"

def fmt_mean(x): return f"{x:.4f}"
def fmt_var(x):  return f"{x:.5f}"
def fmt_pct(x):  return f"{x:.1f}"

# ---------------------------------------------------------------------------
# Build body for one panel (one group)
# ---------------------------------------------------------------------------

def panel_body(group_df):
    lines = []
    for layer_def in ORDER:
        sub = group_df[group_df["layer_def"] == layer_def].reset_index(drop=True)
        k   = len(sub)

        frac_ge2    = sub.loc[0, "frac_ge2_layers"]
        var_total   = sub.loc[0, "var_total"]
        var_within  = sub.loc[0, "var_within"]
        var_between = sub.loc[0, "var_between"]
        pct_within  = sub.loc[0, "pct_within"]
        pct_between = sub.loc[0, "pct_between"]
        formal_def  = sub.loc[0, "formal_def"]

        for i, row in sub.iterrows():
            is_first = (i == sub.index[0])
            is_last  = (i == sub.index[-1])

            col1 = mr(k, formal_def) if is_first else ""
            col2 = row["formal_layer"]
            col3 = f"{row['avg_layer_emp']:.1f}"
            col4 = fmt_mean(row["mean_conn"])

            if is_first:
                col5 = mr(k, f"{frac_ge2*100:.1f}\\%")
                col6 = mr(k, fmt_var(var_total))
                col7 = mr(k, fmt_var(var_within))
                col8 = mr(k, fmt_var(var_between))
                col9 = mr(k, fmt_pct(pct_within))
                col10 = mr(k, fmt_pct(pct_between))
            else:
                col5 = col6 = col7 = col8 = col9 = col10 = ""

            lines.append(
                f"    {col1} & {col2} & {col3} & {col4} & {col5} & {col6} & {col7} & {col8} & {col9} & {col10} \\\\"
            )

            if is_last and layer_def != ORDER[-1]:
                lines.append("    \\midrule")

    return "\n".join(lines)

# ---------------------------------------------------------------------------
# Tablenotes
# ---------------------------------------------------------------------------
notes = (
    "\\textit{Notes:} "
    "This table describes the variance decomposition of within-firm layers' connectivity. "
    "``Avg.\\ layer emp.'' is the average number of workers in each sub-layer "
    "across spillover sample firms in 2009--2011. "
    "The column ``\\% firms w/ $\\geq$2 layers'' reports the share of spillover "
    "sample firms with non-missing connectivity in at least two sub-layers, "
    "which is the minimum required for within-firm identification. "
    "\\textit{Layer connectivity} measures the average pre-treatment worker flow "
    "from a focal firm's sub-layer to treated firms, per employee of that sub-layer, "
    "averaged across year-pairs 2007--08, 2008--09, 2009--10, and 2010--11. "
    "Variance decomposition follows the ANOVA identity "
    "$\\mathrm{Var}(X) = \\mathrm{E}[\\mathrm{Var}(X|Y)] + \\mathrm{Var}(\\mathrm{E}[X|Y])$, "
    "where both components are normalized by $N - 1$ "
    "(with $N = \\text{firms} \\times \\text{sub-layers}$) "
    "so that they sum exactly to total variance. "
    "\\textit{Within-firm} captures cross-layer dispersion in connectivity "
    "within a given firm; \\textit{between-firm} captures dispersion in "
    "firm-level average connectivity. "
    "\\textit{Education (3-levels)} partitions workers into three groups by schooling: "
    "less than high school, high school diploma, and higher education. "
    "\\textit{Education (2-levels)} merges the top two groups. "
    "\\textit{Race} classifies workers as white or non-white. "
    "Panels B and C split firms by median average December employment in 2009--2011 "
    "(median: 31.7 workers)."
)

# ---------------------------------------------------------------------------
# Assemble panels
# ---------------------------------------------------------------------------
PANEL_LABELS = {
    "all":   "Panel A: All firms",
    "small": "Panel B: Small firms (avg.\\ employment 2009--11 $<$ median)",
    "large": "Panel C: Large firms (avg.\\ employment 2009--11 $\\geq$ median)",
}

col_spec = "p{2.4cm}p{2.8cm}" + "c" * 8

header1 = (
    "    \\multicolumn{4}{l}{} & & "
    "\\multicolumn{5}{c}{\\textit{Variance decomposition}} \\\\"
)
cmidrule = "    \\cmidrule(lr){6-10}"

col_header = (
    "    \\shortstack{Layer\\\\definition} & Sub-layer & "
    "\\shortstack{Avg.\\\\layer\\\\emp.} & Mean & "
    "\\shortstack{\\% firms\\\\$\\geq$2 layers} & Total & "
    "\\shortstack{Within-\\\\firm} & \\shortstack{Between-\\\\firm} & "
    "\\shortstack{Within\\\\(\\%)} & \\shortstack{Between\\\\(\\%)} \\\\"
)

panel_blocks = []
for g in GROUP_ORDER:
    label    = PANEL_LABELS[g]
    group_df = df[df["group"] == g]
    body     = panel_body(group_df)
    block = (
        f"    \\multicolumn{{10}}{{l}}{{\\textit{{{label}}}}} \\\\\n"
        f"    \\midrule\n"
        f"{body}"
    )
    panel_blocks.append(block)

panels_tex = "\n    \\midrule\n    \\midrule\n".join(panel_blocks)

# ---------------------------------------------------------------------------
# Write
# ---------------------------------------------------------------------------
tex = f"""%% Table: Within-firm variation in layer connectivity (3 panels)
%% Auto-generated by Programs/layer_connectivity/08_layer_descriptives_table.py
\\begin{{table}}[H]
  \\centering
  \\caption{{Within-Firm Variation in Layer Connectivity}}
  \\label{{tab:layer_descriptives}}
  \\resizebox{{\\textwidth}}{{!}}{{%
  \\begin{{tabular}}{{{col_spec}}}
    \\toprule\\toprule
{header1}
{cmidrule}
{col_header}
    \\midrule
{panels_tex}
    \\bottomrule
  \\end{{tabular}}}}
  \\begin{{tablenotes}}
    \\scriptsize
    {notes}
  \\end{{tablenotes}}
\\end{{table}}
"""

with open(OUT_TEX, "w") as f:
    f.write(tex)

print(f"Saved to {OUT_TEX}")
print()
print(tex)
