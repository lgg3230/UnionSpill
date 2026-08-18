#!/usr/bin/env python3
"""
Generate publication-ready LaTeX tables for wage percentile and inequality
ratio analysis (tfpw_07_11 specification).

For each outcome group, produces TWO tables on separate pages:
  1. Direct effects — Panels A / B / C (treated vs. control establishments)
  2. Spillover effects — connected untreated establishments

Output: UnionSpill/Tables/pct_tables.tex
"""

import re
from pathlib import Path

SPEC = "tfpw_07_11_pct"

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
    r"interacted with year (or CBA-period) fixed effects."
)

_STARS = r"*** p$<$0.01, ** p$<$0.05, * p$<$0.10."


def notes_direct(outcome_desc, extra=""):
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
        extra +
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


# ── Outcome groups ───────────────────────────────────────────────────────────

OUTCOME_GROUPS = [
    dict(
        key="base",
        direct_caption=(
            r"Direct Effects of the Ultractivity Reform on Establishment Outcomes"
        ),
        spill_caption=(
            r"Spillover Effects of the Ultractivity Reform on Establishment Outcomes"
        ),
        outcomes=["lr_remdezr_w", "lr_remdezr_h_w", "l_firm_emp", "numb_clauses"],
        col_headers=[
            r"Log\\Wages", r"Log Hourly\\Wages",
            r"Log\\Employment", r"Clause\\Count",
        ],
        direct_notes=notes_direct(
            r"log wages, log hourly wages, log employment, and the number of "
            r"CBA clauses",
            extra=(
                r"The clause count outcome uses CBA negotiation periods rather "
                r"than calendar years; observations therefore differ in that column. "
            ),
        ),
        spill_notes=notes_spill(
            r"log wages, log hourly wages, and log employment",
        ),
    ),
    dict(
        key="pct_dec",
        direct_caption=(
            r"Direct Effects on the Distribution of Log December Wages"
        ),
        spill_caption=(
            r"Spillover Effects on the Distribution of Log December Wages"
        ),
        outcomes=[
            "lr_remdezr_w_p10", "lr_remdezr_w_p25", "lr_remdezr_w_p50",
            "lr_remdezr_w_p75", "lr_remdezr_w_p90",
        ],
        col_headers=[
            r"10th\\Pctile", r"25th\\Pctile", r"50th\\Pctile",
            r"75th\\Pctile", r"90th\\Pctile",
        ],
        direct_notes=notes_direct(
            r"the within-establishment distribution of log December wages, "
            r"measured at the 10th, 25th, 50th, 75th, and 90th percentiles",
        ),
        spill_notes=notes_spill(
            r"the within-establishment distribution of log December wages "
            r"(10th, 25th, 50th, 75th, and 90th percentiles)",
        ),
    ),
    dict(
        key="pct_hr",
        direct_caption=(
            r"Direct Effects on the Distribution of Log Hourly Wages"
        ),
        spill_caption=(
            r"Spillover Effects on the Distribution of Log Hourly Wages"
        ),
        outcomes=[
            "lr_remdezr_h_w_p10", "lr_remdezr_h_w_p25", "lr_remdezr_h_w_p50",
            "lr_remdezr_h_w_p75", "lr_remdezr_h_w_p90",
        ],
        col_headers=[
            r"10th\\Pctile", r"25th\\Pctile", r"50th\\Pctile",
            r"75th\\Pctile", r"90th\\Pctile",
        ],
        direct_notes=notes_direct(
            r"the within-establishment distribution of log hourly wages, "
            r"measured at the 10th, 25th, 50th, 75th, and 90th percentiles",
        ),
        spill_notes=notes_spill(
            r"the within-establishment distribution of log hourly wages "
            r"(10th, 25th, 50th, 75th, and 90th percentiles)",
        ),
    ),
    dict(
        key="ratio_dec",
        direct_caption=(
            r"Direct Effects on December Wage Inequality within Establishments"
        ),
        spill_caption=(
            r"Spillover Effects on December Wage Inequality within Establishments"
        ),
        outcomes=[
            "lr_remdezr_w_p90p10", "lr_remdezr_w_p75p25",
            "lr_remdezr_w_p90p50", "lr_remdezr_w_p75p50",
        ],
        col_headers=[
            r"p90$-$p10", r"p75$-$p25", r"p90$-$p50", r"p75$-$p50",
        ],
        direct_notes=notes_direct(
            r"December wage inequality within establishments, measured by log "
            r"wage gaps at the 90th--10th (p90$-$p10), 75th--25th (p75$-$p25), "
            r"90th--50th (p90$-$p50), and 75th--50th (p75$-$p50) percentiles",
        ),
        spill_notes=notes_spill(
            r"December wage inequality within establishments (p90$-$p10, "
            r"p75$-$p25, p90$-$p50, and p75$-$p50 log wage gaps)",
        ),
    ),
    dict(
        key="ratio_hr",
        direct_caption=(
            r"Direct Effects on Hourly Wage Inequality within Establishments"
        ),
        spill_caption=(
            r"Spillover Effects on Hourly Wage Inequality within Establishments"
        ),
        outcomes=[
            "lr_remdezr_h_w_p90p10", "lr_remdezr_h_w_p75p25",
            "lr_remdezr_h_w_p90p50", "lr_remdezr_h_w_p75p50",
        ],
        col_headers=[
            r"p90$-$p10", r"p75$-$p25", r"p90$-$p50", r"p75$-$p50",
        ],
        direct_notes=notes_direct(
            r"hourly wage inequality within establishments, measured by log "
            r"wage gaps at the 90th--10th (p90$-$p10), 75th--25th (p75$-$p25), "
            r"90th--50th (p90$-$p50), and 75th--50th (p75$-$p50) percentiles",
        ),
        spill_notes=notes_spill(
            r"hourly wage inequality within establishments (p90$-$p10, "
            r"p75$-$p25, p90$-$p50, and p75$-$p50 log wage gaps)",
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
    outcomes    = group["outcomes"]
    col_headers = group["col_headers"]
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
    script_dir  = Path(__file__).resolve().parent
    tables_dir  = script_dir.parent.parent.parent / "Tables"
    output_file = tables_dir / "pct_tables.tex"

    pa_file = tables_dir / f"results_direct_panelA_{SPEC}.csv"
    pb_file = tables_dir / f"results_direct_panelB_{SPEC}.csv"
    pc_file = tables_dir / f"results_direct_panelC_{SPEC}.csv"
    sp_file = tables_dir / f"results_spill_{SPEC}.csv"

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
{\Huge\bfseries Union Spillovers:\\Wage Distribution Tables\par}
\vspace{2cm}
{\Large Percentiles \& Inequality Ratios --- tfpw\_07\_11 Specification\par}
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
    print(f"  {table_count} tables for {len(OUTCOME_GROUPS)} outcome groups "
          f"(direct + spillover per group)")


if __name__ == "__main__":
    main()
