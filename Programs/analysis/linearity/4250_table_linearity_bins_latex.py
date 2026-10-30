#!/usr/bin/env python3
"""
4250_table_linearity_bins_latex.py
===================================
Builder for the binned-connectivity spillover exhibit: one column per outcome,
one panel per breakdown of positive connectivity (A: median split, B: terciles,
C: quartiles), one row per connectivity group x Post. Zero-connectivity
establishments are the omitted baseline.

Input (comma-delimited, one row per outcome x breakdown x group, written by
3152_linearity_bins.do via 3151_linearity_bins.do):
    Tables/linearity/linearity_bins.csv
    Tables/linearity/linearity_bins_cutoffs.csv

Output:
    Tables/linearity/t_linearity_bins.tex            table fragment for the paper
    Tables/linearity/t_linearity_bins_preview.pdf    standalone compile (--preview), plus a .png copy

Usage
-----
    python 4250_table_linearity_bins_latex.py              # fragment only
    python 4250_table_linearity_bins_latex.py --preview    # fragment + PDF preview
    python 4250_table_linearity_bins_latex.py --baseline lt01 --preview
                                    # baseline = raw connectivity < 0.01 (3153);
                                    # outputs carry the suffix _lt01
    python 4250_table_linearity_bins_latex.py --baseline dec --only 10
                                    # deciles only, no panel letter
                                    # (t_linearity_bins_dec_k10.tex)
    python 4250_table_linearity_bins_latex.py --baseline dec --preview
                                    # zero baseline, quartiles + deciles (3154);
                                    # outputs carry the suffix _dec

Panels are built for the breakdowns present in the CSV, lettered in order. When
the CSV has p_equal (3152 since 2026-10-25), each panel reports the p-value of
the test that all group coefficients are equal.

Layout follows 4020_table_spill.py / 4240_table_linearity_latex.py: [H] float,
\\toprule\\toprule, two-line column headers, a (1)..(4) row, minipage notes.
"""

import argparse
import csv
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[3]
CSV_IN = PROJECT / "Tables" / "linearity" / "linearity_bins.csv"
CUTS_IN = PROJECT / "Tables" / "linearity" / "linearity_bins_cutoffs.csv"
OUT_DIR = PROJECT / "Tables" / "linearity"
OUT_TEX = OUT_DIR / "t_linearity_bins.tex"
OUT_PDF = OUT_DIR / "t_linearity_bins_preview.pdf"

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

# breakdown (number of groups) -> panel title, row labels for groups 1..k
# Baseline variants: which establishments form the omitted group. 'zero' is
# 3151's output (no suffix), 'lt01' is 3153's (raw connectivity < 0.01).
BASELINES = {
    "zero": dict(
        suffix="", base_lt=None, label="tab:linearity_bins",
        caption="Spillover Effects by Connectivity Group",
        grouped_title="positive connectivity",
        grouped_note="with positive connectivity"),
    "lt01": dict(
        suffix="_lt01", base_lt=0.01, label="tab:linearity_bins_lt01",
        caption="Spillover Effects by Connectivity Group: "
                "Baseline of Connectivity Below 0.01",
        grouped_title=r"connectivity $\geq$ 0.01",
        grouped_note="with raw connectivity of at least 0.01"),
    "dec": dict(
        suffix="_dec", base_lt=None, label="tab:linearity_bins_dec",
        caption="Spillover Effects by Connectivity Decile",
        grouped_title="positive connectivity",
        grouped_note="with positive connectivity"),
}

# breakdown -> (panel title without its letter, row labels, phrase for the notes)
PANEL_DEFS = {
    2: ("Median split of positive connectivity",
        ["Below median", "Above median"], "at the median"),
    3: ("Terciles of positive connectivity",
        ["Low tercile", "Medium tercile", "High tercile"], "at terciles"),
    4: ("Quartiles of positive connectivity",
        ["First quartile", "Second quartile", "Third quartile", "Fourth quartile"],
        "at quartiles"),
    10: ("Deciles of positive connectivity",
         [f"Decile {g}" for g in range(1, 11)], "at deciles"),
}


