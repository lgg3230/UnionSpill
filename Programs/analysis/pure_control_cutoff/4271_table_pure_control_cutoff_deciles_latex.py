#!/usr/bin/env python3
"""
4271_table_pure_control_cutoff_deciles_latex.py
===============================================
Decile version of 4270: the direct effect (Post x Treatment) re-estimated as
the pure-control group is widened from zero connectivity to untreated
establishments with connectivity <= c, for c at the deciles (P10 ... P90) of
positive connectivity. One column per outcome (same order as
tab:direct_connectivity_robust), one row per cutoff, ordered by c, then the
unrestricted sample. Two tables:
    Table A (tab:pure_control_cutoff_deciles): Post x Treatment, with the
        standard error and, on a line below it, the p-value of the stacked test
        of equality with the All Untreated estimate (3167), followed by a small
        gap; the All row, the reference, has no p-value.
    Table B (tab:pure_control_cutoff_deciles_placebo): pre-trend placebo.
(One table with both panels and the p-value lines does not fit on a page.)

Also writes a flat summary for every fine-set sample (all vingtiles, not only
the deciles) with the change relative to the zero-connectivity baseline.

Input (written by 3162_pure_control_cutoff.do via 3164_pure_control_cutoff_fine.do):
    Tables/pure_control_cutoff_fine/pure_control_cutoff.csv
    Tables/pure_control_cutoff_fine/pure_control_cutoff_cutoffs.csv
    Tables/pure_control_cutoff_fine/pure_control_cutoff_stacked.csv  (3167; without it,
        Table A has no p-values and a warning is printed)

Output:
    Tables/pure_control_cutoff_fine/t_pure_control_cutoff_deciles.tex                  Table A
    Tables/pure_control_cutoff_fine/t_pure_control_cutoff_deciles_placebo.tex          Table B
    Tables/pure_control_cutoff_fine/pure_control_cutoff_fine_summary.csv               flat summary
    Tables/pure_control_cutoff_fine/t_pure_control_cutoff_deciles[_placebo]_preview.pdf  (--preview), plus .png

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
OUT_TEX_PLACEBO = TAB_DIR / "t_pure_control_cutoff_deciles_placebo.tex"
OUT_SUMMARY = TAB_DIR / "pure_control_cutoff_fine_summary.csv"
STACKED_IN = TAB_DIR / "pure_control_cutoff_stacked.csv"

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
    return rf"$c = {c:.4f}$ ({label})"


def stars(p):
    return "***" if p < 0.01 else "**" if p < 0.05 else "*" if p < 0.10 else ""


def fmt_num(val, digits=4):
    return ("$-$" if val < 0 else "") + f"{abs(val):.{digits}f}"


SPEC_NOTE = (
    r"Specifications are identical to Table "
    r"\ref{tab:direct_connectivity_robust}: establishment fixed effects "
    r"and year fixed effects interacted with three-digit industry, "
    r"microregion, and negotiation-month indicators and with quartile bins of "
    r"pre-treatment firm size, per-worker flows, and the outcome; clause-count "
    r"regressions substitute CBA-period fixed effects for year fixed effects. "
    r"Standard errors clustered at the establishment level in parentheses. "
    r"*** p$<$0.01, ** p$<$0.05, * p$<$0.10."
)
NOTES_MAIN = (
    r"    \textit{Notes:} This table reports difference-in-differences "
    r"estimates of the reform's direct effects (Post $\times$ Treatment, the "
    r"average effect over 2012--2016) when the comparison group consists of "
    r"all untreated establishments whose connectivity to the directly treated "
    r"is at most $c$, in raw (unnormalized) units; $c = 0$ is the "
    r"zero-connectivity comparison group of the main specification. Each row "
    r"is a separate set of regressions; the directly treated establishments "
    r"are the same in every row. Cutoffs P10--P90 are deciles of connectivity "
    r"among the @@NPOS@@ untreated establishments with positive connectivity "
    r"(of @@NPOOL@@ untreated in the balanced panel), so each row adds the "
    r"next-least-connected establishments to the comparison group.@@TIES@@ "
    r"Untreated estab.\ is the number of untreated establishments meeting the "
    r"cutoff before singleton fixed effects are dropped. The first row "
    r"reproduces Panel A and the last row Panel B of Table "
    r"\ref{tab:direct_connectivity_robust}.@@STACKED@@ " + SPEC_NOTE
)
STACKED_NOTE = (
    r" Square brackets below the standard errors give the $p$-value of a "
    r"stacked test that the estimate equals the estimate with all untreated "
    r"establishments as the comparison group (last row); the test accounts for "
    r"the covariance between the two estimates, which share the directly "
    r"treated establishments."
)
NOTES_PLACEBO = (
    r"    \textit{Notes:} This table reports pre-trend placebo coefficients for "
    r"the comparison groups of Table~\ref{tab:pure_control_cutoff_deciles}: "
    r"each row is a placebo regression estimated on pre-treatment data only "
    r"(2009--2010 relative to 2011), with the same sample as the corresponding "
    r"row of Table~\ref{tab:pure_control_cutoff_deciles}. The first row "
    r"reproduces the Panel A placebo and the last row the Panel B placebo of "
    r"Table \ref{tab:direct_connectivity_robust}. " + SPEC_NOTE
)


def load_stacked():
    """{(sample, outcome): p} from 3167, or None if 3167 has not been run."""
    if not STACKED_IN.exists():
        print(f"WARNING: {STACKED_IN} not found; Table A has no stacked-test p-values. "
              "Run 3167_stacked_test_pure_control_cutoff.do.")
        return None
    with open(STACKED_IN, newline="") as fh:
        return {(r["sample"], r["outcome"]): float(r["p"]) for r in csv.DictReader(fh)}


def build(data, cuts, stacked=None, placebo=False):
    """Table A (Post x Treatment, with stacked p-values) or Table B (placebo)."""
    pts = points(cuts, DECILES)
    outcomes = [o for o, _ in OUTCOMES]
    b_row, se_row, p_row = ("pre", "pre_se", "pre_p") if placebo else ("main", "main_se", "main_p")
    header_cells = (
        r" & \begin{tabular}[c]{@{}c@{}}Untreated \\ Estab.\end{tabular}"
        + "".join(
            rf" & \begin{{tabular}}[c]{{@{{}}c@{{}}}}{HEADERS[o]}\end{{tabular}}"
            for o in outcomes
        )
    )
    col_nums = " & " + "".join(f" & ({i})" for i in range(1, len(OUTCOMES) + 1))
    if placebo:
        caption = "Pre-Trend Placebo by Comparison-Group Connectivity Cutoff: Deciles"
        label = "tab:pure_control_cutoff_deciles_placebo"
    else:
        caption = "Direct Effects by Comparison-Group Connectivity Cutoff: Deciles"
        label = "tab:pure_control_cutoff_deciles"

    lines = [
        r"\begin{table}[H]",
        r"\centering",
        rf"\caption{{{caption}}}",
        rf"\label{{{label}}}",
        r"\scriptsize",
        r"\begin{tabular}{lc" + "c" * len(OUTCOMES) + "}",
        r"\toprule\toprule",
        header_cells + r"\\",
        col_nums + r"\\",
        r"\midrule",
    ]
    for s, lab, _ in pts:
        n_ctrl = fmt_count(cuts[s]["n_ctrl_firms"])
        lines.append(
            row_label(s, lab, cuts) + f" & {n_ctrl}"
            + "".join(
                f" & {fmt_num(get(data, s, o, b_row))}{stars(get(data, s, o, p_row))}"
                for o in outcomes)
            + r"\\")
        lines.append(
            " & "
            + "".join(f" & ({fmt_num(get(data, s, o, se_row))})" for o in outcomes)
            + r"\\")
        # Table A: stacked-test p-value vs All on its own line under the SE
        # (not for All itself), with a small gap before the next cutoff.
        if not placebo and stacked is not None and s != "all":
            lines.append(
                " & "
                + "".join(f" & [{stacked[(s, o)]:.3f}]" for o in outcomes)
                + r"\\[2pt]")

    if placebo:
        notes = NOTES_PLACEBO
    else:
        any_cut = next(iter(cuts.values()))
        tied = [lab for _, lab, members in pts if len(members) > 1]
        ties = ("" if not tied else
                " Deciles with the same raw cutoff select the same comparison group "
                "and share a row (" + ", ".join(tied) + ").")
        notes = (NOTES_MAIN
                 .replace("@@NPOS@@", fmt_count(any_cut["n_positive_total"]))
                 .replace("@@NPOOL@@", fmt_count(any_cut["n_untreated_total"]))
                 .replace("@@TIES@@", ties)
                 .replace("@@STACKED@@", STACKED_NOTE if stacked is not None else ""))

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
    OUT_TEX.write_text(build(data, cuts, load_stacked()))
    OUT_TEX_PLACEBO.write_text(build(data, cuts, placebo=True))
    print(f"Wrote {OUT_TEX}\nWrote {OUT_TEX_PLACEBO}")
    write_summary(data, cuts)

    if args.preview:
        for tex in (OUT_TEX, OUT_TEX_PLACEBO):
            compile_preview(tex, tex.with_name(tex.stem + "_preview.pdf"), crop=True)


if __name__ == "__main__":
    main()
