#!/usr/bin/env python3
"""
Compact DRDID table for the ATT section of the referee analyses
(UnionSpill_paper/AER_referee_analyses.tex, "Estimating the Direct and
Spillover ATT's"): TWFE vs the improved doubly robust estimator of Sant'Anna
and Zhao (2020), with and without the own pre-treatment wage bins, for the
direct effect (Panel A) and the binary spillover exposure (Panel B).

Reads  Tables/drdid/results_drdid.csv   (3251 -> 3252_drdid.do)
Writes Tables/drdid/t_drdid_att.tex     table float, paper style ([H], minipage notes)

Usage: python 4355_table_drdid_att.py
"""

import csv
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
CSV_IN = ROOT / "Tables" / "drdid" / "results_drdid.csv"
OUT = ROOT / "Tables" / "drdid" / "t_drdid_att.tex"

OUTCOMES = [("lr_remdezr_h_w", r"Log Hourly\\Wages"), ("lr_remdezr_w", r"Log\\Wages")]

# (label, estimator); estimator None = blank spacer row
PANELS = [
    ("dA", r"\textbf{Panel A:} Direct Effects, Treated vs.\ Zero-Connectivity Untreated", [
        (r"TWFE, main controls", "twfe_paper_bin"),
        (r"TWFE, DR covariates", "twfe_coarse"),
        (r"Improved doubly robust", "dr_drimp"),
        (None, None),
        (r"\textit{Without own pre-treatment wage bins}", "header"),
        (r"\quad TWFE, DR covariates", "twfe_coarse_nolag"),
        (r"\quad Improved doubly robust", "dr_drimp_nolag"),
    ]),
    ("sAny", r"\textbf{Panel B:} Spillover Effects, Exposed vs.\ Zero-Connectivity Untreated", [
        (r"TWFE, main controls", "twfe_paper_bin"),
        (r"TWFE, DR covariates", "twfe_coarse"),
        (r"Improved doubly robust", "dr_drimp"),
        (r"\quad per unit of connectivity", "per_unit"),
        (None, None),
        (r"\textit{Without own pre-treatment wage bins}", "header"),
        (r"\quad TWFE, DR covariates", "twfe_coarse_nolag"),
        (r"\quad Improved doubly robust", "dr_drimp_nolag"),
    ]),
]


def fnum(s):
    try:
        return float((s or "").strip())
    except ValueError:
        return float("nan")


def load():
    if not CSV_IN.exists():
        raise SystemExit(f"Missing input: {CSV_IN}. Run 3251_drdid.do first.")
    rows = {}
    with open(CSV_IN, newline="") as fh:
        for r in csv.DictReader(fh, delimiter=";"):
            key = (r["design"].strip(), r["outcome"].strip(), r["estimand"].strip(), r["estimator"].strip())
            rows[key] = {k: fnum(r[k]) for k in ("b", "se", "p", "n_treat", "n_ctrl")}
    return rows


def get(rows, design, outcome, estimand, estimator):
    try:
        return rows[(design, outcome, estimand, estimator)]
    except KeyError:
        raise SystemExit(f"No row {design}/{outcome}/{estimand}/{estimator} in {CSV_IN.name}.")


def num(x, digits=4):
    s = f"{x:.{digits}f}"
    return r"$-$" + s[1:] if s.startswith("-") else s


def stars(p):
    if math.isnan(p):
        return ""
    return "***" if p < 0.01 else "**" if p < 0.05 else "*" if p < 0.10 else ""


def count(x):
    return f"{int(x):,}".replace(",", "{,}")


def coef_rows(rows, design, estimator):
    """Coefficient and SE cells for every outcome; per_unit divides the DR exposure
    effect by the exposed group's mean scaled connectivity."""
    b_cells, se_cells = [], []
    for o, _ in OUTCOMES:
        if estimator == "per_unit":
            r = get(rows, design, o, "post", "dr_drimp")
            m = get(rows, design, o, "mean_dose", ".")["b"]
            b, se, p = r["b"] / m, r["se"] / m, r["p"]
        else:
            r = get(rows, design, o, "post", estimator)
            b, se, p = r["b"], r["se"], r["p"]
        b_cells.append(num(b) + stars(p))
        se_cells.append(f"({num(se)})")
    return b_cells, se_cells