def panels_in(data):
    """[(k, 'Panel A. ...', labels, phrase), ...] for the breakdowns in the CSV."""
    ks = sorted({k for _, k, _ in data})
    unknown = [k for k in ks if k not in PANEL_DEFS]
    if unknown:
        raise SystemExit(f"No panel definition for breakdown(s) {unknown}.")
    if len(ks) == 1:  # a single panel carries no letter
        k = ks[0]
        return [(k, PANEL_DEFS[k][0], PANEL_DEFS[k][1], PANEL_DEFS[k][2])]
    return [(k, f"Panel {chr(65 + i)}. {PANEL_DEFS[k][0]}", PANEL_DEFS[k][1],
             PANEL_DEFS[k][2]) for i, k in enumerate(ks)]


def panel_ref(title, panels):
    """' (Panel A)' for lettered panels, '' for a single unlettered one."""
    return "" if len(panels) == 1 else f" ({title.split('.')[0]})"


def join_and(items):
    items = list(items)
    if len(items) == 1:
        return items[0]
    if len(items) == 2:
        return f"{items[0]} and {items[1]}"
    return ", ".join(items[:-1]) + f", and {items[-1]}"


def load_csv(path):
    """Read the CSV into {(outcome, breakdown, group): row dict}."""
    if not path.exists():
        raise SystemExit(f"Missing input: {path}. Run 3151_linearity_bins.do first.")
    with open(path, newline="") as fh:
        return {
            (r["outcome"], int(r["breakdown"]), int(r["group"])): r
            for r in csv.DictReader(fh)
        }


def get(data, outcome, k, g, field):
    try:
        val = data[(outcome, k, g)][field].strip()
    except KeyError:
        raise SystemExit(
            f"Missing '{field}' for {outcome}, {k} groups, group {g} in "
            f"{CSV_IN.name}. Re-run 3151_linearity_bins.do."
        )
    if val in ("", "."):
        raise SystemExit(f"'{field}' is missing for {outcome}, {k} groups, group {g}.")
    return val


def stars(p):
    p = float(p)
    return "***" if p < 0.01 else "**" if p < 0.05 else "*" if p < 0.10 else ""


def fmt_num(raw, digits=4):
    val = float(raw)
    return ("$-$" if val < 0 else "") + f"{abs(val):.{digits}f}"


def fmt_coef(raw, p):
    return fmt_num(raw) + stars(p)


def fmt_se(raw):
    return f"({fmt_num(raw)})"


def fmt_count(raw):
    """32495 -> 32{,}495 so the comma keeps its spacing in math-free text."""
    return f"{int(float(raw)):,}".replace(",", "{,}")


NOTES = (
    r"    \textit{Notes:} This table reports difference-in-differences "
    r"estimates of the reform's spillover effects in which the linear term "
    r"Post $\times$ Connectivity of equation (\ref{eq:spill_spec}) is replaced "
    r"by indicators for groups of connectivity interacted with Post. The "
    r"omitted group consists of untreated establishments @@BASE@@, so each "
    r"coefficient is the 2012--2016 effect for a group "
    r"relative to them. Groups split establishments @@GROUPED@@ "
    r"@@SPLITS@@. @@CUTOFFS@@@@PEQUAL@@All "
    r"specifications include establishment fixed effects and year fixed "
    r"effects interacted with three-digit industry, microregion, and "
    r"negotiation-month indicators and with quartile bins of pre-treatment "
    r"firm size, per-worker flows, and the outcome; clause-count regressions "
    r"substitute CBA-period fixed effects for year fixed effects. Standard "
    r"errors clustered at the establishment level in parentheses. "
    r"*** p$<$0.01, ** p$<$0.05, * p$<$0.10."
)


PEQUAL_NOTE = (
    r"The equal-group-effects row reports the $p$-value of a Wald test that all "
    r"group coefficients of an outcome are equal. "
)


