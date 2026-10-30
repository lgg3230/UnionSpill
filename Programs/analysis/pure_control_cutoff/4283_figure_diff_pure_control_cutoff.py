#!/usr/bin/env python3
"""
4283_figure_diff_pure_control_cutoff.py
=======================================
LaTeX wrapper for the difference figure drawn in Stata by
3167_stacked_test_pure_control_cutoff.do: for each vingtile cutoff, the
direct-effect estimate minus the All Untreated estimate, with the 95% CI from
the stacked test, one panel per outcome, joined into a 2x2 subfigure in the
layout of the vingtile figure (4281). A paragraph after the figure explains
why the confidence intervals narrow toward All (the two samples converge, so
the estimates become almost perfectly correlated); its numbers are read from
the result files.

Graphics paths follow the paper convention (Replication/Figures/<name>.pdf).

Input:
    Graphs/pure_control_cutoff_fine/pure_control_cutoff_diff_<outcome>.pdf   (3167)
    Tables/pure_control_cutoff_fine/pure_control_cutoff_cutoffs.csv           (3162)
    Tables/pure_control_cutoff_fine/pure_control_cutoff.csv                   (3162, paragraph)
    Tables/pure_control_cutoff_fine/pure_control_cutoff_stacked.csv           (3167, paragraph)

Output:
    Graphs/pure_control_cutoff_fine/f_pure_control_cutoff_diff.tex
    Graphs/pure_control_cutoff_fine/f_pure_control_cutoff_diff_preview.pdf  (--preview), plus .png

Usage
-----
    python 4283_figure_diff_pure_control_cutoff.py [--preview]
"""

import argparse
import csv

from _pcc_fine_common import (FIG_PREFIX, GRAPH_DIR, OUTCOMES, TAB_DIR,
                              compile_preview, fmt_count, load_cutoffs,
                              load_results)

STACKED_IN = TAB_DIR / "pure_control_cutoff_stacked.csv"

OUT_TEX = GRAPH_DIR / "f_pure_control_cutoff_diff.tex"
OUT_PDF = GRAPH_DIR / "f_pure_control_cutoff_diff_preview.pdf"
LABELS = {"lr_remdezr_h_w": "hw", "lr_remdezr_w": "mw", "l_firm_emp": "emp",
          "numb_clauses": "clauses"}


def notes(cuts):
    any_row = next(iter(cuts.values()))
    return (
        r"\textit{Notes:} This figure plots, for each connectivity cutoff $c$, "
        r"the difference between the direct-effect estimate (Post $\times$ "
        r"Treatment) with the comparison group restricted to untreated "
        r"establishments whose connectivity to the directly treated is at most "
        r"$c$ and the estimate with all untreated establishments as the "
        r"comparison group (Panel~B of Table~\ref{tab:direct_connectivity_robust}). "
        r"The hollow marker at All is the reference and is zero by construction. "
        r"Cutoffs P5--P95 are vingtiles of connectivity among the "
        rf"{fmt_count(any_row['n_positive_total'])} untreated establishments with "
        r"positive connectivity, as in Figure~\ref{fig:pure_control_cutoff_vingtiles}. "
        r"Because the comparison groups are nested and share the directly "
        r"treated establishments, the two estimates are correlated. Each "
        r"difference and its standard error come from a single stacked "
        r"regression of the two samples in which each copy receives its own "
        r"complete set of fixed effects and the difference-in-differences term "
        r"is fully interacted with a copy indicator; standard errors are "
        r"clustered at the establishment level, so that an establishment in "
        r"both copies forms a single cluster. Bars are $95\%$ confidence "
        r"intervals for the difference."
    )


