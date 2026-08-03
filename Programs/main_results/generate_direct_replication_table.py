#!/usr/bin/env python3
"""
generate_direct_replication_table.py
====================================
Builder for the "Direct Effects: Current Recomputable Connectivity" exhibit
(t_direct.tex) in UnionSpill-paper/Replication/Replication_Wages vs Hourly.tex.

Like t_spill, this fragment had no generator -- it was assembled by hand -- and
is inlined TWICE, once per half of the document, because it already carries both
wage columns. One build covers both.

PANEL MAPPING (verified 2026-08-01, easy to get wrong):
    document Panel A  ->  CSV direct_A  (untreated with zero connectivity)
    document Panel B  ->  CSV direct_C  (ALL untreated)
The CSV's direct_B (connectivity <= 0.01) is not shown in this table.

Inputs:
    Tables/pct_tfpw_cc/results_direct_panel{A,C}_tfpw_07_11_pct.csv
        written by Main_Results_pct_tfpw_07_11.do via _run_pct_tfpw_07_11_cc.do
    Tables/conn_margins/direct_sample_coef_test_currentconn.csv
        written by conn_margins/_run_direct_sample_coef_test_cc.do -- the
        stacked A-vs-C equality test behind the $p$-value row. Before
        2026-08-01 no committed script produced this on the currentconn panel.

Output:
    Tables/main_results/t_direct.tex

Usage
-----
    python generate_direct_replication_table.py                # no mean row
    python generate_direct_replication_table.py --with-mean    # adds it
"""

import argparse
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[2]
CSV_DIR = PROJECT / "Tables" / "pct_tfpw_cc"
EQ_CSV = (PROJECT / "Tables" / "conn_margins"
          / "direct_sample_coef_test_currentconn.csv")
OUT_DIR = PROJECT / "Tables" / "main_results"
OUT_TEX = OUT_DIR / "t_direct.tex"

COLUMNS = [
    ("lr_remdezr_w", r"Log \\ Wages"),
    ("lr_remdezr_h_w", r"Log Hourly \\ Wages"),
    ("l_firm_emp", r"Log \\ Employment"),
    ("numb_clauses", r"Clause \\ Count"),
]

PANELS = [
    ("A", "results_direct_panelA_tfpw_07_11_pct.csv",
     r"\textit{Panel A: Zero-Connectivity Untreated Firms}"),
    ("C", "results_direct_panelC_tfpw_07_11_pct.csv",
     r"\textit{Panel B: All Untreated Firms}"),
]

NOTES = (
    r"     \textit{Notes:} This table presents difference-in-differences "
    r"estimates of the ultractivity reform's direct effects (equation "
    r"(\ref{eq:dir_spec})) using the current recomputable connectivity measure "
    r"from \texttt{Data/RAIS\_aux/connectivity\_treat\_2007\_2011\_agg.dta}. An "
    r"establishment is directly treated if it had a firm-level CBA filed before "
    r"September 25, 2012 with a contractual end date after that date. Panel~A "
    r"restricts the comparison group to untreated establishments with "
    r"\texttt{totaltreat\_pw\_n\_current == 0}; Panel~B includes all untreated "
    r"establishments. The final row reports the $p$-value of the test that the "
    r"Post $\times$ Treatment effect is equal across the two panels. The test "
    r"is estimated from a single stacked regression of the two samples in which "
    r"each copy receives its own complete set of fixed effects and the "
    r"difference-in-differences term is fully interacted with a copy indicator, "
    r"so that the interaction coefficient equals the difference between the two "
    r"panels. Standard errors are clustered at the establishment level, so that "
    r"an establishment entering both copies forms a single cluster, which "
    r"recovers the covariance between the two estimators and yields a valid "
    r"test despite the overlapping samples. Wages and employment are measured "
    r"in December of each year. Clause counts are observed only when a CBA is "
    r"filed, reducing the number of observations in column~(4). Post $\times$ "
    r"Treatment reports the average effect for 2012--2016, with 2011 as the "
    r"reference year. Pre-trend (placebo) reports the coefficient from a "
    r"placebo regression estimated on pre-treatment data only (2009--2010 "
    r"relative to 2011). All specifications include establishment fixed effects "
    r"and year or CBA-period fixed effects interacted with two-digit industry, "
    r"microregion, and negotiation-month indicators and with quartile bins of "
    r"pre-treatment firm size, per-worker flows, and the outcome. Standard "
    r"errors clustered at the establishment level in parentheses. *** "
    r"p$<$0.01, ** p$<$0.05, * p$<$0.10."
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
    return data


def load_equality(path):
    """A_vs_C p-values from the stacked test, keyed by outcome."""
    if not path.exists():
        raise SystemExit(
            f"Missing input: {path}\n"
            "Run Programs/conn_margins/_run_direct_sample_coef_test_cc.do first."
        )
    out = {}
    with open(path) as fh:
        header = next(fh).strip().split(",")
        i_out, i_cmp, i_p = (header.index("outcome"),
                             header.index("comparison"),
                             header.index("p_diff"))
        for line in fh:
            parts = line.strip().split(",")
            if len(parts) <= i_p or parts[i_cmp] != "A_vs_C":
                continue
            out[parts[i_out]] = float(parts[i_p])
    return out


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
            "Re-run Main_Results_pct_tfpw_07_11.do."
        )