def load_cutoffs(path):
    """{breakdown: [normalized cutoffs]} from 3152's xtile cutpoints."""
    if not path.exists():
        raise SystemExit(f"Missing input: {path}. Re-run 3151_linearity_bins.do.")
    cuts = {}
    with open(path, newline="") as fh:
        for r in csv.DictReader(fh):
            cuts.setdefault(int(r["breakdown"]), []).append(
                (int(r["cut"]), float(r["cutoff_norm"])))
    return {k: [v for _, v in sorted(c)] for k, c in cuts.items()}


def cutoffs_sentence(cuts, panels):
    parts = [f"{join_and(f'{v:.3f}' for v in cuts[k])}{panel_ref(title, panels)}"
             for k, title, _, _ in panels]
    if len(parts) > 1:
        parts[-1] = "and " + parts[-1]
    return (
        r"In units of normalized connectivity (1 equals the 90th percentile "
        r"among untreated establishments), the cutoffs are "
        + "; ".join(parts) + ". "
    )


def splits_phrase(panels):
    return join_and(f"{phrase}{panel_ref(title, panels)}"
                    for _, title, _, phrase in panels)


def means_sentence(data, panels):
    """Mean normalized connectivity by group (log hourly wage sample); single panel only."""
    if len(panels) != 1:
        return ""
    k = panels[0][0]
    vals = [f"{float(get(data, 'lr_remdezr_h_w', k, g, 'mean_conn')):.2f}"
            for g in range(1, k + 1)]
    return ("Mean normalized connectivity by group, from lowest to highest, is "
            + join_and(vals) + ". ")


def has_pequal(data):
    return all(r.get("p_equal", "").strip() not in ("", ".") for r in data.values())


def base_phrase(variant, cuts_raw):
    """'with zero connectivity', or the threshold in raw and normalized units.
    The p90 normalizer is recovered from any cutoff row (raw / normalized)."""
    if variant["base_lt"] is None:
        return "with zero connectivity"
    p90 = cuts_raw[0][0] / cuts_raw[0][1]
    t = variant["base_lt"]
    return (f"with raw connectivity below {t:g} ({t / p90:.3f} in normalized "
            f"units)")


def build(data, cuts, variant, cuts_raw):
    outcomes = [o for o, _ in COLUMNS]
    ncol = len(COLUMNS)
    header_cells = "".join(
        rf" & \begin{{tabular}}[c]{{@{{}}c@{{}}}}{label}\end{{tabular}}"
        for _, label in COLUMNS
    )
    col_nums = "".join(f" & ({i})" for i in range(1, ncol + 1))

    lines = [
        r"\begin{table}[H]",
        r"\centering",
        rf"\caption{{{variant['caption']}}}",
        rf"\label{{{variant['label']}}}",
        r"\footnotesize",
        r"\begin{tabular}{l" + "c" * ncol + "}",
        r"\toprule\toprule",
        header_cells + r"\\",
        col_nums + r"\\",
    ]

    panels = panels_in(data)
    pequal = has_pequal(data)
    for k, title, labels, _ in panels:
        title = title.replace("positive connectivity", variant["grouped_title"])
        lines += [r"\midrule", rf"\multicolumn{{{ncol + 1}}}{{l}}{{\textit{{{title}}}}}\\", r"\midrule"]
        for g, label in enumerate(labels, start=1):
            if g > 1:
                # blank row between coefficient/SE pairs, so each SE reads
                # with the coefficient above it
                lines.append(" & " * ncol + r"\\")
            lines.append(
                rf"Post $\times$ {label}"
                + "".join(
                    f" & {fmt_coef(get(data, o, k, g, 'coef'), get(data, o, k, g, 'pval'))}"
                    for o in outcomes
                )
                + r"\\"
            )
            lines.append(
                "".join(f" & {fmt_se(get(data, o, k, g, 'se'))}" for o in outcomes) + r"\\"
            )
        lines += [
            " & " * ncol + r"\\",
            "Observations"
            + "".join(f" & {fmt_count(get(data, o, k, 0, 'n_obs'))}" for o in outcomes)
            + r"\\",
            "Establishments"
            + "".join(f" & {fmt_count(get(data, o, k, 0, 'n_estab'))}" for o in outcomes)
            + r"\\",
        ]
        if pequal:
            lines.append(
                r"Equal group effects, $p$-value"
                + "".join(f" & {float(get(data, o, k, 0, 'p_equal')):.3f}" for o in outcomes)
                + r"\\"
            )

    lines += [
        r"\bottomrule\bottomrule",
        r"\end{tabular}",
        "",
        r"\begin{minipage}{\linewidth}",
        r"\scriptsize\vspace{4pt}",
        NOTES.replace("@@CUTOFFS@@", cutoffs_sentence(cuts, panels) + means_sentence(data, panels))
             .replace("@@SPLITS@@", splits_phrase(panels))
             .replace("@@PEQUAL@@", PEQUAL_NOTE if pequal else "")
             .replace("@@BASE@@", base_phrase(variant, cuts_raw))
             .replace("@@GROUPED@@", variant["grouped_note"]),
        r"\end{minipage}",
        r"\end{table}",
    ]
    return "\n".join(lines) + "\n"


