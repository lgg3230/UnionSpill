#!/usr/bin/env python3
"""
4290_latex_figure_pure_control_cutoff.py
========================================
LaTeX wrapper that joins the four per-outcome figures from
4280_figure_pure_control_cutoff.py into one 2x2 figure, in the paper's
subfigure layout (Draft.tex fig:rob_logwages_recentered): caption on top,
\\begin{subfigure}[t]{0.49\\textwidth} panels separated by \\hfill, subcaptions
naming the outcome, \\scriptsize minipage notes below.

Graphics paths follow the paper convention (Replication/Figures/<name>.pdf), so
the fragment can be pasted into Draft.tex once the four PDFs are copied into
UnionSpill-paper/Replication/Figures/. The cutoff values quoted in the notes
are read from 3162's cutoff file, so they stay in sync with the estimates.

Input:
    Graphs/pure_control_cutoff/pure_control_cutoff_<outcome>.pdf   (4280)
    Tables/pure_control_cutoff/pure_control_cutoff_cutoffs.csv     (3162)

Output:
    Graphs/pure_control_cutoff/f_pure_control_cutoff.tex
    Graphs/pure_control_cutoff/f_pure_control_cutoff_preview.pdf   (--preview), plus .png

Usage
-----
    python 4290_latex_figure_pure_control_cutoff.py
    python 4290_latex_figure_pure_control_cutoff.py --preview
"""

import argparse
import csv
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[3]
GRAPH_DIR = PROJECT / "Graphs" / "pure_control_cutoff"
CUTS_IN = PROJECT / "Tables" / "pure_control_cutoff" / "pure_control_cutoff_cutoffs.csv"
OUT_TEX = GRAPH_DIR / "f_pure_control_cutoff.tex"
OUT_PDF = GRAPH_DIR / "f_pure_control_cutoff_preview.pdf"
FIG_PREFIX = "Replication/Figures/"

PDFLATEX_DEFAULT = "/software/2025/texlive/2026/install-tl-20260312/bin/x86_64-linux/pdflatex"

# (outcome, subcaption, label suffix); order as in tab:direct_connectivity_robust
PANELS = [
    ("lr_remdezr_h_w", "Log Hourly Wages", "hw"),
    ("lr_remdezr_w", "Log Monthly Wages", "mw"),
    ("l_firm_emp", "Log Employment", "emp"),
    ("numb_clauses", "Clause Count", "clauses"),
]
# Percentile cutoffs, in the order they are quoted in the notes.
QUANTILE = [("q1_4", "P25"), ("t1_3", "P33"), ("q2_4", "P50"), ("t2_3", "P67"),
            ("q3_4", "P75"), ("p80", "P80"), ("p90", "P90")]


def load_cutoffs():
    if not CUTS_IN.exists():
        raise SystemExit(f"Missing input: {CUTS_IN}. Run 3161_pure_control_cutoff.do first.")
    with open(CUTS_IN, newline="") as fh:
        return {r["sample"]: r for r in csv.DictReader(fh)}


def fmt_count(val):
    return f"{int(float(val)):,}".replace(",", "{,}")


def notes(cuts):
    vals = [f"{lab}~$=$~{float(cuts[s]['cutoff_raw']):.4f}" for s, lab in QUANTILE]
    vals = ", ".join(vals[:-1]) + f", and {vals[-1]}"
    any_row = next(iter(cuts.values()))
    p001 = 100 * float(cuts["fixed_001"]["share_positive_le"])
    return (
        r"\textit{Notes:} This figure plots difference-in-differences estimates "
        r"of the reform's direct effects (Post $\times$ Treatment, the average "
        r"effect over 2012--2016) when the comparison group consists of all "
        r"untreated establishments whose connectivity to the directly treated is "
        r"at most $c$, in raw (unnormalized) units. Each point is a separate "
        r"regression; the directly treated establishments are the same "
        r"throughout. Cutoffs labeled P25--P90 are percentiles of connectivity "
        rf"among the {fmt_count(any_row['n_positive_total'])} untreated "
        r"establishments with positive connectivity (of "
        rf"{fmt_count(any_row['n_untreated_total'])} untreated in the balanced "
        rf"panel): {vals}. The fixed cutoff $c = 0.01$ falls at the "
        rf"{p001:.0f}th percentile; All includes every untreated establishment. "
        r"The hollow marker and the dashed line mark the main specification "
        r"($c = 0$, Panel~A of Table~\ref{tab:direct_connectivity_robust}); "
        r"All reproduces its Panel~B. Specifications are otherwise identical to "
        r"Table~\ref{tab:direct_connectivity_robust}. Bars are $95\%$ confidence "
        r"intervals from standard errors clustered at the establishment level."
    )


