#!/usr/bin/env python
"""
generate_cba_period_arms_vingtiles_latex.py

Four-arm comparison table with VINGTILE control bins.

Reads : Tables/max_clause_row/cba_period_arms_vingtiles_comparison.csv   (written by Stata)
Writes: Tables/max_clause_row/cba_period_arms_vingtiles_comparison.tex
        Tables/max_clause_row/cba_period_arms_vingtiles_standalone.tex

Arms:
  v1_all   current published definition, all rows
  v1_max   v1 periods, max-clause row per establishment x cba_period
  v1_mean  v1 periods, CBA outcomes replaced by their within-cell mean
  v2       new periodization, unique by construction

Run with: ~/.conda/envs/venv_python312/bin/python
"""

from pathlib import Path

import pandas as pd

tables_dir = Path(__file__).resolve().parent.parent.parent / "Tables"
pipeline_dir = tables_dir / "max_clause_row"
csv_path = pipeline_dir / "cba_period_arms_vingtiles_comparison.csv"
tex_path = pipeline_dir / "cba_period_arms_vingtiles_comparison.tex"
standalone_path = pipeline_dir / "cba_period_arms_vingtiles_standalone.tex"

ARMS = ["v1_all", "v1_max", "v1_mean", "v2"]

OUTCOME_LABELS = {
    "numb_clauses": "Total clauses",
    "wage_clauses": "Wage clauses",
    "emp_clauses": "Employment clauses",
    "other_clauses": "Other clauses",
    "wage_clause_prop": "Wage share",
    "emp_clause_prop": "Employment share",
    "other_clause_prop": "Other share",
    "cba_value": "CBA value",
}

GROUPS = [
    ("Direct effect (Sample A)", [("direct_A", "numb_clauses")]),
    ("Direct effect (Sample C)", [("direct_C", "numb_clauses")]),
    ("Spillover: clause count", [("spillover", "numb_clauses")]),
    (
        "Spillover: CBA composition",
        [
            ("spillover", "wage_clauses"),
            ("spillover", "emp_clauses"),
            ("spillover", "other_clauses"),
            ("spillover", "wage_clause_prop"),
            ("spillover", "emp_clause_prop"),
            ("spillover", "other_clause_prop"),
        ],
    ),
    ("Spillover: CBA value", [("spillover", "cba_value")]),
]

N_COLS = 13


def stars(p):
    if pd.isna(p):
        return ""
    return "***" if p < 0.01 else "**" if p < 0.05 else "*" if p < 0.10 else ""


def load():
    df = pd.read_csv(csv_path)
    return df.pivot_table(
        index=["regression", "outcome", "arm"], columns="stat", values="value"
    )


def cell(v, d=4):
    return "--" if pd.isna(v) else f"{v:.{d}f}"


def build_panel(w, panel):
    lines = []
    for group_label, members in GROUPS:
        lines.append(rf"\multicolumn{{{N_COLS}}}{{l}}{{\textit{{{group_label}}}}} \\")
        for regression, outcome in members:
            rows = {a: w.loc[(regression, outcome, a)] for a in ARMS}
            label = OUTCOME_LABELS.get(outcome, outcome)

            if panel == "main":
                coefs = [rows[a]["post_coef"] for a in ARMS]
                ses = [rows[a]["post_se"] for a in ARMS]
                ps = [rows[a]["post_pval"] for a in ARMS]
                obs = [f"{int(rows[a]['n_obs']):,}" for a in ARMS]
                est = [f"{int(rows[a]['n_estab']):,}" for a in ARMS]
            else:
                coefs = [rows[a]["pre_coef"] for a in ARMS]
                ses = [rows[a]["pre_se"] for a in ARMS]
                ps = [rows[a]["pre_pval"] for a in ARMS]
                obs = [f"{int(rows[a]['pre_n_obs']):,}" for a in ARMS]
                est = [f"{int(rows[a]['pre_n_estab']):,}" for a in ARMS]

            coef_cells = " & ".join(f"{cell(c)}{stars(p)}" for c, p in zip(coefs, ps))
            se_cells = " & ".join(f"({cell(s)})" for s in ses)

            lines.append(
                rf"\quad {label} & {coef_cells} & {' & '.join(obs)} & {' & '.join(est)} \\"
            )
            lines.append(rf" & {se_cells} & & & & & & & & \\")
        lines.append(r"\\[-0.5em]")
    if lines and lines[-1] == r"\\[-0.5em]":
        lines.pop()
    return lines


