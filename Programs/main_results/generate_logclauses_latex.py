#!/usr/bin/env python3
"""
Generate the two LaTeX tables requested by Luis:

  Table 1  main_logclauses.tex
    Main outcomes + log clause count, for direct effects (Panels A/B/C) and
    the spillover effect (Panel D). Columns:
      Log earnings | Log hourly earnings | Log employment | Clause count |
      Log clause count
    Each panel reports the post coefficient, the pre-period placebo coefficient,
    the pre-trend p-value, and the numbers of establishments and observations.

  Table 2  clausetypes_logclauses_direct.tex
    The clause-type direct-effects table (Overall / Wage / Employment / Other
    clauses) with Log overall clauses added as the last column. Panels A/B/C.

Both read the ';'-delimited CSVs written by main_logclauses.do, keyed by
(section, outcome, row_type).
"""

import re
from pathlib import Path
from typing import Dict, List

PROJECT = Path(__file__).resolve().parents[2]
TABLES = PROJECT / "Tables" / "logclauses"

MAIN_CSV = TABLES / "main_logclauses.csv"
CTYPE_CSV = TABLES / "clausetypes_logclauses_direct.csv"
ACC_CSV = TABLES / "logclauses_obs_accounting.csv"

MAIN_TEX = TABLES / "main_logclauses.tex"
CTYPE_TEX = TABLES / "clausetypes_logclauses_direct.tex"

# ── Table 1 columns ───────────────────────────────────────────────────────────
MAIN_OUTCOMES = ["lr_remdezr_w", "lr_remdezr_h_w", "l_firm_emp",
                 "numb_clauses", "l_numb_clauses"]
MAIN_HEAD_1 = ["Log", "Log hourly", "Log", "Clause", "Log clause"]
MAIN_HEAD_2 = ["earnings", "earnings", "employment", "count", "count"]

# ── Table 2 columns ───────────────────────────────────────────────────────────
CTYPE_OUTCOMES = ["numb_clauses", "wage_clauses", "emp_clauses",
                  "other_clauses", "l_numb_clauses"]
CTYPE_HEAD_1 = ["Overall", "Wage", "Employment", "Other", "Log overall"]
CTYPE_HEAD_2 = ["clauses", "clauses", "clauses", "clauses", "clauses"]

PANEL_DESC = {
    "direct_A": r"\textit{Control group: zero-connectivity untreated firms}",
    "direct_B": r"\textit{Control group: untreated firms with connectivity $\leq 1\%$}",
    "direct_C": r"\textit{Control group: all untreated firms}",
    "spill":    r"\textit{Sample: untreated firms; exposure = worker-flow connectivity to treated}",
}
PANEL_LETTER = {"direct_A": "A", "direct_B": "B", "direct_C": "C", "spill": "D"}


def load_csv(path: Path) -> Dict[str, Dict[str, Dict[str, str]]]:
    """Return data[section][outcome][row_type] = value."""
    data: Dict[str, Dict[str, Dict[str, str]]] = {}
    with open(path, "r", encoding="utf-8") as f:
        next(f)
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = line.replace('"', "").split(";")
            if len(parts) < 4:
                continue
            section, outcome, row_type, value = parts[:4]
            data.setdefault(section, {}).setdefault(outcome, {})[row_type] = value.strip()
    return data


def load_accounting(path: Path) -> Dict[str, Dict[str, str]]:
    rows: Dict[str, Dict[str, str]] = {}
    with open(path, "r", encoding="utf-8") as f:
        header = next(f).strip().split(";")
        for line in f:
            vals = line.strip().split(";")
            if len(vals) != len(header):
                continue
            d = dict(zip(header, vals))
            rows[d["sample"]] = d
    return rows


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


def getv(sec: Dict[str, Dict[str, str]], outcome: str, row: str, **kw) -> str:
    try:
        return fmt(sec[outcome][row], **kw)
    except KeyError:
        return "--"


