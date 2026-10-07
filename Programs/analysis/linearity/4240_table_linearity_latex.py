#!/usr/bin/env python3
"""
4240_table_linearity_latex.py
===================================
Builder for the linearity-test exhibit of the spillover DiD: one column per
outcome, rows = p-value, sup-t statistic, number of bins, establishments,
observations.

Input (comma-delimited, one row per outcome):
    default (--source vintage): the TWFE columns of
        Tables/linearity/linearity_fd.csv   (3172 via 3171, vintage overlay panel)
    --source rebuilt:
        Tables/linearity/linearity_did_twfe_diag.csv   (3142 via 3141, rebuilt panel)

Output:
    Tables/linearity/t_linearity.tex            table fragment for the paper
    Tables/linearity/t_linearity_preview.pdf    standalone compile (--preview), plus a .png copy

Usage
-----
    python 4240_table_linearity_latex.py              # fragment only
    python 4240_table_linearity_latex.py --preview    # fragment + PDF preview
    python 4240_table_linearity_latex.py --source rebuilt --preview

The fragment follows 4020_table_spill.py: [H] float, \\toprule\\toprule,
two-line column headers, a (1)..(4) row, and minipage notes.
"""

import argparse
import csv
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[3]
# Source of the TWFE results. 'vintage' (default): the TWFE test in 3172, run on
# the July 2026 overlay panel behind the published spillover table.
# 'rebuilt': 3142, run on the Sep-14 panel rebuilt from raw RAIS.
# Each maps the table's fields to that CSV's column names.
SOURCES = {
    "vintage": dict(
        csv=PROJECT / "Tables" / "linearity" / "linearity_fd.csv",
        runner="3171_linearity_fd.do",
        fields=dict(pval="twfe_pval", stat="twfe_stat", nbins="twfe_nbins",
                    estab="twfe_nclust", obs="twfe_n", status="twfe_status")),
    "rebuilt": dict(
        csv=PROJECT / "Tables" / "linearity" / "linearity_did_twfe_diag.csv",
        runner="3141_linearity_twfe.do",
        fields=dict(pval="pval", stat="stat_supt", nbins="nbins_formed",
                    estab="nclust_binstest", obs="n_binstest", status="status")),
}
SOURCE = SOURCES["vintage"]
CSV_IN = SOURCE["csv"]
OUT_DIR = PROJECT / "Tables" / "linearity"
OUT_TEX = OUT_DIR / "t_linearity.tex"
OUT_PDF = OUT_DIR / "t_linearity_preview.pdf"

# pdflatex is not on PATH until `module load texlive/2026`; this is where that
# module puts it. Override with the PDFLATEX environment variable.
PDFLATEX_DEFAULT = "/software/2025/texlive/2026/install-tl-20260312/bin/x86_64-linux/pdflatex"

# Column order and stub headers, matching 4020_table_spill.py.
COLUMNS = [
    ("lr_remdezr_w", r"Log \\ Wages"),
    ("lr_remdezr_h_w", r"Log Hourly \\ Wages"),
    ("l_firm_emp", r"Log \\ Employment"),
    ("numb_clauses", r"Clause \\ Count"),
]


def load_csv(path):
    """Read the diagnostic CSV into {outcome: row dict}."""
    if not path.exists():
        raise SystemExit(f"Missing input: {path}. Run {SOURCE['runner']} first.")
    with open(path, newline="") as fh:
        return {row["outcome"]: row for row in csv.DictReader(fh)}


def get(data, outcome, field):
    """field is a table field (pval, stat, nbins, estab, obs), mapped to the
    source CSV's column name."""
    field = SOURCE["fields"].get(field, field)
    try:
        val = data[outcome][field].strip()
    except KeyError:
        raise SystemExit(
            f"Missing '{field}' for outcome '{outcome}' in {CSV_IN.name}. "
            f"Re-run {SOURCE['runner']}."
        )
    if val in ("", "."):
        raise SystemExit(
            f"'{field}' is missing for '{outcome}' (status "
            f"'{data[outcome].get(SOURCE['fields']['status'], '?')}'): the test did not return a result."
        )
    return val


def fmt_dec(raw, digits=3):
    val = float(raw)
    return ("$-$" if val < 0 else "") + f"{abs(val):.{digits}f}"


def fmt_count(raw):
    """33367 -> 33{,}367 so the comma keeps its spacing in math-free text."""
    return f"{int(float(raw)):,}".replace(",", "{,}")


