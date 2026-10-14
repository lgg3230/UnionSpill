#!/usr/bin/env python3
"""
4320_trim_firmsize_report.py
============================
Report for the size-trimming robustness check: main direct effects (paper
Panel A) and main spillover effects re-estimated after dropping establishments
in the top and bottom 1, 2.5, 5, 10 and 20 percent of pre-treatment size.

  Figure 1  direct-effect event studies: 2 x 2 subfigures, one Stata PDF per
            outcome (drawn by 3222; untrimmed, 5% and 10% trims overlaid)
  Figure 2  spillover event studies (same)
  Table 1   trimming cutoffs and establishments dropped
  Table 2   mean, SD and median pre-treatment size of treated, spillover and
            zero-connectivity establishments, by trim level
  Table 3   direct effects, one column per sample, one panel per outcome
  Table 4   spillover effects, same layout

Also checks the untrimmed results against the 3012 output in
Tables/pct_tfpw_cc/ (b, SE, placebo b and SE, pre-trend p-value, pre-period
mean, N, establishments, as written) and lists the trimmed post coefficients
that fall outside the untrimmed 95% CI.

Input (written by 3222_trim_firmsize.do via 3221_trim_firmsize.do):
    Tables/trim_firmsize/results_trim_firmsize.csv
    Tables/trim_firmsize/trim_cutoffs.csv
    Tables/trim_firmsize/trim_size_by_group.csv
    Graphs/trim_firmsize/trim_es_<section>_<outcome>.pdf          (figures)

Output:
    Tables/trim_firmsize/trim_benchmark_check.csv
    Tables/trim_firmsize/trim_firmsize_report.tex   (+ .pdf, compiled with
                                                     tectonic or pdflatex)
    Tables/trim_firmsize/trim_firmsize_section.tex  body of the 'Trimming Sample
                                                     by Firm Size' section of
                                                     UnionSpill_paper/AER_referee_analyses.tex
                                                     (figures from Figures/TrimSize/)

Usage
-----
    python 4320_trim_firmsize_report.py [TABLES_DIR] [GRAPHS_DIR] [--no-compile]
"""

import argparse
import os
import re
import shutil
import subprocess
from pathlib import Path

import pandas as pd

PROJECT = Path(__file__).resolve().parents[3]
RES_NAME = "results_trim_firmsize.csv"
CUT_NAME = "trim_cutoffs.csv"
SIZE_NAME = "trim_size_by_group.csv"
BENCH_NAME = "trim_benchmark_check.csv"
REPORT_NAME = "trim_firmsize_report.tex"
PAPER_NAME = "trim_firmsize_section.tex"
PAPER_FIG_DIR = "Figures/TrimSize"
REF_DIR = PROJECT / "Tables" / "pct_tfpw_cc"
REF_CSV = {
    "direct_A": "results_direct_panelA_tfpw_07_11_pct.csv",
    "spill": "results_spill_tfpw_07_11_pct.csv",
}

# Paper order (hourly wages first, as in the paper's tables)
OUTCOMES = ["lr_remdezr_h_w", "lr_remdezr_w", "l_firm_emp", "numb_clauses"]
OUTCOME_LABEL = {
    "lr_remdezr_w": "Log wages",
    "lr_remdezr_h_w": "Log hourly wages",
    "l_firm_emp": "Log employment",
    "numb_clauses": "Number of clauses",
}
SECTIONS = ["direct_A", "spill"]
SECTION_TERM = {"direct_A": "Treatment", "spill": "Connectivity"}

TRIMS = ["trim_0", "trim_1", "trim_2p5", "trim_5", "trim_10", "trim_20"]
TRIM_LABEL = {
    "trim_0": "Untrimmed",
    "trim_1": "1%",
    "trim_2p5": "2.5%",
    "trim_5": "5%",
    "trim_10": "10%",
    "trim_20": "20%",
}
BENCH_ROWS = ["main", "main_se", "pre", "pre_se", "pre_pval", "mean_pre", "n_obs", "n_estab"]

NCOL = len(TRIMS)
BLANK_ROW = " &" * NCOL + r" \\"


# ── CSV parsing ───────────────────────────────────────────────────────────────

