#!/usr/bin/env python3
"""
Generate LaTeX tables for the numb_clauses outlier pipeline.
"""

import csv
from pathlib import Path
from typing import Dict, List


PROJECT = Path(__file__).resolve().parents[2]
TABLES = PROJECT / "Tables" / "numb_clauses_outliers"

THRESHOLD = TABLES / "top1_numb_clause_threshold.csv"
FIRMS = TABLES / "top1_numb_clause_firms.csv"
PREFIXES = TABLES / "top1_numb_clause_prefix_summary.csv"
RESULTS = TABLES / "spillover_clause_count_outlier_results.csv"

PREFIX_TEX = TABLES / "numb_clause_outlier_prefixes.tex"
FIRMS_TEX = TABLES / "numb_clause_outlier_firms.tex"
RESULTS_TEX = TABLES / "numb_clause_outlier_spillover_results.tex"

OUTCOMES = ["numb_clauses", "wage_clauses", "emp_clauses", "other_clauses"]
HEADERS = {
    "numb_clauses": "Overall",
    "wage_clauses": "Wage",
    "emp_clauses": "Employment",
    "other_clauses": "Other",
}
SAMPLES = {
    "baseline": "Baseline",
    "drop_top1_firms": "Drop top-1\\% firms",
    "drop_prefix_10877926": "Drop prefix 10877926 firms",
}


def read_csv(path: Path) -> List[Dict[str, str]]:
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def tex_num(value: str, digits: int = 3) -> str:
    if value is None or value == "":
        return "--"
    return f"{float(value):.{digits}f}"


def tex_int(value: str) -> str:
    if value is None or value == "":
        return "--"
    return f"{int(float(value)):,}".replace(",", "{,}")


def stars(p: str) -> str:
    pval = float(p)
    if pval < 0.01:
        return "***"
    if pval < 0.05:
        return "**"
    if pval < 0.10:
        return "*"
    return ""


def coef(value: str, p: str) -> str:
    num = tex_num(value, 4)
    if num.startswith("-"):
        num = r"$-$" + num[1:]
    return f"{num}{stars(p)}"


def se(value: str) -> str:
    num = tex_num(value, 4)
    if num.startswith("-"):
        num = r"$-$" + num[1:]
    return f"({num})"


def pct(value: str, digits: int = 1) -> str:
    return f"{100 * float(value):.{digits}f}"


def build_prefix_table() -> str:
    threshold = read_csv(THRESHOLD)[0]
    rows = read_csv(PREFIXES)[:15]
    lines = [
        r"\begin{table}[!htbp]",
        r"\centering",
        r"\caption{First-8-Digit Concentration Among Top-1\% Period-1 Clause-Count Firms}",
        r"\label{tab:numb_clause_outlier_prefixes}",
        r"\scriptsize",
        r"\begin{tabular}{lrrrr}",
        r"\toprule",
        r"First 8 digits & Firms & Share (\%) & Mean clauses & Max clauses \\",
        r"\midrule",
    ]
    for row in rows:
        lines.append(
            f"{row['id8']} & {tex_int(row['n_firms'])} & {pct(row['share_top1_firms'])} & "
            f"{tex_num(row['mean_period1_numb'], 1)} & {tex_num(row['max_period1_numb'], 0)}" + r"\\"
        )
    lines += [
        r"\bottomrule",
        r"\end{tabular}",
        r"\begin{minipage}{\linewidth}",
        r"\footnotesize\vspace{4pt}",
        (
            r"\textit{Notes:} The table reports the most common first-8-digit "
            r"\texttt{identificad} prefixes among firms in the top 1\% of the "
            r"spillover \texttt{cba\_period == 1} cross-section of total clauses. The cutoff is "
            f"{tex_num(threshold['p99_numb_clause_cutoff'], 0)} clauses. "
            f"The top-1\\% set contains {tex_int(threshold['n_top1_firms'])} firms "
            f"out of {tex_int(threshold['n_period1_spillover_firms'])} period-1 spillover firms."
        ),
        r"\end{minipage}",
        r"\end{table}",
    ]
    return "\n".join(lines) + "\n"


