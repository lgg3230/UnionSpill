#!/usr/bin/env python3
"""
5050_table_union.py
===================================
Builder for the "Spillover Effects ...: Robustness to Union-Level Confounders"
exhibits in UnionSpill-paper/Replication/Replication_Wages vs Hourly.tex:

    t_union.tex     log monthly wages   (10 columns)
    t_union_hw.tex  log hourly wages    (10 columns)

Why a new script rather than an edit to 5180_table_union_controls_latex.py:
that script builds a SIX-column table from the legacy Tables/robustness/ path
for tab:spill_union_controls in the main draft, and 4072_union_controls.do
still calls it. Its numbers (0.0051, 0.0044) are the legacy-panel run and do not
match this document (0.0050, 0.0043). The two exhibits are different tables that
happen to share a topic, so they get different builders.

Note also that frag/t_union.tex in quality_reports/ is a stale FOUR-column
build, superseded by the ten-column table in the document. This script
regenerates it so the fragment and the document agree.

Input (semicolon-delimited rows under a comma-delimited header, written by
4072_union_controls.do run against the currentconn overlay):
    Tables/currentconn_full/robustness/results_spill_union_controls{,_hw}.csv

Output:
    Tables/robustness/t_union{,_hw}.tex

The "Spillover / direct effect" row is COMPUTED here (coefficient divided by the
direct effect for that wage measure), not stored in the CSV.

Usage
-----
    python 5050_table_union.py                # no mean row
    python 5050_table_union.py --with-mean    # adds it
"""

import argparse
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[2]
CSV_DIR = PROJECT / "Tables" / "currentconn_full" / "robustness"
OUT_DIR = PROJECT / "Tables" / "robustness"

COLS = list(range(1, 11))

# Direct-effect denominators for the spillover/direct ratio, from the
# corresponding Direct Effects table (Panel A, Post x Treatment).
VARIANTS = {
    "": {
        "csv": "results_spill_union_controls.csv",
        "out": "t_union.tex",
        "outcome": "lr_remdezr_w",
        "caption": "Spillover Effects on Log Wages: Robustness to Union-Level Confounders",
        "header": "Log December wage",
        "direct": 0.0262,
        "wage_word": "log wage",
    },
    "_hw": {
        "csv": "results_spill_union_controls_hw.csv",
        "out": "t_union_hw.tex",
        "outcome": "lr_remdezr_h_w",
        "caption": "Spillover Effects on Log Hourly Wages: Robustness to Union-Level Confounders",
        "header": "Log hourly wages",
        "direct": 0.0285,
        "wage_word": "log hourly wage",
    },
}

CONTROL_ROWS = [
    (r"Union $\times$ year FE", 2),
    (r"Union exposure (firms), linear", 3),
    (r"Union exposure (workers), linear", 4),
    (r"Union exposure (firms), quartiles", 5),
    (r"Union exposure (workers), quartiles", 6),
    (r"Union exposure (firms), deciles", 7),
    (r"Union exposure (workers), deciles", 8),
    (r"Union exposure (firms), vingtiles", 9),
    (r"Union exposure (workers), vingtiles", 10),
]

MEAN_NOTE = (
    r" Pre-treatment mean is the mean of the dependent variable over "
    r"2009--2011 in the estimation sample of the corresponding column."
)


def notes(cfg):
    return (
        r"    \textit{Notes:} This table assesses whether current-connectivity "
        rf"spillover {cfg['wage_word']} estimates survive controls for "
        r"union-level exposure to the reform, on the full sample of untreated "
        r"establishments. Connectivity is the current recomputable per-worker "
        r"volume of pre-reform (2007--2011) worker flows to treated firms, "
        r"normalized to the 90th percentile. The reported ratio divides each "
        r"column's spillover estimate by the main "
        + ("hourly " if cfg["direct"] == 0.0285 else "")
        + rf"direct-effect estimate ({cfg['direct']:.4f}). Column~(1) "
        r"reproduces the baseline specification; column~(2) adds union "
        r"$\times$ year fixed effects. Columns~(3)--(4) add linear controls "
        r"for the share of the union's covered establishments or workers that "
        r"are directly treated. Columns~(5)--(10) replace those linear terms "
        r"with indicators for the quartile, decile, or vingtile of the same "
        r"two union-exposure measures, defined on the 2009 balanced-panel "
        r"sample in the same manner as the quartile controls. All columns "
        r"include the baseline controls from equation (\ref{eq:spill_spec}). "
        r"Standard errors clustered at the establishment level in "
        r"parentheses. *** p$<$0.01, ** p$<$0.05, * p$<$0.10."
    )