def load_results(filepath):
    """Parse a semicolon-delimited results CSV.

    Returns {spec: {section: {outcome: {row_type: value}}}}.
    """
    data = {}
    with open(filepath) as f:
        next(f)  # skip header
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = line.replace('"', "").split(";")
            if len(parts) < 5:
                continue
            spec, section, outcome, row_type, value = parts[:5]
            data.setdefault(spec, {}).setdefault(section, {}).setdefault(outcome, {})[
                row_type] = value.strip()
    return data


def num(raw):
    return float(raw.replace(",", "").rstrip("*"))


# ── Benchmark against 3012 ────────────────────────────────────────────────────

def benchmark(res, tables_dir):
    """Compare the untrimmed run with the 3012 CSVs, value by value as written."""
    rows = []
    for sec in SECTIONS:
        ref_path = REF_DIR / REF_CSV[sec]
        if not ref_path.exists():
            print(f"  benchmark: {ref_path} not found, skipped")
            continue
        ref = load_results(ref_path)["tfpw_07_11_pct"][sec]
        for o in OUTCOMES:
            for rt in BENCH_ROWS:
                pub = ref.get(o, {}).get(rt, "")
                rep = res["trim_0"][sec].get(o, {}).get(rt, "")
                rows.append({"section": sec, "outcome": o, "stat": rt, "published": pub,
                             "replicated": rep, "match": "yes" if pub == rep else "NO"})
    df = pd.DataFrame(rows)
    df.to_csv(tables_dir / BENCH_NAME, index=False)
    n_bad = int((df["match"] == "NO").sum()) if len(df) else 0
    if n_bad:
        print(f"  BENCHMARK: {n_bad} cell(s) differ from the 3012 output:")
        print(df[df["match"] == "NO"].to_string(index=False))
    else:
        print(f"  benchmark: all {len(df)} untrimmed cells match the 3012 output")
    return len(df), n_bad


def outside_ci(res):
    """Trimmed post coefficients outside the untrimmed 95% CI."""
    out = []
    for sec in SECTIONS:
        for o in OUTCOMES:
            base = res["trim_0"][sec][o]
            b0, s0 = num(base["main"]), num(base["main_se"])
            lo, hi = b0 - 1.96 * s0, b0 + 1.96 * s0
            for t in TRIMS[1:]:
                b = num(res[t][sec][o]["main"])
                if b < lo or b > hi:
                    out.append((sec, o, t, b, lo, hi))
    return out


# ── LaTeX ─────────────────────────────────────────────────────────────────────

def hdr(text):
    return r"\begin{tabular}[c]{@{}c@{}}" + text + r"\end{tabular}"


def format_value(raw, is_se=False, is_count=False, is_pval=False, is_mean=False):
    raw = raw.strip()
    if raw in ("--", ""):
        return "--"
    if is_count:
        return raw.replace(",", "{,}")
    if is_pval:
        return f"[{float(raw):.2f}]"
    if is_mean:
        return f"{float(raw):.3f}"
    match = re.match(r"^([^*]+?)(\*{1,3})?$", raw)
    if not match:
        return raw
    num_str = match.group(1).strip()
    stars = match.group(2) or ""
    if num_str.startswith("-"):
        num_str = r"$-$" + num_str[1:]
    return f"({num_str})" if is_se else f"{num_str}{stars}"


def row(label, res, sec, o, row_type, **kw):
    cells = []
    for t in TRIMS:
        try:
            cells.append(format_value(res[t][sec][o][row_type], **kw))
        except KeyError:
            cells.append("--")
    return f"{label} & " + " & ".join(cells) + r" \\"


def col_header_rows():
    heads = [hdr(r"Untrimmed")] + [hdr(rf"Trim {TRIM_LABEL[t].replace('%', chr(92) + '%')}\\each tail")
                                   for t in TRIMS[1:]]
    return [
        " & " + " & ".join(heads) + r" \\",
        " & " + " & ".join(f"({i})" for i in range(1, NCOL + 1)) + r" \\",
    ]


