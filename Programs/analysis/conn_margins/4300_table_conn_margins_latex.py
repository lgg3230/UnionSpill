#!/usr/bin/env python3
"""
4300_table_conn_margins_latex.py
================================
Wage table of the connectivity-margins exercise: three panels side by side,
log wages and log hourly wages in each.

  Panel A (ex1) - Extensive: Post x 1{conn > 0}, full spillover sample
  Panel B (ex2) - Intensive: Post x conn, positive-connectivity sample
  Panel C (ex3) - Saturated: both terms, full spillover sample

Layout and notes are those of make_wage_table() in
archive/Programs/conn_margins/generate_conn_margins_latex.py
(tab:conn_margins_wages); only the input changed.

Input (written by 3202_conn_margins_es.do via 3201_conn_margins_es.do):
    Tables/conn_margins/results_conn_margins_es.csv   sections ex1, ex2, ex3

Output:
    Tables/conn_margins/conn_margins_es_wages.tex           the table
    Tables/conn_margins/conn_margins_es_wages_preview.tex   standalone wrapper
    Tables/conn_margins/conn_margins_es_wages_preview.pdf   with --preview

Usage
-----
    python 4300_table_conn_margins_latex.py [TABLES_DIR] [--preview]
"""

import argparse
import re
import shutil
import subprocess
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[3]
CSV_NAME = "results_conn_margins_es.csv"
OUT_NAME = "conn_margins_es_wages.tex"
PREVIEW_NAME = "conn_margins_es_wages_preview.tex"

OUTCOMES = ["lr_remdezr_w", "lr_remdezr_h_w"]
BLANK = "--"


# ── LaTeX cell helpers ────────────────────────────────────────────────────────

def hdr(text):
    return r"\begin{tabular}[c]{@{}c@{}}" + text + r"\end{tabular}"


# ── CSV parsing ───────────────────────────────────────────────────────────────

def load_csv(filepath):
    """Parse the semicolon-delimited results CSV.

    Returns {section: {outcome: {row_type: value}}}.
    """
    data = {}
    with open(filepath) as f:
        next(f)  # skip header
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = line.replace('"', "").split(";")
            if len(parts) < 5:
                continue
            _, section, outcome, row_type, value = parts[:5]
            data.setdefault(section, {}).setdefault(outcome, {})[row_type] = value.strip()
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
    stars = match.group(2) or ""
    if num_str.startswith("-"):
        num_str = r"$-$" + num_str[1:]
    return f"({num_str})" if is_se else f"{num_str}{stars}"


def get_val(data, outcome, row_type, **kw):
    try:
        raw = data[outcome][row_type]
    except KeyError:
        return "--"
    return format_value(raw, **kw)


# ── Table ─────────────────────────────────────────────────────────────────────

NOTES = (
    r"\textit{Panel~A} replaces continuous connectivity with a binary "
    r"indicator on the full untreated sample. "
    r"\textit{Panel~B} restricts to establishments with positive "
    r"connectivity and runs the baseline continuous specification. "
    r"\textit{Panel~C} includes both the binary indicator and continuous "
    r"connectivity interacted with post on the full untreated sample. "
    r"All regressions include establishment fixed effects interacted with "
    r"two-digit industry, microregion, and negotiation-month indicators by year "
    r"(or CBA period), and quartile-bin controls for pre-treatment per-worker "
    r"pairwise worker flows (2007--2011) and pre-treatment establishment size. "
    r"Standard errors clustered at the establishment level in parentheses. "
    r"*** p$<$0.01, ** p$<$0.05, * p$<$0.10."
)


