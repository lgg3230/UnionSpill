#!/usr/bin/env python3
"""
4330_trim_top_size_latex.py
===========================
Tables and figure wrappers for the top-size trimming robustness check: main
direct effects (Panel A sample) and spillover effects re-estimated after
dropping the largest establishments within each group (directly treated,
zero-connectivity untreated, positive-connectivity untreated):

    base    no trimming (= published Panel A and spillover estimates)
    cap     drop firms above the largest zero-connectivity firm, all groups
    top5    drop firms above each group's own 95th size percentile
    top10   ... 90th
    top20   ... 80th

  Descriptive table (tab:trim_top_size_groups): one row per variant; for each
    group (column groups) the size cutoff, firms kept, share dropped, and the
    mean and median pre-period employment of the kept firms.
  Estimates table (tab:trim_top_size): 4270 layout, one row per variant, one
    column per outcome; Panels A-B Post x Treatment and its placebo (direct),
    Panels C-D Post x Connectivity and its placebo (spillover).
  Event-study wrappers (fig:es_trim_top_size_direct, _spill): 1x2 subfigures
    (log hourly wages, log wages) of the Stata panels; notes list each series'
    joint pre-trend F-test p-value.
  Summary CSV: every coefficient with its change relative to the baseline.

Input (written by 3232_trim_top_size.do via 3231_trim_top_size.do):
    Tables/trim_top_size/trim_top_size.csv
    Tables/trim_top_size/trim_top_size_groups.csv
    Tables/trim_top_size/trim_top_size_es.csv
    Graphs/trim_top_size/es_trim_top_size_<direct|spill>_<outcome>.pdf  (Stata)

Output:
    Tables/trim_top_size/t_trim_top_size_groups.tex     descriptive table fragment
    Tables/trim_top_size/t_trim_top_size.tex            estimates table fragment
    Tables/trim_top_size/trim_top_size_summary.csv      flat summary vs baseline
    Graphs/trim_top_size/f_es_trim_top_size_<direct|spill>.tex   figure wrappers
    Tables/trim_top_size/trim_top_size_preview.pdf      (--preview) all four exhibits

Fragments use paper-style paths (figures under Figures/TrimTopSize/) and refer
to Draft.tex labels; the preview stubs those labels.

Usage
-----
    python 4330_trim_top_size_latex.py [TABLES_DIR] [GRAPHS_DIR] [--preview]
"""

import argparse
import csv
import math
import shutil
import subprocess
import tempfile
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[3]
FIG_PREFIX = "Figures/TrimTopSize/"

VARIANTS = ["base", "cap", "top5", "top10", "top20"]
GROUPS = [("treated", "Directly treated"),
          ("zero", "Zero-connectivity untreated"),
          ("pos", "Positive-connectivity untreated")]
# Column order and headers as in tab:direct_connectivity_robust.
COLUMNS = [
    ("lr_remdezr_h_w", r"Log Hourly \\ Wages"),
    ("lr_remdezr_w", r"Log \\ Wages"),
    ("l_firm_emp", r"Log \\ Employment"),
    ("numb_clauses", r"Clause \\ Count"),
]
ES_PANELS = [("lr_remdezr_h_w", "Log Hourly Wages", "hw"),
             ("lr_remdezr_w", "Log Wages", "mw")]


# ── Inputs ────────────────────────────────────────────────────────────────────

def num(v):
    v = v.strip()
    return math.nan if v in ("", ".") else float(v)


def load_results(path):
    """{(variant, section, outcome, row_type): float}."""
    out = {}
    with open(path, newline="") as fh:
        for r in csv.DictReader(fh):
            out[(r["spec"], r["section"], r["outcome"], r["row_type"])] = num(r["value"])
    return out


def load_groups(path):
    """{(variant, group): row dict with floats}."""
    out = {}
    with open(path, newline="") as fh:
        for r in csv.DictReader(fh):
            out[(r["variant"], r["group"])] = {k: (num(v) if k not in ("variant", "group") else v)
                                               for k, v in r.items()}
    return out


def load_es_pvals(path):
    """{(variant, section, outcome): pre-trend F-test p-value}."""
    out = {}
    with open(path, newline="") as fh:
        for r in csv.DictReader(fh):
            out[(r["variant"], r["section"], r["outcome"])] = num(r["pre_pval"])
    return out


