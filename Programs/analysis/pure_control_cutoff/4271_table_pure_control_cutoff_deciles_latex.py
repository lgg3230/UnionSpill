#!/usr/bin/env python3
"""
4271_table_pure_control_cutoff_deciles_latex.py
===============================================
Decile version of 4270: the direct effect (Post x Treatment) re-estimated as
the pure-control group is widened from zero connectivity to untreated
establishments with connectivity <= c, for c at the deciles (P10 ... P90) of
positive connectivity. One column per outcome (same order as
tab:direct_connectivity_robust), one row per cutoff, ordered by c, with the
fixed c = 0.01 and the unrestricted sample in place. Panel A: Post x
Treatment. Panel B: pre-trend placebo.

Also writes a flat summary for every fine-set sample (all vingtiles, not only
the deciles) with the change relative to the zero-connectivity baseline.

Input (written by 3162_pure_control_cutoff.do via 3164_pure_control_cutoff_fine.do):
    Tables/pure_control_cutoff_fine/pure_control_cutoff.csv
    Tables/pure_control_cutoff_fine/pure_control_cutoff_cutoffs.csv

Output:
    Tables/pure_control_cutoff_fine/t_pure_control_cutoff_deciles.tex          table fragment
    Tables/pure_control_cutoff_fine/pure_control_cutoff_fine_summary.csv       flat summary
    Tables/pure_control_cutoff_fine/t_pure_control_cutoff_deciles_preview.pdf  (--preview), plus .png

Usage
-----
    python 4271_table_pure_control_cutoff_deciles_latex.py
    python 4271_table_pure_control_cutoff_deciles_latex.py --preview
"""

import argparse
import csv
import math

from _pcc_fine_common import (DECILES, FIXED, OUTCOMES, TAB_DIR, VINGTILES,
                              compile_preview, fmt_count, load_cutoffs,
                              load_results, points, rep)

OUT_TEX = TAB_DIR / "t_pure_control_cutoff_deciles.tex"
OUT_SUMMARY = TAB_DIR / "pure_control_cutoff_fine_summary.csv"
OUT_PDF = TAB_DIR / "t_pure_control_cutoff_deciles_preview.pdf"

HEADERS = {
    "lr_remdezr_h_w": r"Log Hourly \\ Wages",
    "lr_remdezr_w": r"Log \\ Wages",
    "l_firm_emp": r"Log \\ Employment",
    "numb_clauses": r"Clause \\ Count",
}
BASELINE = "zero"


def get(data, s, outcome, row):
    try:
        val = data[(s, outcome, row)]
    except KeyError:
        raise SystemExit(f"Missing '{row}' for {outcome}, sample {s}.")
    if math.isnan(val):
        raise SystemExit(f"'{row}' is missing for {outcome}, sample {s}.")
    return val


def row_label(s, label, cuts):
    if s == "zero":
        return r"$c = 0$ (baseline)"
    if s == "all":
        return r"No cutoff (all untreated)"
    c = float(cuts[s]["cutoff_raw"])
    if s == "fixed_001":
        pct = 100 * float(cuts[s]["share_positive_le"])
        return rf"$c = {c:.2f}$ (P{pct:.0f})"
    return rf"$c = {c:.4f}$ ({label})"


def stars(p):
    return "***" if p < 0.01 else "**" if p < 0.05 else "*" if p < 0.10 else ""


def fmt_num(val, digits=4):
    return ("$-$" if val < 0 else "") + f"{abs(val):.{digits}f}"


NOTES = (
    r"    \textit{Notes:} This table reports difference-in-differences "
    r"estimates of the reform's direct effects when the comparison group "
    r"consists of all untreated establishments whose connectivity to the "
    r"directly treated is at most $c$, in raw (unnormalized) units; $c = 0$ "
    r"is the zero-connectivity comparison group of the main specification. "
    r"Each row is a separate set of regressions; the directly "
    r"treated establishments are the same in every row. Cutoffs P10--P90 are "
    r"deciles of connectivity among the @@NPOS@@ untreated establishments "
    r"with positive connectivity (of @@NPOOL@@ untreated in the balanced "
    r"panel), so each row adds the next-least-connected establishments to the "
    r"comparison group; $c = 0.01$ is the fixed cutoff used in earlier "
    r"versions, which falls at the @@P001@@th percentile.@@TIES@@ Untreated "
    r"estab.\ is the number of untreated establishments meeting the cutoff "
    r"before singleton fixed effects are dropped. The first row reproduces "
    r"Panel A and the last row Panel B of Table "
    r"\ref{tab:direct_connectivity_robust}. Panel A reports Post $\times$ "
    r"Treatment, the average effect over 2012--2016; Panel B reports the "
    r"coefficient from a placebo regression estimated on pre-treatment data "
    r"only. Specifications are identical to Table "
    r"\ref{tab:direct_connectivity_robust}: establishment fixed effects "
    r"and year fixed effects interacted with three-digit industry, "
    r"microregion, and negotiation-month indicators and with quartile bins of "
    r"pre-treatment firm size, per-worker flows, and the outcome; clause-count "
    r"regressions substitute CBA-period fixed effects for year fixed effects. "
    r"Standard errors clustered at the establishment level in parentheses. "
    r"*** p$<$0.01, ** p$<$0.05, * p$<$0.10."
)


