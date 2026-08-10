#!/usr/bin/env python3
"""
Generate LaTeX tables for robustness specifications.

Reads CSV results from Main_Results_robustness.do and produces
robustness_tables.tex with 3 tables per spec (24 tables total).
"""

import os
import re
from pathlib import Path

# ── Configuration ──────────────────────────────────────────────────────────

SPECS = [
    "baseline", "totalflows", "churn", "churn_rate",
    "tf_07_11", "tf_09_11", "tfpw_07_11", "tfpw_09_11",
]

SPEC_DESCRIPTIONS = {
    "baseline":    "No additional pre-treatment controls",
    "totalflows":  "quartiles of pre-treatment total worker flows",
    "churn":       "quartiles of pre-treatment churn",
    "churn_rate":  "quartiles of pre-treatment churn rate",
    "tf_07_11":    "quartiles of avg yearly pairwise flows (2007--2011)",
    "tf_09_11":    "quartiles of avg yearly pairwise flows (2009--2011)",
    "tfpw_07_11":  "quartiles of avg yearly per-worker pairwise flows (2007--2011)",
    "tfpw_09_11":  "quartiles of avg yearly per-worker pairwise flows (2009--2011)",
}

SPEC_LABELS = {
    "baseline":    "Baseline",
    "totalflows":  "Total Flows",
    "churn":       "Churn",
    "churn_rate":  "Churn Rate",
    "tf_07_11":    "Pairwise Flows 07--11",
    "tf_09_11":    "Pairwise Flows 09--11",
    "tfpw_07_11":  "Per-Worker Pairwise Flows 07--11",
    "tfpw_09_11":  "Per-Worker Pairwise Flows 09--11",
}

MAIN_OUTCOMES = ["lr_remdezr_w", "lr_remdezr_h_w", "l_firm_emp", "numb_clauses"]

OUTCOME_HEADERS = {
    "lr_remdezr_w":   "Log Wages",
    "lr_remdezr_h_w": "Log Hourly Wages",
    "l_firm_emp":     "Log Employment",
    "numb_clauses":   "Clause Count",
}

UNION_ROB_OUTCOMES = [
    "lr_remdezr_w",
    "lr_remdezr_w_union",
    "lr_remdezr_w_unionexp",
    "lr_remdezr_w_unionempexp",
]

UNION_ROB_HEADERS = [
    "Baseline",
    "Union FE $\\times$ Year FE",
    "Union Exp (firm) $\\times$ Year FE",
    "Union Exp (workers) $\\times$ Year FE",
]


# ── CSV Parsing ────────────────────────────────────────────────────────────

def load_csv(filepath):
    """Parse semicolon-delimited CSV with quoted fields.

    Returns dict: {outcome: {row_type: value_string}}
    """
    data = {}
    with open(filepath, "r") as f:
        # Skip header
        next(f)
        for line in f:
            line = line.strip()
            if not line:
                continue
            # Strip outer quotes and split on ";"
            parts = line.replace('"', '').split(";")
            if len(parts) < 5:
                continue
            _, _, outcome, row_type, value = parts[0], parts[1], parts[2], parts[3], parts[4]
            value = value.strip()
            data.setdefault(outcome, {})[row_type] = value
    return data


def format_value(raw, is_se=False, is_pval=False, is_count=False):
    """Format a raw value string for LaTeX output."""
    raw = raw.strip()
    if raw == "--" or raw == "":
        return "--"

    if is_count:
        # Keep comma formatting, no stars
        return raw.replace(",", "{,}")

    if is_pval:
        return f"[{raw}]"

    # Separate stars from number
    match = re.match(r"^([^*]+?)(\*{1,3})?$", raw)
    if not match:
        return raw
    num_str = match.group(1).strip()
    stars = match.group(2) or ""

    # LaTeX minus sign
    if num_str.startswith("-"):
        num_str = "$-$" + num_str[1:]

    if is_se:
        return f"({num_str})"
    else:
        return f"{num_str}{stars}"


def get_val(data, outcome, row_type, **fmt_kwargs):
    """Safely retrieve and format a value."""
    try:
        raw = data[outcome][row_type]
    except KeyError:
        return "--"
    return format_value(raw, **fmt_kwargs)