def cutoff_cells(cut, field):
    cells = []
    for t in TRIMS:
        r = cut.loc[t]
        if t == "trim_0":
            cells.append("--")
        elif field == "lo":
            cells.append(f"{r['lo']:.2f}")
        elif field == "hi":
            cells.append(f"{r['hi']:,.1f}".replace(",", "{,}"))
        else:
            n = int(r["n_estab"] - r["n_kept"])
            cells.append(f"{n:,}".replace(",", "{,}") + f" ({100 * n / r['n_estab']:.1f}\\%)")
    return cells


def table_open(caption, label, ncols, paper):
    """\\begin{table} through \\toprule\\toprule. The report wraps the tabular in
    threeparttable; the paper fragment (AER_referee_analyses.tex style) does not."""
    lines = [
        r"\begin{table}[H]",
        r"\centering",
        rf"\caption{{{caption}}}",
        rf"\label{{{label}}}",
        r"\scriptsize",
    ]
    if not paper:
        lines.append(r"\begin{threeparttable}")
    return lines + [r"\begin{tabular}{l" + "c" * ncols + "}", r"\toprule\toprule"]


def table_close(notes, paper):
    """\\bottomrule through \\end{table}: tablenotes (report) or a notes
    minipage under the table (paper fragment)."""
    if paper:
        return [
            r"\bottomrule",
            r"\end{tabular}",
            r"\begin{minipage}{\linewidth}",
            r"\scriptsize\vspace{4pt}",
            rf"\textit{{Notes:}} {notes}",
            r"\end{minipage}",
            r"\end{table}",
        ]
    return [
        r"\bottomrule",
        r"\end{tabular}",
        r"\scriptsize",
        r"\begin{tablenotes}",
        rf"\item \textit{{Notes:}} {notes}",
        r"\end{tablenotes}",
        r"\end{threeparttable}",
        r"\end{table}",
    ]


def results_table(res, cut, sec, caption, label, notes, paper=False):
    term = SECTION_TERM[sec]
    lines = table_open(caption, label, NCOL, paper)
    lines += col_header_rows()
    lines.append(r"\midrule")
    for k, o in enumerate(OUTCOMES):
        letter = "ABCD"[k]
        lines += [
            rf"\multicolumn{{{NCOL + 1}}}{{l}}{{\textbf{{Panel {letter}:}} \textit{{{OUTCOME_LABEL[o]}}}}} \\",
            r"\midrule",
            row(rf"Post $\times$ {term}", res, sec, o, "main"),
            row("", res, sec, o, "main_se", is_se=True),
            row(rf"Pre $\times$ {term}", res, sec, o, "pre"),
            row("", res, sec, o, "pre_se", is_se=True),
            row(r"Pre-trend $F$-test $p$-value", res, sec, o, "pre_pval", is_pval=True),
            BLANK_ROW,
            row(r"Pre-period mean of dep.\ var.", res, sec, o, "mean_pre", is_mean=True),
            row("Observations", res, sec, o, "n_obs", is_count=True),
            row("Establishments", res, sec, o, "n_estab", is_count=True),
            r"\midrule",
        ]
    lines += [
        rf"\multicolumn{{{NCOL + 1}}}{{l}}{{\textbf{{Trimming}} \textit{{(pre-treatment employment, pooled sample)}}}} \\",
        r"\midrule",
        "Lower cutoff (employees) & " + " & ".join(cutoff_cells(cut, "lo")) + r" \\",
        "Upper cutoff (employees) & " + " & ".join(cutoff_cells(cut, "hi")) + r" \\",
        "Establishments dropped & " + " & ".join(cutoff_cells(cut, "drop")) + r" \\",
    ]
    return "\n".join(lines + table_close(notes, paper))


