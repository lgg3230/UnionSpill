#!/usr/bin/env python3
"""
4270_table_pure_control_cutoff_latex.py
=======================================
Builder for the pure-control cutoff robustness exhibit: the direct effect
(Post x Treatment) re-estimated as the pure-control group is widened from zero
connectivity to untreated establishments with connectivity <= c. One column per
outcome (same order as tab:direct_connectivity_robust), one row per cutoff,
ordered by c. Panel A: Post x Treatment. Panel B: pre-trend placebo.

Also writes a flat summary with the change relative to the zero-connectivity
baseline (level and %) for every outcome x cutoff.

Input (written by 3162_pure_control_cutoff.do via 3161_pure_control_cutoff.do):
    Tables/pure_control_cutoff/pure_control_cutoff.csv
    Tables/pure_control_cutoff/pure_control_cutoff_cutoffs.csv

Output:
    Tables/pure_control_cutoff/t_pure_control_cutoff.tex          table fragment
    Tables/pure_control_cutoff/pure_control_cutoff_summary.csv    flat summary
    Tables/pure_control_cutoff/t_pure_control_cutoff_preview.pdf  (--preview), plus .png

Usage
-----
    python 4270_table_pure_control_cutoff_latex.py
    python 4270_table_pure_control_cutoff_latex.py --preview

Layout follows 4250_table_linearity_bins_latex.py: [H] float, \\toprule\\toprule,
two-line column headers, a (1)..(4) row, minipage notes.
"""

import argparse
import csv
import math
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[3]
OUT_DIR = PROJECT / "Tables" / "pure_control_cutoff"
CSV_IN = OUT_DIR / "pure_control_cutoff.csv"
CUTS_IN = OUT_DIR / "pure_control_cutoff_cutoffs.csv"
OUT_TEX = OUT_DIR / "t_pure_control_cutoff.tex"
OUT_SUMMARY = OUT_DIR / "pure_control_cutoff_summary.csv"
OUT_PDF = OUT_DIR / "t_pure_control_cutoff_preview.pdf"

PDFLATEX_DEFAULT = "/software/2025/texlive/2026/install-tl-20260312/bin/x86_64-linux/pdflatex"

# Column order and headers as in tab:direct_connectivity_robust.
COLUMNS = [
    ("lr_remdezr_h_w", r"Log Hourly \\ Wages"),
    ("lr_remdezr_w", r"Log Monthly \\ Wages"),
    ("l_firm_emp", r"Log \\ Employment"),
    ("numb_clauses", r"Clause \\ Count"),
]

# Sample label -> quantile name (None for the fixed / unrestricted samples).
QUANTILE = {"q1_4": "P25", "t1_3": "P33", "q2_4": "P50", "t2_3": "P67",
            "q3_4": "P75", "p80": "P80", "p90": "P90"}
BASELINE = "zero"


def load_results(path):
    """{(section, outcome, row_type): float} from 3162's long CSV."""
    if not path.exists():
        raise SystemExit(f"Missing input: {path}. Run 3161_pure_control_cutoff.do first.")
    out = {}
    with open(path, newline="") as fh:
        for r in csv.DictReader(fh):
            v = r["value"].strip()
            out[(r["section"], r["outcome"], r["row_type"])] = (
                math.nan if v in ("", ".") else float(v))
    return out


def load_cutoffs(path):
    """{sample: row dict} from 3162's cutoff file."""
    if not path.exists():
        raise SystemExit(f"Missing input: {path}. Run 3161_pure_control_cutoff.do first.")
    with open(path, newline="") as fh:
        return {r["sample"]: r for r in csv.DictReader(fh)}


def get(data, s, outcome, row):
    try:
        val = data[(s, outcome, row)]
    except KeyError:
        raise SystemExit(f"Missing '{row}' for {outcome}, sample {s} in {CSV_IN.name}.")
    if math.isnan(val):
        raise SystemExit(f"'{row}' is missing for {outcome}, sample {s}.")
    return val


def ordered_samples(cuts):
    """Samples sorted by cutoff value; the unrestricted sample last."""
    def key(s):
        v = cuts[s]["cutoff_raw"].strip()
        return math.inf if v in ("", ".") else float(v)
    return sorted(cuts, key=key)


