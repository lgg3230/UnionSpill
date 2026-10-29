#!/usr/bin/env python3
"""
LaTeX tables for the doubly robust DiD exercise (3252_drdid.do).

Reads  Tables/drdid/results_drdid.csv
Writes Tables/drdid/t_drdid_direct.tex   direct effects, Panels A and B (table float)
       Tables/drdid/t_drdid_spill.tex    spillover effects, binary exposure and dose terciles
       Tables/drdid/drdid_tables.tex     standalone document \\input-ing both (preview)

Usage: python 4350_table_drdid_latex.py [tables_dir]
"""

import csv
import math
import sys
from pathlib import Path

OUTCOMES = ["lr_remdezr_w", "lr_remdezr_h_w", "l_firm_emp", "numb_clauses"]
HEADERS = [r"Log\\Wages", r"Log Hourly\\Wages", r"Log\\Employment", r"\# CBA\\Clauses"]
IPT_TOL = 1e-4   # drimp rows whose tilting fit leaves a larger imbalance did not converge


# ── LaTeX cell helpers (as in main_results/4160_table_pct_latex.py) ─────────

def hdr(text):
    return r"\begin{tabular}[c]{@{}c@{}}" + text + r"\end{tabular}"


def panel_cell(bold, italic):
    return r"\begin{tabular}[c]{@{}l@{}}" + bold + r"\\ " + italic + r"\end{tabular}"


def num(x, digits):
    s = f"{x:.{digits}f}"
    return r"$-$" + s[1:] if s.startswith("-") else s


def stars(p):
    if p is None or math.isnan(p):
        return ""
    return "***" if p < 0.01 else "**" if p < 0.05 else "*" if p < 0.10 else ""


def digits_for(outcome):
    return 3 if outcome == "numb_clauses" else 4


# ── Data ─────────────────────────────────────────────────────────────────────

def fnum(s):
    s = (s or "").strip()
    try:
        v = float(s)
    except ValueError:
        return float("nan")
    return v


def load(path):
    rows = {}
    with open(path, newline="") as f:
        for r in csv.DictReader(f, delimiter=";"):
            key = (r["design"], r["outcome"], r["estimand"], r["estimator"])
            rows[key] = dict(b=fnum(r["b"]), se=fnum(r["se"]), p=fnum(r["p"]),
                             nt=fnum(r["n_treat"]), nc=fnum(r["n_ctrl"]))
    return rows


class Res:
    def __init__(self, rows):
        self.rows = rows

    def get(self, ds, y, est, mth):
        return self.rows.get((ds, y, est, mth))

    def converged(self, ds, y, est, mth):
        """False for a drimp estimate whose tilting fit did not converge."""
        if not mth.startswith("dr_drimp"):
            return True
        sfx = mth[len("dr_drimp"):]
        imb = self.get(ds, y, est, "ipt_imbalance" + sfx)
        return imb is None or not (imb["b"] > IPT_TOL)

    def cells(self, ds, est, mth, scale=None):
        """Coefficient and SE cells for all outcomes. scale(y) divides b and se."""
        top, bot = [], []
        for y in OUTCOMES:
            r = self.get(ds, y, est, mth)
            if r is None or math.isnan(r["b"]):
                top.append("--")
                bot.append("")
                continue
            if not self.converged(ds, y, est, mth):
                top.append("n.c.")
                bot.append("")
                continue
            b, se, p = r["b"], r["se"], r["p"]
            if scale is not None:
                k = scale(y)
                b, se = b / k, se / k
            d = digits_for(y)
            top.append(num(b, d) + stars(p))
            bot.append("(" + num(se, d) + ")" if not math.isnan(se) else "")
        return top, bot

    def pval_cells(self, ds, mth):
        out = []
        for y in OUTCOMES:
            r = self.get(ds, y, "pretrend_p", mth)
            out.append("--" if r is None or math.isnan(r["b"]) else f"[{r['b']:.2f}]")
        return out

    def count_cells(self, ds, est, mth, field):
        out = []
        for y in OUTCOMES:
            r = self.get(ds, y, est, mth)
            v = None if r is None else r[field]
            out.append("--" if v is None or math.isnan(v) else f"{int(v):,}".replace(",", "{,}"))
        return out

    def dose(self, ds, y):
        r = self.get(ds, y, "mean_dose", ".")
        return r["b"] if r else float("nan")


# ── Table pieces ─────────────────────────────────────────────────────────────

def row(label, cells):
    return label + " & " + " & ".join(cells) + r" \\"


def blank():
    return " & " * len(OUTCOMES) + r"\\"


def coef_rows(res, label, ds, est, mth, scale=None):
    top, bot = res.cells(ds, est, mth, scale)
    return [row(label, top), row("", bot)]


def header(first_cell):
    cols = [hdr(h) for h in HEADERS]
    return [row(first_cell, cols),
            row("", [f"({i})" for i in range(1, len(OUTCOMES) + 1)]),
            r"\midrule"]


