#!/usr/bin/env python3
"""
Generate publication-ready LaTeX tables for employment flows & turnover —
firm-scale specification (counts divided by firm's own pretreatment mean).

Output: UnionSpill/Tables/turnover/turnover_firmscale_tables.tex
"""

import re
from pathlib import Path

SPEC = "turnover_firmscale"

# ── LaTeX cell helpers ───────────────────────────────────────────────────────

def hdr(text):
    return r"\begin{tabular}[c]{@{}c@{}}" + text + r"\end{tabular}"


def panel_cell(bold, italic):
    return (r"\begin{tabular}[c]{@{}l@{}}" + bold + r"\\" +
            " " + italic + r"\end{tabular}")


# ── CSV parsing ──────────────────────────────────────────────────────────────

def load_csv(filepath):
    data = {}
    if not filepath.exists():
        return data
    with open(filepath, "r") as f:
        next(f)
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
    try:
        raw = data[outcome][row_type]
    except KeyError:
        return "--"
    return format_value(raw, **kw)


# ── Notes ────────────────────────────────────────────────────────────────────

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

# CSV outcome keys are fs_<rawname> (set by the do-file)
DIRECT_OUTCOMES = [
    "fs_hired_u", "fs_separations_u", "fs_layoffs_u", "fs_quits_u",
    "fs_churn_count_u", "fs_jan_dec_count", "fs_dec_yoy_count",
    "fs_total_hours", "fs_firm_emp",
]
DIRECT_HEADERS = [
    r"Hires\\(firm-sc.)", r"Seps.\\(firm-sc.)", r"Layoffs\\(firm-sc.)",
    r"Quits\\(firm-sc.)", r"Churn\\(firm-sc.)",
    r"Ret.\\Jan--Dec\\(firm-sc.)", r"Ret.\\YoY\\(firm-sc.)",
    r"Hours\\(firm-sc.)", r"Emp.\\(firm-sc.)",
]

SPILL_OUTCOMES  = DIRECT_OUTCOMES + ["fs_totalflows", "fs_outflows", "fs_inflows"]
SPILL_HEADERS   = DIRECT_HEADERS  + [r"Tot.Flows\\(firm-sc.)", r"Out-\\flows\\(firm-sc.)", r"In-\\flows\\(firm-sc.)"]

OUTCOME_GROUPS = [
    dict(
        key="turnover_firmscale",
        direct_caption=(
            r"Direct Effects of the Ultractivity Reform on Employment Flows "
            r"(Firm-Scale Specification)"
        ),
        spill_caption=(
            r"Spillover Effects of the Ultractivity Reform on Employment Flows "
            r"(Firm-Scale Specification)"
        ),
        outcomes=SPILL_OUTCOMES,
        col_headers=SPILL_HEADERS,
        direct_notes=notes_direct(
            r"establishment employment flow counts, scaled by each establishment's "
            r"own pretreatment (2009--2011) average of the same count "
            r"(firm-scale specification). "
            r"A coefficient of 0.10 indicates the count rose by 10\% relative to "
            r"the establishment's own pretreatment baseline. "
            r"Columns~(1)--(5) report firm-scaled hires, total separations, "
            r"layoffs, quits, and churn count (= hires + separations). "
            r"Columns~(6)--(7) report firm-scaled within-year retention count "
            r"(January stayers surviving to December) and year-over-year "
            r"retention count (December-to-December survivors). "
            r"Columns~(8)--(9) report firm-scaled total contracted hours and "
            r"December employment. "
            r"Establishments with a zero pretreatment average for a given count "
            r"are excluded from that outcome's regression. "
            r"Mean (2011) reports the unscaled raw count mean for reference",
        ),
        spill_notes=notes_spill(
            r"establishment employment flow counts, scaled by each establishment's "
            r"own pretreatment (2009--2011) average of the same count "
            r"(firm-scale specification). "
            r"A coefficient of 0.10 indicates the count rose by 10\% relative to "
            r"the establishment's own pretreatment baseline. "
            r"Columns~(1)--(5) report firm-scaled hires, separations, layoffs, "
            r"quits, and churn count. "
            r"Columns~(6)--(7) report firm-scaled within-year and year-over-year "
            r"retention counts. "
            r"Columns~(8)--(9) report firm-scaled total contracted hours and "
            r"December employment. "
            r"Columns~(10)--(12) report firm-scaled total bilateral worker flows, "
            r"outflows, and inflows. "
            r"Mean (2011) reports the unscaled raw count mean for reference",
        ),
    ),
]