def get(data, v, sec, o, row):
    try:
        val = data[(v, sec, o, row)]
    except KeyError:
        raise SystemExit(f"Missing '{row}' for {sec} {o}, variant {v}.")
    if math.isnan(val):
        raise SystemExit(f"'{row}' is missing for {sec} {o}, variant {v}.")
    return val


# ── Formatting ────────────────────────────────────────────────────────────────

def stars(p):
    return "***" if p < 0.01 else "**" if p < 0.05 else "*" if p < 0.10 else ""


def fmt_num(val, digits=4):
    return ("$-$" if val < 0 else "") + f"{abs(val):.{digits}f}"


def fmt_count(val):
    return f"{int(round(val)):,}".replace(",", "{,}")


def cap_value(groups):
    return groups[("cap", "treated")]["cutoff"]


def variant_label(v, groups):
    return {
        "base": "Untrimmed (baseline)",
        "cap": f"Cap at {cap_value(groups):,.0f}".replace(",", "{,}"),
        "top5": r"Top 5\% trimmed",
        "top10": r"Top 10\% trimmed",
        "top20": r"Top 20\% trimmed",
    }[v]


def hdr(text):
    return r"\begin{tabular}[c]{@{}c@{}}" + text + r"\end{tabular}"


# ── Descriptive table ─────────────────────────────────────────────────────────

def groups_table(groups):
    ncols = 5 * len(GROUPS)
    lines = [
        r"\begin{table}[H]",
        r"\centering",
        r"\caption{Pre-Treatment Establishment Size by Group under Top-Size Trimming}",
        r"\label{tab:trim_top_size_groups}",
        r"\scriptsize",
        r"\setlength{\tabcolsep}{3pt}",
        r"\resizebox{\textwidth}{!}{%",
        r"\begin{tabular}{l" + "c" * ncols + "}",
        r"\toprule\toprule",
        " & " + " & ".join(rf"\multicolumn{{5}}{{c}}{{{name}}}" for _, name in GROUPS) + r"\\",
        " ".join(rf"\cmidrule(lr){{{2 + 5 * i}-{6 + 5 * i}}}" for i in range(len(GROUPS))),
        " & " + " & ".join([hdr(r"Cutoff"), hdr(r"Firms \\ kept"), hdr(r"\% \\ dropped"),
                            hdr(r"Mean"), hdr(r"Median")] * len(GROUPS)) + r"\\",
        " & " + " & ".join(f"({i})" for i in range(1, ncols + 1)) + r"\\",
        r"\midrule",
    ]
    for v in VARIANTS:
        cells = []
        for g, _ in GROUPS:
            r = groups[(v, g)]
            cut = "--" if math.isnan(r["cutoff"]) else f"{r['cutoff']:,.1f}".replace(",", "{,}")
            cells += [cut, fmt_count(r["n_kept"]), f"{100 * r['share_dropped']:.1f}",
                      f"{r['mean']:,.1f}".replace(",", "{,}"), f"{r['p50']:,.1f}".replace(",", "{,}")]
        lines.append(variant_label(v, groups) + " & " + " & ".join(cells) + r"\\")
    emp = "; ".join(
        f"{name.lower()}, "
        + ", ".join(f"{variant_label(v, groups).replace(' (baseline)', '').replace(' trimmed', '')} "
                    f"{100 * groups[(v, g)]['emp_share_dropped']:.1f}\\%"
                    for v in VARIANTS[1:])
        for g, name in GROUPS)
    notes = (
        r"\textit{Notes:} Establishment size is pre-treatment mean employment over 2009--2011, one "
        r"observation per establishment in the balanced Lagos sample. Each row is a separate estimation "
        r"sample. Untrimmed is the main specification's sample. Cap drops every establishment, in every "
        r"group, larger than the largest zero-connectivity untreated establishment ("
        + f"{cap_value(groups):,.1f}".replace(",", "{,}") +
        r" employees). Top $p$\% trimmed drops, within each group separately, the establishments above "
        r"the group's own $(100-p)$th size percentile; establishments exactly at a cutoff are kept. The "
        r"direct-effect sample combines the directly treated and zero-connectivity groups; the spillover "
        r"sample combines the zero- and positive-connectivity groups. Cutoffs are in employees; Mean and "
        r"Median describe the establishments kept. Share of each group's pre-treatment employment held by "
        r"the dropped establishments: " + emp + "."
    )
    lines += [
        r"\bottomrule\bottomrule",
        r"\end{tabular}}",
        "",
        r"\begin{minipage}{\linewidth}",
        r"\scriptsize\vspace{4pt}",
        notes,
        r"\end{minipage}",
        r"\end{table}",
    ]
    return "\n".join(lines) + "\n"


