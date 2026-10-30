#!/usr/bin/env python3
"""
4340_trim_sides_latex.py
========================
Tables and figure wrappers for the tail-trimming robustness check: log hourly
wage effects after dropping firms in the left, right, or both tails (5%, 10%
and 20%) of the POOLED pre-treatment size distribution (treated and untreated
together), for three estimates:

    direct_A   treated vs zero-connectivity untreated  (published Panel A)
    direct_C   treated vs all untreated                (published Panel B)
    spill      untreated only, Post x Connectivity

  Size table (tab:trim_sides_groups): one row per variant; the pooled cutoffs
    and, for the treated, all untreated, and zero-connectivity untreated, the
    firms kept and the mean and median pre-period employment.
  Direct table (tab:trim_sides_direct) and spillover table
    (tab:trim_sides_spill): one column per variant, grouped by trimmed side;
    rows are the Post coefficient, the placebo, the pre-trend F-test p-value,
    observations and establishments. The direct table has Panel A
    (zero-connectivity controls) and Panel B (all untreated controls), and a
    last row with the p-value of the test that the two direct coefficients
    are equal (stacked regression, as in
    conn_margins/3022_direct_sample_coef_test.do).
  Event-study wrappers (fig:es_trim_sides_<estimate>): 1x3 subfigures (left,
    right, both tails) of the Stata panels; notes list each series' pre-trend
    F-test p-value.
  Summary CSV: every coefficient with its change relative to the baseline.
  Check: the both5 / both10 / both20 samples equal 3222_trim_firmsize.do's
    trim_5 / trim_10 / trim_20 (pooled two-tail trims); their direct_A and spill estimates are
    compared with that run (written to check_vs_3222.txt).

Input (written by 3242_trim_sides.do via 3241_trim_sides.do):
    Tables/trim_sides/trim_sides.csv, trim_sides_groups.csv, trim_sides_es.csv
    Graphs/trim_sides/es_trim_sides_<estimate>_<side>.pdf   (Stata)
    Tables/trim_firmsize/results_trim_firmsize.csv          (check only)

Output:
    Tables/trim_sides/t_trim_sides_groups.tex      size table fragment
    Tables/trim_sides/t_trim_sides_direct.tex      direct-effects table fragment
    Tables/trim_sides/t_trim_sides_spill.tex       spillover table fragment
    Tables/trim_sides/trim_sides_summary.csv       flat summary vs baseline
    Tables/trim_sides/check_vs_3222.txt
    Graphs/trim_sides/f_es_trim_sides_<estimate>.tex   figure wrappers
    Tables/trim_sides/trim_sides_preview.pdf       (--preview) all exhibits

Fragments use paper-style paths (figures under Figures/TrimSides/) and refer
to Draft.tex labels; the preview stubs those labels.

Usage
-----
    python 4340_trim_sides_latex.py [TABLES_DIR] [GRAPHS_DIR] [--preview]
"""

import argparse
import csv
import math
import shutil
import subprocess
import tempfile
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[3]
FIG_PREFIX = "Figures/TrimSides/"
OUTCOME = "lr_remdezr_h_w"
REF_3222 = PROJECT / "Tables" / "trim_firmsize" / "results_trim_firmsize.csv"

VARIANTS = ["base", "left5", "left10", "left20", "right5", "right10", "right20",
            "both5", "both10", "both20"]
VARIANT_LABEL = {
    "base": "Untrimmed (baseline)",
    "left5": r"Left 5\%", "left10": r"Left 10\%", "left20": r"Left 20\%",
    "right5": r"Right 5\%", "right10": r"Right 10\%", "right20": r"Right 20\%",
    "both5": r"Both tails 5\%", "both10": r"Both tails 10\%", "both20": r"Both tails 20\%",
}
GROUPS = [("treated", "Directly treated"),
          ("untreated", "All untreated"),
          ("zero", "Zero-connectivity untreated")]