def paragraph(cuts):
    """Why the CIs narrow toward All, with log hourly wages as the example."""
    res = load_results()
    with open(STACKED_IN, newline="") as fh:
        se_diff = {r["sample"]: float(r["se"]) for r in csv.DictReader(fh)
                   if r["outcome"] == "lr_remdezr_h_w"}
    n_all = int(cuts["all"]["n_ctrl_firms"])
    dropped = {s: fmt_count(n_all - int(cuts[s]["n_ctrl_firms"])) for s in ("zero", "p95")}
    se = {s: res[(s, "lr_remdezr_h_w", "main_se")] for s in ("zero", "p95", "all")}
    return (
        r"\paragraph{Why the confidence intervals narrow.} Each difference in "
        r"Figure~\ref{fig:pure_control_cutoff_diff} compares two estimates that "
        r"share every directly treated establishment and every untreated "
        r"establishment with connectivity at most $c$; the two samples differ only "
        r"in the untreated establishments with connectivity above $c$. As $c$ rises, "
        rf"this group shrinks, from {dropped['zero']} establishments at $c = 0$ to "
        rf"{dropped['p95']} at P95, so the two estimates come from nearly the same "
        r"data and become almost perfectly correlated. Because "
        r"$\operatorname{Var}(\hat\beta_c - \hat\beta_{\text{All}}) = "
        r"\operatorname{Var}(\hat\beta_c) + \operatorname{Var}(\hat\beta_{\text{All}}) "
        r"- 2\operatorname{Cov}(\hat\beta_c, \hat\beta_{\text{All}})$, the "
        r"covariance offsets almost all of the two variances: for log hourly wages, "
        rf"the standard error of the difference falls from {se_diff['zero']:.4f} at "
        rf"$c = 0$ to {se_diff['p95']:.4f} at P95, while the standard error of each "
        rf"estimate barely changes ({se['zero']:.4f} at $c = 0$, {se['p95']:.4f} at "
        rf"P95, and {se['all']:.4f} for All; Figure~\ref{{fig:pure_control_cutoff_vingtiles}}). "
        r"At All the two samples coincide, so the difference is zero with no "
        r"sampling uncertainty. The narrowing is therefore a property of the "
        r"comparison, not of the data: near All, the test isolates the contribution "
        r"of a small group of highly connected establishments, so small differences "
        r"can be statistically significant. Significance at high cutoffs should be "
        r"read together with the size of the difference."
    )


def build_tex(cuts):
    lines = [
        r"\begin{figure}[H]",
        r"\centering",
        r"\caption{Direct Effects by Connectivity Cutoff: Difference from All Untreated}",
        r"\label{fig:pure_control_cutoff_diff}",
    ]
    for i, (outcome, subcap) in enumerate(OUTCOMES):
        lines += [
            r"\begin{subfigure}[t]{0.49\textwidth}",
            r"\centering",
            rf"\caption{{{subcap}}}",
            rf"\label{{fig:pcc_diff_{LABELS[outcome]}}}",
            rf"\includegraphics[width=\textwidth]{{{FIG_PREFIX}pure_control_cutoff_diff_{outcome}.pdf}}",
            r"\end{subfigure}",
        ]
        if i % 2 == 0:
            lines.append(r"\hfill")
        elif i < len(OUTCOMES) - 1:
            lines.append(r"\\[1em]")
    lines += [
        "",
        r"\begin{minipage}{\linewidth}",
        r"\scriptsize\vspace{4pt}",
        notes(cuts),
        r"\end{minipage}",
        r"\end{figure}",
        "",
        paragraph(cuts),
    ]
    return "\n".join(lines) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", action="store_true",
                    help="also compile a standalone PDF preview of the 2x2 figure")
    args = ap.parse_args()

    GRAPH_DIR.mkdir(parents=True, exist_ok=True)
    OUT_TEX.write_text(build_tex(load_cutoffs()))
    print(f"Wrote {OUT_TEX}")
    if args.preview:
        figs = [GRAPH_DIR / f"pure_control_cutoff_diff_{o}.pdf" for o, _ in OUTCOMES]
        compile_preview(OUT_TEX, OUT_PDF, figures=figs)


if __name__ == "__main__":
    main()
