#!/usr/bin/env python3
"""
Generate publication-ready LaTeX tables for employment flows & turnover rate
analysis (tfpw_07_11 specification).

Produces TWO tables on separate pages:
  1. Direct effects — Panels A / B / C (treated vs. control establishments)
  2. Spillover effects — connected untreated establishments

Output: UnionSpill/Tables/turnover/turnover_tables.tex
"""

import re
from pathlib import Path

SPEC = "turnover"

# ── LaTeX cell helpers ───────────────────────────────────────────────────────

def hdr(text):
    """Multi-line centered column header."""
    return r"\begin{tabular}[c]{@{}c@{}}" + text + r"\end{tabular}"


def panel_cell(bold, italic):
    """Panel label cell: bold title on line 1, italic descriptor on line 2."""
    return (r"\begin{tabular}[c]{@{}l@{}}" + bold + r"\\" +
            " " + italic + r"\end{tabular}")


# ── CSV parsing ──────────────────────────────────────────────────────────────

def load_csv(filepath):
    """Parse semicolon-delimited CSV. Returns {outcome: {row_type: value}}."""
    data = {}
    if not filepath.exists():
        return data
    with open(filepath, "r") as f:
        next(f)  # skip header
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = line.replace('"', '').split(";")
            if len(parts) < 5:
                continue
            _, _, outcome, row_type, value = (
                parts[0], parts[1], parts[2], parts[3], parts[4]
            )
            data.setdefault(outcome, {})[row_type] = value.strip()
    return data


def format_value(raw, is_se=False, is_count=False, is_pval=False):
    """Format a raw value string for LaTeX output."""
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


def get_val(data, outcome, row_type, **kw):
    """Safely retrieve and format a value from parsed CSV data."""
    try:
        raw = data[outcome][row_type]
    except KeyError:
        return "--"
    return format_value(raw, **kw)


# ── Notes (publication-ready) ────────────────────────────────────────────────

_CONTROLS = (
    r"All regressions include establishment fixed effects, year fixed effects "
    r"interacted with two-digit industry, microregion, and negotiation-month "
    r"indicators, and quartile-bin controls for pre-treatment per-worker "
    r"pairwise worker flows (2007--2011) and pre-treatment establishment size, "
    r"interacted with year fixed effects."
)

_STARS = r"*** p$<$0.01, ** p$<$0.05, * p$<$0.10."


def notes_direct(outcome_desc):
    return (
        r"This table presents difference-in-differences estimates of the direct "
        r"effects of Brazil's 2012 ultractivity reform on " + outcome_desc + r". "
        r"The reform, effective September~25, 2012, extended existing collective "
        r"bargaining agreements (CBAs) indefinitely upon expiration, increasing "
        r"the bargaining power of workers at treated establishments---those with "
        r"an active CBA on that date. The sample covers Brazilian establishments "
        r"in the Lagos sample observed annually from 2009 to 2016. "
        r"Post $\times$ Treatment measures the average treatment effect for "
        r"2012--2016; Pre $\times$ Treatment is a placebo test using 2009--2011 "
        r"as the pre-reform period. " +
        _CONTROLS + r" "
        r"Panel~A restricts the control group to establishments with zero "
        r"pre-reform worker-flow connectivity to treated firms; Panel~B to "
        r"establishments with at most 1\% connectivity; Panel~C includes all "
        r"untreated establishments. "
        r"Standard errors clustered at the establishment level in parentheses. " +
        _STARS
    )


def notes_spill(outcome_desc):
    return (
        r"This table estimates spillover effects of Brazil's 2012 ultractivity "
        r"reform on " + outcome_desc + r" at untreated establishments connected "
        r"to treated firms. Connectivity is defined as the share of an "
        r"establishment's pre-reform workforce (2007--2011) that overlapped with "
        r"a treated firm's workforce, normalized to the 90th percentile of the "
        r"spillover sample distribution. The sample is restricted to untreated "
        r"establishments in the Lagos sample participating in a balanced panel. "
        r"Post $\times$ Connectivity captures the average spillover effect for "
        r"2012--2016; Pre $\times$ Connectivity is a placebo test using 2009--2011. " +
        _CONTROLS + r" "
        r"Standard errors clustered at the establishment level in parentheses. " +
        _STARS
    )