# Group headers of Table 1, wrapped on two lines so the column groups have
# similar widths.
GROUP_HEADER = {"treated": r"Directly \\ treated",
                "untreated": r"All \\ untreated",
                "zero": r"Zero-connectivity \\ untreated"}
SECTIONS = [("direct_A", "Direct, zero-connectivity controls", "Treatment"),
            ("direct_C", "Direct, all untreated controls", "Treatment"),
            ("spill", "Spillover", "Connectivity")]
SIDES = [("left", "Left tail"), ("right", "Right tail"), ("both", "Both tails")]


# ── Inputs ────────────────────────────────────────────────────────────────────

def num(v):
    v = v.strip()
    return math.nan if v in ("", ".") else float(v)


def load_results(path):
    out = {}
    with open(path, newline="") as fh:
        for r in csv.DictReader(fh):
            out[(r["spec"], r["section"], r["row_type"])] = num(r["value"])
    return out


def load_groups(path):
    out = {}
    with open(path, newline="") as fh:
        for r in csv.DictReader(fh):
            out[(r["variant"], r["group"])] = {k: (num(v) if k not in ("variant", "group") else v)
                                               for k, v in r.items()}
    return out


def load_es_pvals(path):
    out = {}
    with open(path, newline="") as fh:
        for r in csv.DictReader(fh):
            out[(r["variant"], r["section"])] = num(r["pre_pval"])
    return out


def get(data, v, sec, row):
    try:
        val = data[(v, sec, row)]
    except KeyError:
        raise SystemExit(f"Missing '{row}' for {sec}, variant {v}.")
    if math.isnan(val):
        raise SystemExit(f"'{row}' is missing for {sec}, variant {v}.")
    return val


# ── Formatting ────────────────────────────────────────────────────────────────

def stars(p):
    return "***" if p < 0.01 else "**" if p < 0.05 else "*" if p < 0.10 else ""


def fmt_num(val, digits=4):
    # no minus sign on values that round to zero ("-0.0000")
    neg = val < 0 and round(abs(val), digits) > 0
    return ("$-$" if neg else "") + f"{abs(val):.{digits}f}"


def fmt_count(val):
    return f"{int(round(val)):,}".replace(",", "{,}")


def fmt_emp(val):
    return "--" if math.isnan(val) else f"{val:,.1f}".replace(",", "{,}")


def hdr(text):
    return r"\begin{tabular}[c]{@{}c@{}}" + text + r"\end{tabular}"


def table_close(notes):
    return [
        r"\bottomrule\bottomrule",
        r"\end{tabular}}",
        "",
        r"\begin{minipage}{\textwidth}",
        r"\scriptsize\vspace{4pt}",
        notes,
        r"\end{minipage}",
        r"\end{table}",
    ]


# ── Size table ────────────────────────────────────────────────────────────────

