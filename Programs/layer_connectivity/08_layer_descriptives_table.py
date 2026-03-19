#!/usr/bin/env python3
"""
Script 08b: Produce LaTeX tables of layer connectivity descriptives.

Produces two tables (both transposed: rows = statistics, columns = layer specs):
  layer_descriptives_full.tex  — full spillover sample
  layer_descriptives_size.tex  — Panel A: small firms, Panel B: large firms

Reads Tables/layer_connectivity/layer_descriptives.csv (produced by 08a).
"""

import os
import pandas as pd

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
ROOT       = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TABLES_DIR = os.path.join(ROOT, "Tables", "layer_connectivity")
IN_CSV     = os.path.join(TABLES_DIR, "layer_descriptives.csv")

# ---------------------------------------------------------------------------
# Load & index
# ---------------------------------------------------------------------------
df = pd.read_csv(IN_CSV)

ORDER = ["edu", "edu2", "gender", "race"]
SUB_ORDER = {
    "edu":    ["0_no_hs", "1_hs", "2_higher"],
    "edu2":   ["no_hs", "has_hs"],
    "gender": ["female", "male"],
    "race":   ["nonwhite", "white"],
}
FORMAL_DEF = {
    "edu":    "Education (3-levels)",
    "edu2":   "Education (2-levels)",
    "gender": "Gender",
    "race":   "Race",
}
FORMAL_LAYER = {}   # filled from data
for _, row in df.iterrows():
    FORMAL_LAYER[(row["layer_def"], row["layer_id"])] = row["formal_layer"]

# Build nested lookup: data[group][layer_def][layer_id] -> dict of stats
data = {}
for _, row in df.iterrows():
    g, ld, li = row["group"], row["layer_def"], row["layer_id"]
    data.setdefault(g, {}).setdefault(ld, {})[li] = row.to_dict()

# All (layer_def, layer_id) pairs in column order
ALL_COLS = [(ld, li) for ld in ORDER for li in SUB_ORDER[ld]]

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def fmt_emp(x):    return f"{x:.1f}"
def fmt_wage(x):   return f"{x:,.0f}"
def fmt_flows(x):  return f"{x:.4f}"
def fmt_conn(x):   return f"{x:.4f}"
def fmt_pct_ge2(x): return f"{x*100:.1f}\\%"
def fmt_var(x):    return f"{x:.5f}"
def fmt_pct(x):    return f"{x:.1f}\\%"

def mc(k, content):
    """LaTeX multicolumn spanning k columns, centered."""
    return f"\\multicolumn{{{k}}}{{c}}{{{content}}}"

# ---------------------------------------------------------------------------
# Build body for one panel (one group)
# ---------------------------------------------------------------------------

# Per-sublayer rows: one cell per (layer_def, sub_layer)
SUBLAYER_ROWS = [
    ("Avg.\\ layer employment",    "avg_layer_emp",     fmt_emp),
    ("Avg.\\ real wage (BRL)",     "avg_layer_wage",    fmt_wage),
    ("Avg.\\ flows p.w.",          "avg_totalflows_pw", fmt_flows),
    ("\\% firms with layer",       "frac_ge1_layer",    fmt_pct_ge2),
    ("Mean connectivity",          "mean_conn",         fmt_conn),
]

# Per-layerdef rows: one multicolumn cell per layer_def
LAYERDEF_ROWS = [
    ("\\% firms $\\geq$2 layers", "frac_ge2_layers", fmt_pct_ge2),
    ("Variance (total)",           "var_total",       fmt_var),
    ("Variance (within-firm)",     "var_within",      fmt_var),
    ("Variance (between-firm)",    "var_between",     fmt_var),
    ("Within-firm (\\%)",          "pct_within",      fmt_pct),
    ("Between-firm (\\%)",         "pct_between",     fmt_pct),
]

def panel_body(group, midrule_after=False):
    lines = []

    # Per-sublayer rows
    for label, stat, fmt_fn in SUBLAYER_ROWS:
        cells = [f"\\quad {label}"]
        for ld, li in ALL_COLS:
            val = data[group][ld][li][stat]
            cells.append(fmt_fn(val))
        lines.append("    " + " & ".join(cells) + " \\\\")

    lines.append("    \\midrule")

    # Per-layerdef rows (multicolumn)
    for label, stat, fmt_fn in LAYERDEF_ROWS:
        cells = [f"\\quad {label}"]
        for ld in ORDER:
            k   = len(SUB_ORDER[ld])
            val = data[group][ld][SUB_ORDER[ld][0]][stat]  # same for all sub-layers
            cells.append(mc(k, fmt_fn(val)))
        lines.append("    " + " & ".join(cells) + " \\\\")

    if midrule_after:
        lines.append("    \\midrule\\midrule")

    return "\n".join(lines)