def cutoff_table(cut, paper=False):
    lines = table_open("Trimming cutoffs and establishments dropped", "tab:trim_cutoffs", NCOL - 1, paper)
    lines += [
        " & " + " & ".join(hdr(rf"Trim {TRIM_LABEL[t].replace('%', chr(92) + '%')}\\each tail")
                           for t in TRIMS[1:]) + r" \\",
        " & " + " & ".join(f"({i})" for i in range(1, NCOL)) + r" \\",
        r"\midrule",
    ]

    def r_(label, f):
        return f"{label} & " + " & ".join(f(cut.loc[t]) for t in TRIMS[1:]) + r" \\"

    def c(v):
        return f"{int(v):,}".replace(",", "{,}")

    lines += [
        r_("Lower cutoff (employees)", lambda r: f"{r['lo']:.2f}"),
        r_("Upper cutoff (employees)", lambda r: f"{r['hi']:,.1f}".replace(",", "{,}")),
        " &" * (NCOL - 1) + r" \\",
        r_("Establishments kept", lambda r: c(r["n_kept"])),
        r_("Dropped, below lower cutoff", lambda r: c(r["n_drop_low"])),
        r_("Dropped, above upper cutoff", lambda r: c(r["n_drop_high"])),
        r_(r"Dropped, share of sample", lambda r: f"{100 * (r['n_estab'] - r['n_kept']) / r['n_estab']:.1f}\\%"),
        " &" * (NCOL - 1) + r" \\",
        r_("Dropped, treated", lambda r: c(r["n_drop_treated"])),
        r_("Dropped, untreated", lambda r: c(r["n_drop_untreated"])),
        r_(r"\quad of which zero connectivity", lambda r: c(r["n_drop_zeroconn"])),
    ]
    notes = (
        r"Pre-treatment establishment size is mean employment over 2009--2011. "
        rf"Percentiles are computed once on the {c(cut.loc['trim_0', 'n_estab'])} establishments of the "
        r"balanced Lagos sample (treated and untreated pooled, observed in 2009). A column with trim $p$ "
        r"drops every establishment below the $p$-th or above the $(100-p)$-th percentile; establishments "
        r"exactly at a cutoff are kept, so with ties in size (employment averaged over three years) the share "
        r"dropped can be below $2p$ percent. The same establishments are dropped from the direct-effect and "
        r"the spillover samples. Zero connectivity: untreated establishments with no pre-reform worker flows "
        r"to treated establishments (the control group of the direct-effect sample)."
    )
    return "\n".join(lines + table_close(notes, paper))


SIZE_GROUPS = [
    ("treated", "Directly treated", "active CBA on the reform date"),
    ("spill", "Spillover sample", "all untreated"),
    ("zeroconn", "Zero-connectivity untreated", "direct-effect controls"),
]


def size_table(size, paper=False):
    """Mean (SD) and median pre-treatment size by group, one column per sample."""
    lines = table_open("Pre-treatment establishment size by group and trimming", "tab:trim_size_groups",
                       NCOL, paper)
    lines += col_header_rows()
    lines.append(r"\midrule")
    for k, (g, name, desc) in enumerate(SIZE_GROUPS):
        d = size[size["group"] == g].set_index("trim")

        def cells(f):
            return " & ".join(f(d.loc[t]) for t in TRIMS)

        lines += [
            rf"\multicolumn{{{NCOL + 1}}}{{l}}{{\textbf{{Panel {'ABC'[k]}:}} \textit{{{name}}} ({desc})}} \\",
            r"\midrule",
            "Mean employment & " + cells(lambda r: f"{r['mean']:,.1f}".replace(",", "{,}")) + r" \\",
            " & " + cells(lambda r: f"({r['sd']:,.1f})".replace(",", "{,}")) + r" \\",
            "Median employment & " + cells(lambda r: f"{r['p50']:,.1f}".replace(",", "{,}")) + r" \\",
            "Establishments & " + cells(lambda r: f"{int(r['n_estab']):,}".replace(",", "{,}")) + r" \\",
        ]
        if k < len(SIZE_GROUPS) - 1:
            lines.append(r"\midrule")
    notes = (
        r"Size is mean employment over 2009--2011 (the trimming variable); standard "
        r"deviations in parentheses. One observation per establishment in the balanced Lagos sample, before "
        r"the regression-specific drops (singletons, missing outcomes), so counts are slightly above the "
        r"Establishments rows of the results tables. Panel~A and Panel~C together form the direct-effect "
        r"sample; Panel~B is the spillover sample. Column (1) is untrimmed; columns (2)--(6) drop "
        r"establishments below the $p$-th or above the $(100-p)$-th percentile of the pooled size "
        r"distribution (cutoffs in Table~\ref{tab:trim_cutoffs})."
    )
    return "\n".join(lines + table_close(notes, paper))


