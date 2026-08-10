#!/usr/bin/env python3
"""
Generate LaTeX table for alternative connectivity measures robustness.

Structure:
  - Two outcome-panel blocks (Panel I: avg_ftreat_pf_n, Panel II: totaltreat_pf_n)
  - Four outcome columns: Log Wages, Log Hourly Wages, Log Employment, # CBA Clauses
  - Rows: Post × Connectivity, (SE), Pre × Connectivity, (SE),
          Pre-trend p-value, Observations, Establishments

Output: Tables/robustness/alt_conn_table.tex
"""

import re
from pathlib import Path


SPECS = [
    ("avg_ftreat_pf_n",  r"\shortstack{Panel I \\ Avg Flow Share \\ to Treated}"),
    ("totaltreat_pf_n",  r"\shortstack{Panel II \\ Prop.\ Flows \\ to Treated}"),
]

OUTCOMES = [
    ("lr_remdezr_w",   "Log Wages"),
    ("lr_remdezr_h_w", "Log Hourly Wages"),
    ("l_firm_emp",     "Log Employment"),
    ("numb_clauses",   r"\# CBA Clauses"),
]


# ── CSV parsing ────────────────────────────────────────────────────────────────

def load_csv(filepath):
    """Returns {spec: {outcome: {row_type: value}}}."""
    data = {}
    if not filepath.exists():
        print(f"  WARNING: {filepath.name} not found.")
        return data
    with open(filepath) as f:
        next(f)
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = line.replace('"', '').split(";")
            if len(parts) < 5:
                continue
            spec, _section, outcome, row_type, value = (
                parts[0], parts[1], parts[2], parts[3], parts[4]
            )
            data.setdefault(spec, {}).setdefault(outcome, {})[row_type] = value.strip()
    return data


def fmt(raw, is_se=False, is_count=False, is_pval=False):
    raw = raw.strip()
    if raw in ("--", ""):
        return "--"
    if is_count:
        return raw.replace(",", "{,}")
    if is_pval:
        return f"[{raw}]"
    match = re.match(r"^([^*]+?)(\*{1,3})?$", raw)
    if not match:
        return raw
    num_str = match.group(1).strip()
    stars   = match.group(2) or ""
    if num_str.startswith("-"):
        num_str = r"$-$" + num_str[1:]
    return f"({num_str})" if is_se else f"{num_str}{stars}"


def get(data, spec, outcome, row_type, **kw):
    try:
        return fmt(data[spec][outcome][row_type], **kw)
    except KeyError:
        return "--"


# ── Table builder ──────────────────────────────────────────────────────────────

