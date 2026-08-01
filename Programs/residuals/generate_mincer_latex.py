#!/usr/bin/env python3
"""
Generate publication-ready LaTeX tables for Mincer residuals analysis.

Produces TWO compact 5-column tables:
  1. December wages  — baseline lr_remdezr_w  vs. residual lr_remdezr_resid
  2. Hourly wages    — baseline lr_remdezr_h_w vs. residual lr_hourly_resid

Column layout (same for both tables):
  (1) Baseline (raw wage)     Panel A
  (2) Residual                Panel A
  (3) Residual                Panel B
  (4) Residual                Panel C
  (5) Residual                Spillover

Output: UnionSpill/Tables/residuals/mincer_tables.tex
"""

import sys
import re
from pathlib import Path

SPEC = "mincer"

COL_HEADERS = [
    r"Baseline\\(Raw Wage)",
    r"Residual\\Panel A",
    r"Residual\\Panel B",
    r"Residual\\Panel C",
    r"Residual\\(Spillover)",
]


# ── LaTeX cell helpers ───────────────────────────────────────────────────────

def hdr(text):
    """Multi-line centered column header."""
    return r"\begin{tabular}[c]{@{}c@{}}" + text + r"\end{tabular}"


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


# ── Notes ────────────────────────────────────────────────────────────────────

_CONTROLS = (
    r"All regressions include establishment fixed effects, year fixed effects "
    r"interacted with two-digit industry, microregion, and negotiation-month "
    r"indicators, and quartile-bin controls for pre-treatment per-worker "
    r"pairwise worker flows (2007--2011) and pre-treatment establishment size, "
    r"interacted with year fixed effects."
)

_STARS = r"*** p$<$0.01, ** p$<$0.05, * p$<$0.10."

_SHARED_NOTES_BODY = (
    r"The reform, effective September~25, 2012, extended existing collective "
    r"bargaining agreements (CBAs) indefinitely upon expiration, increasing "
    r"the bargaining power of workers at treated establishments---those with "
    r"an active CBA on that date. The sample covers Brazilian establishments "
    r"in the Lagos sample observed annually from 2009 to 2016. "
    r"Column~(1) reports the baseline DiD estimate using the raw log wage "
    r"and a Panel~A control group (establishments with zero pre-reform "
    r"worker-flow connectivity to treated firms). Columns~(2)--(4) replace "
    r"the outcome with the firm-level average Mincer residual under Panel~A, "
    r"B, and C control groups, respectively. Column~(5) estimates spillover "
    r"effects at untreated establishments, using connectivity (worker flows "
    r"to treated firms, normalized to the 90th percentile) as the treatment "
    r"variable. "
    r"$^\dagger$Columns~(1)--(4) report the Post~$\times$~Treatment "
    r"interaction (\textit{treat\_ultra}~$\times$~\textit{treat\_year}); "
    r"column~(5) reports the Post~$\times$~Connectivity interaction. "
    + _CONTROLS + r" "
    r"Standard errors clustered at the establishment level in parentheses. "
    + _STARS
)


def notes_dec():
    return (
        r"This table compares direct and spillover effects of Brazil's 2012 "
        r"ultractivity reform on raw and Mincer-residualized log December wages "
        r"(\textit{lr\_remdezr\_w} and \textit{lr\_remdezr\_resid}). "
        + _SHARED_NOTES_BODY
    )


def notes_hr():
    return (
        r"This table compares direct and spillover effects of Brazil's 2012 "
        r"ultractivity reform on raw and Mincer-residualized log hourly wages "
        r"(\textit{lr\_remdezr\_h\_w} and \textit{lr\_hourly\_resid}). "
        + _SHARED_NOTES_BODY
    )


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