def panel_block(section: str, sec: Dict[str, Dict[str, str]], outcomes: List[str],
                ncol: int) -> List[str]:
    interact = "Connectivity" if section == "spill" else "Treatment"
    lines = [
        rf"\multicolumn{{{ncol}}}{{l}}{{\textbf{{Panel {PANEL_LETTER[section]}}}}}\\",
        rf"\multicolumn{{{ncol}}}{{l}}{{{PANEL_DESC[section]}}}\\",
        rf"Post $\times$ {interact} & " + " & ".join(getv(sec, o, "main") for o in outcomes) + r"\\",
        " & " + " & ".join(getv(sec, o, "main_se", se=True) for o in outcomes) + r"\\",
        rf"Pre $\times$ {interact} & " + " & ".join(getv(sec, o, "pre") for o in outcomes) + r"\\",
        " & " + " & ".join(getv(sec, o, "pre_se", se=True) for o in outcomes) + r"\\",
        "Pre-trend p-value & " + " & ".join(getv(sec, o, "pre_pval", pval=True) for o in outcomes) + r"\\",
        r"$N$ establishments & " + " & ".join(getv(sec, o, "n_estab", count=True) for o in outcomes) + r"\\",
        r"$N$ observations & " + " & ".join(getv(sec, o, "n_obs", count=True) for o in outcomes) + r"\\",
    ]
    return lines


def header_rows(h1: List[str], h2: List[str]) -> List[str]:
    return [
        " & " + " & ".join(h1) + r" \\",
        " & " + " & ".join(h2) + r" \\",
    ]


def build_main_table(data) -> str:
    ncol = len(MAIN_OUTCOMES) + 1
    lines = [
        r"\begin{table}[!htbp]",
        r"\centering",
        r"\caption{Main Outcomes and Log Clause Count: Direct and Spillover Effects}",
        r"\label{tab:main_logclauses}",
        r"\scriptsize",
        r"\begin{tabular}{l" + "c" * len(MAIN_OUTCOMES) + "}",
        r"\toprule",
        *header_rows(MAIN_HEAD_1, MAIN_HEAD_2),
        r"\midrule",
    ]
    for i, section in enumerate(["direct_A", "direct_B", "direct_C", "spill"]):
        lines += panel_block(section, data.get(section, {}), MAIN_OUTCOMES, ncol)
        if section != "spill":
            lines.append(r"\addlinespace")
    lines += [
        r"\bottomrule",
        r"\end{tabular}",
        r"\begin{minipage}{\linewidth}",
        r"\footnotesize\vspace{4pt}",
        r"\textit{Notes:} This table reports direct and spillover effects of the 2012 "
        r"ultractivity reform on the main firm-level outcomes plus the (log) number of "
        r"clauses in the firm's collective bargaining agreement. Columns~1--3 are log "
        r"December earnings, log hourly December earnings, and log December employment, "
        r"estimated on the yearly panel with 2011 as the reference year. Column~4 is the "
        r"clause count and Column~5 is its log, $\ln(\text{clauses})$, both estimated on "
        r"the CBA-negotiation-period panel with the second pre-reform period as reference. "
        r"Panels~A--C report direct effects (treated vs.\ untreated controls): Panel~A uses "
        r"untreated firms with zero pre-reform worker-flow connectivity to treated firms, "
        r"Panel~B those with connectivity of at most 1\%, and Panel~C all untreated firms. "
        r"Panel~D reports spillover effects, where exposure is the firm's pre-reform "
        r"worker-flow connectivity to treated firms, normalized by the 90th percentile of "
        r"the 2009 spillover-sample distribution. ``Post'' is the average post-reform effect "
        r"and ``Pre'' the corresponding placebo from pre-reform periods only. All "
        r"specifications include establishment fixed effects, period interactions with "
        r"industry, negotiation month, and microregion, and quartile-bin controls for the "
        r"pre-treatment outcome, pre-treatment log employment, and average per-worker worker "
        r"flows during 2007--2011. The log clause count uses the same controls as the clause "
        r"count, except that $\ln(\text{clauses})$ drops the few firm-period observations with "
        r"exactly zero clauses. Standard "
        r"errors clustered by establishment in parentheses; pre-trend $p$-values in brackets. "
        r"*** p$<$0.01, ** p$<$0.05, * p$<$0.10.",
        r"\end{minipage}",
        r"\end{table}",
    ]
    return "\n".join(lines) + "\n"