def build_notes():
    # Wording agreed with the authors (2026-10-05, slope-test revision 2026-10-06).
    return (
        r"    \textit{Notes:} This table reports the test of "
        r"\citet{Cattaneo2024} of whether the spillover effect is linear in "
        r"connectivity. The test examines whether the first derivative of the "
        r"effect with respect to connectivity is constant: it "
        r"compares the slope of a binned estimate of the effect of Post "
        r"$\times$ Connectivity with the slope of its linear fit in the "
        r"spillover specification (equation (\ref{eq:spill_spec})). The null "
        r"hypothesis is that the slope is constant, so that the effect is "
        r"linear, and the statistic is the supremum over the support of the "
        r"absolute $t$-statistic of the difference, with $p$-values from "
        r"2{,}000 simulations. The number of bins is chosen with the optimal "
        r"bin selection procedure the authors propose. The regression absorbs "
        r"establishment fixed effects and year fixed effects interacted with "
        r"three-digit industry, microregion, and negotiation-month indicators "
        r"and with quartile bins of pre-treatment firm size, per-worker flows, "
        r"and the outcome. Standard errors are clustered at the establishment "
        r"level."
    )


def build(data):
    outcomes = [o for o, _ in COLUMNS]
    header_cells = "".join(
        rf" & \begin{{tabular}}[c]{{@{{}}c@{{}}}}{label}\end{{tabular}}"
        for _, label in COLUMNS
    )
    col_nums = "".join(f" & ({i})" for i in range(1, len(COLUMNS) + 1))

    def row(label, field, fmt):
        return label + "".join(f" & {fmt(get(data, o, field))}" for o in outcomes) + r"\\"

    lines = [
        r"\begin{table}[H]",
        r"\centering",
        r"\caption{Linearity of the Spillover Effect in Connectivity}",
        r"\label{tab:linearity}",
        r"\footnotesize",
        r"\begin{tabular}{l" + "c" * len(COLUMNS) + "}",
        r"\toprule\toprule",
        header_cells + r"\\",
        col_nums + r"\\",
        r"\midrule",
        row(r"$p$-value", "pval", fmt_dec),
        row(r"Test statistic (sup $|T|$)", "stat", fmt_dec),
        row("Number of bins", "nbins", fmt_count),
        " & " * len(COLUMNS) + r"\\",
        row("Establishments", "estab", fmt_count),
        row("Observations", "obs", fmt_count),
        r"\bottomrule\bottomrule",
        r"\end{tabular}",
        "",
        r"\begin{minipage}{\linewidth}",
        r"\scriptsize\vspace{4pt}",
        build_notes(),
        r"\end{minipage}",
        r"\end{table}",
    ]
    return "\n".join(lines) + "\n"


PREVIEW_DOC = r"""\documentclass[12pt]{article}
\usepackage[margin=1in]{geometry}
\usepackage{booktabs,float,caption,amsmath,amssymb}
\captionsetup{font=small,labelfont=bf}
% Preview only: stub the citation and the equation reference that live in Draft.tex.
\newcommand{\citet}[1]{\csname cite@#1\endcsname}
\expandafter\def\csname cite@Cattaneo2024\endcsname{Cattaneo, Crump, Farrell and Feng (2024)}
\expandafter\def\csname cite@Cattaneo2025stata\endcsname{Cattaneo, Crump, Farrell and Feng (2025)}
\expandafter\def\csname r@eq:spill_spec\endcsname{{1}{}}
\pagestyle{empty}
\begin{document}
\input{t_linearity.tex}
\end{document}
"""


def compile_preview():
    pdflatex = os.environ.get("PDFLATEX") or shutil.which("pdflatex") or PDFLATEX_DEFAULT
    if not Path(pdflatex).exists() and not shutil.which(pdflatex):
        raise SystemExit(f"pdflatex not found ({pdflatex}); run `module load texlive/2026`.")
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        shutil.copy(OUT_TEX, tmp / "t_linearity.tex")
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

    # PNG copy (cropped to the table) so the preview opens in any editor
    # without a PDF viewer.
    import fitz  # PyMuPDF; there is no gs/pdftoppm on the cluster
    page = fitz.open(OUT_PDF)[0]
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
    ap.add_argument("--source", choices=sorted(SOURCES), default="vintage",
                    help="TWFE results from 3172 on the vintage overlay panel "
                         "(default) or from 3142 on the rebuilt panel")
    ap.add_argument("--preview", action="store_true",
                    help="also compile a standalone PDF preview of the table")
    args = ap.parse_args()

    global SOURCE, CSV_IN
    SOURCE = SOURCES[args.source]
    CSV_IN = SOURCE["csv"]
    data = load_csv(CSV_IN)
    body = build(data)

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    OUT_TEX.write_text(body)
    print(f"Wrote {OUT_TEX}")

    if args.preview:
        compile_preview()


if __name__ == "__main__":
    main()