# ---------------------------------------------------------------------------
# Build column headers (shared by both tables)
# ---------------------------------------------------------------------------
N_DATACOLS = sum(len(SUB_ORDER[ld]) for ld in ORDER)   # 9
N_COLS     = 1 + N_DATACOLS                            # 10
col_spec   = "l" + "c" * N_DATACOLS

# Header row 1: layer definition names with multicolumn spans
h1_cells = [""]
for ld in ORDER:
    k = len(SUB_ORDER[ld])
    h1_cells.append(mc(k, f"\\textit{{{FORMAL_DEF[ld]}}}"))
header1 = "    " + " & ".join(h1_cells) + " \\\\"

# Cmidrules under each layer definition block
col = 2
cmi_parts = []
for ld in ORDER:
    k = len(SUB_ORDER[ld])
    cmi_parts.append(f"\\cmidrule(lr){{{col}-{col+k-1}}}")
    col += k
cmidrule = "    " + " ".join(cmi_parts)

# Wrapped sub-layer labels for header row 2 (shortstack to save horizontal space)
HEADER_LABEL = {
    ("edu",    "0_no_hs"):  r"\shortstack{No high\\school}",
    ("edu",    "1_hs"):     r"\shortstack{High school\\diploma}",
    ("edu",    "2_higher"): r"\shortstack{Higher\\education}",
    ("edu2",   "no_hs"):    r"\shortstack{No high\\school}",
    ("edu2",   "has_hs"):   r"\shortstack{HS or\\above}",
    ("gender", "female"):   "Female",
    ("gender", "male"):     "Male",
    ("race",   "nonwhite"): "Non-white",
    ("race",   "white"):    "White",
}

# Header row 2: sub-layer names
h2_cells = [""]
for ld, li in ALL_COLS:
    h2_cells.append(HEADER_LABEL.get((ld, li), FORMAL_LAYER[(ld, li)]))
header2 = "    " + " & ".join(h2_cells) + " \\\\"

# ---------------------------------------------------------------------------
# Full-sample table
# ---------------------------------------------------------------------------
notes_full = (
    "\\textit{Notes:} "
    "This table summarises pre-treatment (2009--2011) descriptive statistics "
    "for layer connectivity across four worker-partitioning schemes, "
    "restricted to the spillover sample (untreated, balanced-panel firms). "
    "Each column corresponds to a sub-layer within a given layer definition. "
    "``Avg.\\ layer employment'' is the average number of workers in the sub-layer. "
    "``Avg.\\ real wage'' is the average December real wage (deflated to December 2015 BRL). "
    "``Avg.\\ flows p.w.'' is average total worker outflows per worker in that sub-layer, "
    "averaged across year-pairs 2007--08 through 2010--11. "
    "``\\% firms with layer'' is the share of spillover firms with at least one worker "
    "in the indicated sub-layer during the pre-treatment period. "
    "``Mean connectivity'' is the average pre-treatment flow from a focal firm's sub-layer "
    "to treated firms per worker of that sub-layer. "
    "``\\% firms $\\geq$2 layers'' is the share of spillover firms with non-missing connectivity "
    "in at least two sub-layers (minimum for within-firm identification); "
    "this statistic is the same for all sub-layers within a definition. "
    "The variance decomposition follows the ANOVA identity "
    "$\\mathrm{Var}(X) = \\mathrm{E}[\\mathrm{Var}(X|\\mathrm{firm})] "
    "+ \\mathrm{Var}(\\mathrm{E}[X|\\mathrm{firm}])$, "
    "normalized by $N-1$ so that components sum exactly to total variance."
)

tex_full = f"""%% Auto-generated by Programs/layer_connectivity/08_layer_descriptives_table.py
\\begin{{table}}[H]
  \\centering
  \\caption{{Layer Connectivity Descriptives --- Full Spillover Sample}}
  \\label{{tab:layer_desc_full}}
  \\resizebox{{\\textwidth}}{{!}}{{%
  \\begin{{tabular}}{{{col_spec}}}
    \\toprule\\toprule
{header1}
{cmidrule}
{header2}
    \\midrule
{panel_body("all")}
    \\bottomrule
  \\end{{tabular}}}}
  \\begin{{minipage}}{{\\linewidth}}
    \\scriptsize\\vspace{{4pt}}
    {notes_full}
  \\end{{minipage}}
\\end{{table}}
"""