def build_table(w):
    header = [
        r"\begin{table}[H]",
        r"\centering",
        r"\caption{CBA Outcomes under Four Treatments of Duplicated Agreement Rows, Vingtile Control Bins}",
        r"\label{tab:cba_period_arms_vingtiles}",
        r"\scriptsize",
        r"\begin{tabular}{lcccccccccccc}",
        r"\toprule\toprule",
        r" & \multicolumn{4}{c}{Estimate} & \multicolumn{4}{c}{Observations} "
        r"& \multicolumn{4}{c}{Establishments} \\",
        r"\cmidrule(lr){2-5} \cmidrule(lr){6-9} \cmidrule(lr){10-13}",
        r" & Current & \shortstack{Max\\clause} & \shortstack{Mean\\clause} & \shortstack{Period\\v2}"
        r" & Current & \shortstack{Max\\clause} & \shortstack{Mean\\clause} & \shortstack{Period\\v2}"
        r" & Current & \shortstack{Max\\clause} & \shortstack{Mean\\clause} & \shortstack{Period\\v2} \\",
        r" & (1) & (2) & (3) & (4) & (5) & (6) & (7) & (8) & (9) & (10) & (11) & (12) \\",
        r"\midrule",
        rf"\multicolumn{{{N_COLS}}}{{l}}{{\textbf{{Panel A: Post $\times$ Treatment or Connectivity}}}} \\",
        r"\midrule",
    ]

    body_main = build_panel(w, "main")

    mid = [
        r"\midrule",
        rf"\multicolumn{{{N_COLS}}}{{l}}{{\textbf{{Panel B: Pre-trend (placebo)}}}} \\",
        r"\midrule",
    ]

    body_pre = build_panel(w, "pre")

    notes = (
        r"This table reports difference-in-differences estimates for collective "
        r"bargaining agreement outcomes under three definitions of the CBA period. "
        r"Column (1) uses the current definition, which assigns the period from the "
        r"agreement's average filing date; because the panel repeats each agreement "
        r"across every December it covers, an establishment can appear more than once "
        r"in a period. Column (2) keeps the current definition but retains only the "
        r"highest-clause row within each establishment by period cell. Column (3) instead "
        r"replaces each outcome by its mean within that cell and keeps one row, which "
        r"unlike the max rule does not select on the outcome; the clause-type shares are "
        r"averaged as shares rather than recomputed from averaged counts. Column (4) uses "
        r"an alternative periodization: the two pre-treatment periods identify the same "
        r"agreements as the current definition, namely the 2009 agreement and its "
        r"earliest renewal, retaining the earliest December of each; the post-treatment "
        r"periods are the Decembers in which a new agreement first takes effect, "
        r"detected as a change in the agreement's start date relative to the "
        r"establishment's previous year, and indexed by calendar year. Under column (4) "
        r"each establishment appears at most once per period by construction, which is "
        r"verified in the estimation code. All pre-treatment control bins are "
        r"constructed once on the unrestricted panel using the current period definition "
        r"and are held fixed across the four columns, so the columns differ only in the "
        r"periodization and in which rows enter. All specifications include "
        r"establishment fixed effects and period fixed effects interacted with two-digit "
        r"industry, microregion, and negotiation-month indicators and with vingtile bins "
        r"of pre-treatment firm size, per-worker flows, and the outcome. The bins are "
        r"constructed as in the paper's bin-sensitivity robustness exercise, cutting each "
        r"pre-treatment variable into twenty groups on the 2009 balanced-panel cross-section "
        r"and assigning each establishment its own bin, with missing per-worker flows "
        r"assigned to the reference category. Sample A "
        r"restricts the comparison group to untreated establishments with zero "
        r"connectivity; Sample C includes all untreated establishments. Spillover "
        r"specifications are estimated on untreated establishments, with connectivity "
        r"normalized by its 90th percentile. Panel B reports placebo regressions "
        r"estimated on the pre-treatment periods only, with the sample sizes of those "
        r"regressions. Standard errors clustered at the establishment level in "
        r"parentheses. *** p$<$0.01, ** p$<$0.05, * p$<$0.10."
    )

    footer = [
        r"\bottomrule\bottomrule",
        r"\end{tabular}",
        r"",
        r"\begin{minipage}{\linewidth}",
        r"\scriptsize\vspace{4pt}",
        rf"    \textit{{Notes:}} {notes}",
        r"\end{minipage}",
        r"\end{table}",
    ]

    return "\n".join(header + body_main + mid + body_pre + footer) + "\n"


def build_standalone():
    return r"""\documentclass[11pt]{article}
\usepackage[a3paper,landscape,left=0.5in,right=0.5in,top=0.5in,bottom=0.5in]{geometry}
\usepackage{booktabs}
\usepackage{float}
\usepackage{amsmath}
\usepackage{caption}
\begin{document}
\pagestyle{empty}
\input{cba_period_arms_vingtiles_comparison.tex}
\end{document}
"""


def main():
    w = load()
    tex_path.write_text(build_table(w))
    standalone_path.write_text(build_standalone())
    print(f"Wrote {tex_path}")

    print("\n--- sign flips / significance changes vs current (column 1) ---")
    for _, members in GROUPS:
        for regression, outcome in members:
            base = w.loc[(regression, outcome, "v1_all")]
            for a in ["v1_max", "v2"]:
                alt = w.loc[(regression, outcome, a)]
                flip = (base["post_coef"] > 0) != (alt["post_coef"] > 0)
                sig = stars(base["post_pval"]) != stars(alt["post_pval"])
                if flip or sig:
                    print(
                        f"  {regression:10s} {outcome:18s} {a:7s} "
                        f"{base['post_coef']:+.4f}{stars(base['post_pval']):<3s} -> "
                        f"{alt['post_coef']:+.4f}{stars(alt['post_pval']):<3s}"
                        f"{'  SIGN FLIP' if flip else ''}"
                        f"{'  SIG CHANGE' if sig else ''}"
                    )


if __name__ == "__main__":
    main()
