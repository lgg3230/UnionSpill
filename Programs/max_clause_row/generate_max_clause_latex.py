#!/usr/bin/env python
"""
generate_max_clause_latex.py

Builds the before/after comparison table for the max-clause-row restriction.

Reads : Tables/max_clause_row/max_clause_comparison.csv   (written by Stata)
Writes: Tables/max_clause_row/max_clause_comparison.tex   (bare table, [H] float)
        Tables/max_clause_row/max_clause_standalone.tex   (compile wrapper)

Before = current published CBA results (all rows).
After  = one row per identificad x cba_period, keeping the maximum clause count.

Run with: ~/.conda/envs/venv_python312/bin/python
"""

from pathlib import Path

import pandas as pd

# ---------------------------------------------------------------- paths
tables_dir = Path(__file__).resolve().parent.parent.parent / "Tables"
pipeline_dir = tables_dir / "max_clause_row"
csv_path = pipeline_dir / "max_clause_comparison.csv"
pretrend_csv_path = pipeline_dir / "pretrend_sample_sizes.csv"
tex_path = pipeline_dir / "max_clause_comparison.tex"
standalone_path = pipeline_dir / "max_clause_standalone.tex"

# ---------------------------------------------------------------- labels
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

# (group label, [(regression, outcome), ...])
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

N_COLS = 8


def stars(pval):
    if pd.isna(pval):
        return ""
    if pval < 0.01:
        return "***"
    if pval < 0.05:
        return "**"
    if pval < 0.10:
        return "*"
    return ""


def load():
    df = pd.read_csv(csv_path)
    # long -> wide on stat, keyed by (regression, outcome, arm)
    wide = df.pivot_table(
        index=["regression", "outcome", "arm"], columns="stat", values="value"
    ).reset_index()
    return wide


def load_pretrend():
    """Placebo regressions run on cba_period <= 2 only, so they have their own
    sample sizes and their own e(df_r). max_clause_row.do stores neither, so
    pretrend_sample_sizes.do re-estimates just the placebos and records
    pre_n_obs, pre_n_estab, and the exact t-based pre_pval."""
    pt = pd.read_csv(pretrend_csv_path)
    return pt.set_index(["regression", "outcome", "arm"])


def get_pretrend(pt, regression, outcome, arm):
    key = (regression, outcome, arm)
    if key not in pt.index:
        return None
    return pt.loc[key]


def cell(value, decimals=4):
    if pd.isna(value):
        return "--"
    return f"{value:.{decimals}f}"


def get(wide, regression, outcome, arm):
    row = wide[
        (wide["regression"] == regression)
        & (wide["outcome"] == outcome)
        & (wide["arm"] == arm)
    ]
    if row.empty:
        return None
    return row.iloc[0]


def build_panel(wide, pt, panel):
    """panel: 'main' or 'pre'. Returns list of LaTeX row strings."""
    lines = []
    for group_label, members in GROUPS:
        lines.append(
            rf"\multicolumn{{{N_COLS}}}{{l}}{{\textit{{{group_label}}}}} \\"
        )
        for regression, outcome in members:
            base = get(wide, regression, outcome, "baseline")
            filt = get(wide, regression, outcome, "filtered")
            if base is None or filt is None:
                continue

            if panel == "main":
                b_coef, b_se = base["post_coef"], base["post_se"]
                f_coef, f_se = filt["post_coef"], filt["post_se"]
                b_p, f_p = base["post_pval"], filt["post_pval"]
                obs_b = f"{int(base['n_obs']):,}"
                obs_f = f"{int(filt['n_obs']):,}"
                est_b = f"{int(base['n_estab']):,}"
                est_f = f"{int(filt['n_estab']):,}"
            else:
                # placebo sample sizes and exact t p-values come from the
                # dedicated placebo run, not from the main-effect CSV
                pb = get_pretrend(pt, regression, outcome, "baseline")
                pf_ = get_pretrend(pt, regression, outcome, "filtered")
                b_coef, b_se, b_p = pb["pre_coef"], pb["pre_se"], pb["pre_pval"]
                f_coef, f_se, f_p = pf_["pre_coef"], pf_["pre_se"], pf_["pre_pval"]
                obs_b = f"{int(pb['pre_n_obs']):,}"
                obs_f = f"{int(pf_['pre_n_obs']):,}"
                est_b = f"{int(pb['pre_n_estab']):,}"
                est_f = f"{int(pf_['pre_n_estab']):,}"

            delta = f_coef - b_coef
            label = OUTCOME_LABELS.get(outcome, outcome)

            lines.append(
                rf"\quad {label} & {cell(b_coef)}{stars(b_p)} & {cell(f_coef)}{stars(f_p)} "
                rf"& {cell(delta)} & {obs_b} & {obs_f} & {est_b} & {est_f} \\"
            )
            lines.append(
                rf" & ({cell(b_se)}) & ({cell(f_se)}) & & & & & \\"
            )
        lines.append(r"\\[-0.5em]")
    # drop trailing spacer
    if lines and lines[-1] == r"\\[-0.5em]":
        lines.pop()
    return lines