def groups_table(groups):
    ncols = 2 + 3 * len(GROUPS)
    lines = [
        r"\begin{table}[H]",
        r"\centering",
        r"\caption{Pre-Treatment Establishment Size by Group under Tail Trimming}",
        r"\label{tab:trim_sides_groups}",
        r"\scriptsize",
        r"\setlength{\tabcolsep}{4pt}",
        r"\resizebox{\textwidth}{!}{%",
        r"\begin{tabular}{l" + "c" * ncols + "}",
        r"\toprule\toprule",
        r" & \multicolumn{2}{c}{Cutoffs} & "
        + " & ".join(rf"\multicolumn{{3}}{{c}}{{{hdr(GROUP_HEADER[g])}}}" for g, _ in GROUPS) + r"\\",
        r"\cmidrule(lr){2-3} "
        + " ".join(rf"\cmidrule(lr){{{4 + 3 * i}-{6 + 3 * i}}}" for i in range(len(GROUPS))),
        " & " + " & ".join([hdr("Lower"), hdr("Upper")]
                           + [hdr(r"Firms \\ kept"), hdr("Mean"), hdr("Median")] * len(GROUPS)) + r"\\",
        " & " + " & ".join(f"({i})" for i in range(1, ncols + 1)) + r"\\",
        r"\midrule",
    ]
    for v in VARIANTS:
        first = groups[(v, GROUPS[0][0])]
        cells = [fmt_emp(first["lo"]), fmt_emp(first["hi"])]
        for g, _ in GROUPS:
            r = groups[(v, g)]
            cells += [fmt_count(r["n_kept"]), fmt_emp(r["mean"]), fmt_emp(r["p50"])]
        lines.append(VARIANT_LABEL[v] + " & " + " & ".join(cells) + r"\\")
        if v in ("base", "left20", "right20"):     # small gap between the side blocks
            lines.append(r"\addlinespace[3pt]")
    n_pool = sum(groups[("base", g)]["n_total"] for g in ("treated", "untreated"))
    notes = (
        r"\textit{Notes:} Establishment size is pre-treatment mean employment over 2009--2011, one "
        r"observation per establishment in the balanced Lagos sample. Cutoffs are percentiles of the "
        rf"pooled size distribution of all {fmt_count(n_pool)} establishments (directly treated and "
        r"untreated together), in employees: Left $p$\% drops establishments below the $p$th percentile, "
        r"Right $p$\% those above the $(100-p)$th, and Both tails both; establishments exactly at a cutoff "
        r"are kept. Each row is a separate estimation sample. Mean and Median describe the establishments "
        r"kept. The direct-effect samples combine the directly treated with the zero-connectivity "
        r"untreated (zero-connectivity controls) or with all untreated (all untreated controls); the "
        r"spillover sample is all untreated."
    )
    return "\n".join(lines + table_close(notes)) + "\n"


# ── Estimates table ───────────────────────────────────────────────────────────

# Column layout of the transposed estimates tables: one column per variant,
# grouped by the trimmed side.
SIDE_GROUPS = [("Untrimmed", ["base"]),
               ("Left tail", ["left5", "left10", "left20"]),
               ("Right tail", ["right5", "right10", "right20"]),
               ("Both tails", ["both5", "both10", "both20"])]
COL_LABEL = {"base": "Baseline", "left5": r"5\%", "left10": r"10\%", "left20": r"20\%",
             "right5": r"5\%", "right10": r"10\%", "right20": r"20\%",
             "both5": r"5\%", "both10": r"10\%", "both20": r"20\%"}


def _variant_header():
    """Two header rows (side groups, trim levels), cmidrules and column numbers."""
    top, rules, sub = [], [], []
    col = 2
    for name, vs in SIDE_GROUPS:
        top.append(rf"\multicolumn{{{len(vs)}}}{{c}}{{{name}}}")
        rules.append(rf"\cmidrule(lr){{{col}-{col + len(vs) - 1}}}")
        sub += [COL_LABEL[v] for v in vs]
        col += len(vs)
    n = len(VARIANTS)
    return [
        " & " + " & ".join(top) + r"\\",
        " ".join(rules),
        " & " + " & ".join(sub) + r"\\",
        " & " + " & ".join(f"({i})" for i in range(1, n + 1)) + r"\\",
    ]


def _panel_rows(data, sec, term, placebo_rule=False):
    """Row sequence of the paper's direct and spillover tables
    (tab:direct_connectivity_robust, tab:spill_main_4tf_out): Post x term and
    SE; blank; Mean, Observations, Establishments; blank (or a rule, as in the
    spillover table); Pre-trend (placebo) and SE; plus the pre-trend F-test
    p-value, which the paper tables do not report."""
    n = len(VARIANTS)
    blank = " &" * n + r"\\"

    def row(label, f):
        return f"{label} & " + " & ".join(f(v) for v in VARIANTS) + r"\\"
    return [
        row(rf"Post $\times$ {term}",
            lambda v: f"{fmt_num(get(data, v, sec, 'main'))}{stars(get(data, v, sec, 'main_p'))}"),
        row("", lambda v: f"({fmt_num(get(data, v, sec, 'main_se'))})"),
        blank,
        row("Mean", lambda v: f"{get(data, v, sec, 'mean_pre'):.3f}"),
        row("Observations", lambda v: fmt_count(get(data, v, sec, "n_obs"))),
        row("Establishments", lambda v: fmt_count(get(data, v, sec, "n_estab"))),
        r"\midrule" if placebo_rule else blank,
        row("Pre-trend (placebo)",
            lambda v: f"{fmt_num(get(data, v, sec, 'pre'))}{stars(get(data, v, sec, 'pre_p'))}"),
        row("", lambda v: f"({fmt_num(get(data, v, sec, 'pre_se'))})"),
        row(r"Pre-trend $F$-test $p$-value", lambda v: f"[{get(data, v, sec, 'pre_pval'):.2f}]"),
    ]