def build(cuts):
    lines = [
        r"\begin{figure}[!tbp]",
        r"\centering",
        r"\caption{Direct Effects by Comparison-Group Connectivity Cutoff}",
        r"\label{fig:pure_control_cutoff}",
    ]
    for i, (outcome, subcap, lab) in enumerate(PANELS):
        lines += [
            r"\begin{subfigure}[t]{0.49\textwidth}",
            r"\centering",
            rf"\caption{{{subcap}}}",
            rf"\label{{fig:pcc_{lab}}}",
            rf"\includegraphics[width=\textwidth]{{{FIG_PREFIX}pure_control_cutoff_{outcome}.pdf}}",
            r"\end{subfigure}",
        ]
        if i % 2 == 0:
            lines.append(r"\hfill")
        elif i < len(PANELS) - 1:
            lines.append(r"\\[1em]")
    lines += [
        "",
        r"\begin{minipage}{\linewidth}",
        r"\scriptsize\vspace{4pt}",
        notes(cuts),
        r"\end{minipage}",
        r"\end{figure}",
    ]
    return "\n".join(lines) + "\n"


PREVIEW_DOC = r"""\documentclass[12pt]{article}
\usepackage[margin=1in]{geometry}
\usepackage{graphicx,subcaption,caption,amsmath,amssymb,float}
\captionsetup{font=small,labelfont=bf}
% Preview only: stub the table reference that lives in Draft.tex.
\expandafter\def\csname r@tab:direct_connectivity_robust\endcsname{{2}{}}
\pagestyle{empty}
\begin{document}
\input{f_pure_control_cutoff.tex}
\end{document}
"""


def compile_preview():
    pdflatex = os.environ.get("PDFLATEX") or shutil.which("pdflatex") or PDFLATEX_DEFAULT
    if not Path(pdflatex).exists() and not shutil.which(pdflatex):
        raise SystemExit(f"pdflatex not found ({pdflatex}); run `module load texlive/2026`.")
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        figdir = tmp / FIG_PREFIX
        figdir.mkdir(parents=True)
        for outcome, _, _ in PANELS:
            src = GRAPH_DIR / f"pure_control_cutoff_{outcome}.pdf"
            if not src.exists():
                raise SystemExit(f"Missing {src}. Run 4280_figure_pure_control_cutoff.py first.")
            shutil.copy(src, figdir / src.name)
        shutil.copy(OUT_TEX, tmp / OUT_TEX.name)
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

    # PNG of the first page with content (PyMuPDF; no gs/pdftoppm on the cluster)
    import fitz
    page = next(p for p in fitz.open(OUT_PDF) if p.get_text("blocks"))
    out_png = OUT_PDF.with_suffix(".png")
    page.get_pixmap(dpi=200).save(out_png)
    print(f"Wrote {out_png}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", action="store_true",
                    help="also compile a standalone PDF preview of the figure")
    args = ap.parse_args()

    GRAPH_DIR.mkdir(parents=True, exist_ok=True)
    OUT_TEX.write_text(build(load_cutoffs()))
    print(f"Wrote {OUT_TEX}")
    if args.preview:
        compile_preview()


if __name__ == "__main__":
    main()