# ── Estimates table (4270 layout) ─────────────────────────────────────────────

def estimates_table(data, groups):
    outcomes = [o for o, _ in COLUMNS]
    ncol = len(COLUMNS) + 1
    header = (" & " + hdr(r"Estab.")
              + "".join(" & " + hdr(lab) for _, lab in COLUMNS))
    col_nums = " & " + "".join(f" & ({i})" for i in range(1, len(COLUMNS) + 1))
    lines = [
        r"\begin{table}[H]",
        r"\centering",
        r"\caption{Direct and Spillover Effects after Trimming the Largest Establishments}",
        r"\label{tab:trim_top_size}",
        r"\scriptsize",
        r"\begin{tabular}{lc" + "c" * len(COLUMNS) + "}",
        r"\toprule\toprule",
        header + r"\\",
        col_nums + r"\\",
    ]
    panels = [
        ("direct_A", r"Panel A: Direct effect, Post $\times$ Treatment", "main", "main_se", "main_p"),
        ("direct_A", r"Panel B: Direct effect, pre-trend (placebo)", "pre", "pre_se", "pre_p"),
        ("spill", r"Panel C: Spillover, Post $\times$ Connectivity", "main", "main_se", "main_p"),
        ("spill", r"Panel D: Spillover, pre-trend (placebo)", "pre", "pre_se", "pre_p"),
    ]
    members = {"direct_A": ("treated", "zero"), "spill": ("zero", "pos")}
    for sec, title, b_row, se_row, p_row in panels:
        lines += [r"\midrule",
                  rf"\multicolumn{{{ncol + 1}}}{{l}}{{\textit{{{title}}}}}\\",
                  r"\midrule"]
        for v in VARIANTS:
            n_firms = sum(groups[(v, g)]["n_kept"] for g in members[sec])
            lines.append(
                variant_label(v, groups) + f" & {fmt_count(n_firms)}"
                + "".join(f" & {fmt_num(get(data, v, sec, o, b_row))}{stars(get(data, v, sec, o, p_row))}"
                          for o in outcomes) + r"\\")
            lines.append(" & " + "".join(f" & ({fmt_num(get(data, v, sec, o, se_row))})"
                                         for o in outcomes) + r"\\")
    notes = (
        r"\textit{Notes:} This table reports difference-in-differences estimates of the reform's direct "
        r"effects (Panels A--B; directly treated vs.\ zero-connectivity untreated establishments) and "
        r"spillover effects (Panels C--D; untreated establishments, connectivity to the directly treated) "
        r"after dropping the largest establishments. Each row is a separate estimation sample; "
        r"Table~\ref{tab:trim_top_size_groups} describes the trimming. The untrimmed rows reproduce "
        r"Panel~A of Table~\ref{tab:direct_connectivity_robust} and Table~\ref{tab:spill_main_4tf_out}. "
        r"Estab.\ is the number of establishments in the estimation sample before singleton fixed effects "
        r"are dropped. Panels A and C report the average effect over 2012--2016; Panels B and D report the "
        r"coefficient from a placebo regression estimated on pre-treatment data only. Specifications are "
        r"identical to the main tables: establishment fixed effects and year fixed effects interacted with "
        r"three-digit industry, microregion, and negotiation-month indicators and with quartile bins of "
        r"pre-treatment firm size, per-worker flows, and the outcome, all bins and the connectivity "
        r"normalization built on the untrimmed sample; clause-count regressions substitute CBA-period "
        r"fixed effects for year fixed effects. Standard errors clustered at the establishment level in "
        r"parentheses. *** p$<$0.01, ** p$<$0.05, * p$<$0.10."
    )
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


# ── Event-study wrappers ──────────────────────────────────────────────────────