def _table_open(caption, label):
    n = len(VARIANTS)
    return [
        r"\begin{table}[H]",
        r"\centering",
        rf"\caption{{{caption}}}",
        rf"\label{{{label}}}",
        r"\scriptsize",
        r"\setlength{\tabcolsep}{4pt}",
        r"\resizebox{\textwidth}{!}{%",
        r"\begin{tabular}{l" + "c" * n + "}",
        r"\toprule\toprule",
    ] + _variant_header()


COMMON_EST_NOTES = (
    r"Each column is a separate estimation sample: column (1) is the untrimmed main specification; "
    r"columns (2)--(10) drop establishments in the left tail, the right tail, or both tails of the pooled "
    r"pre-treatment size distribution at the 5, 10, or 20\% level (cutoffs and group sizes in "
    r"Table~\ref{tab:trim_sides_groups}). Post reports the average effect over 2012--2016; the placebo is "
    r"the coefficient from a placebo regression estimated on pre-treatment data only; the pre-trend "
    r"$F$-test $p$-value tests that the 2009 and 2010 event-study coefficients are jointly zero. Mean "
    r"reports the average of the dependent variable over 2009--2011 in each column's estimation sample; "
    r"observations and establishments are those of the Post regression. Specifications are identical to "
    r"the main tables: establishment fixed effects and year fixed effects interacted with three-digit "
    r"industry, microregion, and negotiation-month indicators and with quartile bins of pre-treatment "
    r"firm size, per-worker flows, and the outcome, all bins and the connectivity normalization built on "
    r"the untrimmed sample. Standard errors clustered at the establishment level in parentheses. "
    r"*** p$<$0.01, ** p$<$0.05, * p$<$0.10."
)


def direct_table(data):
    n = len(VARIANTS)
    lines = _table_open("Direct Effects on Log Hourly Wages under Tail Trimming of Firm Size",
                        "tab:trim_sides_direct")
    for title, sec in ((r"\textbf{Panel A:} Treated vs.\ Zero-Connectivity Untreated", "direct_A"),
                       (r"\textbf{Panel B:} Treated vs.\ All Untreated", "direct_C")):
        lines += [r"\midrule", rf"\multicolumn{{{n + 1}}}{{l}}{{{title}}} \\", r"\addlinespace"]
        lines += _panel_rows(data, sec, "Treatment")
    lines += [r"\midrule",
              rf"\multicolumn{{{n + 1}}}{{l}}{{Test: Panel A = Panel B}} \\",
              r"\addlinespace",
              # the stacked regression estimates diff = beta_B - beta_A; report A - B
              r"Difference (A $-$ B) & "
              + " & ".join(fmt_num(-get(data, v, "AvsC", "diff")) for v in VARIANTS) + r"\\",
              " & " + " & ".join(f"({fmt_num(get(data, v, 'AvsC', 'diff_se'))})" for v in VARIANTS) + r"\\",
              r"$p$-value & "
              + " & ".join(f"[{get(data, v, 'AvsC', 'diff_p'):.3f}]" for v in VARIANTS) + r"\\"]
    notes = (
        r"\textit{Notes:} This table reports difference-in-differences estimates of the reform's direct "
        r"effects on log hourly wages after trimming the tails of the firm-size distribution. Panel~A "
        r"compares directly treated with zero-connectivity untreated establishments, and Panel~B with all "
        r"untreated establishments; in column (1) they reproduce Panels~A and B of "
        r"Table~\ref{tab:direct_connectivity_robust}. The last panel reports the difference between the "
        r"Post $\times$ Treatment coefficients of Panels~A and B (A $-$ B), with its standard error, and the "
        r"$p$-value of the test that the two coefficients are equal. Because the "
        r"zero-connectivity controls are a subset of all untreated establishments, the two coefficients are "
        r"estimated on overlapping samples; the test stacks the two samples, each with its own fixed "
        r"effects, interacts Post $\times$ Treatment with a sample indicator, and clusters standard errors "
        r"by establishment across both copies; the difference and its standard error come from the same "
        r"regression. In column (1) it reproduces the equality $p$-value reported "
        r"in Table~\ref{tab:direct_connectivity_robust}. " + COMMON_EST_NOTES
    )
    return "\n".join(lines + table_close(notes)) + "\n"


