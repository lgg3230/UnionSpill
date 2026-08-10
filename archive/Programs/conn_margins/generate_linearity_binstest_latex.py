#!/usr/bin/env python3
"""
Generate publication-quality LaTeX table for the cross-sectional linearity test.

Input:  Tables/conn_margins/linearity_binstest_panel.csv
Output: Tables/conn_margins/linearity_binstest_table.tex
"""

import pandas as pd
from pathlib import Path

script_dir = Path(__file__).resolve().parent
tables_dir = script_dir.parent.parent / "Tables" / "conn_margins"

df = pd.read_csv(tables_dir / "linearity_binstest_panel.csv")

OUTCOME_LABELS = {
    "lr_remdezr_w":  "Log Dec.\\ wage",
    "lr_remdezr_h_w": "Log hourly wage",
    "l_firm_emp":    "Log employment",
    "numb_clauses":  "\\# CBA clauses",
}

SAMPLE_LABELS = {
    "2011":        "Year 2011",
    "cba_period2": "CBA period 2",
}

def fmt_n(v):
    return f"{int(v):,}".replace(",", "{,}")

def fmt_stat(v):
    return f"{float(v):.3f}"

def fmt_pval(v):
    v = float(v)
    if v < 0.001:
        return "$<0.001$"
    s = f"{v:.3f}"
    if v < 0.10:
        s = r"\textbf{" + s + r"}"
    return s

rows = []
for _, row in df.iterrows():
    outcome     = row["outcome"]
    year_sample = str(row["year_sample"])
    label       = OUTCOME_LABELS.get(outcome, outcome)
    sample_lbl  = SAMPLE_LABELS.get(year_sample, year_sample)
    n           = fmt_n(row["n"])
    nbins       = int(row["nbins"])
    stat        = fmt_stat(row["stat_supt"])
    pval        = fmt_pval(row["pval"])
    rows.append((label, sample_lbl, n, nbins, stat, pval))

lines = []
lines.append(r"\begin{table}[H]")
lines.append(r"\centering")
lines.append(r"\caption{Linearity Test: Connectivity and Firm Outcomes}")
lines.append(r"\label{tab:linearity_binstest}")
lines.append(r"\scriptsize")
lines.append(r"\begin{tabular}{llccccc}")
lines.append(r"\toprule\toprule")
lines.append(
    r"Outcome & Sample & $N$ & "
    r"\shortstack{Bins\\(DPI)} & "
    r"\shortstack{Sup-$t$\\stat} & "
    r"$p$-value \\"
)
lines.append(r"\midrule")

for label, sample_lbl, n, nbins, stat, pval in rows:
    lines.append(f"{label} & {sample_lbl} & ${n}$ & {nbins} & {stat} & {pval} \\\\")

lines.append(r"\bottomrule")
lines.append(r"\end{tabular}")
lines.append(r"\begin{minipage}{\linewidth}")
lines.append(r"\footnotesize\vspace{4pt}")
lines.append(
    r"\textit{Notes:} This table reports Cattaneo, Crump, Farrell, and Feng (2024) "
    r"sup-$t$ tests of the null hypothesis that the conditional expectation of each "
    r"outcome is a degree-1 polynomial (linear) in connectivity "
    r"(\texttt{totaltreat\_pw\_norm}). "
    r"The cross-section is fixed at year 2011 (calendar-year outcomes) or "
    r"CBA period 2 (number of CBA clauses). "
    r"Controls included as covariates: industry, month-of-year, microregion, "
    r"pre-treatment outcome quartile, pre-treatment employment quartile, and "
    r"pre-treatment worker-flow quartile. "
    r"Bins are set to 50 (requested); effective bins after dropping repeated "
    r"quantile knots at $x=0$ are reported. "
    r"Inference based on 2{,}000 simulation draws; grid of 50 evaluation points "
    r"per bin. Standard errors are heteroskedasticity-robust."
)
lines.append(r"\end{minipage}")
lines.append(r"\end{table}")

out = tables_dir / "linearity_binstest_table.tex"
out.write_text("\n".join(lines) + "\n")
print(f"Saved: {out}")
print(df[["outcome", "n", "nbins", "stat_supt", "pval"]].to_string(index=False))