def es_wrapper(sec, pvals, groups):
    secname = "direct" if sec == "direct_A" else "spill"
    short = {"base": "untrimmed", "cap": f"cap {cap_value(groups):,.0f}",
             "top5": r"top 5\%", "top10": r"top 10\%", "top20": r"top 20\%"}
    pv = []
    for o, subcap, _ in ES_PANELS:
        pv.append(f"{subcap.lower()}, "
                  + ", ".join(f"{short[v]}: {pvals[(v, sec, o)]:.3f}" for v in VARIANTS))
    if sec == "direct_A":
        what = (r"direct effects on wages, $\beta_t$ from Treatment $\times$ year interactions with 2011 "
                r"omitted (directly treated vs.\ zero-connectivity untreated establishments)")
        ref = r"Panel~A of Table~\ref{tab:direct_connectivity_robust}"
        title = "Direct Wage Effects by Year after Trimming the Largest Establishments"
    else:
        what = (r"spillover effects on wages, $\gamma_t$ from Connectivity $\times$ year interactions with "
                r"2011 omitted (untreated establishments)")
        ref = r"Table~\ref{tab:spill_main_4tf_out}"
        title = "Spillover Wage Effects by Year after Trimming the Largest Establishments"
    notes = (
        r"\textit{Notes:} This figure plots dynamic difference-in-differences estimates of the reform's "
        + what + r". The hollow markers are the untrimmed main specification (" + ref + r"); the other "
        r"series drop the largest establishments: every establishment above the largest zero-connectivity "
        r"establishment (cap), or the top 5, 10, and 20\% of each group's own size distribution "
        r"(Table~\ref{tab:trim_top_size_groups}). Within each year the series are offset horizontally for "
        r"legibility. Specifications are otherwise identical to the main tables. Joint pre-trend $F$-test "
        r"$p$-values (2009 and 2010 coefficients equal to zero): " + "; ".join(pv) + ". "
        r"Bars are $95\%$ confidence intervals from standard errors clustered at the establishment level."
    )
    lines = [
        r"\begin{figure}[H]",
        r"\centering",
        rf"\caption{{{title}}}",
        rf"\label{{fig:es_trim_top_size_{secname}}}",
    ]
    for i, (o, subcap, lab) in enumerate(ES_PANELS):
        lines += [
            r"\begin{subfigure}[t]{0.49\textwidth}",
            r"\centering",
            rf"\caption{{{subcap}}}",
            rf"\label{{fig:es_tts_{secname}_{lab}}}",
            rf"\includegraphics[width=\textwidth]{{{FIG_PREFIX}es_trim_top_size_{secname}_{o}.pdf}}",
            r"\end{subfigure}",
        ]
        if i == 0:
            lines.append(r"\hfill")
    lines += ["", r"\begin{minipage}{\linewidth}", r"\scriptsize\vspace{4pt}", notes,
              r"\end{minipage}", r"\end{figure}"]
    return "\n".join(lines) + "\n"


# ── Summary ───────────────────────────────────────────────────────────────────

