#!/usr/bin/env python3
"""
Generate LaTeX table for connectivity-threshold spillover regressions.

Input:  Tables/conn_margins/results_thresholds.csv
Output: Tables/conn_margins/conn_margins_thresholds.tex
"""

import pandas as pd
from pathlib import Path

script_dir = Path(__file__).resolve().parent
tables_dir = script_dir.parent.parent / "Tables" / "conn_margins"
out_file   = tables_dir / "conn_margins_thresholds.tex"

df = pd.read_csv(tables_dir / "results_thresholds.csv", sep=";", header=0,
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
lines.append(r"\caption{Spillover Effects by Connectivity Threshold}")
lines.append(r"\label{tab:conn_margins_thresholds}")
lines.append(r"\scriptsize")
lines.append(r"\begin{tabular}{lcccc}")
lines.append(r"\toprule\toprule")

# Column headers
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

    # Post coefficient
    post_row = " & ".join(fmt_coef(get(t, outcome, "post_coef")) for t in THRESHOLDS)
    lines.append(r"Post $\times$ Above Threshold & " + post_row + r" \\")
    se_row = " & ".join(fmt_se(get(t, outcome, "post_se")) for t in THRESHOLDS)
    lines.append(r"  & " + se_row + r" \\")
    lines.append(r"  & & & & \\")

    # Pre coefficient
    pre_row = " & ".join(fmt_coef(get(t, outcome, "pre_coef")) for t in THRESHOLDS)
    lines.append(r"Pre $\times$ Above Threshold & " + pre_row + r" \\")
    pse_row = " & ".join(fmt_se(get(t, outcome, "pre_se")) for t in THRESHOLDS)
    lines.append(r"  & " + pse_row + r" \\")

    # Pre-trend F-test
    ft_row = " & ".join(fmt_ftest(get(t, outcome, "pre_ftest")) for t in THRESHOLDS)
    lines.append(r"Pre-trend $F$-test $p$-value & " + ft_row + r" \\")
    lines.append(r"  & & & & \\")

    # N estab then N obs (match example ordering)
    ne_row = " & ".join(fmt_n(get(t, outcome, "n_estab")) for t in THRESHOLDS)
    lines.append(r"$N$ establishments & " + ne_row + r" \\")
    n_row = " & ".join(fmt_n(get(t, outcome, "n_obs")) for t in THRESHOLDS)
    lines.append(r"$N$ observations & " + n_row + r" \\")

lines.append(r"\bottomrule\bottomrule")
lines.append(r"\end{tabular}")
lines.append(r"\begin{minipage}{\linewidth}")
lines.append(r"\footnotesize\vspace{4pt}")
lines.append(
    r"\textit{Notes:} This table examines whether the wage and employment spillovers from Brazil's Ultractivity Reform "
    r"(S\'umula 277, 2012) are concentrated among untreated establishments with high pre-treatment worker-flow "
    r"exposure to directly affected firms. Each column replaces the continuous connectivity measure with a binary "
    r"indicator equal to one if a firm's normalized connectivity exceeds the indicated percentile of the connectivity "
    r"distribution among untreated establishments in 2009, and zero otherwise. "
    r"\textit{Post~$\times$~Above Threshold} is the coefficient on the interaction of the above-threshold dummy "
    r"with a post-2012 indicator in a two-way fixed effects regression estimated on the untreated sample. "
    r"\textit{Pre~$\times$~Above Threshold} is the analogous placebo coefficient estimated on pre-treatment data "
    r"(2009--2011) only. The pre-trend $F$-test $p$-value is from a joint test of the above-threshold $\times$ year "
    r"interactions for 2009 and 2010 relative to 2011 in an event-study specification. "
    r"All regressions include establishment fixed effects interacted with two-digit industry, microregion, and base "
    r"negotiation-month indicators by year, and quartile-bin controls for pre-treatment per-worker pairwise worker "
    r"flows (2007--2011) and pre-treatment establishment size. "
    r"Standard errors clustered at the establishment level in parentheses. *** $p<0.01$, ** $p<0.05$, * $p<0.10$."
)
lines.append(r"\end{minipage}")
lines.append(r"\end{table}")

out_file.write_text("\n".join(lines) + "\n")
print(f"Saved: {out_file}")
