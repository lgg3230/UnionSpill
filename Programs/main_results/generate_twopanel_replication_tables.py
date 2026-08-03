#!/usr/bin/env python3
"""
generate_twopanel_replication_tables.py
=======================================
Builder for the two structurally identical two-panel exhibits in
UnionSpill-paper/Replication/Replication_Wages vs Hourly.tex:

    t_turnover.tex     "Decomposing Employment Effects"
    t_composition.tex  "Effects on Workforce Composition"

Both are Panel A (direct, from the panelA CSV) over Panel B (spillover), with a
shared summary block. They had no generator: the committed
generate_turnover_latex.py and generate_composition_latex.py build a different
layout (two separate captioned tables) for the main draft, and are left alone.
Both fragments are inlined twice, once per half of the document.

Inputs (per table, semicolon-delimited under a comma-delimited header):
    Tables/currentconn_full/<pipeline>/results_direct_panelA_<stem>.csv
    Tables/currentconn_full/<pipeline>/results_spill_<stem>.csv

Outputs:
    Tables/turnover/t_turnover.tex
    Tables/composition/t_composition.tex

Usage
-----
    python generate_twopanel_replication_tables.py                 # both, no mean
    python generate_twopanel_replication_tables.py --with-mean     # both, with mean
    python generate_twopanel_replication_tables.py --only turnover
"""

import argparse
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[2]
CC = PROJECT / "Tables" / "currentconn_full"

MEAN_NOTE = (
    r" Pre-treatment mean is the mean of the dependent variable over "
    r"2009--2011 in the estimation sample of the corresponding column."
)

TURNOVER_NOTES = (
    r"\scriptsize\textit{Notes:} This table presents difference-in-differences "
    r"estimates of the ultractivity reform's effects on establishment-level "
    r"employment flow outcomes using the current recomputable connectivity "
    r"measure. Panel~A reports direct effects, comparing directly treated "
    r"establishments to untreated establishments with zero pre-reform "
    r"connectivity. Panel~B reports spillover effects on the full sample of "
    r"untreated establishments, using continuous connectivity to treated firms "
    r"as the exposure measure, normalized so that a value of 1 corresponds to "
    r"the 90th percentile. Post $\times$ Treatment and Post $\times$ "
    r"Connectivity measure average effects for 2012--2016. Pre-trend (placebo) "
    r"reports the coefficient from a placebo regression estimated on "
    r"pre-treatment data only. Standard errors clustered at the establishment "
    r"level in parentheses. *** p$<$0.01, ** p$<$0.05, * p$<$0.10."
)

COMPOSITION_NOTES = (
    r"\scriptsize\textit{Notes:} This table presents difference-in-differences "
    r"estimates of the ultractivity reform's effects on establishment-level "
    r"workforce composition using the current recomputable connectivity "
    r"measure. Panel~A reports direct effects, comparing directly treated "
    r"establishments to untreated establishments with zero pre-reform "
    r"connectivity. Panel~B reports spillover effects on the full sample of "
    r"untreated establishments, using continuous connectivity to treated firms "
    r"as the exposure measure, normalized so that a value of 1 corresponds to "
    r"the 90th percentile. Average age is the mean age of December-employed "
    r"workers. High school+ is the share of workers with at least a completed "
    r"high school degree. Standard errors clustered at the establishment level "
    r"in parentheses. *** p$<$0.01, ** p$<$0.05, * p$<$0.10."
)

TABLES = {
    "turnover": {
        "pipeline": "turnover",
        "stem": "turnover",
        "out": ("turnover", "t_turnover.tex"),
        "caption": "Decomposing Employment Effects",
        "columns": [
            ("l_total_hours", r"Log\\Hours"),
            ("retention_u", r"Retention\\Rate"),
            ("hiring_rate_u", r"Hiring\\Rate"),
            ("turnover_u", r"Separation\\Rate"),
            ("quit_rate_u", r"Quit\\Rate"),
            ("layoff_rate_u", r"Layoff\\Rate"),
            ("churn_rate_u", r"Churn\\Rate"),
        ],
        "notes": TURNOVER_NOTES,
    },
    "composition": {
        "pipeline": "composition",
        "stem": "composition",
        "out": ("composition", "t_composition.tex"),
        "caption": "Effects on Workforce Composition",
        "columns": [
            ("avg_age", r"Avg.\\Age"),
            ("male_prop", r"\% Male"),
            ("white_prop", r"\% White"),
            ("prop_hs_plus", r"\% High\\School+"),
        ],
        "notes": COMPOSITION_NOTES,
    },
}


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