def row_label(s, cuts):
    if s == "zero":
        return r"$c = 0$ (baseline)"
    if s == "all":
        return r"No cutoff (all untreated)"
    c = float(cuts[s]["cutoff_raw"])
    if s in QUANTILE:
        return rf"$c = {c:.4f}$ ({QUANTILE[s]})"
    pct = 100 * float(cuts[s]["share_positive_le"])
    return rf"$c = {c:.2f}$ (P{pct:.0f})"


def stars(p):
    return "***" if p < 0.01 else "**" if p < 0.05 else "*" if p < 0.10 else ""


def fmt_num(val, digits=4):
    return ("$-$" if val < 0 else "") + f"{abs(val):.{digits}f}"


def fmt_count(val):
    return f"{int(val):,}".replace(",", "{,}")


NOTES = (
    r"    \textit{Notes:} This table reports difference-in-differences "
    r"estimates of the reform's direct effects when the comparison group "
    r"consists of all untreated establishments whose connectivity to the "
    r"directly treated is at most $c$, in raw (unnormalized) units; $c = 0$ "
    r"is the zero-connectivity comparison group of the main specification. "
    r"Each row is a separate set of regressions; the directly "
    r"treated establishments are the same in every row. Cutoffs P25--P90 are "
    r"percentiles of connectivity among the @@NPOS@@ untreated establishments "
    r"with positive connectivity (of @@NPOOL@@ untreated in the balanced "
    r"panel), so each row adds the next-least-connected establishments to the "
    r"comparison group; $c = 0.01$ is the fixed cutoff used in earlier "
    r"versions, which falls at the @@P001@@th percentile. Untreated estab.\ is "
    r"the number of untreated establishments meeting the cutoff before "
    r"singleton fixed effects are dropped. The first row reproduces Panel A "
    r"and the last row Panel B of Table \ref{tab:direct_connectivity_robust}. "
    r"Panel A reports Post $\times$ Treatment, the average effect over "
    r"2012--2016; Panel B reports the coefficient from a placebo regression "
    r"estimated on pre-treatment data only. Specifications are identical to "
    r"Table \ref{tab:direct_connectivity_robust}: establishment fixed effects "
    r"and year fixed effects interacted with three-digit industry, "
    r"microregion, and negotiation-month indicators and with quartile bins of "
    r"pre-treatment firm size, per-worker flows, and the outcome; clause-count "
    r"regressions substitute CBA-period fixed effects for year fixed effects. "
    r"Standard errors clustered at the establishment level in parentheses. "
    r"*** p$<$0.01, ** p$<$0.05, * p$<$0.10."
)


