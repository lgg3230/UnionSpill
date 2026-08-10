#!/usr/bin/env python3
"""
5020_table_spill.py
===================================
Builder for the "Spillover Effects: Current Recomputable Connectivity" exhibit
(t_spill.tex) in UnionSpill-paper/Replication/Replication_Wages vs Hourly.tex.

Until now this fragment had no generator -- it was assembled by hand from the
CSV. This script closes that gap so the pre-treatment mean row (plan
2026-08-01) can be emitted from data rather than typed in.

The fragment is inlined TWICE in the replication document, once in the
log-monthly-wage half and once in the log-hourly-wage half, because it already
carries both wage columns. One build covers both.

Input (semicolon-delimited rows under a comma-delimited header, written by
4012_pct_tfpw.do via 4011_pct_tfpw.do):
    Tables/pct_tfpw_cc/results_spill_tfpw_07_11_pct.csv

Output:
    Tables/main_results/t_spill.tex

Usage
-----
    python 5020_table_spill.py                # no mean row
    python 5020_table_spill.py --with-mean    # adds it

--with-mean requires a "mean_pre" row_type in the CSV, which
4012_pct_tfpw.do only emits after the step-3 edits. Without the
flag the output must match the committed fragment byte for byte; that equality
is the acceptance test for this script.
"""

import argparse
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[2]
CSV_IN = PROJECT / "Tables" / "pct_tfpw_cc" / "results_spill_tfpw_07_11_pct.csv"
OUT_DIR = PROJECT / "Tables" / "main_results"
OUT_TEX = OUT_DIR / "t_spill.tex"

# Column order and stub headers, matching the committed fragment.
COLUMNS = [
    ("lr_remdezr_w", r"Log \\ Wages"),
    ("lr_remdezr_h_w", r"Log Hourly \\ Wages"),
    ("l_firm_emp", r"Log \\ Employment"),
    ("numb_clauses", r"Clause \\ Count"),
]

NOTES = (
    r"    \textit{Notes:} This table presents difference-in-differences "
    r"estimates of the reform's spillover effects (equation "
    r"(\ref{eq:spill_spec})) on the full sample of untreated establishments "
    r"using the current recomputable connectivity measure from "
    r"\texttt{Data/RAIS\_aux/connectivity\_treat\_2007\_2011\_agg.dta}. "
    r"Connectivity is \texttt{totaltreat\_pw\_n\_current}, normalized by its "
    r"90th percentile among untreated establishments, so that a value of 1 "
    r"corresponds to the 90th percentile. Wages and employment are measured "
    r"in December of each year; clause counts are observed only when a CBA is "
    r"filed, reducing the number of observations in column~(4). Post $\times$ "
    r"Connectivity reports the average effect for 2012--2016, with 2011 as "
    r"the reference year. Pre-trend (placebo) reports the coefficient from a "
    r"placebo regression estimated on pre-treatment data only (2009--2010 "
    r"relative to 2011). All specifications include establishment fixed "
    r"effects and year or CBA-period fixed effects interacted with two-digit "
    r"industry, microregion, and negotiation-month indicators and with "
    r"quartile bins of pre-treatment firm size, per-worker flows, and the "
    r"outcome. Standard errors clustered at the establishment level in "
    r"parentheses. *** p$<$0.01, ** p$<$0.05, * p$<$0.10."
)

MEAN_NOTE = (
    r" Pre-treatment mean is the mean of the dependent variable over "
    r"2009--2011 in the estimation sample of the corresponding column."
)


def load_csv(path):
    """Parse Stata postfile output into {outcome: {row_type: value}}.

    The header is comma-delimited while the data rows are semicolon-delimited,
    so the header is skipped rather than parsed.
    """
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
    return data


def fmt_num(raw):
    """Stata writes a plain ASCII minus; LaTeX needs $-$ for a proper sign."""
    val = raw.strip()
    if val.startswith("-"):
        return "$-$" + val[1:]
    return val


def fmt_se(raw):
    return f"({fmt_num(raw)})"


def fmt_count(raw):
    """32,495 -> 32{,}495 so the comma keeps its spacing in math-free text."""
    return raw.strip().replace(",", "{,}")


def fmt_mean(raw):
    """Stata writes 4 decimals; the table shows 3 (decision 2026-08-02). Kept at
    full precision in the CSV so this is reversible without re-estimating."""
    val = float(raw.strip())
    return ("$-$" if val < 0 else "") + f"{abs(val):.3f}"


def get(data, outcome, row_type):
    try:
        return data[outcome][row_type]
    except KeyError:
        raise SystemExit(
            f"Missing '{row_type}' for outcome '{outcome}' in {CSV_IN.name}. "
            "Re-run the estimation do-file."
        )


def build(data, with_mean):
    outcomes = [o for o, _ in COLUMNS]
    header_cells = "".join(
        rf" & \begin{{tabular}}[c]{{@{{}}c@{{}}}}{label}\end{{tabular}}"
        for _, label in COLUMNS
    )
    col_nums = "".join(f" & ({i})" for i in range(1, len(COLUMNS) + 1))

    lines = [
        r"\begin{table}[H]",
        r"\centering",
        r"\caption{Spillover Effects: Current Recomputable Connectivity}",
        r"\footnotesize",
        r"\begin{tabular}{l" + "c" * len(COLUMNS) + "}",
        r"\toprule\toprule",
        header_cells + r"\\",
        col_nums + r"\\",
        r"\midrule",
        r"Post $\times$ Connectivity"
        + "".join(f" & {fmt_num(get(data, o, 'main'))}" for o in outcomes)
        + r"\\",
        "".join(f" & {fmt_se(get(data, o, 'main_se'))}" for o in outcomes) + r"\\",
        " & " * len(COLUMNS) + r"\\",
    ]

    if with_mean:
        lines.append(
            "Pre-treatment mean"
            + "".join(
                f" & {fmt_mean(get(data, o, 'mean_pre'))}" for o in outcomes
            )
            + r"\\"
        )

    lines += [
        "Observations"
        + "".join(f" & {fmt_count(get(data, o, 'n_obs'))}" for o in outcomes)
        + r"\\",
        "Establishments"
        + "".join(f" & {fmt_count(get(data, o, 'n_estab'))}" for o in outcomes)
        + r"\\",
        r"\midrule",
        "Pre-trend (placebo)"
        + "".join(f" & {fmt_num(get(data, o, 'pre'))}" for o in outcomes)
        + r"\\",
        "".join(f" & {fmt_se(get(data, o, 'pre_se'))}" for o in outcomes) + r"\\",
        r"\bottomrule\bottomrule",
        r"\end{tabular}",
        "",
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
                    help="emit the Pre-treatment mean row (needs mean_pre in the CSV)")
    args = ap.parse_args()

    data = load_csv(CSV_IN)
    body = build(data, args.with_mean)

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    OUT_TEX.write_text(body)
    print(f"wrote {OUT_TEX}")


if __name__ == "__main__":
    main()