def build(panels, equality, with_mean):
    outcomes = [o for o, _ in COLUMNS]
    ncol = len(COLUMNS)

    lines = [
        r"\begin{table}[H]",
        r"\centering",
        r"\caption{Direct Effects: Current Recomputable Connectivity}",
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
            r"Post $\times$ Treatment"
            + "".join(f" & {fmt_num(get(data, o, 'main', key))}" for o in outcomes)
            + r"\\",
            "".join(f" & {fmt_se(get(data, o, 'main_se', key))}" for o in outcomes)
            + r"\\",
            " & " * ncol + r"\\",
        ]
        if with_mean:
            lines.append(
                "Pre-treatment mean"
                + "".join(f" & {fmt_mean(get(data, o, 'mean_pre', key))}"
                          for o in outcomes)
                + r"\\")
        lines += [
            "Observations"
            + "".join(f" & {fmt_count(get(data, o, 'n_obs', key))}" for o in outcomes)
            + r"\\",
            "Establishments"
            + "".join(f" & {fmt_count(get(data, o, 'n_estab', key))}" for o in outcomes)
            + r"\\",
            " & " * ncol + r"\\",
            "Pre-trend (placebo)"
            + "".join(f" & {fmt_num(get(data, o, 'pre', key))}" for o in outcomes)
            + r"\\",
            "".join(f" & {fmt_se(get(data, o, 'pre_se', key))}" for o in outcomes)
            + r"\\",
            " & " * ncol + r"\\",
            r"\midrule",
        ]

    missing = [o for o in outcomes if o not in equality]
    if missing:
        raise SystemExit(
            "Equality test CSV is missing outcomes: " + ", ".join(missing)
            + "\nRe-run _run_direct_sample_coef_test_cc.do (it covers all four)."
        )

    lines += [
        rf"\multicolumn{{{ncol + 1}}}{{l}}"
        r"{\textit{Equality of effects, Panel A vs.\ Panel B}}\\",
        "$p$-value"
        + "".join(f" & [{equality[o]:.3f}]" for o in outcomes)
        + r"\\",
        r"\bottomrule\bottomrule",
        r"\end{tabular}",
        r"\begin{minipage}{\linewidth}",
        r"    \scriptsize\vspace{4pt}",
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

    panels = {key: load_csv(CSV_DIR / csv) for key, csv, _ in PANELS}
    equality = load_equality(EQ_CSV)

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    OUT_TEX.write_text(build(panels, equality, args.with_mean))
    print(f"wrote {OUT_TEX}")


if __name__ == "__main__":
    main()