COMMON_NOTES = (
    r"Column (1) uses the full balanced Lagos sample (2009--2016); columns (2)--(6) drop establishments "
    r"below the $p$-th or above the $(100-p)$-th percentile of pooled pre-treatment size (mean employment "
    r"2009--2011), cutoffs in the bottom panel. Quartile bins and the connectivity scale keep their "
    r"full-sample definitions. "
)
CONTROLS_NOTES = (
    r"Number of clauses uses CBA periods (placebo: 2009 vs.\ the 2010--2012 period). Controls as in the "
    r"paper's main tables: establishment FE; year (CBA-period) FE interacted with three-digit industry, "
    r"microregion and negotiation month; quartile bins of the pre-treatment outcome, size and per-worker "
    r"worker flows (2007--2011), each interacted with year (CBA-period) FE. The $F$-test jointly tests the "
    r"pre-reform event-study coefficients. Standard errors clustered by establishment in parentheses. "
    r"*** p$<$0.01, ** p$<$0.05, * p$<$0.10."
)


def direct_notes(paper):
    ref = (r"; column (1) reproduces Panel~A of Table~\ref{tab:direct_connectivity_robust}" if paper
           else r" (paper Panel~A)")
    return (
        r"Difference-in-differences estimates of the direct effect of the 2012 ultractivity reform: treated "
        r"establishments vs.\ untreated establishments with zero pre-reform connectivity to treated "
        r"establishments" + ref + ". " + COMMON_NOTES +
        r"Post $\times$ Treatment: average effect for 2012--2016; Pre $\times$ Treatment: placebo on "
        r"2009--2011. " + CONTROLS_NOTES
    )


def spill_notes(paper):
    ref = r" Column (1) reproduces Table~\ref{tab:spill_main_4tf_out}." if paper else ""
    return (
        r"Spillover effects of the 2012 ultractivity reform on untreated establishments. Connectivity is "
        r"per-worker worker flows to treated establishments (2007--2011), scaled so that 1 is the 90th "
        r"percentile among untreated establishments in 2009 (full sample)." + ref + " " + COMMON_NOTES +
        r"Post $\times$ Connectivity: average effect for 2012--2016; Pre $\times$ Connectivity: placebo on "
        r"2009--2011. " + CONTROLS_NOTES
    )


def figure_block(sec, caption, label, note, paper=False):
    """2 x 2 subfigures, one standalone Stata PDF per outcome (titled in-plot,
    each with its own legend); subcaptions give the (a)-(d) labels."""
    prefix = PAPER_FIG_DIR + "/" if paper else ""
    subs = []
    for k, o in enumerate(OUTCOMES):
        subs += [
            r"\begin{subfigure}[t]{0.49\textwidth}",
            r"\centering",
            rf"\includegraphics[width=\textwidth]{{{prefix}trim_es_{sec}_{o}.pdf}}",
            r"\caption{}",
            rf"\label{{{label}_{o}}}",
            r"\end{subfigure}" + (r"\hfill" if k % 2 == 0 else r"\\[0.6em]"),
        ]
    notes = ([r"\begin{minipage}{\linewidth}", r"\scriptsize\vspace{4pt}"] if paper
             else [r"\begin{minipage}{\textwidth}\footnotesize"])
    return "\n".join([
        r"\begin{figure}[H]",
        r"\centering",
        rf"\caption{{{caption}}}",
        rf"\label{{{label}}}",
        *subs,
        *notes,
        rf"\textit{{Notes:}} {note}",
        r"\end{minipage}",
        r"\end{figure}",
    ])


def fig_note(tab):
    panels = ", ".join(f"({'abcd'[k]}) {OUTCOME_LABEL[o].lower()}" for k, o in enumerate(OUTCOMES))
    return (
        r"Event-study coefficients with 95\% confidence intervals (standard errors clustered by establishment), "
        r"for the untrimmed sample (gray circles) and for samples trimmed at the top and bottom 5\% (blue "
        r"diamonds) and 10\% (darker blue crosses) of pre-treatment establishment size; the tables also report "
        rf"the 1, 2.5 and 20\% trims. Panels: {panels}. The reference period is 2011 (2010--2012 CBA period "
        r"for number of clauses) and is set to zero. The dashed line marks the reform (September 2012). "
        rf"Specification as in Table~\ref{{{tab}}}."
    )


