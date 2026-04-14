#!/usr/bin/env python3
"""
Generate a baseline-vs-top-1% labor spillover LaTeX table.
"""

import csv
from pathlib import Path
from typing import Dict, List


PROJECT = Path(__file__).resolve().parents[2]
TABLES = PROJECT / "Tables" / "numb_clauses_outliers"

RESULTS = TABLES / "labor_top1_spill_results.csv"
THRESHOLD = TABLES / "labor_top1_threshold.csv"
TEX = TABLES / "labor_top1_spillover_results.tex"

OUTCOMES = ["lr_remdezr_w", "lr_remdezr_h_w", "l_firm_emp"]
SAMPLES = {
    "baseline": "Baseline",
    "drop_top1_period1_numb": r"Drop top-1\% period-1 clause-count firms",
}


def read_csv(path: Path) -> List[Dict[str, str]]:
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def fmt_num(value: str, digits: int = 4) -> str:
    num = f"{float(value):.{digits}f}"
    if num.startswith("-"):
        num = r"$-$" + num[1:]
    return num


def fmt_int(value: str) -> str:
    return f"{int(float(value)):,}".replace(",", "{,}")


def stars(value: str) -> str:
    p = float(value)
    if p < 0.01:
        return "***"
    if p < 0.05:
        return "**"
    if p < 0.10:
        return "*"
    return ""


def coef(row: Dict[str, str], name: str) -> str:
    return f"{fmt_num(row[name])}{stars(row['p_' + name.split('_')[1]])}"


def se(row: Dict[str, str], name: str) -> str:
    return f"({fmt_num(row[name])})"


def build_table() -> str:
    data = {(row["sample"], row["outcome"]): row for row in read_csv(RESULTS)}
    threshold = read_csv(THRESHOLD)[0]
    lines = [
        r"\begin{table}[!htbp]",
        r"\centering",
        r"\caption{Spillover Effects on Labor Outcomes After Removing Top-1\% Period-1 Clause-Count Firms}",
        r"\label{tab:labor_top1_spillover_results}",
        r"\scriptsize",
        r"\begin{tabular}{lccc}",
        r"\toprule",
        r" & Monthly wage & Hourly wage & Employment \\",
        r"\midrule",
    ]
    sample_items = list(SAMPLES.items())
    for idx, (sample, label) in enumerate(sample_items):
        rows = [data[(sample, outcome)] for outcome in OUTCOMES]
        lines.append(rf"\multicolumn{{4}}{{l}}{{\textbf{{{label}}}}}\\")
        lines.append("Post $\\times$ Connectivity & " + " & ".join(coef(row, "b_post") for row in rows) + r"\\")
        lines.append(" & " + " & ".join(se(row, "se_post") for row in rows) + r"\\")
        lines.append("Pre $\\times$ Connectivity & " + " & ".join(coef(row, "b_pre") for row in rows) + r"\\")
        lines.append(" & " + " & ".join(se(row, "se_pre") for row in rows) + r"\\")
        lines.append("Pre-trend p-value & " + " & ".join(f"[{float(row['pre_ftest_pval']):.4f}]" for row in rows) + r"\\")
        lines.append(r"$N$ establishments & " + " & ".join(fmt_int(row["n_estab"]) for row in rows) + r"\\")
        lines.append(r"$N$ observations & " + " & ".join(fmt_int(row["n_obs"]) for row in rows) + r"\\")
        if idx != len(sample_items) - 1:
            lines.append(r"\addlinespace")
    lines += [
        r"\bottomrule",
        r"\end{tabular}",
        r"\begin{minipage}{\linewidth}",
        r"\footnotesize\vspace{4pt}",
        (
            r"\textit{Notes:} This table re-estimates the year-based spillover specification "
            r"from \texttt{Main\_Results\_pct\_tfpw\_07\_11.do}. The restricted sample removes "
            f"{fmt_int(threshold['n_top1_firms'])} firms with " + r"\texttt{cba\_period == 1} "
            r"\texttt{numb\_clauses} at or above the 99th percentile of the spillover "
            f"cross-section; the cutoff is {fmt_num(threshold['p99_numb_clause_cutoff'], 0)} clauses. "
            r"Connectivity is normalized by the 90th percentile of the 2009 spillover-sample distribution. "
            r"Monthly wage is \texttt{lr\_remdezr\_w}; hourly wage is \texttt{lr\_remdezr\_h\_w}. "
            r"All specifications include establishment fixed effects, year interactions with industry, "
            r"negotiation month, and microregion, and quartile-bin controls for the pre-treatment outcome, "
            r"pre-treatment log employment, and average per-worker worker flows during 2007--2011. "
            r"Standard errors clustered by establishment are in parentheses. *** p$<$0.01, "
            r"** p$<$0.05, * p$<$0.10."
        ),
        r"\end{minipage}",
        r"\end{table}",
    ]
    return "\n".join(lines) + "\n"


def main() -> None:
    TEX.write_text(build_table(), encoding="utf-8")
    print(f"Wrote {TEX}")


if __name__ == "__main__":
    main()