def preamble(caption, label):
    return [r"\begin{table}[!htbp]", r"\centering", rf"\caption{{{caption}}}",
            rf"\label{{{label}}}", r"\scriptsize", r"\begin{threeparttable}",
            r"\begin{tabular}{l" + "c" * len(OUTCOMES) + "}", r"\toprule\toprule"]


def postamble(notes):
    return [r"\bottomrule", r"\end{tabular}", r"\scriptsize", r"\begin{tablenotes}",
            r"\item \textit{Notes:} " + notes, r"\end{tablenotes}",
            r"\end{threeparttable}", r"\end{table}"]


def estimator_block(res, ds, eff):
    """Rows shared by the direct panels and the spillover binary panel."""
    L = []
    L += [r"\multicolumn{5}{l}{\textit{Two-way fixed effects}} \\"]
    if ds == "sAny":
        L += coef_rows(res, r"\quad Paper specification, per unit of connectivity", ds, "post", "twfe_paper_cont")
    else:
        L += coef_rows(res, r"\quad Paper specification", ds, "post", "twfe_paper")
    L += coef_rows(res, r"\quad Paper controls, exposure dummy, DRDID sample" if ds == "sAny"
                   else r"\quad Paper controls, DRDID sample", ds, "post", "twfe_paper_bin")
    L += coef_rows(res, r"\quad DRDID covariates", ds, "post", "twfe_coarse")
    L += [blank(), r"\multicolumn{5}{l}{\textit{Sant'Anna--Zhao estimators, DRDID covariates}} \\"]
    L += coef_rows(res, r"\quad Outcome regression", ds, "post", "dr_reg")
    L += coef_rows(res, r"\quad Inverse probability weighting", ds, "post", "dr_stdipw")
    L += coef_rows(res, r"\quad Doubly robust", ds, "post", "dr_dripw")
    L += coef_rows(res, r"\quad \textbf{Improved doubly robust}", ds, "post", "dr_drimp")
    L += coef_rows(res, r"\quad Improved DR, without own pre-period outcome", ds, "post", "dr_drimp_nolag")
    if ds == "sAny":
        L += coef_rows(res, r"\quad Improved DR, per unit of connectivity", ds, "post", "dr_drimp",
                       scale=lambda y: res.dose(ds, y))
    L += [blank(), r"\multicolumn{5}{l}{\textit{Placebo and pre-trends (improved DR)}} \\"]
    L += coef_rows(res, rf"\quad Pre $\times$ {eff}", ds, "placebo", "dr_drimp")
    L += [row(r"\quad Joint pre-trend $p$-value, improved DR", res.pval_cells(ds, "dr_drimp"))]
    L += [row(r"\quad Joint pre-trend $p$-value, TWFE paper controls", res.pval_cells(ds, "twfe_paper_bin"))]
    L += [blank()]
    L += [row("Treated establishments" if ds != "sAny" else "Exposed establishments",
              res.count_cells(ds, "post", "dr_drimp", "nt"))]
    L += [row("Control establishments", res.count_cells(ds, "post", "dr_drimp", "nc"))]
    return L


# ── Notes ────────────────────────────────────────────────────────────────────

_COMMON = (
    r"Each Sant'Anna--Zhao (2020) estimate is a two-period panel DiD on establishment-level "
    r"averages: the post-reform mean (2012--2016; CBA periods 3--6 for clauses) minus the "
    r"pre-reform mean (2009--2011; CBA periods 1--2), which is the comparison behind the "
    r"pooled Post coefficient of the main tables. Pre is the 2009--2010 mean minus 2011 "
    r"(CBA period 1 minus period 2). Estimates use \texttt{drdid} (Rios-Avila, Sant'Anna and "
    r"Naqvi, 2021) and match the R package \texttt{DRDID} to machine precision. "
    r"DRDID covariates, all pre-reform: quartiles of the outcome's own 2009--2011 mean, "
    r"of 2009--2011 employment and of 2007--2011 per-worker worker flows, CBA base month, "
    r"state, and industry group (\texttt{industry1}/100). Microregion and four-digit industry, "
    r"absorbed in the paper specification, are coarsened to state and industry group because "
    r"many treated establishments share a microregion--industry cell with no control, where a "
    r"propensity score is not defined. Establishments in covariate cells without both groups "
    r"are dropped, and controls with an estimated propensity score of 0.995 or more are trimmed. "
    r"The joint pre-trend test uses the influence functions of the 2009 and 2010 event-study "
    r"estimates (base 2011; for clauses, CBA period 1 against base period 2). "
    r"``Paper controls, DRDID sample'' re-estimates the paper's TWFE regression on the DRDID "
    r"estimation sample; ``DRDID covariates'' replaces its absorbed controls with the DRDID "
    r"covariates interacted with year. n.c.: the inverse-probability-tilting propensity score "
    r"did not converge. Standard errors, clustered by establishment (influence-function based "
    r"for DRDID), in parentheses. *** p$<$0.01, ** p$<$0.05, * p$<$0.10."
)