# ── Table Generators ───────────────────────────────────────────────────────

def make_direct_table(spec, panel_a, panel_b, panel_c):
    """Table 1: Direct Effects with 3 panels."""
    desc = SPEC_DESCRIPTIONS[spec]
    label_nice = SPEC_LABELS[spec]

    lines = []
    lines.append(r"\begin{table}[H]")
    lines.append(r"\centering")
    lines.append(r"\begin{threeparttable}")
    lines.append(f"\\caption{{Direct Effects --- {label_nice}}}")
    lines.append(f"\\label{{tab:direct_{spec}}}")
    lines.append(r"\small")
    lines.append(r"\begin{tabular}{lcccc}")
    lines.append(r"\toprule")
    lines.append(" & " + " & ".join(OUTCOME_HEADERS[o] for o in MAIN_OUTCOMES) + r" \\")
    lines.append(r"\midrule")

    panels = [
        ("Panel A: Zero-connectivity controls", panel_a),
        ("Panel B: $\\leq$1\\% connectivity controls", panel_b),
        ("Panel C: All untreated controls", panel_c),
    ]

    for i, (panel_title, pdata) in enumerate(panels):
        lines.append(f"\\textbf{{{panel_title}}} \\\\")

        # Post × Treated
        row = "Post $\\times$ Treated"
        for o in MAIN_OUTCOMES:
            row += " & " + get_val(pdata, o, "main")
        lines.append(row + r" \\")

        # SE
        row = ""
        for o in MAIN_OUTCOMES:
            row += " & " + get_val(pdata, o, "main_se", is_se=True)
        lines.append(row + r" \\")

        lines.append(r"\addlinespace")

        # Pre × Treated
        row = "Pre $\\times$ Treated"
        for o in MAIN_OUTCOMES:
            row += " & " + get_val(pdata, o, "pre")
        lines.append(row + r" \\")

        # SE
        row = ""
        for o in MAIN_OUTCOMES:
            row += " & " + get_val(pdata, o, "pre_se", is_se=True)
        lines.append(row + r" \\")

        lines.append(r"\addlinespace")

        # Pre-trend F-test p-value
        row = "Pre-trend p-value"
        for o in MAIN_OUTCOMES:
            row += " & " + get_val(pdata, o, "pre_pval", is_pval=True)
        lines.append(row + r" \\")

        lines.append(r"\addlinespace")

        # Observations
        row = "Observations"
        for o in MAIN_OUTCOMES:
            row += " & " + get_val(pdata, o, "n_obs", is_count=True)
        lines.append(row + r" \\")

        # Establishments
        row = "Establishments"
        for o in MAIN_OUTCOMES:
            row += " & " + get_val(pdata, o, "n_estab", is_count=True)
        lines.append(row + r" \\")

        if i < len(panels) - 1:
            lines.append(r"\midrule")

    lines.append(r"\bottomrule")
    lines.append(r"\end{tabular}")
    lines.append(r"\begin{tablenotes}[flushleft]")
    lines.append(r"\footnotesize")
    lines.append(r"\item \textit{Notes:} *** p$<$0.01, ** p$<$0.05, * p$<$0.10. "
                 r"Standard errors clustered at the firm level. "
                 f"Additional control: {desc}.")
    lines.append(r"\end{tablenotes}")
    lines.append(r"\end{threeparttable}")
    lines.append(r"\end{table}")
    return "\n".join(lines)


