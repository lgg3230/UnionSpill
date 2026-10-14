"""
_pcc_fine_common.py
===================
Shared loaders, cutoff labels and the LaTeX preview step for the fine
pure-control cutoff exhibits (the figures themselves are drawn in Stata by
3165_figures_pure_control_cutoff_fine.do):
    4271_table_pure_control_cutoff_deciles_latex.py
    4281_figure_pure_control_cutoff_fine.py
    4282_figure_es_pure_control_cutoff.py

Inputs are written by 3162_pure_control_cutoff.do run through
3164_pure_control_cutoff_fine.do ($pcc_set = fine):
    Tables/pure_control_cutoff_fine/pure_control_cutoff.csv
    Tables/pure_control_cutoff_fine/pure_control_cutoff_cutoffs.csv
    Tables/pure_control_cutoff_fine/pure_control_cutoff_es.csv

Cutoff samples are p05 ... p95 (vingtiles of positive connectivity among
untreated establishments); the deciles are p10 ... p90. A cutoff whose raw
value equals an earlier one has `same_as` set in the cutoffs CSV and no
estimates of its own: it is shown once, with merged labels (e.g. "P5/P10").
"""

import csv
import math
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[3]
TAB_DIR = PROJECT / "Tables" / "pure_control_cutoff_fine"
GRAPH_DIR = PROJECT / "Graphs" / "pure_control_cutoff_fine"
CSV_IN = TAB_DIR / "pure_control_cutoff.csv"
CUTS_IN = TAB_DIR / "pure_control_cutoff_cutoffs.csv"
ES_IN = TAB_DIR / "pure_control_cutoff_es.csv"
FIG_PREFIX = "Replication/Figures/"

PDFLATEX_DEFAULT = "/software/2025/texlive/2026/install-tl-20260312/bin/x86_64-linux/pdflatex"

# (outcome, label); order as in tab:direct_connectivity_robust
OUTCOMES = [
    ("lr_remdezr_h_w", "Log Hourly Wages"),
    ("lr_remdezr_w", "Log Wages"),
    ("l_firm_emp", "Log Employment"),
    ("numb_clauses", "Clause Count"),
]
DECILES = [f"p{10 * k:02d}" for k in range(1, 10)]
VINGTILES = [f"p{5 * k:02d}" for k in range(1, 20)]
FIXED = ["zero", "fixed_001", "all"]


def _missing(path):
    raise SystemExit(f"Missing input: {path}. Run 3164_pure_control_cutoff_fine.do first.")


def load_results():
    """{(section, outcome, row_type): float} from 3162's long CSV."""
    if not CSV_IN.exists():
        _missing(CSV_IN)
    out = {}
    with open(CSV_IN, newline="") as fh:
        for r in csv.DictReader(fh):
            v = r["value"].strip()
            out[(r["section"], r["outcome"], r["row_type"])] = (
                math.nan if v in ("", ".") else float(v))
    return out


def load_cutoffs():
    """{sample: row dict} from 3162's cutoff file."""
    if not CUTS_IN.exists():
        _missing(CUTS_IN)
    with open(CUTS_IN, newline="") as fh:
        return {r["sample"]: r for r in csv.DictReader(fh)}


def load_es():
    """{(sample, outcome): {"years", "b", "se", "pre_pval", ...}} from 3162's event-study CSV."""
    if not ES_IN.exists():
        _missing(ES_IN)
    out = {}
    with open(ES_IN, newline="") as fh:
        for r in csv.DictReader(fh):
            d = out.setdefault((r["sample"], r["outcome"]),
                               {"years": [], "b": [], "se": []})
            d["years"].append(int(r["year"]))
            d["b"].append(float(r["b"]))
            d["se"].append(float(r["se"]))
            d["pre_pval"] = float(r["pre_pval"])
            d["n_obs"] = int(float(r["n_obs"]))
            d["n_estab"] = int(float(r["n_estab"]))
    return out


def rep(cuts, s):
    """The sample that carries s's estimates (s itself unless its cutoff is tied)."""
    return (cuts[s].get("same_as") or "").strip() or s


def cutoff_value(cuts, s):
    v = cuts[s]["cutoff_raw"].strip()
    return math.inf if v in ("", ".") else float(v)


