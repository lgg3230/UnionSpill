#!/usr/bin/env python3
"""
4272_table_pure_control_cutoff_size_latex.py
============================================
Pre-treatment firm size (mean employment 2009-2011) of the directly treated
establishments and of each comparison group of the decile cutoff exercise
(untreated establishments with connectivity <= c, for c = 0, P10 ... P90, and
all untreated): number of establishments, mean and median.

Two layouts:
    long  one row per group; columns Establishments, Mean, Median
    wide  one column per group; rows Establishments, Mean, Median

Input (written by 3166_firm_size_pure_control_cutoff.do):
    Tables/pure_control_cutoff_fine/pure_control_cutoff_size.csv
    Tables/pure_control_cutoff_fine/pure_control_cutoff_cutoffs.csv   (n positive, for the notes)

Output (<design> = long | wide):
    Tables/pure_control_cutoff_fine/t_pure_control_cutoff_size_<design>.tex
    Tables/pure_control_cutoff_fine/t_pure_control_cutoff_size_<design>_preview.pdf  (--preview), plus .png

Usage
-----
    python 4272_table_pure_control_cutoff_size_latex.py [--design wide|long|both] [--preview]
"""

import argparse
import csv

from _pcc_fine_common import (DECILES, TAB_DIR, compile_preview, fmt_count,
                              load_cutoffs, qlabel)

SIZE_IN = TAB_DIR / "pure_control_cutoff_size.csv"
GROUPS = ["zero"] + DECILES + ["all"]


def load_size():
    if not SIZE_IN.exists():
        raise SystemExit(f"Missing input: {SIZE_IN}. Run 3166_firm_size_pure_control_cutoff.do first.")
    with open(SIZE_IN, newline="") as fh:
        return {r["group"]: r for r in csv.DictReader(fh)}


def fmt1(v):
    return f"{float(v):,.1f}".replace(",", "{,}")


def short_label(g):
    return {"treated": "Treated", "zero": "$c = 0$", "all": "All"}.get(g) or qlabel(g)


def long_label(g, size):
    if g == "treated":
        return "Directly treated"
    if g == "zero":
        return r"$c = 0$ (baseline)"
    if g == "all":
        return r"No cutoff (all untreated)"
    return rf"$c = {float(size[g]['cutoff']):.4f}$ ({qlabel(g)})"


def notes(cuts):
    any_cut = next(iter(cuts.values()))
    return (
        r"    \textit{Notes:} This table reports the pre-treatment size (mean "
        r"employment over 2009--2011) of the directly treated establishments "
        r"and of each comparison group in Table~\ref{tab:pure_control_cutoff_deciles}. "
        r"The comparison group at cutoff $c$ consists of all untreated "
        r"establishments whose connectivity to the directly treated is at most "
        r"$c$, in raw (unnormalized) units, so the groups are nested; $c = 0$ is "
        r"the zero-connectivity comparison group of the main specification. "
        r"Cutoffs P10--P90 are deciles of connectivity among the "
        rf"{fmt_count(any_cut['n_positive_total'])} untreated establishments with "
        rf"positive connectivity (of {fmt_count(any_cut['n_untreated_total'])} "
        r"untreated in the balanced panel). Establishments are counted before "
        r"singleton fixed effects are dropped."
    )


def wrap(lines_tab, label_suffix, cuts):
    return "\n".join([
        r"\begin{table}[H]",
        r"\centering",
        r"\caption{Pre-Treatment Establishment Size by Comparison-Group Connectivity Cutoff}",
        rf"\label{{tab:pure_control_cutoff_size{label_suffix}}}",
        r"\scriptsize",
        *lines_tab,
        "",
        r"\begin{minipage}{\linewidth}",
        r"\scriptsize\vspace{4pt}",
        notes(cuts),
        r"\end{minipage}",
        r"\end{table}",
    ]) + "\n"


def build_long(size, cuts):
    lines = [
        r"\begin{tabular}{lccc}",
        r"\toprule\toprule",
        r" & Establishments & Mean & Median\\",
        r"\midrule",
        long_label("treated", size)
        + f" & {fmt_count(size['treated']['n_firms'])} & {fmt1(size['treated']['mean'])}"
        + f" & {fmt1(size['treated']['p50'])}\\\\",
        r"\midrule",
        r"\multicolumn{4}{l}{\textit{Comparison groups (untreated, connectivity $\leq c$)}}\\",
    ]
    for g in GROUPS:
        r = size[g]
        lines.append(f"{long_label(g, size)} & {fmt_count(r['n_firms'])} & {fmt1(r['mean'])}"
                     f" & {fmt1(r['p50'])}\\\\")
    lines += [r"\bottomrule\bottomrule", r"\end{tabular}"]
    return wrap(lines, "", cuts)


def build_wide(size, cuts):
    groups = ["treated"] + GROUPS
    ncomp = len(GROUPS)
    lines = [
        r"\setlength{\tabcolsep}{3.5pt}",
        r"\begin{tabular}{l" + "c" * len(groups) + "}",
        r"\toprule\toprule",
        rf" & & \multicolumn{{{ncomp}}}{{c}}{{Comparison groups (untreated, connectivity $\leq c$)}}\\",
        rf"\cmidrule(lr){{3-{ncomp + 2}}}",
        " & " + " & ".join(short_label(g) for g in groups) + r"\\",
        r"Cutoff $c$ & & & " + " & ".join(f"{float(size[g]['cutoff']):.4f}" for g in DECILES) + r" & \\",
        r"\midrule",
        "Establishments & " + " & ".join(fmt_count(size[g]["n_firms"]) for g in groups) + r"\\",
        "Mean & " + " & ".join(fmt1(size[g]["mean"]) for g in groups) + r"\\",
        "Median & " + " & ".join(fmt1(size[g]["p50"]) for g in groups) + r"\\",
        r"\bottomrule\bottomrule",
        r"\end{tabular}",
    ]
    return wrap(lines, "", cuts)


def main():
    ap = argparse.ArgumentParser()
    # wide is the compact layout (3 data rows); long kept for comparison.
    ap.add_argument("--design", choices=["long", "wide", "both"], default="wide")
    ap.add_argument("--preview", action="store_true",
                    help="also compile a standalone PDF preview of the table")
    args = ap.parse_args()

    size = load_size()
    cuts = load_cutoffs()
    designs = ["long", "wide"] if args.design == "both" else [args.design]
    builders = {"long": build_long, "wide": build_wide}
    for d in designs:
        out = TAB_DIR / f"t_pure_control_cutoff_size_{d}.tex"
        out.write_text(builders[d](size, cuts))
        print(f"Wrote {out}")
        if args.preview:
            compile_preview(out, TAB_DIR / f"t_pure_control_cutoff_size_{d}_preview.pdf", crop=True)


if __name__ == "__main__":
    main()