def build(data, cuts):
    samples = ordered_samples(cuts)
    outcomes = [o for o, _ in COLUMNS]
    ncol = len(COLUMNS) + 1  # + untreated-establishment column
    header_cells = (
        r" & \begin{tabular}[c]{@{}c@{}}Untreated \\ Estab.\end{tabular}"
        + "".join(
            rf" & \begin{{tabular}}[c]{{@{{}}c@{{}}}}{label}\end{{tabular}}"
            for _, label in COLUMNS
        )
    )
    col_nums = " & " + "".join(f" & ({i})" for i in range(1, len(COLUMNS) + 1))

    lines = [
        r"\begin{table}[H]",
        r"\centering",
        r"\caption{Direct Effects by Comparison-Group Connectivity Cutoff}",
        r"\label{tab:pure_control_cutoff}",
        r"\scriptsize",
        r"\begin{tabular}{lc" + "c" * len(COLUMNS) + "}",
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
        for i, s in enumerate(samples):
            # No blank row between cutoffs: with ten cutoffs x two panels the
            # table only fits one page without them.
            n_ctrl = fmt_count(float(cuts[s]["n_ctrl_firms"]))
            lines.append(
                row_label(s, cuts) + f" & {n_ctrl}"
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
    notes = (NOTES
             .replace("@@NPOS@@", fmt_count(float(any_cut["n_positive_total"])))
             .replace("@@NPOOL@@", fmt_count(float(any_cut["n_untreated_total"])))
             .replace("@@P001@@", f"{p001:.0f}"))

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
    """One row per outcome x cutoff, with the change vs the zero baseline."""
    fields = ["outcome", "sample", "cutoff_raw", "share_positive_le",
              "n_ctrl_firms", "coef", "se", "pval", "pre", "pre_se", "pre_pval",
              "mean_pre", "n_obs", "n_estab", "n_estab_ctrl", "n_estab_treat",
              "diff_vs_zero", "pct_change_vs_zero"]
    with open(OUT_SUMMARY, "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=fields)
        w.writeheader()
        for o, _ in COLUMNS:
            b0 = get(data, BASELINE, o, "main")
            for s in ordered_samples(cuts):
                b = get(data, s, o, "main")
                w.writerow({
                    "outcome": o, "sample": s,
                    "cutoff_raw": cuts[s]["cutoff_raw"].strip(),
                    "share_positive_le": cuts[s]["share_positive_le"].strip(),
                    "n_ctrl_firms": cuts[s]["n_ctrl_firms"].strip(),
                    "coef": b, "se": get(data, s, o, "main_se"),
                    "pval": get(data, s, o, "main_p"),
                    "pre": get(data, s, o, "pre"), "pre_se": get(data, s, o, "pre_se"),
                    "pre_pval": get(data, s, o, "pre_p"),
                    "mean_pre": get(data, s, o, "mean_pre"),
                    "n_obs": int(get(data, s, o, "n_obs")),
                    "n_estab": int(get(data, s, o, "n_estab")),
                    "n_estab_ctrl": int(get(data, s, o, "n_estab_ctrl")),
                    "n_estab_treat": int(get(data, s, o, "n_estab_treat")),
                    "diff_vs_zero": b - b0,
                    "pct_change_vs_zero": 100 * (b - b0) / b0,
                })
    print(f"Wrote {OUT_SUMMARY}")


PREVIEW_DOC = r"""\documentclass[12pt]{article}
\usepackage[margin=1in]{geometry}
\usepackage{booktabs,float,caption,amsmath,amssymb}
\captionsetup{font=small,labelfont=bf}
% Preview only: stub the table reference that lives in Draft.tex.
\expandafter\def\csname r@tab:direct_connectivity_robust\endcsname{{2}{}}
\pagestyle{empty}
\begin{document}
\input{t_pure_control_cutoff.tex}
\end{document}
"""


def compile_preview():
    pdflatex = os.environ.get("PDFLATEX") or shutil.which("pdflatex") or PDFLATEX_DEFAULT
    if not Path(pdflatex).exists() and not shutil.which(pdflatex):
        raise SystemExit(f"pdflatex not found ({pdflatex}); run `module load texlive/2026`.")
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        shutil.copy(OUT_TEX, tmp / "t_pure_control_cutoff.tex")
        (tmp / "preview.tex").write_text(PREVIEW_DOC)
        res = subprocess.run(
            [pdflatex, "-interaction=nonstopmode", "-halt-on-error", "preview.tex"],
            cwd=tmp, capture_output=True, text=True,
        )
        if res.returncode != 0:
            print(res.stdout[-3000:])
            raise SystemExit("pdflatex failed; see output above.")
        shutil.copy(tmp / "preview.pdf", OUT_PDF)
    print(f"Wrote {OUT_PDF}")

    # PNG copy cropped to the table (PyMuPDF; no gs/pdftoppm on the cluster)
    # The [H] float can push the table past a blank first page, so crop the
    # first page that carries text.
    import fitz
    page = next(p for p in fitz.open(OUT_PDF) if p.get_text("blocks"))
    blocks = [b[:4] for b in page.get_text("blocks")]
    x0 = min(b[0] for b in blocks) - 10
    y0 = min(b[1] for b in blocks) - 10
    x1 = max(b[2] for b in blocks) + 10
    y1 = max(b[3] for b in blocks) + 10
    out_png = OUT_PDF.with_suffix(".png")
    page.get_pixmap(dpi=200, clip=fitz.Rect(x0, y0, x1, y1)).save(out_png)
    print(f"Wrote {out_png}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", action="store_true",
                    help="also compile a standalone PDF preview of the table")
    args = ap.parse_args()

    data = load_results(CSV_IN)
    cuts = load_cutoffs(CUTS_IN)

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    OUT_TEX.write_text(build(data, cuts))
    print(f"Wrote {OUT_TEX}")
    write_summary(data, cuts)

    if args.preview:
        compile_preview()


if __name__ == "__main__":
    main()