def make_wage_table(ex1, ex2, ex3):
    def v(data, o, rt, **kw):
        return get_val(data, o, rt, **kw)

    def se(data, o, rt):
        return get_val(data, o, rt, is_se=True)

    lines = [
        r"\begin{table}[]",
        r"\centering",
        r"\caption{Connectivity Margins and Wage Spillovers: Extensive, Intensive, "
        r"and Saturated Specifications \textcolor{red}{Diagnostic Only}}",
        r"\label{tab:conn_margins_wages}",
        r"\scriptsize",
        r"\begin{threeparttable}",
        r"\begin{tabular}{lcccccc}",
        r"\toprule\toprule",
        r" & \multicolumn{2}{c}{\textbf{Panel A: Extensive}} "
        r"& \multicolumn{2}{c}{\textbf{Panel B: Intensive}} "
        r"& \multicolumn{2}{c}{\textbf{Panel C: Saturated}} \\",
        r" & \multicolumn{2}{c}{\textit{Binary; Full Sample}} "
        r"& \multicolumn{2}{c}{\textit{Continuous; Pos-Conn Sample}} "
        r"& \multicolumn{2}{c}{\textit{Extensive + Intensive; Full Sample}} \\",
        r"\cmidrule(lr){2-3}\cmidrule(lr){4-5}\cmidrule(lr){6-7}",
        r" & " + r" & ".join([hdr(r"Log\\Wages"), hdr(r"Log Hourly\\Wages")] * 3) + r" \\",
        r" & (1) & (2) & (3) & (4) & (5) & (6) \\",
        r"\midrule",
    ]
    blank6 = r" & & & & & & \\"

    # Post coefficients
    lines.append(
        r"Post $\times$ Any Connection"
        + "".join(f" & {v(ex1, o, 'main')}" for o in OUTCOMES)
        + f" & {BLANK} & {BLANK}"
        + "".join(f" & {v(ex3, o, 'main_pos')}" for o in OUTCOMES)
        + r" \\"
    )
    lines.append(
        r" "
        + "".join(f" & {se(ex1, o, 'main_se')}" for o in OUTCOMES)
        + r" & & "
        + "".join(f" & {se(ex3, o, 'main_pos_se')}" for o in OUTCOMES)
        + r" \\"
    )
    lines.append(
        r"Post $\times$ Connectivity"
        + f" & {BLANK} & {BLANK}"
        + "".join(f" & {v(ex2, o, 'main')}" for o in OUTCOMES)
        + "".join(f" & {v(ex3, o, 'main_conn')}" for o in OUTCOMES)
        + r" \\"
    )
    lines.append(
        r" "
        + r" & & "
        + "".join(f" & {se(ex2, o, 'main_se')}" for o in OUTCOMES)
        + "".join(f" & {se(ex3, o, 'main_conn_se')}" for o in OUTCOMES)
        + r" \\"
    )
    lines.append(blank6)

    # Pre (placebo) coefficients
    lines.append(
        r"Pre $\times$ Any Connection"
        + "".join(f" & {v(ex1, o, 'pre')}" for o in OUTCOMES)
        + f" & {BLANK} & {BLANK}"
        + "".join(f" & {v(ex3, o, 'pre_pos')}" for o in OUTCOMES)
        + r" \\"
    )
    lines.append(
        r" "
        + "".join(f" & {se(ex1, o, 'pre_se')}" for o in OUTCOMES)
        + r" & & "
        + "".join(f" & {se(ex3, o, 'pre_pos_se')}" for o in OUTCOMES)
        + r" \\"
    )
    lines.append(
        r"Pre $\times$ Connectivity"
        + f" & {BLANK} & {BLANK}"
        + "".join(f" & {v(ex2, o, 'pre')}" for o in OUTCOMES)
        + "".join(f" & {v(ex3, o, 'pre_conn')}" for o in OUTCOMES)
        + r" \\"
    )
    lines.append(
        r" "
        + r" & & "
        + "".join(f" & {se(ex2, o, 'pre_se')}" for o in OUTCOMES)
        + "".join(f" & {se(ex3, o, 'pre_conn_se')}" for o in OUTCOMES)
        + r" \\"
    )

    # Event-study pre-trend F-tests
    lines.append(
        r"Pre-trend $F$: Any Connection"
        + "".join(f" & {v(ex1, o, 'pre_pval', is_pval=True)}" for o in OUTCOMES)
        + f" & {BLANK} & {BLANK}"
        + "".join(f" & {v(ex3, o, 'pre_pval_pos', is_pval=True)}" for o in OUTCOMES)
        + r" \\"
    )
    lines.append(
        r"Pre-trend $F$: Connectivity"
        + f" & {BLANK} & {BLANK}"
        + "".join(f" & {v(ex2, o, 'pre_pval', is_pval=True)}" for o in OUTCOMES)
        + "".join(f" & {v(ex3, o, 'pre_pval_conn', is_pval=True)}" for o in OUTCOMES)
        + r" \\"
    )
    lines.append(blank6)

    # Sample sizes
    for label, rt in (("Observations", "n_obs"), ("Establishments", "n_estab")):
        lines.append(
            label
            + "".join(f" & {v(ex, o, rt, is_count=True)}" for ex in (ex1, ex2, ex3) for o in OUTCOMES)
            + r" \\"
        )

    lines += [
        r"\bottomrule",
        r"\end{tabular}",
        r"\scriptsize",
        r"\begin{tablenotes}",
        r"\item \textit{Notes:} " + NOTES,
        r"\end{tablenotes}",
        r"\end{threeparttable}",
        r"\end{table}",
    ]
    return "\n".join(lines) + "\n"


PREVIEW = r"""\documentclass[12pt]{article}
\usepackage[left=1.0in,right=1.0in,top=1.0in,bottom=1.0in]{geometry}
\usepackage{lmodern}
\usepackage[T1]{fontenc}
\usepackage{booktabs, threeparttable, xcolor, amsmath}
\pagestyle{empty}
\begin{document}
\input{%s}
\end{document}
"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("tables_dir", nargs="?", default=str(PROJECT / "Tables" / "conn_margins"))
    ap.add_argument("--preview", action="store_true", help="compile a standalone PDF")
    args = ap.parse_args()

    tables = Path(args.tables_dir)
    data = load_csv(tables / CSV_NAME)
    for sec in ("ex1", "ex2", "ex3"):
        if sec not in data:
            print(f"  WARNING: section {sec} missing from {CSV_NAME}; its cells show '--'")
    ex1, ex2, ex3 = (data.get(s, {}) for s in ("ex1", "ex2", "ex3"))

    out = tables / OUT_NAME
    out.write_text(make_wage_table(ex1, ex2, ex3))
    print(f"Wrote {out}")

    prev = tables / PREVIEW_NAME
    prev.write_text(PREVIEW % OUT_NAME)
    if args.preview:
        engine = shutil.which("tectonic") or shutil.which("pdflatex")
        if engine is None:
            print("  No tectonic or pdflatex on PATH; preview .tex written but not compiled.")
            return
        cmd = [engine, PREVIEW_NAME] if engine.endswith("tectonic") else \
              [engine, "-interaction=nonstopmode", PREVIEW_NAME]
        subprocess.run(cmd, cwd=tables, check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print(f"Wrote {prev.with_suffix('.pdf')}")


if __name__ == "__main__":
    main()