def notes_direct():
    return (
        r"This table compares the paper's two-way fixed effects (TWFE) estimates of the direct "
        r"effect of the 2012 ultractivity reform with the doubly robust DiD estimators of "
        r"Sant'Anna and Zhao (2020), which identify the average effect on treated establishments "
        r"under parallel trends conditional on pre-reform covariates. Panel~A uses control "
        r"establishments with zero pre-reform connectivity to treated firms; Panel~B all untreated "
        r"establishments. " + _COMMON
    )


def notes_spill():
    return (
        r"This table compares the paper's spillover estimates with doubly robust DiD estimates. "
        r"Because the Sant'Anna--Zhao estimators require a binary treatment, an untreated "
        r"establishment is exposed if its pre-reform connectivity to treated firms is positive, "
        r"and the comparison group is untreated establishments with zero connectivity. "
        r"Panel~A pools all exposed establishments; Panel~B compares each tercile of positive "
        r"connectivity with the zero-connectivity group. The paper's specification regresses on "
        r"connectivity scaled to its 90th percentile; ``per unit of connectivity'' rows divide the "
        r"exposure effect, and its standard error, by the exposed group's mean scaled connectivity "
        r"(reported in Panel~B), which is comparable to the paper's slope if effects are linear in "
        r"connectivity. " + _COMMON
    )


# ── Tables ───────────────────────────────────────────────────────────────────

def table_direct(res):
    L = preamble("Direct Effects: Doubly Robust DiD and TWFE", "tab:drdid_direct")
    L += header(panel_cell(r"\textbf{Panel A:}", r"\textit{Zero-Connectivity Controls}"))
    L += estimator_block(res, "dA", "Treatment")
    L += [blank(), r"\midrule"]
    L += header(panel_cell(r"\textbf{Panel B:}", r"\textit{All Untreated Controls}"))
    L += estimator_block(res, "dC", "Treatment")
    L += postamble(notes_direct())
    return L


def table_spill(res):
    L = preamble("Spillover Effects: Doubly Robust DiD and TWFE", "tab:drdid_spill")
    L += header(panel_cell(r"\textbf{Panel A:}", r"\textit{Any Exposure vs.\ Zero Connectivity}"))
    L += estimator_block(res, "sAny", "Exposure")
    L += [blank(), r"\midrule"]
    L += header(panel_cell(r"\textbf{Panel B:}", r"\textit{Connectivity Terciles vs.\ Zero}"))
    for k, name in [(1, "Bottom"), (2, "Middle"), (3, "Top")]:
        ds = f"sT{k}"
        L += [rf"\multicolumn{{5}}{{l}}{{\textit{{{name} tercile of positive connectivity}}}} \\"]
        L += coef_rows(res, r"\quad Improved doubly robust", ds, "post", "dr_drimp")
        L += coef_rows(res, r"\quad Improved DR, per unit of connectivity", ds, "post", "dr_drimp",
                       scale=lambda y, ds=ds: res.dose(ds, y))
        L += coef_rows(res, r"\quad TWFE, paper controls", ds, "post", "twfe_paper_bin")
        L += [row(r"\quad Mean scaled connectivity",
                  [num(res.dose(ds, y), 3) for y in OUTCOMES])]
        L += [row(r"\quad Exposed / control establishments",
                  [f"{a} / {b}" for a, b in zip(res.count_cells(ds, "post", "dr_drimp", "nt"),
                                                res.count_cells(ds, "post", "dr_drimp", "nc"))])]
        if k < 3:
            L += [blank()]
    L += postamble(notes_spill())
    return L


def main():
    tables_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else \
        Path(__file__).resolve().parents[3] / "Tables" / "drdid"
    res = Res(load(tables_dir / "results_drdid.csv"))

    (tables_dir / "t_drdid_direct.tex").write_text("\n".join(table_direct(res)) + "\n")
    (tables_dir / "t_drdid_spill.tex").write_text("\n".join(table_spill(res)) + "\n")
    (tables_dir / "drdid_tables.tex").write_text("\n".join([
        r"\documentclass[12pt,letterpaper]{article}",
        r"\usepackage[margin=0.8in]{geometry}",
        r"\usepackage{booktabs}",
        r"\usepackage{threeparttable}",
        r"\usepackage{amsmath}",
        r"\begin{document}",
        r"\input{t_drdid_direct.tex}",
        r"\clearpage",
        r"\input{t_drdid_spill.tex}",
        r"\end{document}",
    ]) + "\n")
    print(f"Generated {tables_dir / 't_drdid_direct.tex'}, {tables_dir / 't_drdid_spill.tex'}")


if __name__ == "__main__":
    main()
