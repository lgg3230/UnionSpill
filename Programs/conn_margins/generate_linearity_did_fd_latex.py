#!/usr/bin/env python3
"""
LaTeX table for the first-difference linearity test.

Input:  Tables/conn_margins/linearity_did_fd_test.csv
Output: Tables/conn_margins/linearity_did_fd_table.tex
"""

import pandas as pd
from pathlib import Path

script_dir = Path(__file__).resolve().parent
tables_dir = script_dir.parent.parent / "Tables" / "conn_margins"

df = pd.read_csv(tables_dir / "linearity_did_fd_test.csv")

OUTCOME_LABELS = {
    "lr_remdezr_w":   "Log Dec.\\ wage",
    "lr_remdezr_h_w": "Log hourly wage",
    "l_firm_emp":     "Log employment",
    "numb_clauses":   "\\# CBA clauses",
}


def fmt_n(v):
    return f"{int(v):,}".replace(",", "{,}")


def fmt_pval(v):
    v = float(v)
    if v < 0.001:
        return "$<0.001$"
    s = f"{v:.3f}"
    return r"\textbf{" + s + r"}" if v < 0.10 else s


lines = [
    r"\begin{table}[H]",
    r"\centering",
    r"\caption{Linearity Test of the Spillover Dose--Response (First Difference)}",
    r"\label{tab:linearity_did_fd}",
    r"\scriptsize",
    r"\begin{tabular}{lcccc}",
    r"\toprule\toprule",
    (r"Outcome & $N$ & \shortstack{Bins\\(req.\ 50)} & "
     r"\shortstack{Sup-$t$\\stat} & $p$-value \\"),
    r"\midrule",
]

for _, row in df.iterrows():
    lines.append(
        f"{OUTCOME_LABELS.get(row['outcome'], row['outcome'])} & "
        f"${fmt_n(row['n'])}$ & {int(row['nbins'])} & "
        f"{float(row['stat_supt']):.3f} & {fmt_pval(row['pval'])} \\\\"
    )

lines += [
    r"\bottomrule",
    r"\end{tabular}",
    r"\begin{minipage}{\linewidth}",
    r"\footnotesize\vspace{4pt}",
    (r"\textit{Notes:} This table reports Cattaneo, Crump, Farrell, and Feng "
     r"(2024) sup-$t$ tests of the null hypothesis that the firm-level treatment "
     r"effect is a degree-1 polynomial (linear) in connectivity. For each firm "
     r"the outcome is first-differenced, $\Delta Y_j = \overline{Y}_j^{\,post} - "
     r"\overline{Y}_j^{\,pre}$ (post $=$ 2012--2016, pre $=$ 2009--2011; CBA "
     r"periods 3--6 vs.\ 1--2 for clause counts), which removes the firm fixed "
     r"effect of the panel DiD exactly. The OLS slope of $\Delta Y_j$ on "
     r"connectivity reproduces the panel spillover coefficient to machine "
     r"precision. Industry, month-of-year, microregion, and pre-treatment "
     r"outcome, employment, and worker-flow quartile bins enter the binscatter "
     r"as internal covariates (the semi-linear partial-mean estimator), so no "
     r"variable is pre-residualized. The sample is the balanced panel of "
     r"untreated firms; standard errors are heteroskedasticity-robust; inference "
     r"uses 2{,}000 simulation draws on a grid of 50 points per bin. $p$-values "
     r"below $0.10$ are bolded.")
    ,
    r"\end{minipage}",
    r"\end{table}",
]

out = tables_dir / "linearity_did_fd_table.tex"
out.write_text("\n".join(lines) + "\n")
print(f"Saved: {out}")
print(df[["outcome", "n", "nbins", "stat_supt", "pval"]].to_string(index=False))
