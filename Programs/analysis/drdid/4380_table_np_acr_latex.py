#!/usr/bin/env python3
"""
LaTeX table for the nonparametric ACR exercise (3272_np_acr.do), laid out like
Appendix Table C9 of the QJE national-health-insurance paper.

Reads  Tables/drdid/np_acr.csv
Writes Tables/drdid/t_np_acr.tex      table float, \\input-able
       Tables/drdid/np_acr_table.tex  standalone preview document

Usage: python 4380_table_np_acr_latex.py [tables_dir]
"""

import csv
import math
import sys
from pathlib import Path

OUTCOMES = [("lr_remdezr_w", "Log wages"), ("lr_remdezr_h_w", "Log hourly wages"),
            ("l_firm_emp", "Log employment"), ("numb_clauses", r"\# CBA clauses")]
SPECS = ["twfe", "poly", "bspline", "nspline", "binary"]
ROWS = [("A",  "No covariates, the paper's code (\\texttt{npregress series})"),
        ("A2", "No covariates, explicit bases"),
        ("B",  "Main specification's controls, explicit bases")]


def hdr(text):
    return r"\begin{tabular}[c]{@{}c@{}}" + text + r"\end{tabular}"


def panel_cell(bold, italic):
    return r"\begin{tabular}[c]{@{}l@{}}" + bold + r"\\ " + italic + r"\end{tabular}"


def num(x, d):
    s = f"{x:.{d}f}"
    return r"$-$" + s[1:] if s.startswith("-") else s


def stars(p):
    return "" if p is None or math.isnan(p) else "***" if p < 0.01 else "**" if p < 0.05 else "*" if p < 0.10 else ""


def fl(s):
    try:
        return float(s)
    except (TypeError, ValueError):
        return float("nan")


def load(path):
    rows = {}
    with open(path, newline="") as f:
        for r in csv.DictReader(f, delimiter=";"):
            rows[(r["outcome"], r["panel"], r["spec"])] = {k: fl(r[k]) for k in ("b", "se", "p", "n", "n_exposed", "nknots")}
    return rows


def cells(rows, y, panel, specs, digits):
    top, bot = [], []
    for s in specs:
        r = rows.get((y, panel, s)) if s else None
        if r is None or math.isnan(r["b"]):
            top.append("")
            bot.append("")
            continue
        top.append(num(r["b"], digits) + stars(r["p"]))
        bot.append("(" + num(r["se"], digits) + ")")
    return top, bot


def row(label, c):
    return label + " & " + " & ".join(c) + r" \\"


def notes(rows):
    knots = []
    for y, label in OUTCOMES:
        r1, r2 = rows.get((y, "A", "bspline")), rows.get((y, "A", "nspline"))
        if r1 and r2:
            knots.append(f"{label}: B-spline {int(r1['nknots'])}, spline {int(r2['nknots'])}")
    r = rows.get(("lr_remdezr_h_w", "A", "twfe"))
    n = f"{int(r['n']):,}".replace(",", "{,}") if r else "--"
    ne = f"{int(r['n_exposed']):,}".replace(",", "{,}") if r else "--"
    return (
        r"Average causal response (ACR) of connectivity to treated firms in the spillover sample, "
        r"following Callaway, Goodman-Bacon and Sant'Anna (2025), who show that with a continuous "
        r"treatment the TWFE coefficient need not equal the ACR. Each establishment contributes its "
        r"change $\Delta Y$ between the post-reform mean (2012--2016; CBA periods 3--6 for clauses) and "
        r"the pre-reform mean (2009--2011; periods 1--2), net of the mean change among establishments "
        r"with zero connectivity. Connectivity is scaled to its 2009 90th percentile, as in the main "
        r"spillover regressions. Columns 2--4 fit $E[\Delta Y \mid D=d]$ among establishments with "
        r"positive connectivity with a cubic polynomial, a cubic B-spline and a natural cubic spline, "
        r"and report the fitted derivative averaged over those establishments (ACRT$^{\mathrm{glob}}$). "
        r"Column~1 regresses $\Delta Y$ on connectivity, the two-period analog of the main TWFE "
        r"specification (with the main controls it reproduces the main spillover estimates); column~5 "
        r"regresses it on an indicator for positive connectivity (the binarized DiD, "
        r"ATT$^{\mathrm{glob}}$). In each panel, the first row runs the code of Appendix Table C9 of the "
        r"national-health-insurance paper (\texttt{npregress series}, knots chosen by its "
        r"cross-validation; " + "; ".join(knots) + r"). The second row uses explicit bases with the "
        r"same number of interior knots, placed at quantiles of positive connectivity. The third row "
        r"adds the main specification's controls (quartiles of the outcome's own 2009--2011 mean, of "
        r"2009--2011 employment and of 2007--2011 worker flows, CBA base month, microregion and "
        r"industry) as fixed effects in $\Delta Y$ and uses all untreated establishments, with an "
        r"indicator for positive connectivity, so zero-connectivity establishments inform the "
        r"controls. " + n + r" untreated establishments, " + ne + r" with positive connectivity (log "
        r"hourly wages). Robust standard errors in parentheses; for columns 2--4 they condition on the "
        r"observed connectivity values. *** p$<$0.01, ** p$<$0.05, * p$<$0.10."
    )


def table(rows):
    cols = [hdr(r"TWFE"), hdr(r"Cubic\\polynomial"), hdr(r"Cubic\\B-spline"),
            hdr(r"Natural\\spline"), hdr(r"Binarized\\DiD")]
    L = [r"\begin{table}[!htbp]", r"\centering",
         r"\caption{Spillover Effects: Nonparametric Average Causal Response of Connectivity}",
         r"\label{tab:np_acr}", r"\scriptsize", r"\begin{threeparttable}",
         r"\begin{tabular}{lccccc}", r"\toprule\toprule",
         r" & Baseline & \multicolumn{3}{c}{Nonparametric ACR} & ATT$^{\mathrm{glob}}$ \\",
         r"\cmidrule(lr){3-5}", row("", cols), row("", [f"({i})" for i in range(1, 6)])]
    for i, (y, label) in enumerate(OUTCOMES):
        d = 3 if y == "numb_clauses" else 4
        L += [r"\midrule", r"\multicolumn{6}{l}{" + panel_cell(rf"\textbf{{Panel {'ABCD'[i]}:}}",
                                                             rf"\textit{{{label}}}") + r"} \\"]
        for panel, rlabel in ROWS:
            top, bot = cells(rows, y, panel, SPECS, d)
            L += [row(r"\quad " + rlabel, top), row("", bot)]
    L += [r"\bottomrule", r"\end{tabular}", r"\scriptsize", r"\begin{tablenotes}",
          r"\item \textit{Notes:} " + notes(rows), r"\end{tablenotes}", r"\end{threeparttable}",
          r"\end{table}"]
    return L


def main():
    tables_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else \
        Path(__file__).resolve().parents[3] / "Tables" / "drdid"
    rows = load(tables_dir / "np_acr.csv")
    (tables_dir / "t_np_acr.tex").write_text("\n".join(table(rows)) + "\n")
    (tables_dir / "np_acr_table.tex").write_text("\n".join([
        r"\documentclass[12pt,letterpaper]{article}", r"\usepackage[margin=0.8in]{geometry}",
        r"\usepackage{booktabs}", r"\usepackage{threeparttable}", r"\usepackage{amsmath}",
        r"\begin{document}", r"\input{t_np_acr.tex}", r"\end{document}"]) + "\n")
    print(f"Generated {tables_dir / 't_np_acr.tex'}")


if __name__ == "__main__":
    main()