def spill_table(data):
    lines = _table_open("Spillover Effects on Log Hourly Wages under Tail Trimming of Firm Size",
                        "tab:trim_sides_spill")
    lines.append(r"\midrule")
    lines += _panel_rows(data, "spill", "Connectivity", placebo_rule=True)
    notes = (
        r"\textit{Notes:} This table reports difference-in-differences estimates of the reform's spillover "
        r"effects on the log hourly wages of untreated establishments after trimming the tails of the "
        r"firm-size distribution; in column (1) they reproduce Table~\ref{tab:spill_main_4tf_out}. "
        r"Connectivity is per-worker worker flows to treated establishments (2007--2011), scaled so that 1 "
        r"is the 90th percentile among untreated establishments in 2009 (untrimmed sample). "
        + COMMON_EST_NOTES
    )
    return "\n".join(lines + table_close(notes)) + "\n"


# ── Event-study wrappers ──────────────────────────────────────────────────────

def es_wrapper(sec, pvals):
    name = dict((s, n) for s, n, _ in SECTIONS)[sec]
    pv = [f"untrimmed: {pvals[('base', sec)]:.3f}"]
    for side, _ in SIDES:
        pv += [f"{side} {q}\\%: {pvals[(side + q, sec)]:.3f}" for q in ("5", "10")]
    if sec == "spill":
        what = (r"spillover effects on log hourly wages, $\gamma_t$ from Connectivity $\times$ year "
                r"interactions with 2011 omitted (untreated establishments)")
        ref = r"Table~\ref{tab:spill_main_4tf_out}"
    else:
        ctrl = ("zero-connectivity untreated" if sec == "direct_A" else "all untreated")
        panel = "A" if sec == "direct_A" else "B"
        what = (r"direct effects on log hourly wages, $\beta_t$ from Treatment $\times$ year interactions "
                rf"with 2011 omitted (directly treated vs.\ {ctrl} establishments)")
        ref = rf"Panel~{panel} of Table~\ref{{tab:direct_connectivity_robust}}"
    notes = (
        r"\textit{Notes:} This figure plots dynamic difference-in-differences estimates of the reform's "
        + what + r". Each panel overlays the untrimmed main specification (hollow markers; " + ref
        + r") and the samples trimmed at 5\% and 10\% of the pooled pre-treatment size distribution in the "
        r"left tail (a), the right tail (b), or both tails (c) (Table~\ref{tab:trim_sides_groups}); the 20\% "
        r"trims are reported in the tables only. Within "
        r"each year the series are offset horizontally for legibility. Specifications are otherwise "
        r"identical to the main tables. Joint pre-trend $F$-test $p$-values (2009 and 2010 coefficients "
        r"equal to zero): " + ", ".join(pv) + r". Bars are $95\%$ confidence intervals from standard errors "
        r"clustered at the establishment level."
    )
    lines = [
        r"\begin{figure}[H]",
        r"\centering",
        rf"\caption{{{name}: Log Hourly Wages by Year under Tail Trimming}}",
        rf"\label{{fig:es_trim_sides_{sec}}}",
    ]
    for i, (side, subcap) in enumerate(SIDES):
        lines += [
            r"\begin{subfigure}[t]{0.32\textwidth}",
            r"\centering",
            rf"\caption{{{subcap}}}",
            rf"\label{{fig:es_tsd_{sec}_{side}}}",
            rf"\includegraphics[width=\textwidth]{{{FIG_PREFIX}es_trim_sides_{sec}_{side}.pdf}}",
            r"\end{subfigure}",
        ]
        if i < len(SIDES) - 1:
            lines.append(r"\hfill")
    lines += ["", r"\begin{minipage}{\linewidth}", r"\scriptsize\vspace{4pt}", notes,
              r"\end{minipage}", r"\end{figure}"]
    return "\n".join(lines) + "\n"


