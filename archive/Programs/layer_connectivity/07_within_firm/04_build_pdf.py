#!/usr/bin/env python3
"""Build the six within-firm exhibits (A6/A7/A8, monthly + hourly) into one PDF.

    module load texlive/2026
    ~/.conda/envs/venv_python312/bin/python 04_build_pdf.py

Reads the canonical CSVs written by _run_within_firm_v2.do and
_run_within_firm_hw_v2.do, generates the LaTeX fragments via
5090_table_within_firm.py, and compiles them.

Self-contained: nothing outside Programs/layer_connectivity/07_within_firm/ is
imported or read. The page setup below is vendored from the coauthor's
within_firm_final/scripts/build_pdf.py so the output is visually identical to
tables_A6_A7_A8.pdf, but the dependency is gone.
"""
from __future__ import annotations

import importlib.util
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
TABLE_DIR = ROOT / "Tables" / "layer_connectivity" / "07_within_firm"
DEST = (ROOT / "quality_reports" / "replication" / "hourly_variant_currentconn"
        / "tables_A6_A7_A8.pdf")

TABLES = [
    ("t_layerdesc",     "Table A6 --- Group-Level Connectivity Descriptives (monthly wages)"),
    ("t_groupspecs",    "Table A7 --- Group-level spillover effects, revised specification (log monthly wages)"),
    ("t_horserace",     "Table A8 --- Group-Specific Connectivity and Firm-Level Outcomes (log monthly wages)"),
    ("t_layerdesc_hw",  "Table A6 --- Group-Level Connectivity Descriptives (hourly wages)"),
    ("t_groupspecs_hw", "Table A7 --- Group-level spillover effects, revised specification (log hourly wages)"),
    ("t_horserace_hw",  "Table A8 --- Group-Specific Connectivity and Firm-Level Outcomes (log hourly wages)"),
]

PREAMBLE = r"""\documentclass[11pt]{article}
\usepackage[paperwidth=8.5in,paperheight=14in,margin=0.7in]{geometry}
\usepackage{booktabs,siunitx,makecell,float,amssymb,amsmath,caption}
\usepackage[T1]{fontenc}
\usepackage{xcolor}
\captionsetup{labelformat=empty}
\pagestyle{plain}
\setlength{\parindent}{0pt}
\begin{document}

{\Large\bfseries Within-firm exhibits --- Tables A6, A7 and A8\par}
\vspace{6pt}

\textbf{Stata pipeline.} Estimated by
\texttt{01b\_within\_firm\_estimates}\allowbreak\texttt{\{,\_hw\}.do} in
\texttt{07\_within\_firm/}, from the canonical inputs under \texttt{Data/}.
LaTeX by \texttt{02b\_make\_tables\_all.py}, compiled by
\texttt{04\_build\_pdf.py}. Estimates are the CSVs in
\texttt{Tables/layer\_connectivity/07\_within\_firm/}; the pre-revision ones
are archived alongside them under \texttt{archive\_oldspec\_2026-07-31/}.

All 83 checks in \texttt{03\_verify\_v2.py} pass: Table A6, the printed rows of
Table A8, and the firm-level columns of Table A7 reproduce the pre-revision
estimates bit-for-bit, and the revised A7 group columns match the reference R
implementation at four-decimal print precision.

\textit{Table A7 revision.} Three controls are added to the two group-level
columns. See \texttt{SPEC.md} for the exact fixed-effect lists.
\begin{enumerate}\itemsep1pt
\item The year interactions are allowed to differ by worker group:
      group $\times$ industry $\times$ year, group $\times$ microregion
      $\times$ year, group $\times$ negotiation-month $\times$ year. The plain
      versions are then omitted, being nested inside these.
\item The three pre-treatment quartile bins are made group-specific. They are
      already computed per establishment $\times$ group; only their year path
      was shared.
\item The ``Overall'' column gains the firm-level pre-treatment wage,
      employment and flow bins $\times$ year, the same ones Table A7 column~(1)
      uses. ``Within firms'' absorbs them through establishment $\times$ year.
\end{enumerate}
Cost: 2.45\% to 3.52\% of observations, to singleton dropping in thin
group $\times$ microregion $\times$ year cells.

\textit{Unchanged.} Table A6, the firm-level columns of Table A7, and Table A8
are firm-level objects and are not affected.

\vspace{4pt}\hrule
\clearpage
"""


def main() -> int:
    if not shutil.which("pdflatex"):
        sys.exit("pdflatex not on PATH -- run: module load texlive/2026")

    # 1. fragments, straight from the canonical CSVs
    spec = importlib.util.spec_from_file_location(
        "make_tables_all", HERE / "5090_table_within_firm.py")
    mt = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mt)
    mt.build(TABLE_DIR, ["edu2", "gender", "ten2"])

    # 2. assemble
    body = []
    for stem, heading in TABLES:
        src = TABLE_DIR / f"{stem}.tex"
        if not src.exists():
            sys.exit(f"missing {src}")
        body.append(r"\section*{" + heading + "}")
        body.append(src.read_text())
        body.append(r"\clearpage")

    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp)
        tex = work / "tables.tex"
        tex.write_text(PREAMBLE + "\n".join(body) + "\n\\end{document}\n")
        for _ in range(2):
            proc = subprocess.run(
                ["pdflatex", "-interaction=nonstopmode", "-halt-on-error", tex.name],
                cwd=work, capture_output=True, text=True)
        pdf = work / "tables.pdf"
        if not pdf.exists():
            print("pdflatex failed:", file=sys.stderr)
            for line in proc.stdout.splitlines():
                if line.startswith("!"):
                    print("   ", line, file=sys.stderr)
            return 1
        DEST.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy(pdf, DEST)

    print(f"wrote {DEST}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