def make_spill_table(spec, spill_data):
    """Table 2: Spillover Effects."""
    desc = SPEC_DESCRIPTIONS[spec]
    label_nice = SPEC_LABELS[spec]

    lines = []
    lines.append(r"\begin{table}[H]")
    lines.append(r"\centering")
    lines.append(r"\begin{threeparttable}")
    lines.append(f"\\caption{{Spillover Effects --- {label_nice}}}")
    lines.append(f"\\label{{tab:spill_{spec}}}")
    lines.append(r"\small")
    lines.append(r"\begin{tabular}{lcccc}")
    lines.append(r"\toprule")
    lines.append(" & " + " & ".join(OUTCOME_HEADERS[o] for o in MAIN_OUTCOMES) + r" \\")
    lines.append(r"\midrule")

    # Post × Connectivity
    row = "Post $\\times$ Connectivity"
    for o in MAIN_OUTCOMES:
        row += " & " + get_val(spill_data, o, "main")
    lines.append(row + r" \\")

    # SE
    row = ""
    for o in MAIN_OUTCOMES:
        row += " & " + get_val(spill_data, o, "main_se", is_se=True)
    lines.append(row + r" \\")

    lines.append(r"\addlinespace")

    # Pre × Connectivity
    row = "Pre $\\times$ Connectivity"
    for o in MAIN_OUTCOMES:
        row += " & " + get_val(spill_data, o, "pre")
    lines.append(row + r" \\")

    # SE
    row = ""
    for o in MAIN_OUTCOMES:
        row += " & " + get_val(spill_data, o, "pre_se", is_se=True)
    lines.append(row + r" \\")

    lines.append(r"\addlinespace")

    # Pre-trend F-test p-value
    row = "Pre-trend p-value"
    for o in MAIN_OUTCOMES:
        row += " & " + get_val(spill_data, o, "pre_pval", is_pval=True)
    lines.append(row + r" \\")

    lines.append(r"\addlinespace")

    # Observations
    row = "Observations"
    for o in MAIN_OUTCOMES:
        row += " & " + get_val(spill_data, o, "n_obs", is_count=True)
    lines.append(row + r" \\")

    # Establishments
    row = "Establishments"
    for o in MAIN_OUTCOMES:
        row += " & " + get_val(spill_data, o, "n_estab", is_count=True)
    lines.append(row + r" \\")

    lines.append(r"\bottomrule")
    lines.append(r"\end{tabular}")
    lines.append(r"\begin{tablenotes}[flushleft]")
    lines.append(r"\footnotesize")
    lines.append(r"\item \textit{Notes:} *** p$<$0.01, ** p$<$0.05, * p$<$0.10. "
                 r"Standard errors clustered at the firm level. "
                 f"Additional control: {desc}.")
    lines.append(r"\end{tablenotes}")
    lines.append(r"\end{threeparttable}")
    lines.append(r"\end{table}")
    return "\n".join(lines)


def make_union_rob_table(spec, spill_data):
    """Table 3: Union Exposure Robustness (Log Wages only, 4 columns)."""
    desc = SPEC_DESCRIPTIONS[spec]
    label_nice = SPEC_LABELS[spec]

    lines = []
    lines.append(r"\begin{table}[H]")
    lines.append(r"\centering")
    lines.append(r"\begin{threeparttable}")
    lines.append(f"\\caption{{Union Exposure Robustness --- {label_nice}}}")
    lines.append(f"\\label{{tab:union_rob_{spec}}}")
    lines.append(r"\small")
    lines.append(r"\begin{tabular}{lcccc}")
    lines.append(r"\toprule")
    lines.append(r" & (1) & (2) & (3) & (4) \\")
    lines.append(r"\midrule")
    lines.append(r"\multicolumn{5}{c}{\textit{Dependent variable: Log Wages}} \\")
    lines.append(r"\addlinespace")

    # Post × Connectivity
    row = "Post $\\times$ Connectivity"
    for o in UNION_ROB_OUTCOMES:
        row += " & " + get_val(spill_data, o, "main")
    lines.append(row + r" \\")

    # SE
    row = ""
    for o in UNION_ROB_OUTCOMES:
        row += " & " + get_val(spill_data, o, "main_se", is_se=True)
    lines.append(row + r" \\")

    lines.append(r"\addlinespace")

    # Pre × Connectivity
    row = "Pre $\\times$ Connectivity"
    for o in UNION_ROB_OUTCOMES:
        row += " & " + get_val(spill_data, o, "pre")
    lines.append(row + r" \\")

    # SE
    row = ""
    for o in UNION_ROB_OUTCOMES:
        row += " & " + get_val(spill_data, o, "pre_se", is_se=True)
    lines.append(row + r" \\")

    lines.append(r"\addlinespace")

    # Pre-trend F-test p-value
    row = "Pre-trend p-value"
    for o in UNION_ROB_OUTCOMES:
        row += " & " + get_val(spill_data, o, "pre_pval", is_pval=True)
    lines.append(row + r" \\")

    lines.append(r"\addlinespace")

    # Observations
    row = "Num Obs"
    for o in UNION_ROB_OUTCOMES:
        row += " & " + get_val(spill_data, o, "n_obs", is_count=True)
    lines.append(row + r" \\")

    # Establishments
    row = "Num Establishments"
    for o in UNION_ROB_OUTCOMES:
        row += " & " + get_val(spill_data, o, "n_estab", is_count=True)
    lines.append(row + r" \\")

    lines.append(r"\midrule")

    # Checkmark panel for controls
    lines.append(r"Union FE $\times$ Year FE & & $\checkmark$ & & \\")
    lines.append(r"Union Exp (firm) $\times$ Year FE & & & $\checkmark$ & \\")
    lines.append(r"Union Exp (workers) $\times$ Year FE & & & & $\checkmark$ \\")

    lines.append(r"\bottomrule")
    lines.append(r"\end{tabular}")
    lines.append(r"\begin{tablenotes}[flushleft]")
    lines.append(r"\footnotesize")
    lines.append(r"\item \textit{Notes:} *** p$<$0.01, ** p$<$0.05, * p$<$0.10. "
                 r"Standard errors clustered at the firm level. "
                 r"Column (1) is the baseline spillover estimate. "
                 r"Column (2) adds union fixed effects interacted with year. "
                 r"Column (3) controls for firm-level union exposure to treatment interacted with year. "
                 r"Column (4) controls for worker-level union exposure to treatment interacted with year. "
                 f"Additional control: {desc}.")
    lines.append(r"\end{tablenotes}")
    lines.append(r"\end{threeparttable}")
    lines.append(r"\end{table}")
    return "\n".join(lines)