def build_report(res, cut, size, tables_dir, graphs_dir, bench, flagged):
    rel = os.path.relpath(graphs_dir, tables_dir).replace(os.sep, "/")
    n_cells, n_bad = bench
    if n_cells == 0:
        bench_txt = r"The 3012 output was not found, so the untrimmed column was not checked against it."
    elif n_bad == 0:
        bench_txt = (rf"The untrimmed column reproduces the paper's main results (3012 output in "
                     rf"\texttt{{Tables/pct\_tfpw\_cc/}}) in all {n_cells} reported cells.")
    else:
        bench_txt = (rf"\textbf{{Warning:}} {n_bad} of {n_cells} untrimmed cells differ from the 3012 output "
                     rf"(see \texttt{{{BENCH_NAME.replace('_', chr(92) + '_')}}}).")
    if flagged:
        items = "; ".join(
            f"{'direct' if s == 'direct_A' else 'spillover'}, {OUTCOME_LABEL[o].lower()}, "
            f"trim {TRIM_LABEL[t].replace('%', chr(92) + '%')} ({b:.4f}, untrimmed CI [{lo:.4f}, {hi:.4f}])"
            for s, o, t, b, lo, hi in flagged)
        flag_txt = "Post-period coefficients outside the untrimmed 95\\% confidence interval: " + items + "."
    else:
        flag_txt = ("Every trimmed post-period coefficient lies inside the 95\\% confidence interval of the "
                    "untrimmed estimate.")

    parts = [
        r"\documentclass[11pt]{article}",
        r"\usepackage[hmargin=0.9in,vmargin=0.7in]{geometry}",
        r"\usepackage{graphicx,booktabs,threeparttable,amsmath,float}",
        r"\usepackage[labelfont=bf]{caption}",
        r"\usepackage{subcaption}",
        rf"\graphicspath{{{{{rel}/}}}}",
        r"\title{Robustness: Trimming by Pre-Treatment Establishment Size}",
        r"\date{\today}",
        r"\begin{document}",
        r"\maketitle",
        r"\noindent This note re-estimates the main direct effects (treated vs.\ zero-connectivity untreated "
        r"establishments) and the main spillover effects (untreated establishments, connectivity to treated "
        r"establishments) after dropping establishments at both tails of the pre-treatment size distribution. "
        r"Size is mean employment over 2009--2011; cutoffs are percentiles of the pooled establishment sample, "
        r"applied to both estimation samples (Table~\ref{tab:trim_cutoffs}; group means of size by trim level in Table~\ref{tab:trim_size_groups}). Specifications, fixed effects, "
        r"controls and clustering are those of the paper's main tables; quartile-bin controls and the "
        r"connectivity scale keep their full-sample definitions. " + bench_txt + " " + flag_txt,
        "",
        cutoff_table(cut),
        size_table(size),
        r"\clearpage",
        figure_block("direct_A", "Direct effects: event studies by size trimming",
                     "fig:trim_es_direct", fig_note("tab:trim_direct")),
        r"\clearpage",
        figure_block("spill", "Spillover effects: event studies by size trimming",
                     "fig:trim_es_spill", fig_note("tab:trim_spill")),
        r"\clearpage",
        results_table(res, cut, "direct_A", "Direct effects by size trimming", "tab:trim_direct",
                      direct_notes(False)),
        r"\clearpage",
        results_table(res, cut, "spill", "Spillover effects by size trimming", "tab:trim_spill",
                      spill_notes(False)),
        r"\end{document}",
        "",
    ]
    out = tables_dir / REPORT_NAME
    out.write_text("\n".join(parts))
    return out