# ---------------------------------------------------------------------------
# Size-split table (Panel A: small, Panel B: large)
# ---------------------------------------------------------------------------
notes_size = (
    "\\textit{Notes:} "
    "This table reports the same descriptive statistics as Table~\\ref{{tab:layer_desc_full}}, "
    "split by firm size. "
    "Panel A restricts to small firms (average December employment 2009--2011 below the median); "
    "Panel B restricts to large firms (at or above the median, corresponding to 31.7 workers). "
    "See notes to Table~\\ref{{tab:layer_desc_full}} for variable definitions."
)

panel_a = (
    f"    \\multicolumn{{{N_COLS}}}{{l}}{{\\textit{{Panel A: Small firms "
    f"(avg.\\ employment 2009--11 $<$ median)}}}} \\\\\n"
    f"    \\midrule\n"
    f"{panel_body('small', midrule_after=True)}"
)
panel_b = (
    f"    \\multicolumn{{{N_COLS}}}{{l}}{{\\textit{{Panel B: Large firms "
    f"(avg.\\ employment 2009--11 $\\geq$ median)}}}} \\\\\n"
    f"    \\midrule\n"
    f"{panel_body('large')}"
)

tex_size = f"""%% Auto-generated by Programs/layer_connectivity/08_layer_descriptives_table.py
\\begin{{table}}[H]
  \\centering
  \\caption{{Layer Connectivity Descriptives --- By Firm Size}}
  \\label{{tab:layer_desc_size}}
  \\resizebox{{\\textwidth}}{{!}}{{%
  \\begin{{tabular}}{{{col_spec}}}
    \\toprule\\toprule
{header1}
{cmidrule}
{header2}
    \\midrule
{panel_a}
{panel_b}
    \\bottomrule
  \\end{{tabular}}}}
  \\begin{{minipage}}{{\\linewidth}}
    \\scriptsize\\vspace{{4pt}}
    {notes_size}
  \\end{{minipage}}
\\end{{table}}
"""

# ---------------------------------------------------------------------------
# Write full + size tables
# ---------------------------------------------------------------------------
out_full = os.path.join(TABLES_DIR, "layer_descriptives_full.tex")
out_size = os.path.join(TABLES_DIR, "layer_descriptives_size.tex")

with open(out_full, "w") as f:
    f.write(tex_full)
print(f"Saved: {out_full}")

with open(out_size, "w") as f:
    f.write(tex_size)
print(f"Saved: {out_size}")

# ---------------------------------------------------------------------------
# Demog table: edu2 + gender + race only (drop 3-bin edu)
# ---------------------------------------------------------------------------
ORDER_DEMOG    = ["edu2", "gender", "race"]
ALL_COLS_DEMOG = [(ld, li) for ld in ORDER_DEMOG for li in SUB_ORDER[ld]]

N_DATACOLS_D = sum(len(SUB_ORDER[ld]) for ld in ORDER_DEMOG)   # 6
N_COLS_D     = 1 + N_DATACOLS_D
col_spec_d   = "l" + "c" * N_DATACOLS_D

h1_cells_d = [""]
for ld in ORDER_DEMOG:
    k = len(SUB_ORDER[ld])
    h1_cells_d.append(mc(k, f"\\textit{{{FORMAL_DEF[ld]}}}"))
header1_d = "    " + " & ".join(h1_cells_d) + " \\\\"

col = 2
cmi_parts_d = []
for ld in ORDER_DEMOG:
    k = len(SUB_ORDER[ld])
    cmi_parts_d.append(f"\\cmidrule(lr){{{col}-{col+k-1}}}")
    col += k
cmidrule_d = "    " + " ".join(cmi_parts_d)

h2_cells_d = [""]
for ld, li in ALL_COLS_DEMOG:
    h2_cells_d.append(HEADER_LABEL.get((ld, li), FORMAL_LAYER[(ld, li)]))
header2_d = "    " + " & ".join(h2_cells_d) + " \\"

def panel_body_demog(group, midrule_after=False):
    lines = []
    for label, stat, fmt_fn in SUBLAYER_ROWS:
        cells = [f"\\quad {label}"]
        for ld, li in ALL_COLS_DEMOG:
            val = data[group][ld][li][stat]
            cells.append(fmt_fn(val))
        lines.append("    " + " & ".join(cells) + " \\\\")
    lines.append("    \\midrule")
    for label, stat, fmt_fn in LAYERDEF_ROWS:
        cells = [f"\\quad {label}"]
        for ld in ORDER_DEMOG:
            k   = len(SUB_ORDER[ld])
            val = data[group][ld][SUB_ORDER[ld][0]][stat]
            cells.append(mc(k, fmt_fn(val)))
        lines.append("    " + " & ".join(cells) + " \\\\")
    if midrule_after:
        lines.append("    \\midrule\\midrule")
    return "\n".join(lines)