# ── Outcome group definition ─────────────────────────────────────────────────

DIRECT_OUTCOMES = [
    "retention_u", "retention_yoy_u", "hiring_rate_u", "turnover_u",
    "quit_rate_u", "layoff_rate_u", "churn_rate_u", "l_total_hours", "l_firm_emp",
]
DIRECT_HEADERS = [
    r"Retention\\Rate", r"YoY\\Retention", r"Hiring\\Rate", r"Sep.\\Rate",
    r"Quit\\Rate", r"Layoff\\Rate", r"Churn\\Rate", r"Log\\Hours", r"Log\\Emp.",
]

SPILL_OUTCOMES = DIRECT_OUTCOMES + [
    "totalflows_pw", "outflows_pw", "inflows_pw",
]
SPILL_HEADERS = DIRECT_HEADERS + [
    r"Total\\Flows p.w.", r"Outflows\\p.w.", r"Inflows\\p.w.",
]

OUTCOME_GROUPS = [
    dict(
        key="turnover",
        direct_caption=(
            r"Direct Effects of the Ultractivity Reform on Employment Flows"
        ),
        spill_caption=(
            r"Spillover Effects of the Ultractivity Reform on Employment Flows"
        ),
        outcomes=SPILL_OUTCOMES,
        col_headers=SPILL_HEADERS,
        direct_notes=notes_direct(
            r"establishment employment flow rates and worker mobility outcomes. "
            r"Columns (1)--(6) report the retention rate (Jan stayers / Dec "
            r"employment), hiring rate, separation rate (= separations / average "
            r"employment), quit rate, layoff rate, and churn rate "
            r"(= (separations + hires) / average employment). "
            r"Column (7) reports log total contracted hours summed across "
            r"December-employment workers. "
            r"Columns (8)--(10) report annual per-worker bilateral flow outcomes: "
            r"total bilateral flows per worker, total outflows per worker, and "
            r"total inflows per worker. These three columns measure whether the "
            r"reform reshapes overall labour mobility",
        ),
        spill_notes=notes_spill(
            r"establishment employment flow rates and worker mobility outcomes. "
            r"Columns (1)--(6) report the retention rate, hiring rate, separation "
            r"rate, quit rate, layoff rate, and churn rate "
            r"(= (separations + hires) / average employment). "
            r"Column (7) reports log total contracted hours summed across "
            r"December-employment workers. "
            r"Columns (8)--(10) report annual per-worker bilateral flow outcomes: "
            r"total bilateral flows per worker, total outflows per worker, and "
            r"total inflows per worker. These three columns measure whether "
            r"spillover effects propagate through overall worker mobility",
        ),
    ),
]


# ── Panel section builder ────────────────────────────────────────────────────

def panel_section(pdata, outcomes, panel_bold, panel_italic, col_headers,
                  post_label, pre_label):
    """Return LaTeX lines for one panel (header row + coefficient rows)."""
    n = len(outcomes)
    blank = " " + " & " * n + r"\\"

    lines = []
    # Header row: panel label in col-0, column headers in data cols
    col_hdrs = " & ".join(hdr(h) for h in col_headers)
    lines.append(panel_cell(panel_bold, panel_italic) + " & " + col_hdrs + r" \\")
    # Column numbers
    nums = " & ".join(f"({i+1})" for i in range(n))
    lines.append(" & " + nums + r" \\")
    lines.append(r"\midrule")

    # Post coefficient
    row = post_label + "".join(
        " & " + get_val(pdata, o, "main") for o in outcomes)
    lines.append(row + r" \\")
    # Post SE
    row = "".join(
        " & " + get_val(pdata, o, "main_se", is_se=True) for o in outcomes)
    lines.append(" " + row + r" \\")
    lines.append(blank)

    # Pre coefficient
    row = pre_label + "".join(
        " & " + get_val(pdata, o, "pre") for o in outcomes)
    lines.append(row + r" \\")
    # Pre SE
    row = "".join(
        " & " + get_val(pdata, o, "pre_se", is_se=True) for o in outcomes)
    lines.append(" " + row + r" \\")
    # Joint pre-trend F-test p-value
    row = r"Pre-trend $F$-test $p$-value" + "".join(
        " & " + get_val(pdata, o, "pre_pval", is_pval=True) for o in outcomes)
    lines.append(row + r" \\")
    lines.append(blank)

    # Baseline mean (2009)
    row = r"Mean (2009)" + "".join(
        " & " + get_val(pdata, o, "mean_pre") for o in outcomes)
    lines.append(row + r" \\")

    # Observations / Establishments
    row = "Observations" + "".join(
        " & " + get_val(pdata, o, "n_obs", is_count=True) for o in outcomes)
    lines.append(row + r" \\")
    row = "Establishments" + "".join(
        " & " + get_val(pdata, o, "n_estab", is_count=True) for o in outcomes)
    lines.append(row + r" \\")

    return lines