PREVIEW_DOC = r"""\documentclass[12pt]{article}
\usepackage[margin=1in]{geometry}
\usepackage{booktabs,float,caption,amsmath,amssymb}
\captionsetup{font=small,labelfont=bf}
% Preview only: stub the equation reference that lives in Draft.tex.
\expandafter\def\csname r@eq:spill_spec\endcsname{{1}{}}
\pagestyle{empty}
\begin{document}
\input{t_linearity_bins.tex}
\end{document}
"""


def compile_preview():
    pdflatex = os.environ.get("PDFLATEX") or shutil.which("pdflatex") or PDFLATEX_DEFAULT
    if not Path(pdflatex).exists() and not shutil.which(pdflatex):
        raise SystemExit(f"pdflatex not found ({pdflatex}); run `module load texlive/2026`.")
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        shutil.copy(OUT_TEX, tmp / "t_linearity_bins.tex")
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
    ap.add_argument("--baseline", choices=sorted(BASELINES), default="zero",
                    help="zero connectivity (3151), raw connectivity < 0.01 "
                         "(3153), or zero connectivity with deciles (3154)")
    ap.add_argument("--only", type=int, metavar="K",
                    help="keep only the breakdown with K groups (e.g. 10); "
                         "the output name gains _k<K>")
    ap.add_argument("--preview", action="store_true",
                    help="also compile a standalone PDF preview of the table")
    args = ap.parse_args()

    global CSV_IN, CUTS_IN, OUT_TEX, OUT_PDF
    variant = BASELINES[args.baseline]
    sfx = variant["suffix"]
    CSV_IN = OUT_DIR / f"linearity_bins{sfx}.csv"
    CUTS_IN = OUT_DIR / f"linearity_bins_cutoffs{sfx}.csv"
    osfx = sfx + (f"_k{args.only}" if args.only else "")
    OUT_TEX = OUT_DIR / f"t_linearity_bins{osfx}.tex"
    OUT_PDF = OUT_DIR / f"t_linearity_bins{osfx}_preview.pdf"

    data = load_csv(CSV_IN)
    if args.only:
        data = {key: r for key, r in data.items() if key[1] == args.only}
        if not data:
            raise SystemExit(f"No breakdown with {args.only} groups in {CSV_IN.name}.")
    cuts = load_cutoffs(CUTS_IN)
    with open(CUTS_IN, newline="") as fh:
        cuts_raw = [(float(r["cutoff_raw"]), float(r["cutoff_norm"]))
                    for r in csv.DictReader(fh)]
    body = build(data, cuts, variant, cuts_raw)

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    OUT_TEX.write_text(body)
    print(f"Wrote {OUT_TEX}")

    if args.preview:
        compile_preview()


if __name__ == "__main__":
    main()