notes_demog = (
    "\\textit{Notes:} "
    "This table summarises pre-treatment (2009--2011) descriptive statistics "
    "for layer connectivity across three worker-partitioning schemes "
    "(2-bin education, gender, and race), "
    "restricted to the spillover sample (untreated, balanced-panel firms). "
    "Each column corresponds to a sub-layer within a given layer definition. "
    "``Avg.\\ layer employment'' is the average number of workers in the sub-layer. "
    "``Avg.\\ real wage'' is the average December real wage (deflated to December 2015 BRL). "
    "``Avg.\\ flows p.w.'' is average total worker outflows per worker in that sub-layer, "
    "averaged across year-pairs 2007--08 through 2010--11. "
    "``\\% firms with layer'' is the share of spillover firms with at least one worker "
    "in the indicated sub-layer during the pre-treatment period. "
    "``Mean connectivity'' is the average pre-treatment flow from a focal firm's sub-layer "
    "to treated firms per worker of that sub-layer. "
    "``\\% firms $\\geq$2 layers'' is the share of spillover firms with non-missing connectivity "
    "in at least two sub-layers (minimum for within-firm identification); "
    "this statistic is the same for all sub-layers within a definition. "
    "The variance decomposition follows the ANOVA identity "
    "$\\mathrm{Var}(X) = \\mathrm{E}[\\mathrm{Var}(X|\\mathrm{firm})] "
    "+ \\mathrm{Var}(\\mathrm{E}[X|\\mathrm{firm}])$, "
    "normalized by $N-1$ so that components sum exactly to total variance."
)

panel_a_d = (
    f"    \\multicolumn{{{N_COLS_D}}}{{l}}{{\\textit{{Panel A: Small firms "
    f"(avg.\\ employment 2009--11 $<$ median)}}}} \\\\\n"
    f"    \\midrule\n"
    f"{panel_body_demog('small', midrule_after=True)}"
)
panel_b_d = (
    f"    \\multicolumn{{{N_COLS_D}}}{{l}}{{\\textit{{Panel B: Large firms "
    f"(avg.\\ employment 2009--11 $\\geq$ median)}}}} \\\\\n"
    f"    \\midrule\n"
    f"{panel_body_demog('large')}"
)

tex_demog_full = f"""%% Auto-generated by Programs/layer_connectivity/08_layer_descriptives_table.py
\\begin{{table}}[H]
  \\centering
  \\caption{{Layer Connectivity Descriptives --- Full Spillover Sample}}
  \\label{{tab:layer_desc_demog_full}}
  \\resizebox{{\\textwidth}}{{!}}{{%
  \\begin{{tabular}}{{{col_spec_d}}}
    \\toprule\\toprule
{header1_d}
{cmidrule_d}
{header2_d}\\
    \\midrule
{panel_body_demog("all")}
    \\bottomrule
  \\end{{tabular}}}}
  \\begin{{minipage}}{{\\linewidth}}
    \\scriptsize\\vspace{{4pt}}
    {notes_demog}
  \\end{{minipage}}
\\end{{table}}
"""

tex_demog_size = f"""%% Auto-generated by Programs/layer_connectivity/08_layer_descriptives_table.py
\\begin{{table}}[H]
  \\centering
  \\caption{{Layer Connectivity Descriptives --- By Firm Size}}
  \\label{{tab:layer_desc_demog_size}}
  \\resizebox{{\\textwidth}}{{!}}{{%
  \\begin{{tabular}}{{{col_spec_d}}}
    \\toprule\\toprule
{header1_d}
{cmidrule_d}
{header2_d}\\
    \\midrule
{panel_a_d}
{panel_b_d}
    \\bottomrule
  \\end{{tabular}}}}
  \\begin{{minipage}}{{\\linewidth}}
    \\scriptsize\\vspace{{4pt}}
    {notes_demog}
  \\end{{minipage}}
\\end{{table}}
"""

out_demog_full = os.path.join(TABLES_DIR, "layer_descriptives_demog_full.tex")
out_demog_size = os.path.join(TABLES_DIR, "layer_descriptives_demog_size.tex")

with open(out_demog_full, "w") as f:
    f.write(tex_demog_full)
print(f"Saved: {out_demog_full}")

with open(out_demog_size, "w") as f:
    f.write(tex_demog_size)
print(f"Saved: {out_demog_size}")
