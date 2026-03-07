#!/usr/bin/env python3
"""
resid_explore_table.py
======================
Reads 12 CSVs from Tables/residuals/ and writes two LaTeX tables:
  Table 1: Direct effects   (8 cols: 4 specs × 2 samples A/B)
  Table 2: Spillover effects (4 cols: 4 specs, spillover sample)

Input CSVs (3 panels × 4 cols):
  resid_explore_panel{A|B|spill}_col{raw|base|ocup|tenure}.csv

Output: Tables/residuals/resid_explore_table.tex
"""

import re
from pathlib import Path

PIPELINE_DIR = Path(__file__).resolve().parent.parent.parent / "Tables" / "residuals"
OUTPUT_FILE  = PIPELINE_DIR / "resid_explore_table.tex"

PANELS  = ["A", "B", "spill"]
COLS    = ["raw", "base", "ocup2", "ocup", "tenure", "tenpoly"]


# ---------------------------------------------------------------------------
# CSV parsing
# ---------------------------------------------------------------------------

def load_csv(filepath):
    """Parse semicolon-delimited CSV. Returns {row_type: value}."""
    data = {}
    if not filepath.exists():
        print(f"  WARNING: missing {filepath.name}")
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
            row_type = parts[3]
            value    = parts[4].strip()
            data[row_type] = value
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


def get_val(data, row_type, **kw):
    try:
        raw = data[row_type]
    except KeyError:
        return "--"
    return format_value(raw, **kw)


# ---------------------------------------------------------------------------
# Load all 12 CSVs into a nested dict: cell[panel][col] = {row_type: val}
# ---------------------------------------------------------------------------

def load_all():
    cell = {}
    for panel in PANELS:
        cell[panel] = {}
        for col in COLS:
            fname = PIPELINE_DIR / f"resid_explore_panel{panel}_col{col}.csv"
            cell[panel][col] = load_csv(fname)
    return cell


# ---------------------------------------------------------------------------
# LaTeX helpers
# ---------------------------------------------------------------------------

def row_n(label, vals):
    """Build a table row with arbitrarily many columns."""
    return label + " & " + " & ".join(vals) + r" \\"


def blank_n(n):
    """Empty row with n data columns."""
    return ("& " * n).rstrip() + r"\\"


# ---------------------------------------------------------------------------
# Notes text
# ---------------------------------------------------------------------------

_CONTROLS = (
    r"All regressions include establishment fixed effects, year fixed effects "
    r"interacted with two-digit industry, microregion, and negotiation-month "
    r"indicators, and quartile-bin controls for pre-treatment per-worker "
    r"pairwise worker flows (2007--2011) and pre-treatment establishment size, "
    r"interacted with year fixed effects."
)

_RESID_PROCESS = (
    r"\textit{Residualization procedure.} "
    r"For each specification, we estimate a Mincer-style wage regression "
    r"at the worker level using the full RAIS worker panel. "
    r"The outcome is log real December wages deflated to 2015 prices "
    r"(\textit{lr\_remdezr}). "
    r"The regression is run cell by cell: within each cell we project log wages "
    r"onto a quartic age polynomial (plus a quartic tenure polynomial where noted) "
    r"and recover the residual. "
    r"The base cell is defined by a unique combination of race group, education "
    r"group, gender, and calendar year. "
    r"Cells with fewer than six worker-spell observations are dropped. "
    r"The firm-level outcome used in the regressions below is the "
    r"employment-weighted average of worker-level residuals within each "
    r"establishment-year. "
    r"Specifications differ in how the base cell is augmented: "
    r"\textit{base} (col.~(2)) uses the base cell with a quartic age polynomial only; "
    r"\textit{$+$2-dig.\ occ.} (col.~(3)) further interacts the base cell with the "
    r"first two digits of the worker's \textit{ocup2002} occupation code; "
    r"\textit{$+$4-dig.\ occ.} (col.~(4)) instead uses the full 4-digit "
    r"\textit{ocup2002} code; "
    r"\textit{$+$Ten.\ bins} (col.~(5)) interacts the base cell with six tenure "
    r"brackets based on months of tenure at the current employer "
    r"(\textit{tempempr}): $<$1~year, 1--2~years, 3--5~years, 5--10~years, "
    r"10--20~years, and $\geq$20~years (so the age polynomial is estimated "
    r"separately within each race-education-gender-year-tenure-bin cell); "
    r"\textit{$+$Ten.\ poly.} (col.~(6)) keeps the base cell definition but "
    r"appends a quartic polynomial in months of tenure to the within-cell "
    r"regression alongside the quartic age polynomial, producing a fully "
    r"saturated age-and-tenure profile within each demographic cell."
)

