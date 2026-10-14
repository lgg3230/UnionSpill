#!/usr/bin/env python3
"""
4310_table_joint_spec_latex.py
==============================
Tables of the joint specification (direct effect and connectivity spillover in
one regression).

  Joint specification table (tab:joint_spec), the summary table
    Post x Treatment (joint_direct) and Post x Connectivity (joint_spill) from
    the same regression, one column per outcome
  Comparison tables, each joint coefficient next to the main specification:
  Direct effects table (tab:joint_spec_direct)
    Panel A (direct_A)     main spec, zero-connectivity controls (paper headline)
    Panel B (direct_C)     main spec, all untreated controls
    Panel C (joint_direct) joint spec, Post x Treatment
  Spillover table (tab:joint_spec_spill)
    Panel A (spill)        main spec, untreated establishments
    Panel B (joint_spill)  joint spec, Post x Connectivity

Layout follows the unionspill-tables conventions (4160_table_pct_latex.py):
\\scriptsize, double top rule, panel title cells, (1)-(4) column numbers.

Input (written by 3212_joint_spec.do via 3211_joint_spec.do):
    Tables/joint_spec/results_joint_spec.csv

Output:
    Tables/joint_spec/joint_spec_table.tex            joint specification only
    Tables/joint_spec/joint_spec_tables.tex           comparison tables (direct, spillover)
    Tables/joint_spec/<name>_preview.tex              standalone wrappers
    Tables/joint_spec/<name>_preview.pdf              with --preview

Usage
-----
    python 4310_table_joint_spec_latex.py [TABLES_DIR] [--preview]
"""

import argparse
import re
import shutil
import subprocess
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[3]
CSV_NAME = "results_joint_spec.csv"
JOINT_NAME = "joint_spec_table.tex"
COMPARE_NAME = "joint_spec_tables.tex"

OUTCOMES = ["lr_remdezr_h_w", "lr_remdezr_w", "l_firm_emp", "numb_clauses"]
COL_HEADERS = [r"Log Hourly\\Wages", r"Log\\Wages", r"Log\\Employment", r"Number of\\Clauses"]
NCOL = len(OUTCOMES)
BLANK_ROW = " &" * NCOL + r" \\"


# ── LaTeX cell helpers ────────────────────────────────────────────────────────

def hdr(text):
    return r"\begin{tabular}[c]{@{}c@{}}" + text + r"\end{tabular}"


def panel_cell(bold, italic1, italic2):
    return (r"\begin{tabular}[c]{@{}l@{}}\textbf{" + bold + r"} \textit{" + italic1
            + r"}\\ \textit{" + italic2 + r"}\end{tabular}")


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


def format_value(raw, is_se=False, is_count=False, is_pval=False, is_mean=False):
    raw = raw.strip()
    if raw in ("--", ""):
        return "--"
    if is_count:
        return raw.replace(",", "{,}")
    if is_pval:
        return f"[{float(raw):.2f}]"
    if is_mean:
        return f"{float(raw):.3f}"
    match = re.match(r"^([^*]+?)(\*{1,3})?$", raw)
    if not match:
        return raw
    num_str = match.group(1).strip()
    stars = match.group(2) or ""
    if num_str.startswith("-"):
        num_str = r"$-$" + num_str[1:]
    return f"({num_str})" if is_se else f"{num_str}{stars}"


def row(label, sec_data, row_type, **kw):
    cells = []
    for o in OUTCOMES:
        try:
            cells.append(format_value(sec_data[o][row_type], **kw))
        except KeyError:
            cells.append("--")
    return f"{label} & " + " & ".join(cells) + r" \\"


# ── Table pieces ──────────────────────────────────────────────────────────────