def make_table(data):
    n_outcomes = len(OUTCOMES)
    col_spec = "l" + "c" * n_outcomes
    blank = " " + " & " * n_outcomes + r"\\"

    notes = (
        r"This table assesses the robustness of the main spillover results to "
        r"alternative connectivity measures. The sample is restricted to "
        r"untreated establishments in the Lagos balanced panel. "
        r"Panel~I uses \textit{avg\_ftreat\_pf\_n}: the average yearly share of "
        r"worker flows directed to treated firms, computed across pre-treatment "
        r"year pairs (2007--2011). "
        r"Panel~II uses \textit{totaltreat\_pf\_n}: the proportion of total "
        r"pre-treatment flows going to treated firms. "
        r"Both measures are scaled to the 90th percentile of the spillover "
        r"sample (untreated, balanced panel) in 2009, matching the normalization "
        r"of the main specification. "
        r"Post $\times$ Connectivity captures the average spillover effect for "
        r"2012--2016; Pre $\times$ Connectivity is a placebo test using "
        r"2009--2011. The \# CBA Clauses outcome uses CBA negotiation periods "
        r"rather than calendar years. "
        r"All regressions include establishment fixed effects, year fixed effects "
        r"interacted with two-digit industry, microregion, and negotiation-month "
        r"indicators, and quartile-bin controls for pre-treatment per-worker "
        r"pairwise flows (2007--2011) and pre-treatment log employment, each "
        r"interacted with year fixed effects. "
        r"Pre-trend $p$-value is from the joint test of pre-treatment "
        r"placebo coefficients. "
        r"Standard errors clustered at the establishment level in parentheses. "
        r"*** p$<$0.01, ** p$<$0.05, * p$<$0.10."
    )

    outcome_hdrs = " & ".join(
        r"\textbf{" + label + r"}" for _, label in OUTCOMES
    )

    lines = [
        r"\begin{table}[H]",
        r"\centering",
        r"\caption{Spillover Effects: Alternative Connectivity Measures}",
        r"\label{tab:rob_spill_alt_conn}",
        r"\scriptsize",
        r"\begin{threeparttable}",
        f"\\begin{{tabular}}{{{col_spec}}}",
        r"\toprule\toprule",
        " & " + outcome_hdrs + r" \\",
        r"\midrule",
    ]

    for idx, (spec, panel_label) in enumerate(SPECS):
        if idx > 0:
            lines.append(blank)
            lines.append(r"\midrule")

        lines.append(
            r"\multicolumn{" + str(n_outcomes + 1) + r"}{l}{"
            + r"\textbf{" + panel_label.replace(r"\shortstack{", "").replace("}", "").replace(r" \\ ", ": ").replace(r"\\", " ")
            + r"}} \\"
        )

        # Use a clean panel header with \shortstack
        lines[-1] = (
            r"\multicolumn{" + str(n_outcomes + 1) + r"}{l}{"
            + panel_label
            + r"} \\"
        )
        lines.append(r"\midrule")

        # Post × Connectivity
        row = r"Post $\times$ Connectivity"
        row += "".join(" & " + get(data, spec, outcome, "main") for outcome, _ in OUTCOMES)
        lines.append(row + r" \\")

        row = ""
        row += "".join(" & " + get(data, spec, outcome, "main_se", is_se=True) for outcome, _ in OUTCOMES)
        lines.append(" " + row + r" \\")
        lines.append(blank)

        # Pre × Connectivity
        row = r"Pre $\times$ Connectivity"
        row += "".join(" & " + get(data, spec, outcome, "pre") for outcome, _ in OUTCOMES)
        lines.append(row + r" \\")

        row = ""
        row += "".join(" & " + get(data, spec, outcome, "pre_se", is_se=True) for outcome, _ in OUTCOMES)
        lines.append(" " + row + r" \\")

        # Pre-trend p-value
        row = r"Pre-trend $p$-value"
        row += "".join(" & " + get(data, spec, outcome, "pre_pval", is_pval=True) for outcome, _ in OUTCOMES)
        lines.append(row + r" \\")
        lines.append(blank)

        # N
        row = "Observations"
        row += "".join(" & " + get(data, spec, outcome, "n_obs", is_count=True) for outcome, _ in OUTCOMES)
        lines.append(row + r" \\")

        row = "Establishments"
        row += "".join(" & " + get(data, spec, outcome, "n_estab", is_count=True) for outcome, _ in OUTCOMES)
        lines.append(row + r" \\")

    lines += [
        r"\bottomrule",
        r"\end{tabular}",
        r"\scriptsize",
        r"\begin{tablenotes}",
        r"\item \textit{Notes:} " + notes,
        r"\end{tablenotes}",
        r"\end{threeparttable}",
        r"\end{table}",
    ]

    return "\n".join(lines)


# ── Main ───────────────────────────────────────────────────────────────────────

def main():
    script_dir  = Path(__file__).resolve().parent
    rob_dir     = script_dir.parent.parent / "Tables" / "robustness"
    output_file = rob_dir / "alt_conn_table.tex"

    data = load_csv(rob_dir / "results_spill_alt_conn.csv")
    table = make_table(data)

    with open(output_file, "w") as f:
        f.write(table)

    print(f"Generated {output_file}")
    print(f"  2 connectivity-measure panels × {len(OUTCOMES)} outcome columns")


if __name__ == "__main__":
    main()
