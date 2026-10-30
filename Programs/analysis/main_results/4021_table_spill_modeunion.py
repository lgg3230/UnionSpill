#!/usr/bin/env python3
"""
4021_table_spill_modeunion.py
===================================
Union-clustered version of 4020_table_spill.py: spillover effects on the four
main outcomes with standard errors clustered by the establishment's modal
union (mode_union) instead of by establishment.

Differences from 4020:
  - adds a "Unions (clusters)" row from the CSV's n_clust rows;
  - always emits the Pre-treatment mean row (4020's --with-mean).

Input (written by 3014_main_modeunion.do via 3013_main_modeunion.do):
    Tables/main_modeunion/results_spill_tfpw_07_11_modeunion.csv

Output:
    Tables/main_modeunion/t_spill_modeunion.tex

Usage
-----
    python 4021_table_spill_modeunion.py [TABLES_DIR]
"""

import sys
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[3]
DEFAULT_DIR = PROJECT / "Tables" / "main_modeunion"
CSV_NAME = "results_spill_tfpw_07_11_modeunion.csv"

COLUMNS = [
    ("lr_remdezr_w", r"Log \\ Wages"),
    ("lr_remdezr_h_w", r"Log Hourly \\ Wages"),
    ("l_firm_emp", r"Log \\ Employment"),
    ("numb_clauses", r"Clause \\ Count"),
]

NOTES = (
    r"    \textit{Notes:} This table presents difference-in-differences "
    r"estimates of the reform's spillover effects (equation "
    r"(\ref{eq:spill_spec})) on the full sample of untreated establishments, "
    r"with standard errors clustered by union. The specification, sample, and "
    r"point estimates are those of Table~\ref{tab:spill_main_4tf_out}; only the level of "
    r"clustering differs. Each establishment is assigned to its modal union "
    r"over the sample period, which is constant within establishment, so "
    r"establishments are nested within clusters. Connectivity is per-worker "
    r"pairwise flows to treated establishments over 2007--2011, normalized by "
    r"its 90th percentile among untreated establishments, so that a value of 1 "
    r"corresponds to the 90th percentile. Wages and employment are measured "
    r"in December of each year; clause counts are observed only when a CBA is "
    r"filed, reducing the number of observations in column~(4). Post $\times$ "
    r"Connectivity reports the average effect for 2012--2016, with 2011 as "
    r"the reference year. Pre-trend (placebo) reports the coefficient from a "
    r"placebo regression estimated on pre-treatment data only (2009--2010 "
    r"relative to 2011). Pre-treatment mean is the mean of the dependent "
    r"variable over 2009--2011 in the estimation sample of the corresponding "
    r"column. All specifications include establishment fixed effects and year "
    r"or CBA-period fixed effects interacted with two-digit industry, "
    r"microregion, and negotiation-month indicators and with quartile bins of "
    r"pre-treatment firm size, per-worker flows, and the outcome. Standard "
    r"errors clustered at the union level in parentheses; the number of unions "
    r"(clusters) is reported for each column. *** p$<$0.01, ** p$<$0.05, * "
    r"p$<$0.10."
)


def load_csv(path):
    """Parse Stata file-write output into {outcome: {row_type: value}}.

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
    """Stata writes 4 decimals; the table shows 3 (decision 2026-08-02)."""
    val = float(raw.strip())
    return ("$-$" if val < 0 else "") + f"{abs(val):.3f}"


def get(data, outcome, row_type):
    try:
        return data[outcome][row_type]
    except KeyError:
        raise SystemExit(
            f"Missing '{row_type}' for outcome '{outcome}' in {CSV_NAME}. "
            "Re-run 3013_main_modeunion.do."
        )


def build(data):
    outcomes = [o for o, _ in COLUMNS]
    ncol = len(COLUMNS)

    def row(label, row_type, fmt):
        return (label
                + "".join(f" & {fmt(get(data, o, row_type))}" for o in outcomes)
                + r"\\")

    lines = [
        r"\begin{table}[H]",
        r"\centering",
        r"\caption{Spillover Effects: Standard Errors Clustered by Union}",
        r"\label{tab:spill_modeunion}",
        r"\footnotesize",
        r"\begin{tabular}{l" + "c" * ncol + "}",
        r"\toprule\toprule",
        "".join(rf" & \begin{{tabular}}[c]{{@{{}}c@{{}}}}{lab}\end{{tabular}}"
                for _, lab in COLUMNS) + r"\\",
        "".join(f" & ({i})" for i in range(1, ncol + 1)) + r"\\",
        r"\midrule",
        row(r"Post $\times$ Connectivity", "main", fmt_num),
        row("", "main_se", fmt_se),
        " & " * ncol + r"\\",
        row("Pre-treatment mean", "mean_pre", fmt_mean),
        row("Observations", "n_obs", fmt_count),
        row("Establishments", "n_estab", fmt_count),
        row("Unions (clusters)", "n_clust", fmt_count),
        r"\midrule",
        row("Pre-trend (placebo)", "pre", fmt_num),
        row("", "pre_se", fmt_se),
        r"\bottomrule\bottomrule",
        r"\end{tabular}",
        "",
        r"\begin{minipage}{\linewidth}",
        r"\scriptsize\vspace{4pt}",
        NOTES,
        r"\end{minipage}",
        r"\end{table}",
    ]
    return "\n".join(lines) + "\n"


def main():
    tables_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_DIR
    data = load_csv(tables_dir / CSV_NAME)
    out_tex = tables_dir / "t_spill_modeunion.tex"
    out_tex.write_text(build(data))
    print(f"wrote {out_tex}")


if __name__ == "__main__":
    main()