def panel(cell, sec_data, term, joint=False):
    lines = [
        cell + " & " + " & ".join(hdr(h) for h in COL_HEADERS) + r" \\",
        " & " + " & ".join(f"({i})" for i in range(1, NCOL + 1)) + r" \\",
        r"\midrule",
        row(rf"Post $\times$ {term}", sec_data, "main"),
        row("", sec_data, "main_se", is_se=True),
        row(rf"Pre $\times$ {term}", sec_data, "pre"),
        row("", sec_data, "pre_se", is_se=True),
        row(r"Pre-trend $F$-test $p$-value", sec_data, "pre_pval", is_pval=True),
    ]
    if joint:
        lines.append(row(r"Pre-trend $F$-test $p$-value, both terms", sec_data,
                         "pre_pval_both", is_pval=True))
    lines += [
        BLANK_ROW,
        row(r"Pre-period mean of dep.\ var.", sec_data, "mean_pre", is_mean=True),
        row("Observations", sec_data, "n_obs", is_count=True),
        row("Establishments", sec_data, "n_estab", is_count=True),
        BLANK_ROW,
    ]
    return lines


def table(caption, label, panels, notes):
    lines = [
        r"\begin{table}[]",
        r"\centering",
        rf"\caption{{{caption}}}",
        rf"\label{{{label}}}",
        r"\scriptsize",
        r"\begin{threeparttable}",
        r"\begin{tabular}{l" + "c" * NCOL + "}",
        r"\toprule\toprule",
    ]
    for i, p in enumerate(panels):
        if i > 0:
            lines.append(r"\midrule")
        lines += p
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
    return "\n".join(lines) + "\n"


REFORM_SAMPLE = (
    r"The reform, effective September~25, 2012, extended existing CBAs indefinitely upon "
    r"expiration, increasing bargaining power at treated establishments. The sample covers "
    r"Brazilian establishments in the Lagos sample observed annually from 2009 to 2016."
)

JOINT_DEF = (
    r"The joint specification is "
    r"$Y_{it} = \alpha_i + \beta\,(\text{Post}_t \times T_i) + \gamma\,(\text{Post}_t \times C_i) "
    r"+ X_{it}'\delta + \varepsilon_{it}$, estimated on treated and all untreated establishments, "
    r"where $C_i$ is connectivity to treated establishments (normalized so that 1 is the 90th "
    r"percentile among untreated establishments in 2009) for untreated establishments and zero for "
    r"treated ones. $\gamma$ is therefore identified only from untreated establishments, and "
    r"$\beta$ compares treated establishments with untreated establishments at zero connectivity, "
    r"adjusting linearly for connectivity."
)

POST_PRE = (
    r"Post coefficients measure the average effect for 2012--2016; Pre coefficients come from a "
    r"placebo regression on 2009--2011 comparing 2009--2010 with 2011."
)

CBA_TIME = (
    r"For the number of clauses, time is measured in CBA periods: Post covers agreements signed "
    r"from 2013 on, and the base is the 2010--2012 agreement."
)

CONTROLS = (
    r"All regressions include establishment fixed effects, year fixed effects interacted with "
    r"two-digit industry, microregion, and negotiation-month indicators, and quartile-bin "
    r"controls for the pre-treatment outcome, pre-treatment establishment size, and "
    r"pre-treatment per-worker pairwise worker flows (2007--2011), interacted with year (or "
    r"CBA-period) fixed effects. Standard errors clustered at the establishment level in "
    r"parentheses. *** p$<$0.01, ** p$<$0.05, * p$<$0.10."
)

TIMING_CONTROLS = " ".join([
    POST_PRE,
    r"The pre-trend $F$-test $p$-value tests that the 2009 and 2010 event-study coefficients of "
    r"that term are zero (base year 2011); in the joint panel the second $p$-value tests both "
    r"terms together.",
    CBA_TIME,
    CONTROLS,
])