# ── Summary and check ─────────────────────────────────────────────────────────

def write_summary(data, pvals, path):
    fields = ["section", "variant", "coef", "se", "pval", "pre", "pre_se", "pre_p", "pre_trend_F_p",
              "mean_pre", "n_obs", "n_estab", "diff_vs_base", "pct_change_vs_base", "diff_in_base_se"]
    with open(path, "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=fields)
        w.writeheader()
        for sec, _, _ in SECTIONS:
            b0, se0 = get(data, "base", sec, "main"), get(data, "base", sec, "main_se")
            for v in VARIANTS:
                b = get(data, v, sec, "main")
                w.writerow({
                    "section": sec, "variant": v, "coef": b, "se": get(data, v, sec, "main_se"),
                    "pval": get(data, v, sec, "main_p"), "pre": get(data, v, sec, "pre"),
                    "pre_se": get(data, v, sec, "pre_se"), "pre_p": get(data, v, sec, "pre_p"),
                    "pre_trend_F_p": pvals[(v, sec)], "mean_pre": get(data, v, sec, "mean_pre"),
                    "n_obs": int(get(data, v, sec, "n_obs")), "n_estab": int(get(data, v, sec, "n_estab")),
                    "diff_vs_base": b - b0, "pct_change_vs_base": 100 * (b - b0) / b0,
                    "diff_in_base_se": (b - b0) / se0,
                })
    print(f"Wrote {path}")


def check_vs_3222(data, out_path):
    """both5/10/20 equal 3222's trim_5/10/20: compare as written (4 decimals)."""
    lines = [f"both5/both10/both20 vs 3222 trim_5/trim_10/trim_20 ({REF_3222.relative_to(PROJECT)}), {OUTCOME}", ""]
    if not REF_3222.exists():
        lines.append("Reference file not found: check skipped.")
    else:
        ref = {}
        with open(REF_3222) as fh:
            next(fh)
            for line in fh:
                parts = line.strip().replace('"', "").split(";")
                if len(parts) >= 5:
                    ref[tuple(parts[:4])] = parts[4].strip().rstrip("*").replace(",", "")
        ok = True
        for v, t in (("both5", "trim_5"), ("both10", "trim_10"), ("both20", "trim_20")):
            for sec in ("direct_A", "spill"):
                for row, fmt in (("main", ".4f"), ("main_se", ".4f"), ("pre", ".4f"), ("pre_se", ".4f"),
                                 ("pre_pval", ".4f"), ("n_obs", ".0f"), ("n_estab", ".0f")):
                    mine = format(get(data, v, sec, row), fmt)
                    theirs = ref.get((t, sec, OUTCOME, row))
                    if theirs is not None and fmt == ".4f":
                        theirs = format(float(theirs), fmt)
                    match = mine == theirs
                    ok &= match
                    lines.append(f"  {'ok  ' if match else 'DIFF'} {v:7s} {sec:9s} {row:9s} {mine:>10s} {str(theirs):>10s}")
        lines += ["", "RESULT: PASS" if ok else "RESULT: FAIL"]
    out_path.write_text("\n".join(lines) + "\n")
    print(lines[-1])


# ── Preview ───────────────────────────────────────────────────────────────────

PREVIEW_DOC = r"""\documentclass[12pt]{article}
\usepackage[margin=0.9in]{geometry}
\usepackage{graphicx,booktabs,float,caption,subcaption,amsmath,amssymb}
\captionsetup{font=small,labelfont=bf}
% Preview only: stub the references that live in Draft.tex.
\expandafter\def\csname r@tab:direct_connectivity_robust\endcsname{{2}{}}
\expandafter\def\csname r@tab:spill_main_4tf_out\endcsname{{4}{}}
\begin{document}
\input{t_trim_sides_groups.tex}
\input{t_trim_sides_direct.tex}
\input{t_trim_sides_spill.tex}
\clearpage
\input{f_es_trim_sides_direct_A.tex}
\input{f_es_trim_sides_direct_C.tex}
\input{f_es_trim_sides_spill.tex}
\end{document}
"""


def compile_preview(tables_dir, graphs_dir):
    engine = shutil.which("pdflatex") or shutil.which("tectonic")
    if engine is None:
        print("No pdflatex or tectonic on PATH: preview skipped.")
        return
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        for f in ("t_trim_sides_groups.tex", "t_trim_sides_direct.tex", "t_trim_sides_spill.tex"):
            shutil.copy(tables_dir / f, tmp / f)
        figdir = tmp / FIG_PREFIX
        figdir.mkdir(parents=True)
        for sec, _, _ in SECTIONS:
            shutil.copy(graphs_dir / f"f_es_trim_sides_{sec}.tex", tmp)
            for side, _ in SIDES:
                src = graphs_dir / f"es_trim_sides_{sec}_{side}.pdf"
                if not src.exists():
                    raise SystemExit(f"Missing figure {src} (drawn by 3242_trim_sides.do).")
                shutil.copy(src, figdir)
        (tmp / "preview.tex").write_text(PREVIEW_DOC)
        args = ([engine, "preview.tex"] if engine.endswith("tectonic")
                else [engine, "-interaction=nonstopmode", "-halt-on-error", "preview.tex"])
        for _ in range(1 if engine.endswith("tectonic") else 2):
            res = subprocess.run(args, cwd=tmp, capture_output=True, text=True)
            if res.returncode != 0:
                print(res.stdout[-3000:], res.stderr[-3000:])
                raise SystemExit("LaTeX failed; see output above.")
        out = tables_dir / "trim_sides_preview.pdf"
        shutil.copy(tmp / "preview.pdf", out)
    print(f"Wrote {out}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("tables_dir", nargs="?", default=str(PROJECT / "Tables" / "trim_sides"))
    ap.add_argument("graphs_dir", nargs="?", default=str(PROJECT / "Graphs" / "trim_sides"))
    ap.add_argument("--preview", action="store_true",
                    help="also compile a standalone PDF with both tables and the three figures")
    a = ap.parse_args()
    tables_dir, graphs_dir = Path(a.tables_dir), Path(a.graphs_dir)

    data = load_results(tables_dir / "trim_sides.csv")
    groups = load_groups(tables_dir / "trim_sides_groups.csv")
    pvals = load_es_pvals(tables_dir / "trim_sides_es.csv")

    (tables_dir / "t_trim_sides_groups.tex").write_text(groups_table(groups))
    (tables_dir / "t_trim_sides_direct.tex").write_text(direct_table(data))
    (tables_dir / "t_trim_sides_spill.tex").write_text(spill_table(data))
    print(f"Wrote {tables_dir / 't_trim_sides_groups.tex'}, t_trim_sides_direct.tex, t_trim_sides_spill.tex")
    for sec, _, _ in SECTIONS:
        out = graphs_dir / f"f_es_trim_sides_{sec}.tex"
        out.write_text(es_wrapper(sec, pvals))
        print(f"Wrote {out}")
    write_summary(data, pvals, tables_dir / "trim_sides_summary.csv")
    check_vs_3222(data, tables_dir / "check_vs_3222.txt")
    if a.preview:
        compile_preview(tables_dir, graphs_dir)


if __name__ == "__main__":
    main()