def build_firm_table() -> str:
    threshold = read_csv(THRESHOLD)[0]
    rows = read_csv(FIRMS)[:20]
    lines = [
        r"\begin{table}[!htbp]",
        r"\centering",
        r"\caption{Largest Top-1\% Period-1 Clause-Count Firms}",
        r"\label{tab:numb_clause_outlier_firms}",
        r"\scriptsize",
        r"\begin{tabular}{llrrrr}",
        r"\toprule",
        r"Firm ID & First 8 & Clauses & Connectivity & Employment & Industry \\",
        r"\midrule",
    ]
    for row in rows:
        lines.append(
            f"{row['identificad']} & {row['id8']} & {tex_num(row['firm_period1_numb'], 0)} & "
            f"{tex_num(row['firm_conn'], 2)} & {tex_num(row['firm_emp_pre'], 1)} & {row['industry1']}" + r"\\"
        )
    lines += [
        r"\bottomrule",
        r"\end{tabular}",
        r"\begin{minipage}{\linewidth}",
        r"\footnotesize\vspace{4pt}",
        (
            r"\textit{Notes:} Firms are sorted by their total clause count in the "
            r"\texttt{cba\_period == 1} spillover cross-section, with connectivity used as the secondary sort. "
            f"The top-1\\% cutoff is {tex_num(threshold['p99_numb_clause_cutoff'], 0)} clauses."
        ),
        r"\end{minipage}",
        r"\end{table}",
    ]
    return "\n".join(lines) + "\n"


def build_results_table() -> str:
    rows = read_csv(RESULTS)
    data = {(row["sample"], row["outcome"]): row for row in rows}
    lines = [
        r"\begin{table}[!htbp]",
        r"\centering",
        r"\caption{Spillover Clause-Count Estimates After Removing Period-1 Outlier and Prefix Firms}",
        r"\label{tab:numb_clause_outlier_spillover_results}",
        r"\scriptsize",
        r"\begin{tabular}{lcccc}",
        r"\toprule",
        r" & Overall & Wage & Employment & Other \\",
        r" & clauses & clauses & clauses & clauses \\",
        r"\midrule",
    ]
    sample_items = list(SAMPLES.items())
    for idx, (sample, label) in enumerate(sample_items):
        lines.append(rf"\multicolumn{{5}}{{l}}{{\textbf{{{label}}}}}\\")
        lines.append(
            "Post $\\times$ Connectivity & "
            + " & ".join(coef(data[(sample, o)]["b_post"], data[(sample, o)]["p_post"]) for o in OUTCOMES)
            + r"\\"
        )
        lines.append(
            " & " + " & ".join(se(data[(sample, o)]["se_post"]) for o in OUTCOMES) + r"\\"
        )
        lines.append(
            "Pre $\\times$ Connectivity & "
            + " & ".join(coef(data[(sample, o)]["b_pre"], data[(sample, o)]["p_pre"]) for o in OUTCOMES)
            + r"\\"
        )
        lines.append(
            " & " + " & ".join(se(data[(sample, o)]["se_pre"]) for o in OUTCOMES) + r"\\"
        )
        lines.append(
            "Pre-trend p-value & "
            + " & ".join(f"[{tex_num(data[(sample, o)]['pre_ftest_pval'], 4)}]" for o in OUTCOMES)
            + r"\\"
        )
        lines.append(
            r"$N$ establishments & "
            + " & ".join(tex_int(data[(sample, o)]["n_estab"]) for o in OUTCOMES)
            + r"\\"
        )
        lines.append(
            r"$N$ observations & "
            + " & ".join(tex_int(data[(sample, o)]["n_obs"]) for o in OUTCOMES)
            + r"\\"
        )
        if idx != len(sample_items) - 1:
            lines.append(r"\addlinespace")
    lines += [
        r"\bottomrule",
        r"\end{tabular}",
        r"\begin{minipage}{\linewidth}",
        r"\footnotesize\vspace{4pt}",
        (
            r"\textit{Notes:} The baseline sample is the untreated Lagos balanced-panel spillover sample. "
            r"The first trimmed sample removes firms in the top 1\% of the \texttt{cba\_period == 1} total "
            r"clause-count cross-section. The second trimmed sample removes all spillover firms whose "
            r"\texttt{identificad} starts with \texttt{10877926}. Connectivity is normalized by the 90th percentile of the 2009 spillover-sample "
            r"distribution. All specifications include establishment fixed effects, CBA-period interactions "
            r"with industry, negotiation month, and microregion, and quartile-bin controls for the pre-treatment "
            r"outcome, pre-treatment log employment, and average per-worker worker flows during 2007--2011. "
            r"Standard errors clustered by establishment are reported in parentheses. *** p$<$0.01, "
            r"** p$<$0.05, * p$<$0.10."
        ),
        r"\end{minipage}",
        r"\end{table}",
    ]
    return "\n".join(lines) + "\n"


def main() -> None:
    PREFIX_TEX.write_text(build_prefix_table(), encoding="utf-8")
    FIRMS_TEX.write_text(build_firm_table(), encoding="utf-8")
    RESULTS_TEX.write_text(build_results_table(), encoding="utf-8")
    print(f"Wrote {PREFIX_TEX}")
    print(f"Wrote {FIRMS_TEX}")
    print(f"Wrote {RESULTS_TEX}")


if __name__ == "__main__":
    main()