def write_summary(data, pvals, path):
    fields = ["section", "outcome", "variant", "coef", "se", "pval", "pre", "pre_se", "pre_p",
              "pre_trend_F_p", "mean_pre", "n_obs", "n_estab", "diff_vs_base", "pct_change_vs_base",
              "diff_in_base_se"]
    with open(path, "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=fields)
        w.writeheader()
        for sec in ("direct_A", "spill"):
            for o, _ in COLUMNS:
                b0 = get(data, "base", sec, o, "main")
                se0 = get(data, "base", sec, o, "main_se")
                for v in VARIANTS:
                    b = get(data, v, sec, o, "main")
                    w.writerow({
                        "section": sec, "outcome": o, "variant": v,
                        "coef": b, "se": get(data, v, sec, o, "main_se"),
                        "pval": get(data, v, sec, o, "main_p"),
                        "pre": get(data, v, sec, o, "pre"), "pre_se": get(data, v, sec, o, "pre_se"),
                        "pre_p": get(data, v, sec, o, "pre_p"),
                        "pre_trend_F_p": pvals[(v, sec, o)],
                        "mean_pre": get(data, v, sec, o, "mean_pre"),
                        "n_obs": int(get(data, v, sec, o, "n_obs")),
                        "n_estab": int(get(data, v, sec, o, "n_estab")),
                        "diff_vs_base": b - b0,
                        "pct_change_vs_base": 100 * (b - b0) / b0,
                        "diff_in_base_se": (b - b0) / se0,
                    })
    print(f"Wrote {path}")


# ── Preview ───────────────────────────────────────────────────────────────────

PREVIEW_DOC = r"""\documentclass[12pt]{article}
\usepackage[margin=0.9in]{geometry}
\usepackage{graphicx,booktabs,float,caption,subcaption,amsmath,amssymb}
\captionsetup{font=small,labelfont=bf}
% Preview only: stub the references that live in Draft.tex.
\expandafter\def\csname r@tab:direct_connectivity_robust\endcsname{{2}{}}
\expandafter\def\csname r@tab:spill_main_4tf_out\endcsname{{4}{}}
\begin{document}
\input{t_trim_top_size_groups.tex}
\input{t_trim_top_size.tex}
\clearpage
\input{f_es_trim_top_size_direct.tex}
\input{f_es_trim_top_size_spill.tex}
\end{document}
"""


def compile_preview(tables_dir, graphs_dir):
    engine = shutil.which("pdflatex") or shutil.which("tectonic")
    if engine is None:
        print("No pdflatex or tectonic on PATH: preview skipped.")
        return
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        for f in ("t_trim_top_size_groups.tex", "t_trim_top_size.tex"):
            shutil.copy(tables_dir / f, tmp / f)
        for sec in ("direct", "spill"):
            shutil.copy(graphs_dir / f"f_es_trim_top_size_{sec}.tex", tmp)
        figdir = tmp / FIG_PREFIX
        figdir.mkdir(parents=True)
        for sec in ("direct", "spill"):
            for o, _, _ in ES_PANELS:
                src = graphs_dir / f"es_trim_top_size_{sec}_{o}.pdf"
                if not src.exists():
                    raise SystemExit(f"Missing figure {src} (drawn by 3232_trim_top_size.do).")
                shutil.copy(src, figdir)
        (tmp / "preview.tex").write_text(PREVIEW_DOC)
        args = ([engine, "preview.tex"] if engine.endswith("tectonic")
                else [engine, "-interaction=nonstopmode", "-halt-on-error", "preview.tex"])
        for _ in range(1 if engine.endswith("tectonic") else 2):
            res = subprocess.run(args, cwd=tmp, capture_output=True, text=True)
            if res.returncode != 0:
                print(res.stdout[-3000:], res.stderr[-3000:])
                raise SystemExit("LaTeX failed; see output above.")
        out = tables_dir / "trim_top_size_preview.pdf"
        shutil.copy(tmp / "preview.pdf", out)
    print(f"Wrote {out}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("tables_dir", nargs="?", default=str(PROJECT / "Tables" / "trim_top_size"))
    ap.add_argument("graphs_dir", nargs="?", default=str(PROJECT / "Graphs" / "trim_top_size"))
    ap.add_argument("--preview", action="store_true",
                    help="also compile a standalone PDF with both tables and both figures")
    a = ap.parse_args()
    tables_dir, graphs_dir = Path(a.tables_dir), Path(a.graphs_dir)

    data = load_results(tables_dir / "trim_top_size.csv")
    groups = load_groups(tables_dir / "trim_top_size_groups.csv")
    pvals = load_es_pvals(tables_dir / "trim_top_size_es.csv")

    (tables_dir / "t_trim_top_size_groups.tex").write_text(groups_table(groups))
    (tables_dir / "t_trim_top_size.tex").write_text(estimates_table(data, groups))
    print(f"Wrote {tables_dir / 't_trim_top_size_groups.tex'} and t_trim_top_size.tex")
    for sec in ("direct_A", "spill"):
        secname = "direct" if sec == "direct_A" else "spill"
        out = graphs_dir / f"f_es_trim_top_size_{secname}.tex"
        out.write_text(es_wrapper(sec, pvals, groups))
        print(f"Wrote {out}")
    write_summary(data, pvals, tables_dir / "trim_top_size_summary.csv")
    if a.preview:
        compile_preview(tables_dir, graphs_dir)


if __name__ == "__main__":
    main()
