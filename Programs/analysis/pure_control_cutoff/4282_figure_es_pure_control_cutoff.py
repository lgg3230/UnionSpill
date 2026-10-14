#!/usr/bin/env python3
"""
4282_figure_es_pure_control_cutoff.py
=====================================
LaTeX wrapper and check for the direct-effect event studies of the two wage
outcomes when the comparison group is widened from zero connectivity to
untreated establishments with connectivity <= c, for c at P5, P10, P20 and P50
of positive connectivity. The panels (one per outcome, drawn in Stata by
3165_figures_pure_control_cutoff_fine.do) overlay the zero-connectivity
baseline (hollow marker, published Panel A event study) and the four cutoffs,
dodged within each year. This script joins them in a 1x2 subfigure whose notes
give each series' joint pre-trend F-test p-value (2009 = 2010 = 0).

Check: the c = 0 series must reproduce the Panel A event study of 3012. It is
compared with the untrimmed (trim_0, direct_A) series of 3222_trim_firmsize.do,
whose benchmark against the 3012 CSVs passes, if that file is present; the
result is written to verify_es.txt.

Input (written by 3162_pure_control_cutoff.do via 3164_pure_control_cutoff_fine.do):
    Graphs/pure_control_cutoff_fine/es_pure_control_cutoff_<outcome>.pdf   (3165)
    Tables/pure_control_cutoff_fine/pure_control_cutoff_es.csv
    Tables/pure_control_cutoff_fine/pure_control_cutoff_cutoffs.csv
    Tables/trim_firmsize/trim_firmsize_es_coefs.csv   (check only)

Output:
    Graphs/pure_control_cutoff_fine/f_es_pure_control_cutoff.tex          1x2 wrapper
    Graphs/pure_control_cutoff_fine/f_es_pure_control_cutoff_preview.pdf  (--preview), plus .png
    Tables/pure_control_cutoff_fine/verify_es.txt

Usage
-----
    python 4282_figure_es_pure_control_cutoff.py
    python 4282_figure_es_pure_control_cutoff.py --preview
"""

import argparse
import csv

from _pcc_fine_common import (FIG_PREFIX, GRAPH_DIR, PROJECT, TAB_DIR,
                              compile_preview, load_cutoffs, load_es, points)

ES_QUANTILES = ["p05", "p10", "p20", "p50"]
PANELS = [("lr_remdezr_h_w", "Log Hourly Wages", "hw"),
          ("lr_remdezr_w", "Log Wages", "mw")]
TRIM_ES = PROJECT / "Tables" / "trim_firmsize" / "trim_firmsize_es_coefs.csv"
VERIFY_OUT = TAB_DIR / "verify_es.txt"
TOL = 1e-6


def series(cuts):
    """[(sample, short label)] in the figure's order: baseline first."""
    out = [("zero", "$c = 0$")]
    for s, lab, _ in points(cuts, ES_QUANTILES):
        if s not in ("zero", "fixed_001", "all"):
            out.append((s, lab))
    return out


def verify(es):
    """Compare the c = 0 series with the untrimmed Panel A event study of 3222."""
    lines = ["Event-study check: c = 0 series vs 3222 trim_0 direct_A "
             f"({TRIM_ES.relative_to(PROJECT)})", ""]
    if not TRIM_ES.exists():
        lines.append("Reference file not found: check skipped.")
    else:
        ref = {}
        with open(TRIM_ES, newline="") as fh:
            for r in csv.DictReader(fh):
                if r["trim"] == "trim_0" and r["section"] == "direct_A":
                    ref[(r["outcome"], int(r["period"]))] = (float(r["b"]), float(r["se"]))
        ok = True
        for outcome, _, _ in PANELS:
            d = es[("zero", outcome)]
            for y, b, se in zip(d["years"], d["b"], d["se"]):
                if (outcome, y) not in ref:
                    ok = False
                    lines.append(f"  MISSING  {outcome:16s} {y}")
                    continue
                rb, rse = ref[(outcome, y)]
                match = abs(b - rb) <= TOL and abs(se - rse) <= TOL
                ok &= match
                lines.append(f"  {'ok  ' if match else 'DIFF'}     {outcome:16s} {y} "
                             f"b={b:.10f} ref={rb:.10f}  se={se:.10f} ref={rse:.10f}")
        lines += ["", "RESULT: PASS" if ok else "RESULT: FAIL"]
    VERIFY_OUT.write_text("\n".join(lines) + "\n")
    print("\n".join(lines))


def build_tex(es, ser):
    pvals = []
    for outcome, subcap, _ in PANELS:
        vals = [f"{short}: {es[(s, outcome)]['pre_pval']:.3f}" for s, short in ser]
        pvals.append(f"{subcap.lower()}, " + ", ".join(vals))
    notes = (
        r"\textit{Notes:} This figure plots dynamic difference-in-differences "
        r"estimates of the reform's direct effects on wages, $\beta_t$ from "
        r"Treatment $\times$ year interactions with 2011 omitted, when the "
        r"comparison group consists of all untreated establishments whose "
        r"connectivity to the directly treated is at most $c$, in raw "
        r"(unnormalized) units. The hollow markers are the main specification "
        r"($c = 0$, Panel~A of Table~\ref{tab:direct_connectivity_robust}); the "
        r"other series set $c$ at the 5th, 10th, 20th, and 50th percentiles of "
        r"connectivity among untreated establishments with positive "
        r"connectivity. Within each year the series are offset horizontally "
        r"for legibility. The directly treated establishments are the same in "
        r"every series, and specifications are otherwise identical to Table~"
        r"\ref{tab:direct_connectivity_robust}. Joint pre-trend $F$-test "
        r"$p$-values (2009 and 2010 coefficients equal to zero): "
        + "; ".join(pvals) + ". "
        r"Bars are $95\%$ confidence intervals from standard errors clustered "
        r"at the establishment level."
    )
    lines = [
        r"\begin{figure}[!tbp]",
        r"\centering",
        r"\caption{Direct Wage Effects by Year and Comparison-Group Connectivity Cutoff}",
        r"\label{fig:es_pure_control_cutoff}",
    ]
    for i, (outcome, subcap, lab) in enumerate(PANELS):
        lines += [
            r"\begin{subfigure}[t]{0.49\textwidth}",
            r"\centering",
            rf"\caption{{{subcap}}}",
            rf"\label{{fig:es_pcc_{lab}}}",
            rf"\includegraphics[width=\textwidth]{{{FIG_PREFIX}es_pure_control_cutoff_{outcome}.pdf}}",
            r"\end{subfigure}",
        ]
        if i == 0:
            lines.append(r"\hfill")
    lines += [
        "",
        r"\begin{minipage}{\linewidth}",
        r"\scriptsize\vspace{4pt}",
        notes,
        r"\end{minipage}",
        r"\end{figure}",
    ]
    return "\n".join(lines) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", action="store_true",
                    help="also compile a standalone PDF preview of the 1x2 figure")
    args = ap.parse_args()

    es = load_es()
    cuts = load_cutoffs()
    ser = series(cuts)
    GRAPH_DIR.mkdir(parents=True, exist_ok=True)

    verify(es)
    tex = GRAPH_DIR / "f_es_pure_control_cutoff.tex"
    tex.write_text(build_tex(es, ser))
    print(f"Wrote {tex}")
    if args.preview:
        figs = [GRAPH_DIR / f"es_pure_control_cutoff_{o}.pdf" for o, _, _ in PANELS]
        compile_preview(tex, GRAPH_DIR / "f_es_pure_control_cutoff_preview.pdf", figures=figs)


if __name__ == "__main__":
    main()