def make_mincer_table(panel_a, panel_b, panel_c, spill,
                      raw_outcome, resid_outcome, caption, label, notes):
    """Build a single 5-column Mincer table for one wage type."""
    n        = 5
    col_spec = "l" + "c" * n
    blank    = " " + " & " * n + r"\\"

    lines = table_preamble(caption, label, col_spec)

    # Column headers
    col_hdrs = " & ".join(hdr(h) for h in COL_HEADERS)
    lines.append(" & " + col_hdrs + r" \\")
    nums = " & ".join(f"({i+1})" for i in range(n))
    lines.append(" & " + nums + r" \\")
    lines.append(r"\midrule")

    # (data_dict, outcome) pairs for the 5 columns
    cols = [
        (panel_a, raw_outcome),    # (1) baseline raw
        (panel_a, resid_outcome),  # (2) residual Panel A
        (panel_b, resid_outcome),  # (3) residual Panel B
        (panel_c, resid_outcome),  # (4) residual Panel C
        (spill,   resid_outcome),  # (5) residual spillover
    ]

    # Post coefficient
    row = r"Post $\times$ Treat.\ / Conn.$^\dagger$"
    for d, o in cols:
        row += " & " + get_val(d, o, "main")
    lines.append(row + r" \\")
    # Post SE
    row = ""
    for d, o in cols:
        row += " & " + get_val(d, o, "main_se", is_se=True)
    lines.append(" " + row + r" \\")
    lines.append(blank)

    # Pre coefficient
    row = r"Pre $\times$ Treat.\ / Conn.$^\dagger$"
    for d, o in cols:
        row += " & " + get_val(d, o, "pre")
    lines.append(row + r" \\")
    # Pre SE
    row = ""
    for d, o in cols:
        row += " & " + get_val(d, o, "pre_se", is_se=True)
    lines.append(" " + row + r" \\")
    # F-test p-value
    row = r"Pre-trend $F$-test $p$-value"
    for d, o in cols:
        row += " & " + get_val(d, o, "pre_pval", is_pval=True)
    lines.append(row + r" \\")
    lines.append(blank)

    # Mean (2009)
    row = r"Mean (2009)"
    for d, o in cols:
        row += " & " + get_val(d, o, "mean_pre")
    lines.append(row + r" \\")

    # Observations
    row = "Observations"
    for d, o in cols:
        row += " & " + get_val(d, o, "n_obs", is_count=True)
    lines.append(row + r" \\")

    # Establishments
    row = "Establishments"
    for d, o in cols:
        row += " & " + get_val(d, o, "n_estab", is_count=True)
    lines.append(row + r" \\")

    lines += table_postamble(notes)
    return "\n".join(lines)


# ── LaTeX document wrapper ────────────────────────────────────────────────────

def latex_document(tables):
    header = r"""\documentclass[12pt,letterpaper]{article}

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
{\Huge\bfseries Union Spillovers:\\Mincer Residuals Tables\par}
\vspace{2cm}
{\Large Raw vs.\ Residualized Wages --- December \& Hourly\par}
\vspace{1cm}
{\large \today\par}
\vfill
{\large Luis Gomes\\Northwestern University\par}
\end{titlepage}

\tableofcontents
\clearpage
"""
    footer = r"\end{document}"
    body = ("\n\n" + r"\clearpage" + "\n\n").join(tables)
    return header + "\n" + body + "\n\n" + footer


# ── Main ─────────────────────────────────────────────────────────────────────

def main():
    # Optional results suffix (argv[1]); default "" reproduces prior behaviour.
    # Suffixed runs (e.g. _currentconn_ten_fullrais) write their CSVs under
    # Tables/currentconn_full/residuals/, so the input directory follows the
    # suffix while the .tex stays in Tables/residuals/.
    suffix = sys.argv[1] if len(sys.argv) > 1 else ""

    tables_dir   = Path(__file__).resolve().parent.parent.parent / "Tables"
    pipeline_dir = tables_dir / "residuals"
    input_dir    = pipeline_dir
    if suffix.startswith("_currentconn"):
        input_dir = tables_dir / "currentconn_full" / "residuals"

    output_file  = pipeline_dir / f"mincer_tables{suffix}.tex"

    pa_file = input_dir / f"results_direct_panelA_{SPEC}{suffix}.csv"
    pb_file = input_dir / f"results_direct_panelB_{SPEC}{suffix}.csv"
    pc_file = input_dir / f"results_direct_panelC_{SPEC}{suffix}.csv"
    sp_file = input_dir / f"results_spill_{SPEC}{suffix}.csv"

    missing = [f.name for f in [pa_file, pb_file, pc_file, sp_file] if not f.exists()]
    if missing:
        print(f"  WARNING: Missing CSV files: {', '.join(missing)}")

    panel_a = load_csv(pa_file)
    panel_b = load_csv(pb_file)
    panel_c = load_csv(pc_file)
    spill   = load_csv(sp_file)

    table_dec = make_mincer_table(
        panel_a, panel_b, panel_c, spill,
        raw_outcome="lr_remdezr_w",
        resid_outcome="lr_remdezr_resid",
        caption=r"Raw and Mincer-Residualized Log December Wage Effects",
        label="tab:mincer_dec",
        notes=notes_dec(),
    )

    table_hr = make_mincer_table(
        panel_a, panel_b, panel_c, spill,
        raw_outcome="lr_remdezr_h_w",
        resid_outcome="lr_hourly_resid",
        caption=r"Raw and Mincer-Residualized Log Hourly Wage Effects",
        label="tab:mincer_hr",
        notes=notes_hr(),
    )

    content = latex_document([table_dec, table_hr])
    output_file.write_text(content)

    print(f"Generated {output_file}")
    print("  2 tables: December wages (lr_remdezr_resid) + Hourly wages (lr_hourly_resid)")


if __name__ == "__main__":
    main()
