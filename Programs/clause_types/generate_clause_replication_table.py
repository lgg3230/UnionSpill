#!/usr/bin/env python3
"""
generate_clause_replication_table.py
====================================
Builder for the "Spillover Effects on CBA Composition and Value" exhibit
(t_clause.tex) in UnionSpill-paper/Replication/Replication_Wages vs Hourly.tex.

Seven columns drawn from TWO pipelines:
    (1)-(3) clause-type counts   -- clause_types.do
    (4)-(6) clause-type shares   -- clause_types.do
    (7)     wage-equivalent value -- cba_value/Main_Results_cba_value.do

Like t_spill and t_direct, this fragment had no generator and is inlined twice,
once per half of the document.

Inputs:
    Tables/currentconn_full/clause_types/results_spill_clause_counts_tfpw_07_11.csv
    Tables/currentconn_full/clause_types/results_spill_clause_props_tfpw_07_11.csv
    Tables/currentconn_full/cba_value/results_spill_cba_value.csv

Output:
    Tables/clause_types/t_clause.tex

Usage
-----
    python generate_clause_replication_table.py                # no mean row
    python generate_clause_replication_table.py --with-mean    # adds it
"""

import argparse
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[2]
CT_DIR = PROJECT / "Tables" / "currentconn_full" / "clause_types"
CV_DIR = PROJECT / "Tables" / "currentconn_full" / "cba_value"
OUT_DIR = PROJECT / "Tables" / "clause_types"
OUT_TEX = OUT_DIR / "t_clause.tex"

COUNTS_CSV = CT_DIR / "results_spill_clause_counts_tfpw_07_11.csv"
PROPS_CSV = CT_DIR / "results_spill_clause_props_tfpw_07_11.csv"
VALUE_CSV = CV_DIR / "results_spill_cba_value.csv"

# (source key, outcome name in that source)
COLUMNS = [
    ("counts", "wage_clauses"),
    ("counts", "emp_clauses"),
    ("counts", "other_clauses"),
    ("props", "wage_clause_prop"),
    ("props", "emp_clause_prop"),
    ("props", "other_clause_prop"),
    ("value", "cba_value"),
]

NOTES = (
    r"    \textit{Notes:} This table presents difference-in-differences "
    r"estimates of the reform's spillover effects (equation "
    r"(\ref{eq:spill_spec})) on the content of collective agreements, on the "
    r"full sample of untreated establishments, using the current recomputable "
    r"connectivity measure. Columns (1)--(3) report effects on the counts of "
    r"wage-related, employment-related, and other clauses, following "
    r"\textit{Sistema Mediador}'s classification; columns (4)--(6) report "
    r"effects on each type's share of total clauses. Column (7) reports the "
    r"effect on agreement value, the sum across the 24 \textit{Sistema "
    r"Mediador} subgroups of each subgroup's clause count weighted by its "
    r"wage-equivalent value from \citet{Lagos2026}, expressed in log wage "
    r"points. Connectivity is normalized so that a value of 1 corresponds to "
    r"the 90th percentile among untreated establishments. Post $\times$ "
    r"Connectivity reports the average effect for 2012--2016, with 2011 as the "
    r"reference year. Pre-trend (placebo) reports the coefficient from a "
    r"placebo regression estimated on pre-treatment data only (2009--2010 "
    r"relative to 2011). All specifications include establishment fixed effects "
    r"and year fixed effects interacted with two-digit industry, microregion, "
    r"and negotiation-month indicators and with quartile bins of pre-treatment "
    r"firm size, per-worker flows, and outcome. Standard errors clustered at "
    r"the establishment level in parentheses. *** p$<$0.01, ** p$<$0.05, "
    r"* p$<$0.10."
)

MEAN_NOTE = (
    r" Pre-treatment mean is the mean of the dependent variable over "
    r"2009--2011 in the estimation sample of the corresponding column."
)


def load_csv(path):
    if not path.exists():
        raise SystemExit(f"Missing input: {path}")
    data = {}
    with open(path) as fh:
        next(fh)
        for line in fh:
            parts = [p.strip().strip('"') for p in line.strip().split(";")]
            if len(parts) < 5:
                continue
            _spec, _section, outcome, row_type, value = parts[:5]
            data.setdefault(outcome, {})[row_type] = value.strip().strip('"').strip()
    if not data:
        raise SystemExit(
            f"{path.name} is header-only. Re-run the pipeline that writes it."
        )
    return data


def fmt_num(raw):
    val = raw.strip()
    return "$-$" + val[1:] if val.startswith("-") else val


def fmt_se(raw):
    return f"({fmt_num(raw)})"


def fmt_count(raw):
    return raw.strip().replace(",", "{,}")


def fmt_mean(raw):
    """CSV keeps 4 decimals; the table shows 3 (decision 2026-08-02)."""
    val = float(raw.strip())
    return ("$-$" if val < 0 else "") + f"{abs(val):.3f}"


def build(sources, with_mean):
    ncol = len(COLUMNS)

    def cell(row_type, formatter):
        out = []
        for src, outcome in COLUMNS:
            try:
                raw = sources[src][outcome][row_type]
            except KeyError:
                raise SystemExit(
                    f"Missing '{row_type}' for '{outcome}' in the {src} source. "
                    "Re-run that pipeline."
                )
            out.append(f" & {formatter(raw)}")
        return "".join(out)

    lines = [
        r"\begin{table}[H]",
        r"\centering",
        r"\caption{Spillover Effects on CBA Composition and Value}",
        r"\footnotesize",
        r"\begin{tabular}{l" + "c" * ncol + "}",
        r"\toprule\toprule",
        r" & \multicolumn{3}{c}{Clause-type counts} & "
        r"\multicolumn{3}{c}{Clause-type shares} & "
        r"\begin{tabular}[c]{@{}c@{}}Wage-equivalent\\ value\end{tabular} \\",
        r"\cmidrule(lr){2-4}\cmidrule(lr){5-7}\cmidrule(lr){8-8}",
        r" & Wage & Employment & Other & Wage & Employment & Other & \\",
        "".join(f" & ({i})" for i in range(1, ncol + 1)) + r" \\",
        r"\midrule",
        r"Post $\times$ Connectivity" + cell("main", fmt_num) + r"\\",
        cell("main_se", fmt_se) + r"\\",
        " & " * ncol + r"\\",
    ]

    if with_mean:
        lines.append("Pre-treatment mean" + cell("mean_pre", fmt_mean) + r"\\")

    lines += [
        "Observations" + cell("n_obs", fmt_count) + r"\\",
        "Establishments" + cell("n_estab", fmt_count) + r"\\",
        r"\midrule",
        "Pre-trend (placebo)" + cell("pre", fmt_num) + r"\\",
        cell("pre_se", fmt_se) + r"\\",
        r"\bottomrule\bottomrule",
        r"\end{tabular}",
        r"\begin{minipage}{\linewidth}",
        r"\scriptsize\vspace{4pt}",
        NOTES + (MEAN_NOTE if with_mean else ""),
        r"\end{minipage}",
        r"\end{table}",
    ]
    return "\n".join(lines) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--with-mean", action="store_true",
                    help="emit the Pre-treatment mean row (needs mean_pre in the CSVs)")
    args = ap.parse_args()

    sources = {
        "counts": load_csv(COUNTS_CSV),
        "props": load_csv(PROPS_CSV),
        "value": load_csv(VALUE_CSV),
    }

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    OUT_TEX.write_text(build(sources, args.with_mean))
    print(f"wrote {OUT_TEX}")


if __name__ == "__main__":
    main()
