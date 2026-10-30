#!/usr/bin/env python3
"""
4011_table_direct_modeunion.py
====================================
Union-clustered version of 4010_table_direct.py: direct effects on the four
main outcomes with standard errors clustered by the establishment's modal
union (mode_union) instead of by establishment.

PANEL MAPPING (same as 4010):
    document Panel A  ->  CSV direct_A  (untreated with zero connectivity)
    document Panel B  ->  CSV direct_C  (ALL untreated)
The CSV's direct_B (connectivity <= 0.01) is not shown in this table.

Differences from 4010:
  - adds a "Unions (clusters)" row from the CSV's n_clust rows;
  - always emits the Pre-treatment mean row (4010's --with-mean);
  - drops the Panel A vs. Panel B equality p-value row. That test comes from
    conn_margins/3021_direct_sample_coef_test.do, which clusters by
    establishment, so it does not belong in a union-clustered table.

Input (written by 3014_main_modeunion.do via 3013_main_modeunion.do):
    Tables/main_modeunion/results_direct_panel{A,C}_tfpw_07_11_modeunion.csv

Output:
    Tables/main_modeunion/t_direct_modeunion.tex

Usage
-----
    python 4011_table_direct_modeunion.py [TABLES_DIR]
"""

import sys
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[3]
DEFAULT_DIR = PROJECT / "Tables" / "main_modeunion"
SPEC = "tfpw_07_11_modeunion"

COLUMNS = [
    ("lr_remdezr_w", r"Log \\ Wages"),
    ("lr_remdezr_h_w", r"Log Hourly \\ Wages"),
    ("l_firm_emp", r"Log \\ Employment"),
    ("numb_clauses", r"Clause \\ Count"),
]

PANELS = [
    ("A", f"results_direct_panelA_{SPEC}.csv",
     r"\textit{Panel A: Zero-Connectivity Untreated Firms}"),
    ("C", f"results_direct_panelC_{SPEC}.csv",
     r"\textit{Panel B: All Untreated Firms}"),
]

NOTES = (
    r"     \textit{Notes:} This table presents difference-in-differences "
    r"estimates of the ultractivity reform's direct effects (equation "
    r"(\ref{eq:dir_spec})), with standard errors clustered by union. The "
    r"specification, samples, and point estimates are those of "
    r"Table~\ref{tab:direct_connectivity_robust}; only the level of clustering differs. Each "
    r"establishment is assigned to its modal union over the sample period, "
    r"which is constant within establishment, so establishments are nested "
    r"within clusters. An establishment is directly treated if it had a "
    r"firm-level CBA filed before September 25, 2012 with a contractual end "
    r"date after that date. Panel~A restricts the comparison group to "
    r"untreated establishments with zero pre-reform connectivity to treated "
    r"establishments; Panel~B includes all untreated establishments. Wages and "
    r"employment are measured in December of each year. Clause counts are "
    r"observed only when a CBA is filed, reducing the number of observations "
    r"in column~(4). Post $\times$ Treatment reports the average effect for "
    r"2012--2016, with 2011 as the reference year. Pre-trend (placebo) reports "
    r"the coefficient from a placebo regression estimated on pre-treatment "
    r"data only (2009--2010 relative to 2011). Pre-treatment mean is the mean "
    r"of the dependent variable over 2009--2011 in the estimation sample of "
    r"the corresponding column. All specifications include establishment "
    r"fixed effects and year or CBA-period fixed effects interacted with "
    r"two-digit industry, microregion, and negotiation-month indicators and "
    r"with quartile bins of pre-treatment firm size, per-worker flows, and the "
    r"outcome. Standard errors clustered at the union level in parentheses; "
    r"the number of unions (clusters) is reported for each column. *** "
    r"p$<$0.01, ** p$<$0.05, * p$<$0.10."
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


def get(data, outcome, row_type, panel):
    try:
        return data[outcome][row_type]
    except KeyError:
        raise SystemExit(
            f"Missing '{row_type}' for '{outcome}' in panel {panel}. "
            "Re-run 3013_main_modeunion.do."
        )


def build(panels):
    outcomes = [o for o, _ in COLUMNS]
    ncol = len(COLUMNS)

    def row(label, key, data, row_type, fmt):
        return (label
                + "".join(f" & {fmt(get(data, o, row_type, key))}" for o in outcomes)
                + r"\\")

    lines = [
        r"\begin{table}[H]",
        r"\centering",
        r"\caption{Direct Effects: Standard Errors Clustered by Union}",
        r"\label{tab:direct_modeunion}",
        r"\footnotesize",
        r"\begin{tabular}{l" + "c" * ncol + "}",
        r"\toprule\toprule",
        "".join(rf" & \begin{{tabular}}[c]{{@{{}}c@{{}}}}{lab}\end{{tabular}}"
                for _, lab in COLUMNS) + r"\\",
        "".join(f" & ({i})" for i in range(1, ncol + 1)) + r"\\",
        r"\midrule",
    ]

    for idx, (key, _csv, title) in enumerate(PANELS):
        data = panels[key]
        lines += [
            rf"\multicolumn{{{ncol + 1}}}{{l}}{{{title}}}\\",
            r"\midrule",
            row(r"Post $\times$ Treatment", key, data, "main", fmt_num),
            row("", key, data, "main_se", fmt_se),
            " & " * ncol + r"\\",
            row("Pre-treatment mean", key, data, "mean_pre", fmt_mean),
            row("Observations", key, data, "n_obs", fmt_count),
            row("Establishments", key, data, "n_estab", fmt_count),
            row("Unions (clusters)", key, data, "n_clust", fmt_count),
            " & " * ncol + r"\\",
            row("Pre-trend (placebo)", key, data, "pre", fmt_num),
            row("", key, data, "pre_se", fmt_se),
        ]
        if idx < len(PANELS) - 1:
            lines += [" & " * ncol + r"\\", r"\midrule"]

    lines += [
        r"\bottomrule\bottomrule",
        r"\end{tabular}",
        r"\begin{minipage}{\linewidth}",
        r"    \scriptsize\vspace{4pt}",
        NOTES,
        r"\end{minipage}",
        r"\end{table}",
    ]
    return "\n".join(lines) + "\n"


def main():
    tables_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_DIR
    panels = {key: load_csv(tables_dir / csv) for key, csv, _ in PANELS}
    out_tex = tables_dir / "t_direct_modeunion.tex"
    out_tex.write_text(build(panels))
    print(f"wrote {out_tex}")


if __name__ == "__main__":
    main()