_NOTES_DIRECT = (
    r"Each column reports the Post~$\times$~Treatment coefficient "
    r"(\textit{treat\_ultra}~$\times$~\textit{treat\_year}) from a two-way "
    r"fixed-effects regression comparing treated establishments to a control group. "
    r"Odd columns use the zero-connectivity control group (sample~A: untreated "
    r"establishments with zero pre-reform worker-flow connectivity to treated "
    r"firms). "
    r"Even columns use all untreated establishments as controls (sample~B). "
    r"Column pairs~(1)--(2) use the raw (unresidualised) log December wage. "
    r"Remaining column pairs replace the outcome with a Mincer-residualized "
    r"log wage; pairs~(3)--(4) add a 2-digit and 4-digit occupation interaction "
    r"to the Mincer cell, respectively; pairs~(5)--(6) add a tenure-bin "
    r"interaction and a quartic tenure polynomial, respectively. "
    r"See below for details. "
    + _CONTROLS + r" "
    + _RESID_PROCESS + r" "
    r"Standard errors clustered at the establishment level in parentheses. "
    r"*** p$<$0.01, ** p$<$0.05, * p$<$0.10."
)

_NOTES_SPILL = (
    r"Each column reports the Post~$\times$~Connectivity coefficient from a "
    r"two-way fixed-effects regression for untreated establishments in the "
    r"spillover sample, where connectivity (\textit{totaltreat\_pw\_norm}) "
    r"measures pre-reform per-worker flows to treated firms scaled to the "
    r"90th~percentile of the spillover-sample distribution. "
    r"Column~(1) uses the raw log December wage; "
    r"columns~(2)--(6) use progressively richer Mincer-residualized wages "
    r"as described below. "
    + _CONTROLS + r" "
    + _RESID_PROCESS + r" "
    r"Standard errors clustered at the establishment level in parentheses. "
    r"*** p$<$0.01, ** p$<$0.05, * p$<$0.10."
)


# ---------------------------------------------------------------------------
# Table 1: Direct effects (8 columns, alternating A/B)
# ---------------------------------------------------------------------------

def build_direct_table(cell):
    """12-column table: cols alternate panelA / panelB for each of 6 specs."""
    # Column order: raw, base, ocup2, ocup, tenure, tenpoly — each × (A, B)
    col_data = [
        (cell["A"]["raw"],     cell["B"]["raw"]),
        (cell["A"]["base"],    cell["B"]["base"]),
        (cell["A"]["ocup2"],   cell["B"]["ocup2"]),
        (cell["A"]["ocup"],    cell["B"]["ocup"]),
        (cell["A"]["tenure"],  cell["B"]["tenure"]),
        (cell["A"]["tenpoly"], cell["B"]["tenpoly"]),
    ]
    ncols = 12

    lines = []
    lines += [
        r"\begin{table}[H]",
        r"\centering",
        r"\caption{Direct Wage Effects Across Residualization Specifications}",
        r"\label{tab:resid_explore_direct}",
        r"\scriptsize",
        r"\begin{threeparttable}",
        r"\resizebox{\textwidth}{!}{%",
        r"\begin{tabular}{lcccccccccccc}",
        r"\toprule\toprule",
    ]

    # Header row 1: column numbers
    nums = " & ".join(f"({i})" for i in range(1, ncols + 1))
    lines.append(f" & {nums} \\\\")

    # Header row 2: spec labels spanning pairs
    lines.append(
        r" & \multicolumn{2}{c}{Raw}"
        r" & \multicolumn{2}{c}{Base resid.}"
        r" & \multicolumn{2}{c}{+2-dig.\ occ.}"
        r" & \multicolumn{2}{c}{+4-dig.\ occ.}"
        r" & \multicolumn{2}{c}{+Ten.\ bins}"
        r" & \multicolumn{2}{c}{+Ten.\ poly.} \\"
    )
    lines.append(
        r"\cmidrule(lr){2-3}\cmidrule(lr){4-5}\cmidrule(lr){6-7}"
        r"\cmidrule(lr){8-9}\cmidrule(lr){10-11}\cmidrule(lr){12-13}"
    )

    # Header row 3: sample labels A/B
    lines.append(r" & " + " & ".join(["A", "B"] * 6) + r" \\")
    lines.append(r"\midrule")

    # ── Data rows ──────────────────────────────────────────────────────────
    def vals12(row_type, **kw):
        out = []
        for dA, dB in col_data:
            out.append(get_val(dA, row_type, **kw))
            out.append(get_val(dB, row_type, **kw))
        return out

    lines.append(row_n(r"Post $\times$ Treatment", vals12("main")))
    lines.append(row_n("", vals12("main_se", is_se=True)))
    lines.append(blank_n(ncols))

    lines.append(row_n(r"Pre $\times$ Treatment", vals12("pre")))
    lines.append(row_n("", vals12("pre_se", is_se=True)))

    lines.append(r"\midrule")

    lines.append(row_n(r"Pre-trend $F$-test $p$-val", vals12("pre_pval", is_pval=True)))
    lines.append(blank_n(ncols))

    lines.append(row_n(r"Mean (2009)",    vals12("mean_pre")))
    lines.append(row_n(r"Observations",  vals12("n_obs",   is_count=True)))
    lines.append(row_n(r"Establishments", vals12("n_estab", is_count=True)))

    lines.append(r"\midrule")

    lines.append(
        r"\multicolumn{13}{l}{\textit{Specification details (residualization cell)}}\\"
    )
    chk = r"\checkmark"
    lines.append(row_n(r"Age polynomial",
        ["", "", chk, chk, chk, chk, chk, chk, chk, chk, chk, chk]))
    lines.append(row_n(r"$+$ 2-digit occupation",
        ["", "", "", "", chk, chk, "", "", "", "", "", ""]))
    lines.append(row_n(r"$+$ 4-digit occupation",
        ["", "", "", "", "", "", chk, chk, "", "", "", ""]))
    lines.append(row_n(r"$+$ Tenure bins",
        ["", "", "", "", "", "", "", "", chk, chk, "", ""]))
    lines.append(row_n(r"$+$ Tenure polynomial",
        ["", "", "", "", "", "", "", "", "", "", chk, chk]))

    lines += [
        r"\bottomrule",
        r"\end{tabular}%",
        r"}",   # close \resizebox
        r"\scriptsize",
        r"\begin{tablenotes}",
        r"\item \textit{Notes:} " + _NOTES_DIRECT,
        r"\end{tablenotes}",
        r"\end{threeparttable}",
        r"\end{table}",
    ]

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Table 2: Spillover effects (4 columns)
# ---------------------------------------------------------------------------

