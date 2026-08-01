#!/usr/bin/env python3
"""OPTIONAL: compile the six within-firm tables to PDF for visual inspection.

Not part of the estimation pipeline -- run_all.sh does not call it. It exists so you
can eyeball Tables 10, 11, 12, 22, 23 and 24 without pasting the fragments into the
paper. Each table is compiled on its own page, numbered as it is in
"Replication: Wages vs Hourly Wages", then cropped to its content.

Outputs -> output/preview/
    table10_group_descriptives.pdf      ... one file per table
    tables_within_firm_all.pdf          ... all six, one per page

Requires pdflatex (module load texlive/2026) and PyMuPDF for cropping. If PyMuPDF is
missing the PDFs are still produced, just uncropped.
"""

from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "output"
PREVIEW = OUTPUT / "preview"

# fragment stem -> (table number in the replication PDF, output slug)
TABLES = [
    ("t_layerdesc", 10, "table10_group_descriptives"),
    ("t_groupspecs", 11, "table11_group_spillover"),
    ("t_horserace", 12, "table12_horse_race"),
    ("t_layerdesc_hw", 22, "table22_group_descriptives_hourly"),
    ("t_groupspecs_hw", 23, "table23_group_spillover_hourly"),
    ("t_horserace_hw", 24, "table24_horse_race_hourly"),
]

# Text width matches a normal 8.5in page with 1in margins, so each table breaks exactly
# as it will in the paper -- in particular the horse-race notes sit BELOW the table,
# not beside it. The page is only made very tall to keep each table on one page.
PREAMBLE = r"""\documentclass[12pt]{article}
\usepackage[paperwidth=8.5in,paperheight=20in,margin=1in]{geometry}
\usepackage{booktabs,siunitx,makecell,float,amssymb,amsmath,caption}
\pagestyle{empty}
\begin{document}
"""


def build(tex_body: str, workdir: Path, name: str) -> Path | None:
    src = workdir / f"{name}.tex"
    src.write_text(PREAMBLE + tex_body + "\n\\end{document}\n")
    proc = subprocess.run(
        ["pdflatex", "-interaction=nonstopmode", "-halt-on-error", src.name],
        cwd=workdir, capture_output=True, text=True,
    )
    pdf = workdir / f"{name}.pdf"
    if proc.returncode != 0 or not pdf.exists():
        print(f"  ! pdflatex failed for {name}", file=sys.stderr)
        tail = [l for l in proc.stdout.splitlines() if l.startswith("!")][:5]
        for l in tail:
            print("   ", l, file=sys.stderr)
        return None
    return pdf


def crop(pdf: Path, dest: Path, pad: float = 8.0) -> None:
    """Crop every page to its content bounding box, then write to dest."""
    try:
        import fitz
    except ImportError:
        shutil.copy(pdf, dest)
        return
    doc = fitz.open(pdf)
    for page in doc:
        bbox = fitz.Rect()
        for block in page.get_text("blocks"):
            bbox |= fitz.Rect(block[:4])
        for d in page.get_drawings():
            bbox |= d["rect"]
        if not bbox.is_empty:
            bbox = fitz.Rect(bbox.x0 - pad, bbox.y0 - pad, bbox.x1 + pad, bbox.y1 + pad)
            page.set_cropbox(bbox & page.rect)
    doc.save(dest)
    doc.close()


def main() -> None:
    missing = [s for s, _, _ in TABLES if not (OUTPUT / f"{s}.tex").exists()]
    if missing:
        sys.exit(f"missing fragments in {OUTPUT}: {missing}\n"
                 "run 05b_make_tables_within_firm.py first")

    PREVIEW.mkdir(parents=True, exist_ok=True)
    combined = []

    with tempfile.TemporaryDirectory() as tmp:
        workdir = Path(tmp)
        for stem, number, slug in TABLES:
            body = (OUTPUT / f"{stem}.tex").read_text()
            numbered = f"\\setcounter{{table}}{{{number - 1}}}\n{body}"
            combined.append(numbered)
            pdf = build(numbered, workdir, slug)
            if pdf:
                crop(pdf, PREVIEW / f"{slug}.pdf")
                print(f"wrote {PREVIEW / f'{slug}.pdf'}")

        allpdf = build("\n\\clearpage\n".join(combined), workdir, "tables_within_firm_all")
        if allpdf:
            crop(allpdf, PREVIEW / "tables_within_firm_all.pdf")
            print(f"wrote {PREVIEW / 'tables_within_firm_all.pdf'}")


if __name__ == "__main__":
    main()