# ── Main ───────────────────────────────────────────────────────────────────

def main():
    script_dir = Path(__file__).resolve().parent
    tables_dir = script_dir.parent / "Tables"
    output_file = tables_dir / "robustness_tables.tex"

    # LaTeX preamble (standalone document)
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
{\Huge\bfseries Union Spillovers:\\Robustness Tables\par}
\vspace{2cm}
{\Large Pre-Treatment Controls Robustness\par}
\vspace{1cm}
{\large \today\par}
\vfill
{\large Luis Gomes\\Northwestern University\par}
\end{titlepage}

\tableofcontents
\clearpage
""")

    table_count = 0

    for spec in SPECS:
        label_nice = SPEC_LABELS[spec]

        # Load CSVs
        pa_file = tables_dir / f"results_direct_panelA_{spec}.csv"
        pb_file = tables_dir / f"results_direct_panelB_{spec}.csv"
        pc_file = tables_dir / f"results_direct_panelC_{spec}.csv"
        sp_file = tables_dir / f"results_spill_{spec}.csv"

        missing = []
        for f in [pa_file, pb_file, pc_file, sp_file]:
            if not f.exists():
                missing.append(f.name)
        if missing:
            print(f"  WARNING: Missing files for {spec}: {', '.join(missing)}")

        panel_a = load_csv(pa_file) if pa_file.exists() else {}
        panel_b = load_csv(pb_file) if pb_file.exists() else {}
        panel_c = load_csv(pc_file) if pc_file.exists() else {}
        spill   = load_csv(sp_file) if sp_file.exists() else {}

        doc.append(f"\\section{{{label_nice}}}")
        doc.append("")

        # Table 1: Direct Effects (own page)
        doc.append(make_direct_table(spec, panel_a, panel_b, panel_c))
        doc.append("")
        table_count += 1

        # Page break
        doc.append(r"\clearpage")
        doc.append("")

        # Table 2: Spillover Effects
        doc.append(make_spill_table(spec, spill))
        doc.append("")
        table_count += 1

        # Table 3: Union Exposure Robustness
        doc.append(make_union_rob_table(spec, spill))
        doc.append("")
        table_count += 1

        # Page break between specs
        doc.append(r"\clearpage")
        doc.append("")

    doc.append(r"\end{document}")

    content = "\n".join(doc)
    with open(output_file, "w") as f:
        f.write(content)

    print(f"Generated {output_file}")
    print(f"  {table_count} tables across {len(SPECS)} specifications")


if __name__ == "__main__":
    main()