def build_table(wide, pt):
    header = [
        r"\begin{table}[H]",
        r"\centering",
        r"\caption{CBA Outcomes Before and After the One-Row-Per-CBA-Period Restriction}",
        r"\label{tab:max_clause_row}",
        r"\scriptsize",
        r"\begin{tabular}{lccccccc}",
        r"\toprule\toprule",
        r" & \shortstack{Before\\(current)} & \shortstack{After\\(max clause)} "
        r"& $\Delta$ & \shortstack{Obs.\\before} & \shortstack{Obs.\\after} "
        r"& \shortstack{Estab.\\before} & \shortstack{Estab.\\after} \\",
        r" & (1) & (2) & (3) & (4) & (5) & (6) & (7) \\",
        r"\midrule",
        rf"\multicolumn{{{N_COLS}}}{{l}}{{\textbf{{Panel A: Post $\times$ Treatment or Connectivity}}}} \\",
        r"\midrule",
    ]

    body_main = build_panel(wide, pt, "main")

    mid = [
        r"\midrule",
        rf"\multicolumn{{{N_COLS}}}{{l}}{{\textbf{{Panel B: Pre-trend (placebo)}}}} \\",
        r"\midrule",
    ]

    body_pre = build_panel(wide, pt, "pre")

    notes = (
        r"This table reports difference-in-differences estimates for collective "
        r"bargaining agreement outcomes before and after restricting the estimation "
        r"sample to one observation per establishment and CBA period. Column (1) "
        r"reproduces the current results, in which an agreement occupying several "
        r"firm-year rows contributes each of those rows. Column (2) keeps, within "
        r"each establishment by CBA-period cell containing more than one row, only "
        r"the row with the highest total clause count, breaking ties by earliest "
        r"agreement filing date and then earliest year; cells already containing a "
        r"single row are unchanged. The selection is made once on the total clause "
        r"count, and the selected row supplies every outcome, so the rows remain "
        r"mutually comparable. Column (3) reports the difference between columns "
        r"(2) and (1). Specifications are otherwise identical across the two "
        r"columns: all include establishment fixed effects and CBA-period fixed "
        r"effects interacted with two-digit industry, microregion, and "
        r"negotiation-month indicators and with quartile bins of pre-treatment firm "
        r"size, per-worker flows, and the outcome. All pre-treatment controls are "
        r"constructed on the unrestricted panel before the restriction is applied, "
        r"so the two columns differ only in which rows enter the regression. Sample "
        r"A restricts the comparison group to untreated establishments with zero "
        r"connectivity; Sample C includes all untreated establishments. Spillover "
        r"specifications are estimated on untreated establishments, with "
        r"connectivity normalized by its 90th percentile. Panel B reports "
        r"coefficients from placebo regressions estimated on pre-treatment CBA "
        r"periods only; columns (4) through (7) in that panel report the sample "
        r"sizes of those placebo regressions, which are smaller than the "
        r"corresponding Panel A samples because only CBA periods 1 and 2 enter. "
        r"Standard errors clustered at the establishment level in "
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
    # a3 landscape: the table is ~55 rows plus a long notes block, which
    # overflows letter landscape and leaves a blank first page under [H].
    return r"""\documentclass[11pt]{article}
\usepackage[a3paper,landscape,left=0.6in,right=0.6in,top=0.5in,bottom=0.5in]{geometry}
\usepackage{booktabs}
\usepackage{float}
\usepackage{amsmath}
\usepackage{caption}
\begin{document}
\pagestyle{empty}
\input{max_clause_comparison.tex}
\end{document}
"""


def main():
    wide = load()
    pt = load_pretrend()
    tex_path.write_text(build_table(wide, pt))
    standalone_path.write_text(build_standalone())
    print(f"Wrote {tex_path}")
    print(f"Wrote {standalone_path}")

    # console summary: flag sign flips and significance changes
    print("\n--- sign flips / significance changes (main effect) ---")
    for _, members in GROUPS:
        for regression, outcome in members:
            base = get(wide, regression, outcome, "baseline")
            filt = get(wide, regression, outcome, "filtered")
            if base is None or filt is None:
                continue
            flip = (base["post_coef"] > 0) != (filt["post_coef"] > 0)
            sig_change = stars(base["post_pval"]) != stars(filt["post_pval"])
            if flip or sig_change:
                print(
                    f"  {regression:12s} {outcome:20s} "
                    f"{base['post_coef']:+.4f}{stars(base['post_pval']):<3s} -> "
                    f"{filt['post_coef']:+.4f}{stars(filt['post_pval']):<3s}"
                    f"{'  SIGN FLIP' if flip else ''}"
                    f"{'  SIG CHANGE' if sig_change else ''}"
                )

    print("\n--- sample reduction ---")
    for _, members in GROUPS:
        for regression, outcome in members:
            base = get(wide, regression, outcome, "baseline")
            filt = get(wide, regression, outcome, "filtered")
            if base is None or filt is None:
                continue
            print(
                f"  {regression:12s} {outcome:20s} "
                f"obs {int(base['n_obs']):>7,} -> {int(filt['n_obs']):>7,} "
                f"({int(filt['n_obs'] - base['n_obs']):+,})   "
                f"estab {int(base['n_estab']):>6,} -> {int(filt['n_estab']):>6,} "
                f"({int(filt['n_estab'] - base['n_estab']):+,})"
            )


if __name__ == "__main__":
    main()