def build(data, cuts):
    pts = points(cuts, DECILES)
    outcomes = [o for o, _ in OUTCOMES]
    ncol = len(OUTCOMES) + 1  # + untreated-establishment column
    header_cells = (
        r" & \begin{tabular}[c]{@{}c@{}}Untreated \\ Estab.\end{tabular}"
        + "".join(
            rf" & \begin{{tabular}}[c]{{@{{}}c@{{}}}}{HEADERS[o]}\end{{tabular}}"
            for o in outcomes
        )
    )
    col_nums = " & " + "".join(f" & ({i})" for i in range(1, len(OUTCOMES) + 1))

    lines = [
        r"\begin{table}[H]",
        r"\centering",
        r"\caption{Direct Effects by Comparison-Group Connectivity Cutoff: Deciles}",
        r"\label{tab:pure_control_cutoff_deciles}",
        r"\scriptsize",
        # Twelve cutoffs x two panels: tighter rows keep table and notes on one page.
        r"\renewcommand{\arraystretch}{0.8}",
        r"\begin{tabular}{lc" + "c" * len(OUTCOMES) + "}",
        r"\toprule\toprule",
        header_cells + r"\\",
        col_nums + r"\\",
    ]

    for title, b_row, se_row, p_row in [
        (r"Panel A: Post $\times$ Treatment", "main", "main_se", "main_p"),
        (r"Panel B: Pre-trend (placebo)", "pre", "pre_se", "pre_p"),
    ]:
        lines += [r"\midrule",
                  rf"\multicolumn{{{ncol + 1}}}{{l}}{{\textit{{{title}}}}}\\",
                  r"\midrule"]
        for s, label, _ in pts:
            n_ctrl = fmt_count(cuts[s]["n_ctrl_firms"])
            lines.append(
                row_label(s, label, cuts) + f" & {n_ctrl}"
                + "".join(
                    f" & {fmt_num(get(data, s, o, b_row))}{stars(get(data, s, o, p_row))}"
                    for o in outcomes)
                + r"\\")
            lines.append(
                " & "
                + "".join(f" & ({fmt_num(get(data, s, o, se_row))})" for o in outcomes)
                + r"\\")

    any_cut = next(iter(cuts.values()))
    p001 = 100 * float(cuts["fixed_001"]["share_positive_le"])
    tied = [label for _, label, members in pts if len(members) > 1]
    ties = ("" if not tied else
            " Deciles with the same raw cutoff select the same comparison group "
            "and share a row (" + ", ".join(tied) + ").")
    notes = (NOTES
             .replace("@@NPOS@@", fmt_count(any_cut["n_positive_total"]))
             .replace("@@NPOOL@@", fmt_count(any_cut["n_untreated_total"]))
             .replace("@@P001@@", f"{p001:.0f}")
             .replace("@@TIES@@", ties))

    lines += [
        r"\bottomrule\bottomrule",
        r"\end{tabular}",
        "",
        r"\begin{minipage}{\linewidth}",
        r"\scriptsize\vspace{4pt}",
        notes,
        r"\end{minipage}",
        r"\end{table}",
    ]
    return "\n".join(lines) + "\n"


def write_summary(data, cuts):
    """One row per outcome x fine-set sample, with the change vs the zero baseline."""
    fields = ["outcome", "sample", "same_as", "is_decile", "cutoff_raw",
              "share_positive_le", "n_ctrl_firms", "coef", "se", "pval", "pre",
              "pre_se", "pre_pval", "mean_pre", "n_obs", "n_estab",
              "n_estab_ctrl", "n_estab_treat", "diff_vs_zero", "pct_change_vs_zero"]
    samples = sorted(FIXED + VINGTILES,
                     key=lambda s: math.inf if s == "all" else float(cuts[s]["cutoff_raw"]))
    with open(OUT_SUMMARY, "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=fields)
        w.writeheader()
        for o, _ in OUTCOMES:
            b0 = get(data, BASELINE, o, "main")
            for s in samples:
                r = rep(cuts, s)
                b = get(data, r, o, "main")
                w.writerow({
                    "outcome": o, "sample": s,
                    "same_as": "" if r == s else r,
                    "is_decile": int(s in DECILES),
                    "cutoff_raw": cuts[s]["cutoff_raw"].strip(),
                    "share_positive_le": cuts[s]["share_positive_le"].strip(),
                    "n_ctrl_firms": cuts[s]["n_ctrl_firms"].strip(),
                    "coef": b, "se": get(data, r, o, "main_se"),
                    "pval": get(data, r, o, "main_p"),
                    "pre": get(data, r, o, "pre"), "pre_se": get(data, r, o, "pre_se"),
                    "pre_pval": get(data, r, o, "pre_p"),
                    "mean_pre": get(data, r, o, "mean_pre"),
                    "n_obs": int(get(data, r, o, "n_obs")),
                    "n_estab": int(get(data, r, o, "n_estab")),
                    "n_estab_ctrl": int(get(data, r, o, "n_estab_ctrl")),
                    "n_estab_treat": int(get(data, r, o, "n_estab_treat")),
                    "diff_vs_zero": b - b0,
                    "pct_change_vs_zero": 100 * (b - b0) / b0,
                })
    print(f"Wrote {OUT_SUMMARY}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", action="store_true",
                    help="also compile a standalone PDF preview of the table")
    args = ap.parse_args()

    data = load_results()
    cuts = load_cutoffs()

    TAB_DIR.mkdir(parents=True, exist_ok=True)
    OUT_TEX.write_text(build(data, cuts))
    print(f"Wrote {OUT_TEX}")
    write_summary(data, cuts)

    if args.preview:
        compile_preview(OUT_TEX, OUT_PDF, crop=True)


if __name__ == "__main__":
    main()