# ── Panel section builder ────────────────────────────────────────────────────

def panel_section(pdata, outcomes, panel_bold, panel_italic, col_headers,
                  post_label, pre_label):
    n = len(outcomes)
    blank = " " + " & " * n + r"\\"
    lines = []

    col_hdrs = " & ".join(hdr(h) for h in col_headers)
    lines.append(panel_cell(panel_bold, panel_italic) + " & " + col_hdrs + r" \\")
    nums = " & ".join(f"({i+1})" for i in range(n))
    lines.append(" & " + nums + r" \\")
    lines.append(r"\midrule")

    row = post_label + "".join(
        " & " + get_val(pdata, o, "main") for o in outcomes)
    lines.append(row + r" \\")
    row = "".join(
        " & " + get_val(pdata, o, "main_se", is_se=True) for o in outcomes)
    lines.append(" " + row + r" \\")
    lines.append(blank)

    row = pre_label + "".join(
        " & " + get_val(pdata, o, "pre") for o in outcomes)
    lines.append(row + r" \\")
    row = "".join(
        " & " + get_val(pdata, o, "pre_se", is_se=True) for o in outcomes)
    lines.append(" " + row + r" \\")
    row = r"Pre-trend $F$-test $p$-value" + "".join(
        " & " + get_val(pdata, o, "pre_pval", is_pval=True) for o in outcomes)
    lines.append(row + r" \\")
    lines.append(blank)

    row = r"Mean (2011)" + "".join(
        " & " + get_val(pdata, o, "mean_pre") for o in outcomes)
    lines.append(row + r" \\")
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
        (r"\textbf{Panel A:} \textit{Only Control Firms}",
         r"\textit{with Zero Connectivity}", "panel_a"),
        (r"\textbf{Panel B:} \textit{Control Firms with}",
         r"\textit{$\leq$1\% Connectivity}", "panel_b"),
        (r"\textbf{Panel C:} \textit{All Untreated}",
         r"\textit{Control Firms}", "panel_c"),
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

    col_hdrs = " & ".join(hdr(h) for h in col_headers)
    lines.append(" & " + col_hdrs + r" \\")
    nums = " & ".join(f"({i+1})" for i in range(n))
    lines.append(" & " + nums + r" \\")
    lines.append(r"\midrule")

    pdata = group["spill"]

    row = r"Post $\times$ Connectivity" + "".join(
        " & " + get_val(pdata, o, "main") for o in outcomes)
    lines.append(row + r" \\")
    row = "".join(
        " & " + get_val(pdata, o, "main_se", is_se=True) for o in outcomes)
    lines.append(" " + row + r" \\")
    lines.append(blank)

    row = r"Pre $\times$ Connectivity" + "".join(
        " & " + get_val(pdata, o, "pre") for o in outcomes)
    lines.append(row + r" \\")
    row = "".join(
        " & " + get_val(pdata, o, "pre_se", is_se=True) for o in outcomes)
    lines.append(" " + row + r" \\")
    row = r"Pre-trend $F$-test $p$-value" + "".join(
        " & " + get_val(pdata, o, "pre_pval", is_pval=True) for o in outcomes)
    lines.append(row + r" \\")
    lines.append(blank)

    row = r"Mean (2011)" + "".join(
        " & " + get_val(pdata, o, "mean_pre") for o in outcomes)
    lines.append(row + r" \\")
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
    output_file  = pipeline_dir / "turnover_firmscale_tables.tex"

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

    for g in OUTCOME_GROUPS:
        g["panel_a"] = panel_a
        g["panel_b"] = panel_b
        g["panel_c"] = panel_c
        g["spill"]   = spill

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
{\Large Firm-Scale Specification\par}
\vspace{0.5cm}
{\large Counts Scaled by Firm-Specific Pretreatment Mean (2009--2011)\par}
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
        doc.append(make_direct_table(g))
        doc.append("")
        doc.append(r"\clearpage")
        doc.append("")
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
    print(f"  {table_count} tables for {len(OUTCOME_GROUPS)} outcome group(s)")


if __name__ == "__main__":
    main()
