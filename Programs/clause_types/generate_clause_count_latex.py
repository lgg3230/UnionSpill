#!/usr/bin/env python3
"""
Generate direct and spillover LaTeX tables for clause-count outcomes.
"""

import re
from pathlib import Path


PROJECT = Path(__file__).resolve().parents[2]
TABLES = PROJECT / "Tables" / "clause_types"

DIRECT_FILES = {
    "A": TABLES / "results_direct_panelA_clause_counts_tfpw_07_11.csv",
    "B": TABLES / "results_direct_panelB_clause_counts_tfpw_07_11.csv",
    "C": TABLES / "results_direct_panelC_clause_counts_tfpw_07_11.csv",
}
SPILL_FILE = TABLES / "results_spill_clause_counts_tfpw_07_11.csv"

DIRECT_TEX = TABLES / "clause_count_direct_effects.tex"
SPILL_TEX = TABLES / "clause_count_spillover_effects.tex"

OUTCOMES = ["numb_clauses", "wage_clauses", "emp_clauses", "other_clauses"]
COL_HEADERS = ["Overall clauses", "Wage clauses", "Employment clauses", "Other clauses"]


def load_csv(path: Path) -> dict[str, dict[str, str]]:
    data: dict[str, dict[str, str]] = {}
    with open(path, "r", encoding="utf-8") as f:
        next(f)
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = line.replace('"', "").split(";")
            if len(parts) < 5:
                continue
            _, _, outcome, row_type, value = parts[:5]
            data.setdefault(outcome, {})[row_type] = value.strip()
    return data


def fmt(raw: str, *, se: bool = False, count: bool = False, pval: bool = False) -> str:
    raw = raw.strip()
    if raw in ("", "--"):
        return "--"
    if count:
        return raw.replace(",", "{,}")
    if pval:
        return f"[{raw}]"
    m = re.match(r"^([^*]+?)(\*{1,3})?$", raw)
    if not m:
        return raw
    num = m.group(1).strip()
    stars = m.group(2) or ""
    if num.startswith("-"):
        num = r"$-$" + num[1:]
    return f"({num})" if se else f"{num}{stars}"


def getv(data: dict[str, dict[str, str]], outcome: str, row: str, **kw) -> str:
    try:
        return fmt(data[outcome][row], **kw)
    except KeyError:
        return "--"


def build_direct_table() -> str:
    panels = {k: load_csv(v) for k, v in DIRECT_FILES.items()}
    lines: list[str] = []
    lines += [
        r"\begin{table}[!htbp]",
        r"\centering",
        r"\caption{Direct Effects on Clause Counts}",
        r"\label{tab:clause_count_direct}",
        r"\scriptsize",
        r"\begin{tabular}{lcccc}",
        r"\toprule",
        r" & Overall & Wage & Employment & Other \\",
        r" & clauses & clauses & clauses & clauses \\",
        r"\midrule",
    ]

    for panel in ["A", "B", "C"]:
        data = panels[panel]
        lines.append(rf"\multicolumn{{5}}{{l}}{{\textbf{{Panel {panel}}}}}\\")
        lines.append(
            {
                "A": r"\multicolumn{5}{l}{\textit{Control group: zero connectivity untreated firms}}\\",
                "B": r"\multicolumn{5}{l}{\textit{Control group: untreated firms with connectivity $\leq 1\%$}}\\",
                "C": r"\multicolumn{5}{l}{\textit{Control group: all untreated firms}}\\",
            }[panel]
        )
        lines.append(
            "Post $\\times$ Treatment & " + " & ".join(getv(data, o, "main") for o in OUTCOMES) + r"\\"
        )
        lines.append(
            " & " + " & ".join(getv(data, o, "main_se", se=True) for o in OUTCOMES) + r"\\"
        )
        lines.append(
            "Pre $\\times$ Treatment & " + " & ".join(getv(data, o, "pre") for o in OUTCOMES) + r"\\"
        )
        lines.append(
            " & " + " & ".join(getv(data, o, "pre_se", se=True) for o in OUTCOMES) + r"\\"
        )
        lines.append(
            "Pre-trend p-value & " + " & ".join(getv(data, o, "pre_pval", pval=True) for o in OUTCOMES) + r"\\"
        )
        lines.append(
            r"$N$ establishments & " + " & ".join(getv(data, o, "n_estab", count=True) for o in OUTCOMES) + r"\\"
        )
        lines.append(
            r"$N$ observations & " + " & ".join(getv(data, o, "n_obs", count=True) for o in OUTCOMES) + r"\\"
        )
        if panel != "C":
            lines.append(r"\addlinespace")

    lines += [
        r"\bottomrule",
        r"\end{tabular}",
        r"\begin{minipage}{\linewidth}",
        r"\footnotesize\vspace{4pt}",
        r"\textit{Notes:} This table reports direct effects of the 2012 ultractivity reform on the number of clauses in firms' collective bargaining agreements. Column~1 reports the total number of clauses. Columns~2--4 decompose that total into wage clauses, employment clauses, and other clauses. Treated firms are establishments whose agreement was directly affected by the reform. Panel~A uses untreated firms with zero pre-reform worker-flow connectivity to treated firms as controls; Panel~B restricts the control group to untreated firms with connectivity of at most 1\%; Panel~C includes all untreated firms. ``Post $\times$ Treatment'' reports the average post-reform effect, and ``Pre $\times$ Treatment'' reports the corresponding placebo coefficient estimated from pre-reform CBA periods only. All specifications include establishment fixed effects, CBA-period interactions with industry, negotiation month, and microregion, and quartile-bin controls for the pre-treatment outcome, pre-treatment log employment, and average per-worker worker flows during 2007--2011. Standard errors clustered by establishment are reported in parentheses. The pre-trend p-value is from a test of differential pre-trends across pre-reform CBA periods. *** p$<$0.01, ** p$<$0.05, * p$<$0.10.",
        r"\end{minipage}",
        r"\end{table}",
    ]
    return "\n".join(lines) + "\n"