def load_csv(path):
    """Parse into {col: {row_type: value}} for the single wage outcome."""
    if not path.exists():
        raise SystemExit(f"Missing input: {path}")
    data = {}
    with open(path) as fh:
        next(fh)
        for line in fh:
            parts = [p.strip().strip('"') for p in line.strip().split(";")]
            if len(parts) < 4:
                continue
            _outcome, col, row_type, value = parts[:4]
            data.setdefault(col, {})[row_type] = value.strip().strip('"').strip()
    return data


def fmt_num(raw):
    val = raw.strip()
    if val.startswith("-"):
        return "$-$" + val[1:]
    return val


def strip_stars(raw):
    return raw.strip().rstrip("*")


def fmt_se(raw):
    return f"({fmt_num(raw)})"


def fmt_count(raw):
    return raw.strip().replace(",", "{,}")


def fmt_mean(raw):
    """Stata writes 4 decimals; the table shows 3 (decision 2026-08-02). Kept at
    full precision in the CSV so this is reversible without re-estimating."""
    val = float(raw.strip())
    return ("$-$" if val < 0 else "") + f"{abs(val):.3f}"


def get(data, col, row_type, csv_name):
    try:
        return data[str(col)][row_type]
    except KeyError:
        raise SystemExit(
            f"Missing '{row_type}' for column {col} in {csv_name}. "
            "Re-run 4072_union_controls.do."
        )


def build(data, cfg, csv_name, with_mean):
    def cell(row_type, formatter=fmt_num):
        return "".join(
            f" & {formatter(get(data, c, row_type, csv_name))}" for c in COLS
        )

    ratios = []
    for c in COLS:
        coef = float(strip_stars(get(data, c, "main", csv_name)))
        ratios.append(f"{coef / cfg['direct']:.2f}")

    lines = [
        r"\begin{table}[H]",
        r"\centering",
        rf"\caption{{{cfg['caption']}}}",
        r"\scriptsize",
        r"\resizebox{\textwidth}{!}{%",
        r"\begin{tabular}{l" + "c" * len(COLS) + "}",
        r"\toprule\toprule",
        rf" & \multicolumn{{{len(COLS)}}}{{c}}{{{cfg['header']}}}\\",
        r"\cmidrule(lr){2-" + str(len(COLS) + 1) + "}",
        "".join(f" & ({c})" for c in COLS) + r"\\",
        r"\midrule",
        r"Post $\times$ Connectivity" + cell("main") + r"\\",
        cell("main_se", fmt_se) + r"\\",
        " & " * len(COLS) + r"\\",
        "Spillover / direct effect"
        + "".join(f" & {r}" for r in ratios)
        + r"\\",
        " & " * len(COLS) + r"\\",
    ]

    if with_mean:
        lines.append("Pre-treatment mean" + cell("mean_pre", fmt_mean) + r"\\")

    lines += [
        "Observations" + cell("n_obs", fmt_count) + r"\\",
        "Establishments" + cell("n_estab", fmt_count) + r"\\",
        r"\midrule",
        "Pre-trend (placebo)" + cell("pre") + r"\\",
        cell("pre_se", fmt_se) + r"\\",
        r"\midrule",
        rf"\multicolumn{{{len(COLS) + 1}}}{{l}}{{\textit{{Union controls}}}} \\",
    ]

    for label, active in CONTROL_ROWS:
        marks = "".join(
            r" & \checkmark" if c == active else " & ---" for c in COLS
        )
        lines.append(f"{label}{marks} \\\\")

    lines += [
        r"\bottomrule\bottomrule",
        r"\end{tabular}",
        r"}",
        "",
        r"\begin{minipage}{\linewidth}",
        r"    \scriptsize\vspace{4pt}",
        notes(cfg) + (MEAN_NOTE if with_mean else ""),
        r"\end{minipage}",
        r"\footnotesize",
        r"\end{table}",
    ]
    return "\n".join(lines) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--with-mean", action="store_true",
                    help="emit the Pre-treatment mean row (needs mean_pre in the CSV)")
    args = ap.parse_args()

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for suffix, cfg in VARIANTS.items():
        csv_path = CSV_DIR / cfg["csv"]
        data = load_csv(csv_path)
        body = build(data, cfg, cfg["csv"], args.with_mean)
        out = OUT_DIR / cfg["out"]
        out.write_text(body)
        print(f"wrote {out}")


if __name__ == "__main__":
    main()