def build_ctype_table(data) -> str:
    ncol = len(CTYPE_OUTCOMES) + 1
    lines = [
        r"\begin{table}[!htbp]",
        r"\centering",
        r"\caption{Direct Effects on Clause Counts, with Log Clause Count}",
        r"\label{tab:clause_count_direct_logcol}",
        r"\scriptsize",
        r"\begin{tabular}{l" + "c" * len(CTYPE_OUTCOMES) + "}",
        r"\toprule",
        *header_rows(CTYPE_HEAD_1, CTYPE_HEAD_2),
        r"\midrule",
    ]
    for section in ["direct_A", "direct_B", "direct_C"]:
        lines += panel_block(section, data.get(section, {}), CTYPE_OUTCOMES, ncol)
        if section != "direct_C":
            lines.append(r"\addlinespace")
    lines += [
        r"\bottomrule",
        r"\end{tabular}",
        r"\begin{minipage}{\linewidth}",
        r"\footnotesize\vspace{4pt}",
        r"\textit{Notes:} This table reports direct effects of the 2012 ultractivity reform "
        r"on the number of clauses in firms' collective bargaining agreements. Column~1 is the "
        r"total number of clauses; Columns~2--4 decompose that total into wage, employment, and "
        r"other clauses; Column~5 is the log of the total, $\ln(\text{clauses})$. Treated firms "
        r"are establishments whose agreement was directly affected by the reform. Panel~A uses "
        r"untreated firms with zero pre-reform worker-flow connectivity to treated firms as "
        r"controls; Panel~B restricts the control group to connectivity of at most 1\%; Panel~C "
        r"includes all untreated firms. ``Post $\times$ Treatment'' is the average post-reform "
        r"effect and ``Pre $\times$ Treatment'' the corresponding placebo estimated from pre-reform "
        r"CBA periods only. All specifications include establishment fixed effects, CBA-period "
        r"interactions with industry, negotiation month, and microregion, and quartile-bin controls "
        r"for the pre-treatment outcome, pre-treatment log employment, and average per-worker worker "
        r"flows during 2007--2011. The log column uses the same controls as Column~1 but drops "
        r"the few firm-period observations with zero clauses. Standard errors clustered by "
        r"establishment in parentheses; pre-trend "
        r"$p$-values in brackets. *** p$<$0.01, ** p$<$0.05, * p$<$0.10.",
        r"\end{minipage}",
        r"\end{table}",
    ]
    return "\n".join(lines) + "\n"


def main() -> None:
    main_data = load_csv(MAIN_CSV)
    ctype_data = load_csv(CTYPE_CSV)
    MAIN_TEX.write_text(build_main_table(main_data), encoding="utf-8")
    CTYPE_TEX.write_text(build_ctype_table(ctype_data), encoding="utf-8")
    print(f"Wrote {MAIN_TEX}")
    print(f"Wrote {CTYPE_TEX}")

    if ACC_CSV.exists():
        acc = load_accounting(ACC_CSV)
        print("\nObs accounting (log transform):")
        print(f"{'sample':>7} {'N obs':>9} {'N firms':>9} {'zero-clause obs':>16} {'missing obs':>12}")
        for s in ["A", "B", "C", "spill"]:
            if s in acc:
                d = acc[s]
                print(f"{s:>7} {d['n_obs']:>9} {d['n_firms']:>9} "
                      f"{d['n_obs_zero']:>16} {d['n_obs_missing']:>12}")


if __name__ == "__main__":
    main()
