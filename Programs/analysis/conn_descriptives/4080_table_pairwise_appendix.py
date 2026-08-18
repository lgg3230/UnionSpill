#!/usr/bin/env python3
"""
Appendix table of the pairwise-connectivity regressions behind
Figure fig:bilateral_coefplot (coefplot_bilateral_combined.pdf).

The figure is hard to read; this table prints the same estimates as numbers.
Nothing is re-estimated -- the four coefficient CSVs written by the original
regressions are read as-is from Docs/fixtures/figure_A2/. They are a FIXTURE:
no script in Programs/ produces them, so they are committed inputs rather than
pipeline output. See Docs/pipeline/INVENTORY.md.

Layout (per the 2026-07-30 revision request):
  Two column groups, one per outcome measure:
      Connectivity        = pairwise connectivity      (spec "gravity")
      Late connectivity   = late-pre connectivity      (spec "pretreat")
  Within each group, two columns: univariate | multivariate.
  Two panels:
      Panel A = continuous measures (var_type "proximity", plus the
                early-connectivity regressor where present)
      Panel B = the dummy / indicator version used in the results
                (var_type "dummy")

Each cell: coefficient, standard error in parentheses, significance stars.

Output: quality_reports/replication/hourly_variant_currentconn/frag/t_pairwise_appendix.tex
"""
from pathlib import Path
import math
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent.parent.parent
SRC = ROOT / "Docs" / "fixtures" / "figure_A2"
OUT = ROOT / "quality_reports/replication/hourly_variant_currentconn/frag/t_pairwise_appendix.tex"

COLS = [
    ("conn_u", "coef_connectivity_univ.csv"),
    ("conn_m", "coef_connectivity_multi.csv"),
    ("late_u", "coef_late_connectivity_univ.csv"),
    ("late_m", "coef_late_connectivity_multi.csv"),
]

# House labels (CLAUDE.md coefficient-plot standards)
LABELS = {
    "z_bilateral_conn_early_pre": "Early connectivity",
    "z_cep_proximity": "Spatial",
    "z_geo_proximity": "Spatial",
    "z_turnover_proximity": "Turnover",
    "z_size_proximity": "Size",
    "z_wage_proximity": "Wage",
    "z_female_proximity": "\\% Female",
    "z_nonwhite_proximity": "\\% Non-white",
    "z_educ_proximity": "\\% Higher ed.",
    "z_hs_proximity": "\\% High school",
    "z_nhs_proximity": "\\% No high school",
    "z_clauses_proximity": "\\# CBA clauses",
    "same_muni": "Municipality",
    "same_microregion": "Microregion",
    "same_union": "Union",
    "same_industry": "Industry",
    "same_industry_micro": "Industry $\\times$ microregion",
}


def stars(coef, se):
    if se is None or se <= 0 or (isinstance(se, float) and math.isnan(se)):
        return ""
    z = abs(coef / se)
    # two-sided normal p-value (n is ~2.5e8, so z is appropriate)
    p = math.erfc(z / math.sqrt(2))
    return "***" if p < 0.01 else "**" if p < 0.05 else "*" if p < 0.10 else ""


data = {}
meta = {}
for key, fn in COLS:
    d = pd.read_csv(SRC / fn)
    data[key] = d.set_index("variable")
    meta[key] = (d["r2"].iloc[0], d["n"].iloc[0])

# Row order: keep each source file's own order, union across columns.
def rows_for(vtypes):
    seen, order = set(), []
    for key, _ in COLS:
        d = data[key]
        for v in d.index[d["var_type"].isin(vtypes)]:
            if v not in seen:
                seen.add(v); order.append(v)
    return order


def cell(key, var):
    d = data[key]
    if var not in d.index:
        return "---", ""
    r = d.loc[var]
    c, s = float(r["coef"]), float(r["se"])
    return f"{c:.4f}{stars(c, s)}", f"({s:.4f})"


L = []
A = L.append
A(r"\begin{table}[H]")
A(r"\centering")
A(r"\caption{Predictors of Pairwise Connectivity}")
A(r"\label{tab:pairwise_conn_appendix}")
A(r"\footnotesize")
A(r"\begin{tabular}{lcccc}")
A(r"\toprule\toprule")
A(r" & \multicolumn{2}{c}{Connectivity} & \multicolumn{2}{c}{Late connectivity} \\")
A(r"\cmidrule(lr){2-3} \cmidrule(lr){4-5}")
A(r" & Univariate & Multivariate & Univariate & Multivariate \\")
A(r" & (1) & (2) & (3) & (4) \\")
A(r"\midrule")

for panel, title, vtypes in [
    ("A", "Continuous measures", ["proximity", "early_connectivity"]),
    ("B", "Indicator measures", ["dummy"]),
]:
    A(r"\multicolumn{5}{l}{\textbf{Panel " + panel + r":} " + title + r"} \\")
    for var in rows_for(vtypes):
        cs = [cell(k, var) for k, _ in COLS]
        A(LABELS.get(var, var.replace("_", r"\_")) + " & "
          + " & ".join(c[0] for c in cs) + r" \\")
        A(" & " + " & ".join(c[1] for c in cs) + r" \\")
    A(r" &  &  &  & \\")

A(r"\midrule")
A(r"$R^2$ & " + " & ".join(f"{meta[k][0]:.4f}" for k, _ in COLS) + r" \\")
A(r"Observations & " + " & ".join(f"{meta[k][1]:,}".replace(",", "{,}")
                                  for k, _ in COLS) + r" \\")
A(r"\bottomrule\bottomrule")
A(r"\end{tabular}")
A(r"\begin{minipage}{\linewidth}")
A(r"    \scriptsize\vspace{4pt}")
A(r"    \textit{Notes:} This table reports the estimates plotted in the "
  r"pairwise-connectivity coefficient figure. The unit of observation is an "
  r"establishment pair. Columns~(1)--(2) take pairwise connectivity as the "
  r"dependent variable; columns~(3)--(4) take late pre-reform connectivity, "
  r"with early pre-reform connectivity included as a regressor. Univariate "
  r"columns report one regression per row; multivariate columns report a "
  r"single regression including all listed regressors jointly, so the reported "
  r"$R^2$ is common to every row in that column. Panel~A reports the "
  r"continuous proximity measures, each defined as the negative absolute "
  r"difference between the two establishments' values so that higher means "
  r"more similar; Panel~B reports the indicator measures for shared "
  r"classifications. All regressors are standardized, so coefficients are in "
  r"standard-deviation units of the dependent variable. Standard errors in "
  r"parentheses. *** p$<$0.01, ** p$<$0.05, * p$<$0.10.")
A(r"\end{minipage}")
A(r"\end{table}")

OUT.write_text("\n".join(L) + "\n")
print(f"wrote {OUT}")
print(f"Panel A rows: {len(rows_for(['proximity','early_connectivity']))}, "
      f"Panel B rows: {len(rows_for(['dummy']))}")