def build_paper_section(res, cut, size, tables_dir):
    """Body of the 'Trimming Sample by Firm Size' section of
    UnionSpill_paper/AER_referee_analyses.tex: same tables and figures in that
    document's style (notes minipage, figures under Figures/TrimSize/)."""
    parts = [
        "% Generated by Programs/analysis/robustness/4320_trim_firmsize_report.py from the",
        "% 3222_trim_firmsize.do output; paste below \\section{Trimming Sample by Firm Size}.",
        r"This section re-estimates the paper's main direct effects (Panel~A of "
        r"Table~\ref{tab:direct_connectivity_robust}) and spillover effects (Table~\ref{tab:spill_main_4tf_out}) "
        r"after dropping establishments at both tails of the pre-treatment size distribution. Size is mean "
        r"employment over 2009--2011. For each $p \in \{1, 2.5, 5, 10, 20\}$, establishments below the "
        r"$p$-th or above the $(100-p)$-th percentile of the pooled distribution of treated and untreated "
        r"establishments are dropped from both estimation samples (Table~\ref{tab:trim_cutoffs}); "
        r"Table~\ref{tab:trim_size_groups} reports the size of the directly treated, spillover, and "
        r"zero-connectivity groups under each trim. Specifications, fixed effects, controls, and clustering "
        r"are those of the main tables; the quartile-bin controls and the connectivity normalization keep their "
        r"full-sample definitions, so only the estimation sample changes across columns.",
        "",
        cutoff_table(cut, paper=True),
        "",
        size_table(size, paper=True),
        "",
        results_table(res, cut, "direct_A", "Direct Effects by Size Trimming", "tab:trim_direct",
                      direct_notes(True), paper=True),
        "",
        figure_block("direct_A", "Direct Effects: Event Studies by Size Trimming", "fig:trim_es_direct",
                     fig_note("tab:trim_direct"), paper=True),
        "",
        results_table(res, cut, "spill", "Spillover Effects by Size Trimming", "tab:trim_spill",
                      spill_notes(True), paper=True),
        "",
        figure_block("spill", "Spillover Effects: Event Studies by Size Trimming", "fig:trim_es_spill",
                     fig_note("tab:trim_spill"), paper=True),
        "",
    ]
    out = tables_dir / PAPER_NAME
    out.write_text("\n".join(parts))
    return out


def compile_pdf(tex_path):
    engine = shutil.which("tectonic") or shutil.which("pdflatex")
    if engine is None:
        print("  no tectonic or pdflatex on PATH: .tex written, PDF not compiled")
        return None
    args = [engine, tex_path.name] if engine.endswith("tectonic") else \
        [engine, "-interaction=nonstopmode", tex_path.name]
    runs = 1 if engine.endswith("tectonic") else 2
    for _ in range(runs):
        p = subprocess.run(args, cwd=tex_path.parent, capture_output=True, text=True)
        if p.returncode != 0:
            print(p.stdout[-3000:], p.stderr[-3000:])
            raise SystemExit(f"LaTeX failed ({engine})")
    pdf = tex_path.with_suffix(".pdf")
    print(f"  PDF: {pdf}")
    return pdf


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("tables_dir", nargs="?", default=str(PROJECT / "Tables" / "trim_firmsize"))
    ap.add_argument("graphs_dir", nargs="?", default=str(PROJECT / "Graphs" / "trim_firmsize"))
    ap.add_argument("--no-compile", action="store_true")
    a = ap.parse_args()
    tables_dir, graphs_dir = Path(a.tables_dir), Path(a.graphs_dir)

    res = load_results(tables_dir / RES_NAME)
    cut = pd.read_csv(tables_dir / CUT_NAME, skipinitialspace=True, na_values=["."]).set_index("trim")
    size = pd.read_csv(tables_dir / SIZE_NAME, skipinitialspace=True)

    bench = benchmark(res, tables_dir)
    flagged = outside_ci(res)
    for s, o, t, b, lo, hi in flagged:
        print(f"  outside untrimmed CI: {s} {o} {t}: {b:.4f} not in [{lo:.4f}, {hi:.4f}]")

    for sec in SECTIONS:
        for o in OUTCOMES:
            fig = graphs_dir / f"trim_es_{sec}_{o}.pdf"
            if not fig.exists():
                print(f"  missing figure {fig} (drawn by 3222_trim_firmsize.do)")
    tex = build_report(res, cut, size, tables_dir, graphs_dir, bench, flagged)
    print(f"  LaTeX: {tex}")
    print(f"  paper section: {build_paper_section(res, cut, size, tables_dir)}")
    if not a.no_compile:
        compile_pdf(tex)


if __name__ == "__main__":
    main()
