#!/usr/bin/env python3
"""
Generate a combined labor spillover LaTeX table with four panels:
  1. Baseline
  2. Drop top-1% period-1 clause-count firms
  3. Drop prefix-10877926 firms
  4. Winsorize numb_clauses at 99th percentile (labor outcomes unaffected)
"""

import csv
from pathlib import Path
from typing import Dict, List

PROJECT = Path(__file__).resolve().parents[2]
TABLES  = PROJECT / "Tables" / "numb_clauses_outliers"

TOP1_CSV    = TABLES / "labor_top1_spill_results.csv"
PREFIX_CSV  = TABLES / "labor_prefix_spill_results.csv"
TOP1_THRESH = TABLES / "labor_top1_threshold.csv"
TEX         = TABLES / "labor_combined_spillover_results.tex"

OUTCOMES = ["lr_remdezr_w", "lr_remdezr_h_w", "l_firm_emp"]


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


def stars(p_val: str) -> str:
    p = float(p_val)
    if p < 0.01:
        return "***"
    if p < 0.05:
        return "**"
    if p < 0.10:
        return "*"
    return ""


def coef_cell(row: Dict[str, str]) -> str:
    return f"{fmt_num(row['b_post'])}{stars(row['p_post'])}"


def se_cell(row: Dict[str, str]) -> str:
    return f"({fmt_num(row['se_post'])})"


def pre_cell(row: Dict[str, str]) -> str:
    return f"{fmt_num(row['b_pre'])}{stars(row['p_pre'])}"


def pre_se_cell(row: Dict[str, str]) -> str:
    return f"({fmt_num(row['se_pre'])})"


def panel_block(label: str, rows: List[Dict[str, str]], addlinespace: bool = True) -> List[str]:
    lines = [
        rf"\multicolumn{{4}}{{l}}{{\textbf{{{label}}}}}\\",
        "Post $\\times$ Connectivity & "
            + " & ".join(coef_cell(r) for r in rows) + r"\\",
        " & " + " & ".join(se_cell(r) for r in rows) + r"\\",
        "Pre $\\times$ Connectivity & "
            + " & ".join(pre_cell(r) for r in rows) + r"\\",
        " & " + " & ".join(pre_se_cell(r) for r in rows) + r"\\",
        "Pre-trend p-value & "
            + " & ".join(f"[{float(r['pre_ftest_pval']):.4f}]" for r in rows) + r"\\",
        r"$N$ establishments & " + " & ".join(fmt_int(r["n_estab"]) for r in rows) + r"\\",
        r"$N$ observations & "   + " & ".join(fmt_int(r["n_obs"])   for r in rows) + r"\\",
    ]
    if addlinespace:
        lines.append(r"\addlinespace")
    return lines


def build_table() -> str:
    # ── Load data ────────────────────────────────────────────────────────────
    top1_data   = {(r["sample"], r["outcome"]): r for r in read_csv(TOP1_CSV)}
    prefix_data = {r["outcome"]: r for r in read_csv(PREFIX_CSV)}
    threshold   = read_csv(TOP1_THRESH)[0]

    baseline_rows = [top1_data[("baseline",              o)] for o in OUTCOMES]
    top1_rows     = [top1_data[("drop_top1_period1_numb", o)] for o in OUTCOMES]
    prefix_rows   = [prefix_data[o]                           for o in OUTCOMES]

    # ── Build LaTeX ──────────────────────────────────────────────────────────
    lines = [
        r"\begin{table}[H]",
        r"\centering",
        r"\caption{Robustness of Labor Spillover Estimates to Clause-Count Outlier Firms}",
        r"\label{tab:labor_combined_spillover}",
        r"\scriptsize",
        r"\begin{tabular}{lccc}",
        r"\toprule",
        r" & Monthly wage & Hourly wage & Employment \\",
        r"\midrule",
    ]

    lines += panel_block("(1) Baseline",                                  baseline_rows)
    lines += panel_block(r"(2) Drop top-1\% period-1 clause-count firms", top1_rows)
    lines += panel_block(r"(3) Drop prefix-10877926 firms",               prefix_rows, addlinespace=False)

    cutoff   = fmt_num(threshold["p99_numb_clause_cutoff"], 0)
    n_top1   = fmt_int(threshold["n_top1_firms"])

    lines += [
        r"\bottomrule",
        r"\end{tabular}",
        r"\begin{minipage}{\linewidth}",
        r"\footnotesize\vspace{4pt}",
        (
            r"\textit{Notes:} This table re-estimates the year-based spillover specification "
            r"across three samples. "
            r"\textbf{(1)} Full spillover sample (untreated, balanced-panel firms). "
            r"\textbf{(2)} Drops " + n_top1 + r" firms whose \texttt{cba\_period\,=\,1} "
            r"\texttt{numb\_clauses} is at or above the 99th-percentile cross-sectional cutoff "
            r"(" + cutoff + r" clauses). "
            r"\textbf{(3)} Drops firms with CNPJ prefix 10877926, which account for a "
            r"disproportionate share of the cross-sectional clause count. "
            r"Connectivity is normalized by the 90th percentile of the 2009 spillover-sample "
            r"distribution. Monthly wage is \texttt{lr\_remdezr\_w}; hourly wage is "
            r"\texttt{lr\_remdezr\_h\_w}. All specifications include establishment fixed effects "
            r"and year interactions with industry, negotiation month, and microregion, plus "
            r"quartile-bin controls for pre-treatment outcome, pre-treatment log employment, and "
            r"average per-worker flows during 2007--2011. "
            r"Standard errors clustered by establishment in parentheses. "
            r"*** p$<$0.01, ** p$<$0.05, * p$<$0.10."
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