def build(cfg, direct, spill, with_mean):
    outcomes = [o for o, _ in cfg["columns"]]
    ncol = len(outcomes)

    def cells(data, row_type, formatter, label):
        out = []
        for o in outcomes:
            try:
                raw = data[o][row_type]
            except KeyError:
                raise SystemExit(
                    f"Missing '{row_type}' for '{o}' in the {label} panel of "
                    f"{cfg['stem']}. Re-run that pipeline."
                )
            out.append(f" & {formatter(raw)}")
        return "".join(out)

    lines = [
        r"\begin{table}[H]",
        r"\centering",
        rf"\caption{{{cfg['caption']}}}",
        r"\footnotesize",
        r"\begin{tabular}{l" + "c" * ncol + "}",
        r"\toprule\toprule",
        "".join(rf" & \begin{{tabular}}[c]{{@{{}}c@{{}}}}{lab}\end{{tabular}}"
                for _, lab in cfg["columns"]) + r" \\",
        "".join(f" & ({i})" for i in range(1, ncol + 1)) + r" \\",
        r"\midrule",
    ]

    panels = [
        ("A", direct, r"\textbf{Panel A:} Direct Effects",
         r"Post $\times$ Treatment"),
        ("B", spill, r"\textbf{Panel B:} Spillover Effects",
         r"Post $\times$ Connectivity"),
    ]

    for idx, (label, data, title, coef_label) in enumerate(panels):
        lines += [
            rf"\multicolumn{{{ncol + 1}}}{{l}}{{{title}}} \\",
            coef_label + cells(data, "main", fmt_num, label) + r"\\",
            cells(data, "main_se", fmt_se, label) + r"\\",
            " & " * ncol + r"\\",
        ]
        if with_mean:
            lines.append("Pre-treatment mean"
                         + cells(data, "mean_pre", fmt_mean, label) + r"\\")
        lines += [
            "Observations" + cells(data, "n_obs", fmt_count, label) + r"\\",
            "Establishments" + cells(data, "n_estab", fmt_count, label) + r"\\",
            r"\midrule",
            "Pre-trend (placebo)" + cells(data, "pre", fmt_num, label) + r"\\",
            cells(data, "pre_se", fmt_se, label) + r"\\",
        ]
        if idx == 0:
            lines += [" & " * ncol + r"\\", r"\midrule"]

    lines += [
        r"\bottomrule\bottomrule",
        r"\end{tabular}",
        r"\begin{minipage}{\linewidth}\vspace{4pt}",
        cfg["notes"] + (MEAN_NOTE if with_mean else ""),
        r"\end{minipage}",
        r"\end{table}",
    ]
    return "\n".join(lines) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--with-mean", action="store_true")
    ap.add_argument("--only", choices=sorted(TABLES))
    args = ap.parse_args()

    keys = [args.only] if args.only else sorted(TABLES)
    for key in keys:
        cfg = TABLES[key]
        d = CC / cfg["pipeline"]
        direct = load_csv(d / f"results_direct_panelA_{cfg['stem']}.csv")
        spill = load_csv(d / f"results_spill_{cfg['stem']}.csv")

        out_dir = PROJECT / "Tables" / cfg["out"][0]
        out_dir.mkdir(parents=True, exist_ok=True)
        out = out_dir / cfg["out"][1]
        out.write_text(build(cfg, direct, spill, args.with_mean))
        print(f"wrote {out}")


if __name__ == "__main__":
    main()


