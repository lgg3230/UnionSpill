#!/usr/bin/env python3
"""
Generate LaTeX table for connectivity-quartile-vs-zero spillover regressions.

Columns:  Q1 (bottom), Q2, Q3, Q4 (top quartile of positive-connectivity firms)
Panels:   Panel A — Log December Wages; Panel B — Log Hourly Wages
Reference group in each column: zero-connectivity establishments.

Input:  Tables/conn_margins/results_quartiles_vs_zero.csv
Output: Tables/conn_margins/conn_margins_quartiles_vs_zero.tex
"""

import pandas as pd
from pathlib import Path

script_dir = Path(__file__).resolve().parent
tables_dir = script_dir.parent.parent / "Tables" / "conn_margins"
out_file   = tables_dir / "conn_margins_quartiles_vs_zero.tex"

df = pd.read_csv(tables_dir / "results_quartiles_vs_zero.csv", sep=";", header=0,
                 names=["quartile", "outcome", "row_type", "value"])

QUARTILES = ["1", "2", "3", "4"]
OUTCOMES  = ["lr_remdezr_w", "lr_remdezr_h_w"]

PANEL_LABELS = {
    "lr_remdezr_w":   "Panel A: Log December Wages",
    "lr_remdezr_h_w": "Panel B: Log Hourly Wages",
}

Q_LABELS = {
    "1": "Q1 (bottom)",
    "2": "Q2",
    "3": "Q3",
    "4": "Q4 (top)",
}


def get(q, outcome, row_type):
    mask = (df["quartile"].astype(str) == str(q)) & \
           (df["outcome"] == outcome) & \
           (df["row_type"] == row_type)
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
            val = val[: -len(s)].strip()
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

lines.append(r"\begin{table}[H]")
lines.append(r"\centering")
lines.append(r"\caption{Spillover Effects by Connectivity Quartile vs.\ Zero-Connectivity Firms}")
lines.append(r"\label{tab:conn_margins_quartiles_vs_zero}")
lines.append(r"\scriptsize")
lines.append(r"\begin{tabular}{lcccc}")
lines.append(r"\toprule\toprule")

lines.append(
    " & " + " & ".join(r"\textbf{" + Q_LABELS[q] + r"}" for q in QUARTILES) + r" \\"
)
lines.append(
    " & " + " & ".join(f"({i + 1})" for i in range(len(QUARTILES))) + r" \\"
)

for outcome in OUTCOMES:
    panel_label = PANEL_LABELS[outcome]
    lines.append(r"\midrule")
    lines.append(
        r"\multicolumn{5}{l}{\textit{\textbf{" + panel_label + r"}}} \\"
    )
    lines.append(r"\midrule")

    post_row = " & ".join(fmt_coef(get(q, outcome, "post_coef")) for q in QUARTILES)
    lines.append(r"Post $\times$ Connectivity Group & " + post_row + r" \\")
    se_row = " & ".join(fmt_se(get(q, outcome, "post_se")) for q in QUARTILES)
    lines.append(r"  & " + se_row + r" \\")
    lines.append(r"  & & & & \\")

    pre_row = " & ".join(fmt_coef(get(q, outcome, "pre_coef")) for q in QUARTILES)
    lines.append(r"Pre $\times$ Connectivity Group & " + pre_row + r" \\")
    pse_row = " & ".join(fmt_se(get(q, outcome, "pre_se")) for q in QUARTILES)
    lines.append(r"  & " + pse_row + r" \\")

    ft_row = " & ".join(fmt_ftest(get(q, outcome, "pre_ftest")) for q in QUARTILES)
    lines.append(r"Pre-trend $F$-test $p$-value & " + ft_row + r" \\")
    lines.append(r"  & & & & \\")

    ne_row = " & ".join(fmt_n(get(q, outcome, "n_estab")) for q in QUARTILES)
    lines.append(r"$N$ establishments & " + ne_row + r" \\")
    n_row = " & ".join(fmt_n(get(q, outcome, "n_obs")) for q in QUARTILES)
    lines.append(r"$N$ observations & " + n_row + r" \\")

lines.append(r"\bottomrule\bottomrule")
lines.append(r"\end{tabular}")
lines.append(r"\begin{minipage}{\linewidth}")
lines.append(r"\footnotesize\vspace{4pt}")
lines.append(
    r"\textit{Notes:} This table presents difference-in-differences estimates "
    r"comparing each quartile of the positive-connectivity distribution against "
    r"establishments with strictly zero pre-treatment connectivity to treated firms. "
    r"Connectivity quartile thresholds are computed among spillover-sample establishments "
    r"with positive connectivity ($\text{totaltreat\_pw\_n} > 0$) in 2009. "
    r"Q1 (bottom quartile) through Q4 (top quartile) partition the positive-connectivity "
    r"mass; each column's reference group is the zero-connectivity group. "
    r"The coefficient \textit{Post~$\times$~Connectivity Group} captures the "
    r"differential post-reform change in wages relative to unconnected establishments. "
    r"All regressions include establishment fixed effects interacted with two-digit industry, "
    r"microregion, and base negotiation-month indicators by year, and quartile-bin controls "
    r"for pre-treatment per-worker pairwise worker flows (2007--2011) and pre-treatment "
    r"establishment size. Standard errors clustered at the establishment level in parentheses. "
    r"Pre-trend $F$-test $p$-value (in brackets) tests joint significance of the "
    r"2009--2010 interaction terms from the event-study specification. "
    r"*** $p<0.01$, ** $p<0.05$, * $p<0.10$."
)
lines.append(r"\end{minipage}")
lines.append(r"\end{table}")

out_file.write_text("\n".join(lines) + "\n")
print(f"Saved: {out_file}")