# ── Table builders ───────────────────────────────────────────────────────────

def table_preamble(caption, label, col_spec):
    return [
        r"\begin{table}[]",
        r"\centering",
        f"\\caption{{{caption}}}",
        f"\\label{{{label}}}",
        r"\scriptsize",
        r"\begin{threeparttable}",
        f"\\begin{{tabular}}{{{col_spec}}}",
        r"\toprule\toprule",
    ]


def table_postamble(notes):
    return [
        r"\bottomrule",
        r"\end{tabular}",
        r"\scriptsize",
        r"\begin{tablenotes}",
        r"\item \textit{Notes:} " + notes,
        r"\end{tablenotes}",
        r"\end{threeparttable}",
        r"\end{table}",
    ]


def make_direct_table(group):
    key         = group["key"]
    outcomes    = group["outcomes"]
    col_headers = group["col_headers"]
    n           = len(outcomes)
    col_spec    = "l" + "c" * n
    blank       = " " + " & " * n + r"\\"

    lines = table_preamble(group["direct_caption"], f"tab:direct_{key}", col_spec)

    panel_defs = [
        (
            r"\textbf{Panel A:} \textit{Only Control Firms}",
            r"\textit{with Zero Connectivity}",
            "panel_a",
        ),
        (
            r"\textbf{Panel B:} \textit{Control Firms with}",
            r"\textit{$\leq$1\% Connectivity}",
            "panel_b",
        ),
        (
            r"\textbf{Panel C:} \textit{All Untreated}",
            r"\textit{Control Firms}",
            "panel_c",
        ),
    ]

    for idx, (bold, italic, data_key) in enumerate(panel_defs):
        lines += panel_section(
            group[data_key], outcomes, bold, italic, col_headers,
            r"Post $\times$ Treatment", r"Pre $\times$ Treatment",
        )
        if idx < len(panel_defs) - 1:
            lines.append(blank)
            lines.append(r"\midrule")

    lines += table_postamble(group["direct_notes"])
    return "\n".join(lines)


def make_spill_table(group):
    key         = group["key"]
    outcomes    = group.get("spill_outcomes", group["outcomes"])
    col_headers = group.get("spill_col_headers", group["col_headers"])
    n           = len(outcomes)
    col_spec    = "l" + "c" * n
    blank       = " " + " & " * n + r"\\"

    lines = table_preamble(group["spill_caption"], f"tab:spill_{key}", col_spec)

    # Simple column header (no panel label cell — only one section)
    col_hdrs = " & ".join(hdr(h) for h in col_headers)
    lines.append(" & " + col_hdrs + r" \\")
    nums = " & ".join(f"({i+1})" for i in range(n))
    lines.append(" & " + nums + r" \\")
    lines.append(r"\midrule")

    pdata = group["spill"]

    # Post connectivity
    row = r"Post $\times$ Connectivity" + "".join(
        " & " + get_val(pdata, o, "main") for o in outcomes)
    lines.append(row + r" \\")
    row = "".join(
        " & " + get_val(pdata, o, "main_se", is_se=True) for o in outcomes)
    lines.append(" " + row + r" \\")
    lines.append(blank)

    # Pre connectivity
    row = r"Pre $\times$ Connectivity" + "".join(
        " & " + get_val(pdata, o, "pre") for o in outcomes)
    lines.append(row + r" \\")
    row = "".join(
        " & " + get_val(pdata, o, "pre_se", is_se=True) for o in outcomes)
    lines.append(" " + row + r" \\")
    # Joint pre-trend F-test p-value
    row = r"Pre-trend $F$-test $p$-value" + "".join(
        " & " + get_val(pdata, o, "pre_pval", is_pval=True) for o in outcomes)
    lines.append(row + r" \\")
    lines.append(blank)

    # Baseline mean (2009)
    row = r"Mean (2009)" + "".join(
        " & " + get_val(pdata, o, "mean_pre") for o in outcomes)
    lines.append(row + r" \\")

    # Observations / Establishments
    row = "Observations" + "".join(
        " & " + get_val(pdata, o, "n_obs", is_count=True) for o in outcomes)
    lines.append(row + r" \\")
    row = "Establishments" + "".join(
        " & " + get_val(pdata, o, "n_estab", is_count=True) for o in outcomes)
    lines.append(row + r" \\")

    lines += table_postamble(group["spill_notes"])
    return "\n".join(lines)