def build_spill_table() -> str:
    data = load_csv(SPILL_FILE)
    lines: list[str] = []
    lines += [
        r"\begin{table}[!htbp]",
        r"\centering",
        r"\caption{Spillover Effects on Clause Counts}",
        r"\label{tab:clause_count_spill}",
        r"\scriptsize",
        r"\begin{tabular}{lcccc}",
        r"\toprule",
        r" & Overall & Wage & Employment & Other \\",
        r" & clauses & clauses & clauses & clauses \\",
        r"\midrule",
        "Post $\\times$ Connectivity & " + " & ".join(getv(data, o, "main") for o in OUTCOMES) + r"\\",
        " & " + " & ".join(getv(data, o, "main_se", se=True) for o in OUTCOMES) + r"\\",
        "Pre $\\times$ Connectivity & " + " & ".join(getv(data, o, "pre") for o in OUTCOMES) + r"\\",
        " & " + " & ".join(getv(data, o, "pre_se", se=True) for o in OUTCOMES) + r"\\",
        "Pre-trend p-value & " + " & ".join(getv(data, o, "pre_pval", pval=True) for o in OUTCOMES) + r"\\",
        r"$N$ establishments & " + " & ".join(getv(data, o, "n_estab", count=True) for o in OUTCOMES) + r"\\",
        r"$N$ observations & " + " & ".join(getv(data, o, "n_obs", count=True) for o in OUTCOMES) + r"\\",
        r"\bottomrule",
        r"\end{tabular}",
        r"\begin{minipage}{\linewidth}",
        r"\footnotesize\vspace{4pt}",
        r"\textit{Notes:} This table reports spillover effects of the 2012 ultractivity reform on the number of clauses in collective bargaining agreements at untreated firms. Column~1 reports the total number of clauses. Columns~2--4 decompose that total into wage clauses, employment clauses, and other clauses. The sample is restricted to untreated establishments in the Lagos balanced-panel spillover sample. Connectivity is the firm's pre-reform worker-flow exposure to treated firms, normalized by the 90th percentile of the 2009 spillover-sample distribution. ``Post $\times$ Connectivity'' reports the average post-reform spillover effect, and ``Pre $\times$ Connectivity'' reports the corresponding placebo coefficient estimated from pre-reform CBA periods only. All specifications include establishment fixed effects, CBA-period interactions with industry, negotiation month, and microregion, and quartile-bin controls for the pre-treatment outcome, pre-treatment log employment, and average per-worker worker flows during 2007--2011. Standard errors clustered by establishment are reported in parentheses. The pre-trend p-value is from a test of differential pre-trends with respect to connectivity across pre-reform CBA periods. *** p$<$0.01, ** p$<$0.05, * p$<$0.10.",
        r"\end{minipage}",
        r"\end{table}",
    ]
    return "\n".join(lines) + "\n"


def main() -> None:
    DIRECT_TEX.write_text(build_direct_table(), encoding="utf-8")
    SPILL_TEX.write_text(build_spill_table(), encoding="utf-8")
    print(f"Wrote {DIRECT_TEX}")
    print(f"Wrote {SPILL_TEX}")


if __name__ == "__main__":
    main()