# Notes of the joint table, in the voice of the Draft.tex table notes
# (tab:direct_connectivity_robust, tab:spill_main_4tf_out): equation references,
# comparison group, one sentence per row label, fixed effects, clustering.
JOINT_NOTES = " ".join([
    r"This table presents difference-in-differences estimates of the reform's direct and "
    r"spillover effects from a single regression that combines equations "
    r"(\ref{eq:dir_spec}) and (\ref{eq:spill_spec}), estimated on directly treated and all "
    r"untreated establishments.",
    r"Connectivity is set to zero for directly treated establishments, so Post $\times$ "
    r"Connectivity is identified only from untreated establishments, and Post $\times$ Treatment "
    r"compares directly treated establishments with untreated establishments at zero "
    r"connectivity, adjusting linearly for connectivity among the rest.",
    r"Connectivity is normalized so that a value of 1 corresponds to the 90th percentile among "
    r"untreated establishments.",
    r"Wages and employment are measured in December of each year; clause counts are observed "
    r"only when a CBA is filed, reducing the number of observations in column~(4).",
    r"Post $\times$ Treatment and Post $\times$ Connectivity report average effects for "
    r"2012--2016, relative to the pre-reform period (2009--2011).",
    r"Pre $\times$ Treatment and Pre $\times$ Connectivity report the coefficients from a placebo "
    r"regression estimated on pre-treatment data only (2009--2010 relative to 2011).",
    r"Pre-trend $F$-test $p$-values are for the null that the 2009 and 2010 event-study "
    r"coefficients of each term, or of both terms together, are jointly zero.",
    r"Mean reports the average of the dependent variable over 2009--2011 in each column's "
    r"estimation sample, and \textit{of which untreated} counts the untreated observations that "
    r"identify Post $\times$ Connectivity.",
    r"All specifications include establishment fixed effects and year fixed effects interacted "
    r"with three-digit industry, microregion, and negotiation-month indicators and with quartile "
    r"bins of pre-treatment firm size, per-worker flows, and the outcome.",
    r"Clause-count regressions substitute CBA-period fixed effects for year fixed effects, and "
    r"their pre-trend tests use the 2009 agreement relative to the 2010--2012 one.",
    r"Standard errors clustered at the establishment level in parentheses. "
    r"*** p$<$0.01, ** p$<$0.05, * p$<$0.10.",
])

DIRECT_NOTES = " ".join([
    r"This table compares difference-in-differences estimates of the direct effect of Brazil's "
    r"2012 ultractivity reform from the paper's main specification with those from a joint "
    r"specification that also includes connectivity.",
    REFORM_SAMPLE,
    r"Panel~A reproduces the main specification, whose control group is untreated "
    r"establishments with zero pre-reform worker-flow connectivity to treated establishments; "
    r"Panel~B uses all untreated establishments as controls; Panel~C reports $\beta$ from the "
    r"joint specification, which uses the Panel~B sample.",
    JOINT_DEF,
    TIMING_CONTROLS,
])

SPILL_NOTES = " ".join([
    r"This table compares difference-in-differences estimates of the spillover effect of Brazil's "
    r"2012 ultractivity reform from the paper's main specification with those from a joint "
    r"specification that also includes the direct effect.",
    REFORM_SAMPLE,
    r"Panel~A reproduces the main specification, estimated on untreated establishments only; "
    r"Panel~B reports $\gamma$ from the joint specification. Observations and establishments in "
    r"Panel~B include the treated establishments, which have zero connectivity.",
    JOINT_DEF,
    TIMING_CONTROLS,
])