# ── Main ─────────────────────────────────────────────────────────────────────

def main():
    script_dir   = Path(__file__).resolve().parent
    tables_dir   = script_dir.parent.parent / "Tables"
    pipeline_dir = tables_dir / "turnover"
    output_file  = pipeline_dir / "turnover_tables.tex"

    pa_file = pipeline_dir / f"results_direct_panelA_{SPEC}.csv"
    pb_file = pipeline_dir / f"results_direct_panelB_{SPEC}.csv"
    pc_file = pipeline_dir / f"results_direct_panelC_{SPEC}.csv"
    sp_file = pipeline_dir / f"results_spill_{SPEC}.csv"

    missing = [f.name for f in [pa_file, pb_file, pc_file, sp_file] if not f.exists()]
    if missing:
        print(f"  WARNING: Missing CSV files: {', '.join(missing)}")

    panel_a = load_csv(pa_file)
    panel_b = load_csv(pb_file)
    panel_c = load_csv(pc_file)
    spill   = load_csv(sp_file)

    # Attach loaded data to each group dict
    for g in OUTCOME_GROUPS:
        g["panel_a"] = panel_a
        g["panel_b"] = panel_b
        g["panel_c"] = panel_c
        g["spill"]   = spill

    # ── LaTeX document ───────────────────────────────────────────────────────
    doc = []
    doc.append(r"""\documentclass[12pt,letterpaper]{article}

\usepackage[margin=1in]{geometry}
\usepackage{booktabs}
\usepackage{threeparttable}
\usepackage{amsmath}
\usepackage{amssymb}
\usepackage{hyperref}
\usepackage{float}

\hypersetup{colorlinks=true,linkcolor=blue,citecolor=blue,urlcolor=blue}

\begin{document}

\begin{titlepage}
\centering
\vspace*{2cm}
{\Huge\bfseries Union Spillovers:\\Employment Flow Tables\par}
\vspace{2cm}
{\Large Retention, Hiring, Separation, Quit, Layoff, and Churn Rates\par}
\vspace{0.5cm}
{\large tfpw\_07\_11 Specification\par}
\vspace{1cm}
{\large \today\par}
\vfill
{\large Luis Gomes\\Northwestern University\par}
\end{titlepage}

\tableofcontents
\clearpage
""")

    table_count = 0
    for g in OUTCOME_GROUPS:
        # Direct effects table
        doc.append(make_direct_table(g))
        doc.append("")
        doc.append(r"\clearpage")
        doc.append("")

        # Spillover effects table
        doc.append(make_spill_table(g))
        doc.append("")
        doc.append(r"\clearpage")
        doc.append("")

        table_count += 2

    doc.append(r"\end{document}")

    content = "\n".join(doc)
    with open(output_file, "w") as f:
        f.write(content)

    print(f"Generated {output_file}")
    print(f"  {table_count} tables for {len(OUTCOME_GROUPS)} outcome group(s) "
          f"(direct + spillover per group)")


if __name__ == "__main__":
    main()
