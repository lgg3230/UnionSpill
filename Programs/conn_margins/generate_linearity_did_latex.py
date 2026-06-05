#!/usr/bin/env python3
"""
LaTeX table for the panel DiD linearity test (Cattaneo et al. 2024 sup-norm).

Input:  Tables/conn_margins/linearity_did_test.csv
Output: Tables/conn_margins/linearity_did_table.tex
"""

import pandas as pd
from pathlib import Path

script_dir = Path(__file__).resolve().parent
tables_dir = script_dir.parent.parent / "Tables" / "conn_margins"

df = pd.read_csv(tables_dir / "linearity_did_test.csv")

OUTCOME_LABELS = {
    "lr_remdezr_w":   "Log Dec.\\ wage",
    "lr_remdezr_h_w": "Log hourly wage",
    "l_firm_emp":     "Log employment",
    "numb_clauses":   "\\# CBA clauses",
}
SAMPLE_LABELS = {
    "s_spill_pos":     "Intensive margin",
    "s_spill_pos_cba": "Intensive margin (CBA)",
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
    r"\caption{Linearity Test of the DiD Dose--Response: Connectivity and Firm Outcomes}",
    r"\label{tab:linearity_did}",
    r"\scriptsize",
    r"\begin{tabular}{llccccc}",
    r"\toprule\toprule",
    (r"Outcome & Sample & $N$ & \shortstack{Bins\\(req.\ 50)} & "
     r"\shortstack{Sup-$t$\\stat} & $p$-value \\"),
    r"\midrule",
]

for _, row in df.iterrows():
    lines.append(
        f"{OUTCOME_LABELS.get(row['outcome'], row['outcome'])} & "
        f"{SAMPLE_LABELS.get(row['sample'], row['sample'])} & "
        f"${fmt_n(row['n'])}$ & {int(row['nbins'])} & "
        f"{float(row['stat_supt']):.3f} & {fmt_pval(row['pval'])} \\\\"
    )

lines += [
    r"\bottomrule",
    r"\end{tabular}",
    r"\begin{minipage}{\linewidth}",
    r"\footnotesize\vspace{4pt}",
    (r"\textit{Notes:} This table reports Cattaneo, Crump, Farrell, and Feng "
     r"(2024) sup-$t$ tests of the null hypothesis that the conditional "
     r"expectation of each residualized outcome is a degree-1 polynomial "
     r"(linear) in residualized treatment intensity $D_{jt}=Conn_j\times "
     r"Post_t$. Both the outcome and $D_{jt}$ are residualized by "
     r"Frisch--Waugh--Lovell on the same firm fixed effects, "
     r"industry$\times$year, month-of-year$\times$year, and "
     r"microregion$\times$year fixed effects, pre-treatment outcome, "
     r"employment, and worker-flow quartile bins interacted with year, and the "
     r"post indicator, as in the baseline intensive-margin specification. The "
     r"sample is the balanced panel of untreated, positively connected firms "
     r"(2009--2016; CBA periods for clause counts). Standard errors are "
     r"clustered by firm; inference uses 2{,}000 simulation draws on a grid of "
     r"50 evaluation points per bin. $p$-values below $0.10$ are bolded.")
    ,
    r"\end{minipage}",
    r"\end{table}",
]

out = tables_dir / "linearity_did_table.tex"
out.write_text("\n".join(lines) + "\n")
print(f"Saved: {out}")
print(df[["outcome", "sample", "n", "nbins", "stat_supt", "pval"]].to_string(index=False))