def qlabel(s):
    """'p05' -> 'P5'."""
    return f"P{int(s[1:])}"


def points(cuts, quantiles):
    """Distinct samples to show, ordered by cutoff (All last).

    Returns [(sample, label, members)]: sample carries the estimates; label
    merges every quantile in `quantiles` that shares it (e.g. "P5/P10").
    """
    groups = {}
    for q in quantiles:
        groups.setdefault(rep(cuts, q), []).append(q)
    pts = [(s, s, [s]) for s in FIXED]
    pts += [(r, "/".join(qlabel(q) for q in members), members)
            for r, members in groups.items()]
    return sorted(pts, key=lambda p: cutoff_value(cuts, p[0]))


def fmt_count(val):
    return f"{int(float(val)):,}".replace(",", "{,}")


def compile_preview(tex_path, out_pdf, figures=(), crop=False):
    """Compile tex_path (a fragment) in a minimal preamble into out_pdf.

    `figures` are PDFs copied under FIG_PREFIX so the fragment's paper-style
    \\includegraphics paths resolve. Uses $PDFLATEX, pdflatex, or tectonic
    (the Mac has no pdflatex), whichever is found first. A PNG of the first
    page with content is written next to the PDF when PyMuPDF is available
    (cropped to the text for tables), else with macOS sips, else skipped.
    """
    doc = (
        "\\documentclass[12pt]{article}\n"
        "\\usepackage[margin=1in]{geometry}\n"
        "\\usepackage{graphicx,subcaption,caption,booktabs,float,amsmath,amssymb}\n"
        "\\captionsetup{font=small,labelfont=bf}\n"
        "% Preview only: stub the table reference that lives in Draft.tex.\n"
        "\\expandafter\\def\\csname r@tab:direct_connectivity_robust\\endcsname{{2}{}}\n"
        "\\pagestyle{empty}\n"
        "\\begin{document}\n"
        f"\\input{{{tex_path.name}}}\n"
        "\\end{document}\n"
    )
    engine = os.environ.get("PDFLATEX") or shutil.which("pdflatex")
    if not engine and Path(PDFLATEX_DEFAULT).exists():
        engine = PDFLATEX_DEFAULT
    tectonic = None if engine else shutil.which("tectonic")
    if not engine and not tectonic:
        raise SystemExit("Neither pdflatex nor tectonic found; skip --preview.")
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        if figures:
            figdir = tmp / FIG_PREFIX
            figdir.mkdir(parents=True)
            for src in figures:
                if not src.exists():
                    raise SystemExit(f"Missing {src}.")
                shutil.copy(src, figdir / src.name)
        shutil.copy(tex_path, tmp / tex_path.name)
        (tmp / "preview.tex").write_text(doc)
        cmd = ([engine, "-interaction=nonstopmode", "-halt-on-error", "preview.tex"]
               if engine else [tectonic, "--chatter", "minimal", "preview.tex"])
        res = subprocess.run(cmd, cwd=tmp, capture_output=True, text=True)
        if res.returncode != 0:
            print((res.stdout + res.stderr)[-3000:])
            raise SystemExit("LaTeX preview failed; see output above.")
        shutil.copy(tmp / "preview.pdf", out_pdf)
    print(f"Wrote {out_pdf}")

    out_png = out_pdf.with_suffix(".png")
    try:
        import fitz
    except ImportError:
        if shutil.which("sips"):
            subprocess.run(["sips", "-s", "format", "png", "-s", "dpiWidth", "200",
                            "-s", "dpiHeight", "200", str(out_pdf), "--out", str(out_png)],
                           capture_output=True)
            print(f"Wrote {out_png} (sips, uncropped)")
        return
    page = next(p for p in fitz.open(out_pdf) if p.get_text("blocks"))
    clip = None
    if crop:
        blocks = [b[:4] for b in page.get_text("blocks")]
        clip = fitz.Rect(min(b[0] for b in blocks) - 10, min(b[1] for b in blocks) - 10,
                         max(b[2] for b in blocks) + 10, max(b[3] for b in blocks) + 10)
    page.get_pixmap(dpi=200, clip=clip).save(out_png)
    print(f"Wrote {out_png}")
