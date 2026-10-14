#!/usr/bin/env python3
"""
4281_figure_pure_control_cutoff_fine.py
=======================================
Decile and vingtile versions of 4290: LaTeX wrapper that joins the four
per-outcome cutoff figures (drawn in Stata by
3165_figures_pure_control_cutoff_fine.do) into one 2x2 figure per cutoff set,
in the paper's subfigure layout (caption on top, subcaptions naming the
outcome, \\scriptsize minipage notes below). The cutoff values quoted in the
notes are read from 3162's cutoff file, so they stay in sync with the
estimates.

Graphics paths follow the paper convention (Replication/Figures/<name>.pdf),
so the fragments can be pasted into Draft.tex once the PDFs are copied into
UnionSpill-paper/Replication/Figures/.

Input:
    Graphs/pure_control_cutoff_fine/pure_control_cutoff_<set>_<outcome>.pdf   (3165)
    Tables/pure_control_cutoff_fine/pure_control_cutoff_cutoffs.csv           (3162)

Output (<set> = deciles | vingtiles):
    Graphs/pure_control_cutoff_fine/f_pure_control_cutoff_<set>.tex
    Graphs/pure_control_cutoff_fine/f_pure_control_cutoff_<set>_preview.pdf  (--preview), plus .png

Usage
-----
    python 4281_figure_pure_control_cutoff_fine.py
    python 4281_figure_pure_control_cutoff_fine.py --preview
"""

import argparse

from _pcc_fine_common import (DECILES, FIG_PREFIX, GRAPH_DIR, OUTCOMES,
                              VINGTILES, compile_preview, fmt_count,
                              load_cutoffs, points)

# set name -> (quantile samples, how the notes describe them)
SETS = {
    "deciles": (DECILES, "P10--P90 are deciles"),
    "vingtiles": (VINGTILES, "P5--P95 are vingtiles (5th, 10th, \\ldots, 95th percentiles)"),
}
LABELS = {"lr_remdezr_h_w": "hw", "lr_remdezr_w": "mw", "l_firm_emp": "emp",
          "numb_clauses": "clauses"}


def notes(cuts, pts, set_name):
    _, what = SETS[set_name]
    vals = [f"{lab}~$=$~{float(cuts[s]['cutoff_raw']):.4f}"
            for s, lab, _ in pts if s not in ("zero", "fixed_001", "all")]
    vals = ", ".join(vals[:-1]) + f", and {vals[-1]}"
    any_row = next(iter(cuts.values()))
    p001 = 100 * float(cuts["fixed_001"]["share_positive_le"])
    tied = [lab for _, lab, members in pts if len(members) > 1]
    ties = ("" if not tied else
            " Cutoffs with the same raw value select the same comparison group "
            "and are shown once (" + ", ".join(tied) + ").")
    return (
        r"\textit{Notes:} This figure plots difference-in-differences estimates "
        r"of the reform's direct effects (Post $\times$ Treatment, the average "
        r"effect over 2012--2016) when the comparison group consists of all "
        r"untreated establishments whose connectivity to the directly treated is "
        r"at most $c$, in raw (unnormalized) units. Each point is a separate "
        r"regression; the directly treated establishments are the same "
        rf"throughout. Cutoffs labeled {what} of connectivity "
        rf"among the {fmt_count(any_row['n_positive_total'])} untreated "
        r"establishments with positive connectivity (of "
        rf"{fmt_count(any_row['n_untreated_total'])} untreated in the balanced "
        rf"panel): {vals}. The fixed cutoff $c = 0.01$ falls at the "
        rf"{p001:.0f}th percentile; All includes every untreated establishment."
        rf"{ties} The hollow marker and the dashed line mark the main specification "
        r"($c = 0$, Panel~A of Table~\ref{tab:direct_connectivity_robust}); "
        r"All reproduces its Panel~B. Specifications are otherwise identical to "
        r"Table~\ref{tab:direct_connectivity_robust}. Bars are $95\%$ confidence "
        r"intervals from standard errors clustered at the establishment level."
    )


def build_tex(cuts, pts, set_name):
    title = set_name.capitalize()
    lines = [
        r"\begin{figure}[!tbp]",
        r"\centering",
        rf"\caption{{Direct Effects by Comparison-Group Connectivity Cutoff: {title}}}",
        rf"\label{{fig:pure_control_cutoff_{set_name}}}",
    ]
    for i, (outcome, subcap) in enumerate(OUTCOMES):
        lines += [
            r"\begin{subfigure}[t]{0.49\textwidth}",
            r"\centering",
            rf"\caption{{{subcap}}}",
            rf"\label{{fig:pcc_{set_name}_{LABELS[outcome]}}}",
            rf"\includegraphics[width=\textwidth]{{{FIG_PREFIX}pure_control_cutoff_{set_name}_{outcome}.pdf}}",
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
        notes(cuts, pts, set_name),
        r"\end{minipage}",
        r"\end{figure}",
    ]
    return "\n".join(lines) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", action="store_true",
                    help="also compile a standalone PDF preview of each 2x2 figure")
    args = ap.parse_args()

    cuts = load_cutoffs()
    GRAPH_DIR.mkdir(parents=True, exist_ok=True)

    for set_name, (quantiles, _) in SETS.items():
        pts = points(cuts, quantiles)
        tex = GRAPH_DIR / f"f_pure_control_cutoff_{set_name}.tex"
        tex.write_text(build_tex(cuts, pts, set_name))
        print(f"Wrote {tex}")
        if args.preview:
            figs = [GRAPH_DIR / f"pure_control_cutoff_{set_name}_{o}.pdf" for o, _ in OUTCOMES]
            compile_preview(tex, GRAPH_DIR / f"f_pure_control_cutoff_{set_name}_preview.pdf",
                            figures=figs)


if __name__ == "__main__":
    main()
