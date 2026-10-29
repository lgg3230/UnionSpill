#!/usr/bin/env python3
"""
Nonparametric average causal response table for the ATT section of the referee
analyses, in the layout of Appendix Table C9 of the national-health-insurance
paper (Docs/ATT/qjag024): the main TWFE estimate next to the cubic polynomial
and natural cubic spline ACRs with the main specification's controls (Panel B
of 3272_np_acr.do). The B-spline is left out.

Columns: (1) TWFE, main specification (tab:spill_main_4tf_out), (2) cubic
         polynomial ACR, (3) natural cubic spline ACR (one interior knot).
         Rows: log hourly wages, log wages.

Reads  Tables/drdid/np_acr.csv          (3272_np_acr.do)
       Tables/drdid/results_drdid.csv   (3252_drdid.do; sAny post twfe_paper_cont = main table)
Writes Tables/drdid/t_np_acr_c9.tex     table float, label tab:np_acr_c9

Usage: python 4381_table_np_acr_c9.py
"""

import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
TAB = ROOT / "Tables" / "drdid"
CSV_IN = TAB / "np_acr.csv"
CSV_TWFE = TAB / "results_drdid.csv"
OUT = TAB / "t_np_acr_c9.tex"

PANEL = "B"
SPECS = ["twfe", "poly", "nspline"]
OUTCOMES = [("lr_remdezr_h_w", "Log hourly wages"), ("lr_remdezr_w", "Log wages")]


def load():
    for f, prog in ((CSV_IN, "3272_np_acr.do"), (CSV_TWFE, "3252_drdid.do")):
        if not f.exists():
            raise SystemExit(f"Missing input: {f}. Run {prog} first.")
    with open(CSV_IN, newline="") as fh:
        rows = {(r["outcome"], r["spec"]): r for r in csv.DictReader(fh, delimiter=";")
                if r["panel"] == PANEL and r["spec"] != "twfe"}
    # Column 1: the main table's TWFE (panel, establishment-year), in place of 3272's two-period slope
    with open(CSV_TWFE, newline="") as fh:
        for r in csv.DictReader(fh, delimiter=";"):
            if (r["design"], r["estimand"], r["estimator"]) == ("sAny", "post", "twfe_paper_cont"):
                rows[(r["outcome"], "twfe")] = {"b": r["b"], "se": r["se"], "p": r["p"], "n": r["n_treat"]}
    missing = [(y, s) for y, _ in OUTCOMES for s in SPECS if (y, s) not in rows]
    if missing:
        raise SystemExit(f"Rows missing from {CSV_IN} / {CSV_TWFE}: {missing}")
    return rows


def num(x, digits=4):
    s = f"{float(x):.{digits}f}"
    return r"$-$" + s[1:] if s.startswith("-") else s


def stars(p):
    p = float(p)
    return "***" if p < 0.01 else "**" if p < 0.05 else "*" if p < 0.10 else ""


def count(x):
    return f"{int(float(x)):,}".replace(",", "{,}")


def row(label, cells):
    return label + "".join(f" & {c}" for c in cells) + r"\\"


def build(rows):
    lines = [
        r"\begin{table}[H]",
        r"\centering",
        r"\caption{Spillover Effects: Nonparametric Estimates of the Average Causal Response}",
        r"\label{tab:np_acr_c9}",
        r"\footnotesize",
        r"\begin{tabular}{lccc}",
        r"\toprule\toprule",
        r" & Baseline & \multicolumn{2}{c}{Nonparametric Estimator}\\",
        r"\cmidrule(lr){3-4}",
        r"Method: & TWFE & \begin{tabular}[c]{@{}c@{}}Cubic\\Polynomial\end{tabular}"
        r" & \begin{tabular}[c]{@{}c@{}}Natural Cubic\\Spline\end{tabular}\\",
        row("", [f"({i})" for i in range(1, len(SPECS) + 1)]),
        r"\midrule",
    ]
    for k, (y, label) in enumerate(OUTCOMES):
        R = [rows[(y, s)] for s in SPECS]
        lines.append(row(label, [num(r["b"]) + stars(r["p"]) for r in R]))
        lines.append(row("", [f"({num(r['se'])})" for r in R]))
        if k < len(OUTCOMES) - 1:
            lines.append(row("", [""] * len(SPECS)))
    y0 = OUTCOMES[0][0]
    lines += [
        r"\midrule",
        row("Establishments", [count(rows[(y0, s)]["n"]) for s in SPECS]),
        row("Exposed establishments", ["--"] + [count(rows[(y0, s)]["n_exposed"]) for s in SPECS[1:]]),
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


NOTES = (
    r"\textit{Notes:} This table reports spillover effects of connectivity on untreated "
    r"establishments. Column~(1) reports the TWFE estimates of Table~\ref{tab:spill_main_4tf_out} "
    r"(equation~\ref{eq:spill_spec}). Columns~(2) and~(3) report the average causal response (ACR) "
    r"among establishments with positive connectivity (the exposed), estimated with the nonparametric "
    r"procedure of \citet{callaway2023}. Each establishment contributes the change in its outcome "
    r"between the 2012--2016 and 2009--2011 means, net of the mean change among zero-connectivity "
    r"establishments. This change is fit as a flexible function of connectivity among exposed "
    r"establishments, a cubic polynomial in column~(2) and a natural cubic spline in column~(3), and the "
    r"table reports the fitted derivative averaged over exposed establishments. The spline has one "
    r"interior knot, the number selected by cross-validation in Stata's \texttt{npregress series}, "
    r"placed at the median of positive connectivity. Columns~(2) and~(3) use all untreated "
    r"establishments, include an indicator for positive connectivity, and absorb the controls of the "
    r"main specification as fixed effects in the outcome change: quartiles of the establishment's own "
    r"2009--2011 outcome, of 2009--2011 employment, and of 2007--2011 per-worker flows, negotiation "
    r"month, microregion, and industry. Connectivity is normalized so that 1 is the 90th "
    r"percentile among untreated establishments in 2009. Standard errors in parentheses: clustered at "
    r"the establishment level in column~(1); robust in columns~(2) and~(3), where they condition on the "
    r"observed connectivity values. *** p$<$0.01, ** p$<$0.05, * p$<$0.10."
)


def main():
    OUT.write_text(build(load()))
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    main()