def make_joint_table(data):
    d, c = data.get("joint_direct", {}), data.get("joint_spill", {})
    for s in ("joint_direct", "joint_spill"):
        if s not in data:
            print(f"  WARNING: section {s} missing from {CSV_NAME}; its cells show '--'")
    lines = [
        r"\begin{table}[]",
        r"\centering",
        r"\caption{Direct and Spillover Effects Estimated Jointly}",
        r"\label{tab:joint_spec}",
        r"\scriptsize",
        r"\begin{tabular}{l" + "c" * NCOL + "}",
        r"\toprule\toprule",
        " & " + " & ".join(hdr(h) for h in COL_HEADERS) + r" \\",
        " & " + " & ".join(f"({i})" for i in range(1, NCOL + 1)) + r" \\",
        r"\midrule",
        row(r"Post $\times$ Treatment", d, "main"),
        row("", d, "main_se", is_se=True),
        row(r"Post $\times$ Connectivity", c, "main"),
        row("", c, "main_se", is_se=True),
        BLANK_ROW,
        row(r"Pre $\times$ Treatment", d, "pre"),
        row("", d, "pre_se", is_se=True),
        row(r"Pre $\times$ Connectivity", c, "pre"),
        row("", c, "pre_se", is_se=True),
        BLANK_ROW,
        row(r"Pre-trend $F$-test $p$-value: Treatment", d, "pre_pval", is_pval=True),
        row(r"Pre-trend $F$-test $p$-value: Connectivity", c, "pre_pval", is_pval=True),
        row(r"Pre-trend $F$-test $p$-value: both terms", d, "pre_pval_both", is_pval=True),
        BLANK_ROW,
        row("Mean", d, "mean_pre", is_mean=True),
        row("Observations", d, "n_obs", is_count=True),
        row("\\quad of which untreated", d, "n_obs_untr", is_count=True),
        row("Establishments", d, "n_estab", is_count=True),
        r"\bottomrule",
        r"\end{tabular}",
        # Notes span the page (\linewidth), not the table, as in Draft.tex
        r"\begin{minipage}{\linewidth}",
        r"    \scriptsize\vspace{4pt}",
        r"    \textit{Notes:} " + JOINT_NOTES,
        r"\end{minipage}",
        r"\end{table}",
    ]
    return "\n".join(lines) + "\n"


def make_tables(data):
    def sec(s):
        if s not in data:
            print(f"  WARNING: section {s} missing from {CSV_NAME}; its cells show '--'")
        return data.get(s, {})

    direct = table(
        "Direct Effects: Main and Joint Specifications",
        "tab:joint_spec_direct",
        [
            panel(panel_cell("Panel A:", "Main Specification,", "Zero-Connectivity Controls"),
                  sec("direct_A"), "Treatment"),
            panel(panel_cell("Panel B:", "Main Specification,", "All Untreated Controls"),
                  sec("direct_C"), "Treatment"),
            panel(panel_cell("Panel C:", "Joint Specification,", "All Untreated Controls"),
                  sec("joint_direct"), "Treatment", joint=True),
        ],
        DIRECT_NOTES,
    )
    spill = table(
        "Spillover Effects: Main and Joint Specifications",
        "tab:joint_spec_spill",
        [
            panel(panel_cell("Panel A:", "Main Specification,", "Untreated Establishments"),
                  sec("spill"), "Connectivity"),
            panel(panel_cell("Panel B:", "Joint Specification,", "Treated and Untreated"),
                  sec("joint_spill"), "Connectivity", joint=True),
        ],
        SPILL_NOTES,
    )
    return direct + "\n\\clearpage\n\n" + spill


PREVIEW = r"""\documentclass[12pt]{article}
\usepackage[left=1.0in,right=1.0in,top=1.0in,bottom=1.0in]{geometry}
\usepackage{lmodern}
\usepackage[T1]{fontenc}
\usepackage{booktabs, threeparttable, amsmath}
\pagestyle{empty}
\begin{document}
\input{%s}
\end{document}
"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("tables_dir", nargs="?", default=str(PROJECT / "Tables" / "joint_spec"))
    ap.add_argument("--preview", action="store_true", help="compile a standalone PDF")
    args = ap.parse_args()

    tables = Path(args.tables_dir)
    data = load_csv(tables / CSV_NAME)

    engine = (shutil.which("tectonic") or shutil.which("pdflatex")) if args.preview else None
    if args.preview and engine is None:
        print("  No tectonic or pdflatex on PATH; preview .tex files written but not compiled.")

    for name, content in ((JOINT_NAME, make_joint_table(data)),
                          (COMPARE_NAME, make_tables(data))):
        out = tables / name
        out.write_text(content)
        print(f"Wrote {out}")

        prev = tables / name.replace(".tex", "_preview.tex")
        prev.write_text(PREVIEW % name)
        if engine:
            cmd = [engine, prev.name] if engine.endswith("tectonic") else \
                  [engine, "-interaction=nonstopmode", prev.name]
            subprocess.run(cmd, cwd=tables, check=True,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            print(f"Wrote {prev.with_suffix('.pdf')}")


if __name__ == "__main__":
    main()