def build_spillover_table(cell):
    """6-column table: 6 specs, spillover sample only."""
    ncols = 6
    lines = []
    lines += [
        r"\begin{table}[H]",
        r"\centering",
        r"\caption{Spillover Wage Effects Across Residualization Specifications}",
        r"\label{tab:resid_explore_spill}",
        r"\scriptsize",
        r"\begin{threeparttable}",
        r"\begin{tabular}{lcccccc}",
        r"\toprule\toprule",
    ]

    # Column headers
    lines.append(r" & (1) & (2) & (3) & (4) & (5) & (6) \\")
    lines.append(
        r" & Raw & Base resid. & +2-dig.\ occ."
        r" & +4-dig.\ occ. & +Ten.\ bins & +Ten.\ poly. \\"
    )
    lines.append(r"\midrule")

    d = cell["spill"]

    def vals6(row_type, **kw):
        return [get_val(d[c], row_type, **kw) for c in COLS]

    lines.append(row_n(r"Post $\times$ Connectivity", vals6("main")))
    lines.append(row_n("", vals6("main_se", is_se=True)))
    lines.append(blank_n(ncols))

    lines.append(row_n(r"Pre $\times$ Connectivity", vals6("pre")))
    lines.append(row_n("", vals6("pre_se", is_se=True)))

    lines.append(r"\midrule")

    lines.append(row_n(r"Pre-trend $F$-test $p$-val", vals6("pre_pval", is_pval=True)))
    lines.append(blank_n(ncols))

    lines.append(row_n(r"Mean (2009)",    vals6("mean_pre")))
    lines.append(row_n(r"Observations",  vals6("n_obs",   is_count=True)))
    lines.append(row_n(r"Establishments", vals6("n_estab", is_count=True)))

    lines.append(r"\midrule")

    lines.append(
        r"\multicolumn{7}{l}{\textit{Specification details (residualization cell)}}\\"
    )
    chk = r"\checkmark"
    lines.append(row_n(r"Age polynomial",
        ["", chk, chk, chk, chk, chk]))
    lines.append(row_n(r"$+$ 2-digit occupation",
        ["", "", chk, "", "", ""]))
    lines.append(row_n(r"$+$ 4-digit occupation",
        ["", "", "", chk, "", ""]))
    lines.append(row_n(r"$+$ Tenure bins",
        ["", "", "", "", chk, ""]))
    lines.append(row_n(r"$+$ Tenure polynomial",
        ["", "", "", "", "", chk]))

    lines += [
        r"\bottomrule",
        r"\end{tabular}",
        r"\scriptsize",
        r"\begin{tablenotes}",
        r"\item \textit{Notes:} " + _NOTES_SPILL,
        r"\end{tablenotes}",
        r"\end{threeparttable}",
        r"\end{table}",
    ]

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# LaTeX document wrapper
# ---------------------------------------------------------------------------

def latex_document(body):
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
{\Huge\bfseries Union Spillovers:\\Residualization Exploration\par}
\vspace{2cm}
{\Large Comparing Raw vs.\ Mincer-Residualized Wage Effects\par}
\vspace{1cm}
{\large \today\par}
\vfill
{\large Luis Gomes\\Northwestern University\par}
\end{titlepage}

"""
    footer = r"\end{document}"
    return header + body + "\n\n" + footer


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    cell = load_all()
    t1 = build_direct_table(cell)
    t2 = build_spillover_table(cell)
    content = latex_document(t1 + "\n\n\\clearpage\n\n" + t2)
    OUTPUT_FILE.write_text(content)
    print(f"Generated {OUTPUT_FILE}")
    print("  Table 1: Direct effects    (12 cols: 6 specs × A/B)")
    print("  Table 2: Spillover effects  (6 cols: 6 specs)")


if __name__ == "__main__":
    main()
