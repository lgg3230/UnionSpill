#!/usr/bin/env python3
"""
Generate LaTeX table for connectivity-threshold-vs-zero spillover regressions.

Input:  Tables/conn_margins/results_thresholds_vs_zero.csv
Output: Tables/conn_margins/conn_margins_thresholds_vs_zero.tex
"""

import pandas as pd
from pathlib import Path

script_dir = Path(__file__).resolve().parent
tables_dir = script_dir.parent.parent / "Tables" / "conn_margins"
out_file   = tables_dir / "conn_margins_thresholds_vs_zero.tex"

df = pd.read_csv(tables_dir / "results_thresholds_vs_zero.csv", sep=";", header=0,
                 names=["threshold", "outcome", "row_type", "value"])

THRESHOLDS = ["p50", "p65", "p75", "p90"]
OUTCOMES   = ["lr_remdezr_w", "lr_remdezr_h_w", "l_firm_emp"]

PANEL_LABELS = {
    "lr_remdezr_w":   "Panel A: Log Wages",
    "lr_remdezr_h_w": "Panel B: Log Hourly Wages",
    "l_firm_emp":     "Panel C: Log Employment",
}

THR_LABELS = {
    "p50": "Above Median",
    "p65": "Above p65",
    "p75": "Above p75",
    "p90": "Above p90",
}


def get(thr, outcome, row_type):
    mask = (df["threshold"] == thr) & (df["outcome"] == outcome) & (df["row_type"] == row_type)
    vals = df.loc[mask, "value"]
    if vals.empty:
        return ""
    return str(vals.iloc[0]).strip().strip('"')


def fmt_coef(val):
    val = val.strip()
    stars = ""
    for s in ["***", "**", "*"]:
        if val.endswith(s):
            stars = s
            val = val[:-len(s)].strip()
            break
    try:
        num = float(val)
    except ValueError:
        return val
    formatted = f"{abs(num):.4f}"
    if num < 0:
        formatted = r"$-$" + formatted
    return formatted + stars


def fmt_se(val):
    val = val.strip().strip('"')
    try:
        return f"({float(val):.4f})"
    except ValueError:
        return val


def fmt_ftest(val):
    val = val.strip().strip('"')
    try:
        return f"[{float(val):.4f}]"
    except ValueError:
        return val


def fmt_n(val):
    val = val.strip().strip('"')
    try:
        return f"{int(float(val)):,}".replace(",", "{,}")
    except ValueError:
        return val


lines = []

lines.append(r"\begin{table}[!htbp]")
lines.append(r"\centering")
lines.append(r"\caption{Spillover Effects: Above-Threshold vs.\ Zero-Connectivity Firms}")
lines.append(r"\label{tab:conn_margins_thresholds_vs_zero}")
lines.append(r"\scriptsize")
lines.append(r"\begin{tabular}{lcccc}")
lines.append(r"\toprule\toprule")

lines.append(
    " & " + " & ".join(f"\\textbf{{{THR_LABELS[t]}}}" for t in THRESHOLDS) + r" \\"
)
lines.append(
    " & " + " & ".join(f"({i+1})" for i in range(len(THRESHOLDS))) + r" \\"
)

for outcome in OUTCOMES:
    panel_label = PANEL_LABELS[outcome]
    lines.append(r"\midrule")
    lines.append(
        r"\multicolumn{5}{l}{\textit{\textbf{" + panel_label + r"}}} \\"
    )
    lines.append(r"\midrule")

    post_row = " & ".join(fmt_coef(get(t, outcome, "post_coef")) for t in THRESHOLDS)
    lines.append(r"Post $\times$ Above Threshold & " + post_row + r" \\")
    se_row = " & ".join(fmt_se(get(t, outcome, "post_se")) for t in THRESHOLDS)
    lines.append(r"  & " + se_row + r" \\")
    lines.append(r"  & & & & \\")

    pre_row = " & ".join(fmt_coef(get(t, outcome, "pre_coef")) for t in THRESHOLDS)
    lines.append(r"Pre $\times$ Above Threshold & " + pre_row + r" \\")
    pse_row = " & ".join(fmt_se(get(t, outcome, "pre_se")) for t in THRESHOLDS)
    lines.append(r"  & " + pse_row + r" \\")

    ft_row = " & ".join(fmt_ftest(get(t, outcome, "pre_ftest")) for t in THRESHOLDS)
    lines.append(r"Pre-trend $F$-test $p$-value & " + ft_row + r" \\")
    lines.append(r"  & & & & \\")

    ne_row = " & ".join(fmt_n(get(t, outcome, "n_estab")) for t in THRESHOLDS)
    lines.append(r"$N$ establishments & " + ne_row + r" \\")
    n_row = " & ".join(fmt_n(get(t, outcome, "n_obs")) for t in THRESHOLDS)
    lines.append(r"$N$ observations & " + n_row + r" \\")

lines.append(r"\bottomrule\bottomrule")
lines.append(r"\end{tabular}")
lines.append(r"\begin{minipage}{\linewidth}")
lines.append(r"\footnotesize\vspace{4pt}")
lines.append(
    r"\textit{Notes:} This table replicates Table~\ref{tab:conn_margins_thresholds} "
    r"but restricts the comparison group to establishments with strictly zero pre-treatment "
    r"connectivity to treated firms. In each column, firms with positive connectivity below "
    r"the indicated threshold are excluded, so the coefficient on \textit{Post~$\times$~Above "
    r"Threshold} captures the differential post-reform wage or employment change of "
    r"high-connectivity establishments relative to unconnected establishments only. "
    r"Each column defines a binary indicator equal to one if a firm's normalized connectivity "
    r"exceeds the indicated percentile of the 2009 spillover-sample distribution. "
    r"All regressions include establishment fixed effects interacted with two-digit industry, "
    r"microregion, and base negotiation-month indicators by year, and quartile-bin controls "
    r"for pre-treatment per-worker pairwise worker flows (2007--2011) and pre-treatment "
    r"establishment size. Standard errors clustered at the establishment level in parentheses. "
    r"*** $p<0.01$, ** $p<0.05$, * $p<0.10$."
)
lines.append(r"\end{minipage}")
lines.append(r"\end{table}")

out_file.write_text("\n".join(lines) + "\n")
print(f"Saved: {out_file}")