def build(rows):
    ncol = len(OUTCOMES)
    blank = " & " * ncol + r"\\"
    hdr = "".join(rf" & \begin{{tabular}}[c]{{@{{}}c@{{}}}}{lab}\end{{tabular}}" for _, lab in OUTCOMES)
    lines = [
        r"\begin{table}[H]",
        r"\centering",
        r"\caption{Direct and Spillover Effects: Doubly Robust Difference-in-Differences}",
        r"\label{tab:drdid_att}",
        r"\footnotesize",
        r"\begin{tabular}{l" + "c" * ncol + "}",
        r"\toprule\toprule",
        hdr + r"\\",
        "".join(f" & ({i})" for i in range(1, ncol + 1)) + r"\\",
    ]
    for design, title, spec in PANELS:
        lines += [r"\midrule", rf"\multicolumn{{{ncol + 1}}}{{l}}{{{title}}}\\", r"\midrule"]
        for label, est in spec:
            if label is None:
                lines.append(blank)
            elif est == "header":
                lines.append(rf"\multicolumn{{{ncol + 1}}}{{l}}{{{label}}}\\")
            else:
                b, se = coef_rows(rows, design, est)
                lines.append(label + "".join(f" & {c}" for c in b) + r"\\")
                lines.append("".join(f" & {c}" for c in se) + r"\\")
        lines.append(blank)
        for label, est in [("Pre-trend $p$-value, TWFE main controls", "twfe_paper_bin"),
                           ("Pre-trend $p$-value, improved doubly robust", "dr_drimp")]:
            lines.append(label + "".join(
                f" & [{get(rows, design, o, 'pretrend_p', est)['b']:.2f}]" for o, _ in OUTCOMES) + r"\\")
        if design == "sAny":
            lines.append("Mean connectivity, exposed" + "".join(
                f" & {get(rows, design, o, 'mean_dose', '.')['b']:.2f}" for o, _ in OUTCOMES) + r"\\")
        lab = "Treated" if design == "dA" else "Exposed"
        lines.append(f"{lab} / comparison establishments" + "".join(
            f" & {count(get(rows, design, o, 'post', 'dr_drimp')['n_treat'])} / "
            f"{count(get(rows, design, o, 'post', 'dr_drimp')['n_ctrl'])}" for o, _ in OUTCOMES) + r"\\")
    lines += [r"\bottomrule\bottomrule", r"\end{tabular}", "", r"\begin{minipage}{\linewidth}",
              r"\scriptsize\vspace{4pt}", NOTES, r"\end{minipage}", r"\end{table}"]
    return "\n".join(lines) + "\n"


NOTES = (
    r"\textit{Notes:} This table compares two-way fixed effects (TWFE) estimates with the improved "
    r"doubly robust (DR) difference-in-differences estimator of \citet{SANTANNA2020101}, which "
    r"identifies the average effect on the treated under parallel trends conditional on pre-treatment "
    r"covariates. Every estimate is a two-period panel difference-in-differences on establishment-level "
    r"means: the 2012--2016 mean minus the 2009--2011 mean, the comparison behind the pooled Post "
    r"coefficient of the main tables. Panel~A compares directly treated establishments with untreated "
    r"establishments with zero connectivity. Panel~B compares untreated establishments with positive "
    r"connectivity (exposed) with the same zero-connectivity establishments; the per-unit row divides "
    r"the DR exposure effect and its standard error by the mean normalized connectivity of exposed "
    r"establishments (1 equals the 90th percentile among untreated establishments), which makes it "
    r"comparable to the main spillover estimate if effects are linear in connectivity. TWFE, main "
    r"controls, uses the fixed effects and controls of the main specification. The DR covariates, all "
    r"pre-treatment, are quartiles of the establishment's own 2009--2011 outcome, of 2009--2011 "
    r"employment, and of 2007--2011 per-worker flows, negotiation month, state, and two-digit industry; "
    r"TWFE, DR covariates, interacts them with year. Microregion and three-digit industry are coarsened "
    r"to state and two-digit industry because many treated establishments share a microregion--industry "
    r"cell with no zero-connectivity establishment, where the propensity score is not defined. "
    r"Establishments in covariate cells without both groups are dropped, and comparison establishments "
    r"with an estimated propensity score of 0.995 or more are trimmed. The rows without own pre-treatment "
    r"wage bins drop the quartiles of the own 2009--2011 outcome from the covariates. Pre-trend "
    r"$p$-values test that the 2009 and 2010 event-study coefficients (base 2011) are jointly zero; for "
    r"the DR estimator the test uses their influence functions. Establishment counts refer to the DR "
    r"sample; TWFE samples differ by a few establishments because singleton fixed effects are dropped. "
    r"Standard errors clustered at the establishment level (influence-function based for DR) in "
    r"parentheses. *** p$<$0.01, ** p$<$0.05, * p$<$0.10."
)


def main():
    OUT.write_text(build(load()))
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    main()
