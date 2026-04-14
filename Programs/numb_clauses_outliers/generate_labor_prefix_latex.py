#!/usr/bin/env python3
"""
Generate LaTeX tables for prefix-excluded labor outcome estimates.
"""

import csv
from pathlib import Path
from typing import Dict, List, Tuple


PROJECT = Path(__file__).resolve().parents[2]
TABLES = PROJECT / "Tables" / "numb_clauses_outliers"

DIRECT = TABLES / "labor_prefix_direct_results.csv"
SPILL = TABLES / "labor_prefix_spill_results.csv"
DIRECT_TEX = TABLES / "labor_prefix_direct_effects.tex"
SPILL_TEX = TABLES / "labor_prefix_spillover_effects.tex"

OUTCOMES = ["lr_remdezr_w", "lr_remdezr_h_w", "l_firm_emp"]
HEADERS = ["Monthly wage", "Hourly wage", "Employment"]


def read_csv(path: Path) -> List[Dict[str, str]]:
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def index_rows(rows: List[Dict[str, str]]) -> Dict[Tuple[str, str], Dict[str, str]]:
    return {(row["section"], row["outcome"]): row for row in rows}


def fmt_num(value: str, digits: int = 4) -> str:
    num = f"{float(value):.{digits}f}"
    if num.startswith("-"):
        num = r"$-$" + num[1:]
    return num


def fmt_int(value: str) -> str:
    return f"{int(float(value)):,}".replace(",", "{,}")


def stars(pval: str) -> str:
    p = float(pval)
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


def build_direct() -> str:
    data = index_rows(read_csv(DIRECT))
    lines = [
        r"\begin{table}[!htbp]",
        r"\centering",
        r"\caption{Direct Effects on Labor Outcomes, Excluding Prefix 10877926 Firms}",
        r"\label{tab:labor_prefix_direct}",
        r"\scriptsize",
        r"\begin{tabular}{lccc}",
        r"\toprule",
        r" & Monthly wage & Hourly wage & Employment \\",
        r"\midrule",
    ]
    panel_notes = {
        "direct_A": r"Control group: zero connectivity untreated firms",
        "direct_B": r"Control group: untreated firms with connectivity $\leq 1\%$",
        "direct_C": r"Control group: all untreated firms",
    }
    for idx, section in enumerate(["direct_A", "direct_B", "direct_C"]):
        panel = section[-1]
        lines.append(rf"\multicolumn{{4}}{{l}}{{\textbf{{Panel {panel}}}}}\\")
        lines.append(rf"\multicolumn{{4}}{{l}}{{\textit{{{panel_notes[section]}}}}}\\")
        rows = [data[(section, outcome)] for outcome in OUTCOMES]
        lines.append("Post $\\times$ Treatment & " + " & ".join(coef(row, "b_post") for row in rows) + r"\\")
        lines.append(" & " + " & ".join(se(row, "se_post") for row in rows) + r"\\")
        lines.append("Pre $\\times$ Treatment & " + " & ".join(coef(row, "b_pre") for row in rows) + r"\\")
        lines.append(" & " + " & ".join(se(row, "se_pre") for row in rows) + r"\\")
        lines.append("Pre-trend p-value & " + " & ".join(f"[{float(row['pre_ftest_pval']):.4f}]" for row in rows) + r"\\")
        lines.append(r"$N$ establishments & " + " & ".join(fmt_int(row["n_estab"]) for row in rows) + r"\\")
        lines.append(r"$N$ observations & " + " & ".join(fmt_int(row["n_obs"]) for row in rows) + r"\\")
        if idx != 2:
            lines.append(r"\addlinespace")
    lines += [
        r"\bottomrule",
        r"\end{tabular}",
        r"\begin{minipage}{\linewidth}",
        r"\footnotesize\vspace{4pt}",
        (
            r"\textit{Notes:} This table re-estimates the year-based direct-effect "
            r"specification from \texttt{Main\_Results\_pct\_tfpw\_07\_11.do}, excluding "
            r"all firms whose \texttt{identificad} starts with \texttt{10877926}. "
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


def build_spill() -> str:
    rows = read_csv(SPILL)
    data = {row["outcome"]: row for row in rows}
    rows = [data[outcome] for outcome in OUTCOMES]
    lines = [
        r"\begin{table}[!htbp]",
        r"\centering",
        r"\caption{Spillover Effects on Labor Outcomes, Excluding Prefix 10877926 Firms}",
        r"\label{tab:labor_prefix_spill}",
        r"\scriptsize",
        r"\begin{tabular}{lccc}",
        r"\toprule",
        r" & Monthly wage & Hourly wage & Employment \\",
        r"\midrule",
        "Post $\\times$ Connectivity & " + " & ".join(coef(row, "b_post") for row in rows) + r"\\",
        " & " + " & ".join(se(row, "se_post") for row in rows) + r"\\",
        "Pre $\\times$ Connectivity & " + " & ".join(coef(row, "b_pre") for row in rows) + r"\\",
        " & " + " & ".join(se(row, "se_pre") for row in rows) + r"\\",
        "Pre-trend p-value & " + " & ".join(f"[{float(row['pre_ftest_pval']):.4f}]" for row in rows) + r"\\",
        r"$N$ establishments & " + " & ".join(fmt_int(row["n_estab"]) for row in rows) + r"\\",
        r"$N$ observations & " + " & ".join(fmt_int(row["n_obs"]) for row in rows) + r"\\",
        r"\bottomrule",
        r"\end{tabular}",
        r"\begin{minipage}{\linewidth}",
        r"\footnotesize\vspace{4pt}",
        (
            r"\textit{Notes:} This table re-estimates the year-based spillover "
            r"specification from \texttt{Main\_Results\_pct\_tfpw\_07\_11.do}, excluding "
            r"all firms whose \texttt{identificad} starts with \texttt{10877926}. "
            r"Connectivity is normalized by the 90th percentile of the 2009 spillover-sample "
            r"distribution. Monthly wage is \texttt{lr\_remdezr\_w}; hourly wage is "
            r"\texttt{lr\_remdezr\_h\_w}. All specifications include establishment fixed effects, "
            r"year interactions with industry, negotiation month, and microregion, and quartile-bin "
            r"controls for the pre-treatment outcome, pre-treatment log employment, and average "
            r"per-worker worker flows during 2007--2011. Standard errors clustered by establishment "
            r"are in parentheses. *** p$<$0.01, ** p$<$0.05, * p$<$0.10."
        ),
        r"\end{minipage}",
        r"\end{table}",
    ]
    return "\n".join(lines) + "\n"


def main() -> None:
    DIRECT_TEX.write_text(build_direct(), encoding="utf-8")
    SPILL_TEX.write_text(build_spill(), encoding="utf-8")
    print(f"Wrote {DIRECT_TEX}")
    print(f"Wrote {SPILL_TEX}")


if __name__ == "__main__":
    main()
