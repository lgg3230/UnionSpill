#!/usr/bin/env python3
"""
4070_table_resid.py
====================================
Builders for the two "Effects on Residualized Wages" exhibits in
UnionSpill-paper/Replication/Replication_Wages vs Hourly.tex:

    Table 10  t_resid.tex     raw vs residualized log December wages
    Table 22  t_resid_hw.tex  raw vs residualized log hourly wages

Both are 4-column tables: direct effects (Panel A) in columns (1)-(2) and
spillover effects in columns (3)-(4), each pairing the raw wage against its
Mincer-residualized counterpart.

Inputs (semicolon-delimited, written by 3112_mincer.do):
    Tables/currentconn_full/residuals/results_direct_panelA_mincer{suffix}.csv
    Tables/currentconn_full/residuals/results_spill_mincer{suffix}.csv

Outputs:
    Tables/residuals/t_resid{suffix}.tex
    Tables/residuals/t_resid_hw{suffix}.tex

With --update-replication, the generated bodies are spliced into the
Replication .tex between the existing
    % BEGIN inlined t_resid.tex   ...   % END inlined t_resid.tex
markers, leaving the rest of the document untouched.

Usage
-----
    python 4070_table_resid.py \
        --suffix _currentconn_age_fullrais_rb --mode age --update-replication
"""

import argparse
import re
import shutil
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[3]
TABLES  = PROJECT / "Tables"
OUT_DIR = TABLES / "residuals"
REPL_TEX = (PROJECT / "UnionSpill-paper" / "Replication"
            / "Replication_Wages vs Hourly.tex")


# ── CSV parsing ──────────────────────────────────────────────────────────────

def load_csv(path):
    """Parse Stata postfile output. Header is comma-delimited, rows are
    semicolon-delimited, so the header is skipped rather than parsed."""
    data = {}
    if not path.exists():
        raise SystemExit(f"Missing input: {path}")
    with open(path) as f:
        next(f)
        for line in f:
            parts = [p.strip().strip('"') for p in line.strip().split(";")]
            if len(parts) < 5:
                continue
            data.setdefault(parts[2], {})[parts[3]] = parts[4].strip().strip('"')
    return data


# ── Cell formatting ──────────────────────────────────────────────────────────

def num(data, outcome, row):
    """Coefficient or pre-trend cell: LaTeX minus sign, stars preserved."""
    raw = data.get(outcome, {}).get(row, "").strip()
    if not raw:
        return ""
    return r"$-$" + raw[1:] if raw.startswith("-") else raw


def se(data, outcome, row):
    """Standard-error cell, wrapped in parentheses."""
    raw = data.get(outcome, {}).get(row, "").strip()
    return f"({raw})" if raw else ""


def count(data, outcome, row):
    """Integer count with LaTeX thousands separator."""
    raw = data.get(outcome, {}).get(row, "").strip()
    return raw.replace(",", "{,}")


# ── Notes ────────────────────────────────────────────────────────────────────

def notes(wage_label, mode):
    # The note describes the specification only. It does not explain what the
    # projection omits: readers see this table on its own, not against an
    # earlier draft.
    if mode == "agetenure":
        projection = r"on quartic age and establishment-tenure polynomials"
    else:
        projection = r"on a quartic age polynomial"

    return (
        r"\textit{Notes:} This table presents current-connectivity estimates "
        r"using raw and Mincer-residualized " + wage_label + r". "
        r"Columns~(1)--(2) report direct effects, comparing directly treated "
        r"establishments to untreated establishments with zero pre-reform "
        r"connectivity. Columns~(3)--(4) report spillover effects on the full "
        r"sample of untreated establishments. Worker-level residuals are "
        r"estimated on the full RAIS worker sample by projecting wages within "
        r"race $\times$ education $\times$ gender $\times$ year cells "
        + projection +
        r", then collapsing residuals to establishment-year means for "
        r"Lagos-sample establishments. "
        r"Post effects average 2012--2016, with 2011 as the reference year. "
        r"Pre-treatment mean is the mean of the dependent variable over "
        r"2009--2011 in the estimation sample of the corresponding column. "
        r"Standard errors clustered at the establishment level in parentheses. "
        r"*** p$<$0.01, ** p$<$0.05, * p$<$0.10."
    )


def mean2(d, o, key):
    """Pre-treatment mean: 4 decimals in the CSV, 2 in the table
    (decision 2026-08-01)."""
    raw = d.get(o, {}).get(key)
    if raw in (None, "", "--"):
        return "--"
    val = float(str(raw).strip())
    return ("$-$" if val < 0 else "") + f"{abs(val):.3f}"


# ── Table builder ────────────────────────────────────────────────────────────

def build_table(panel_a, spill, raw_outcome, resid_outcome,
                caption, header_raw, header_resid, wage_label, mode):
    cols = [(panel_a, raw_outcome), (panel_a, resid_outcome),
            (spill, raw_outcome),   (spill, resid_outcome)]

    def row(fn, key, which):
        """which: 'direct' -> cols 1-2 only, 'spill' -> cols 3-4 only,
        'all' -> every column."""
        out = []
        for i, (d, o) in enumerate(cols):
            if which == "direct" and i >= 2:
                out.append("")
            elif which == "spill" and i < 2:
                out.append("")
            else:
                out.append(fn(d, o, key))
        return out

    def line(label, cells, trail=r"\\"):
        return label + " & " + " & ".join(cells) + trail

    hdr_raw   = r"\begin{tabular}[c]{@{}c@{}}" + header_raw + r"\end{tabular}"
    hdr_resid = r"\begin{tabular}[c]{@{}c@{}}" + header_resid + r"\end{tabular}"

    L = [
        r"\begin{table}[H]",
        r"\centering",
        f"\\caption{{{caption}}}",
        r"\footnotesize",
        r"\begin{tabular}{lcccc}",
        r"\toprule\toprule",
        r" & \multicolumn{2}{c}{Direct Effects} & \multicolumn{2}{c}{Spillover Effects} \\",
        r" \cmidrule(lr){2-3} \cmidrule(lr){4-5}",
        " & " + " & ".join([hdr_raw, hdr_resid, hdr_raw, hdr_resid]) + r" \\",
        r" & (1) & (2) & (3) & (4) \\",
        r"\midrule",
        # Trailing whitespace before \\ comes from the " & " join when the last
        # cell is empty; do not add another space here or the output drifts
        # from the hand-written original.
        line(r"Post $\times$ Treatment", row(num, "main", "direct")),
        line("", row(se, "main_se", "direct")),
        line("", ["", "", "", ""]),
        line(r"Post $\times$ Connectivity", row(num, "main", "spill")),
        line("", row(se, "main_se", "spill")),
        line("", ["", "", "", ""]),
        line("Pre-treatment mean", row(mean2, "mean_pre", "all")),
        line("Observations", row(count, "n_obs", "all")),
        line("Establishments", row(count, "n_estab", "all")),
        r"\midrule",
        line("Pre-trend (placebo)", row(num, "pre", "all")),
        line("", row(se, "pre_se", "all")),
        r"\bottomrule\bottomrule",
        r"\end{tabular}",
        r"\begin{minipage}{\linewidth}",
        r"    \scriptsize\vspace{4pt}",
        notes(wage_label, mode),
        r"\end{minipage}",
        r"\end{table}",
    ]
    return "\n".join(L)


# ── Replication .tex splicing ────────────────────────────────────────────────

def splice(tex_path, marker, body):
    """Replace the content between the BEGIN/END markers for one table."""
    text = tex_path.read_text()
    begin = f"% BEGIN inlined {marker}"
    end   = f"% END inlined {marker}"
    pattern = re.compile(
        re.escape(begin) + r".*?" + re.escape(end), re.DOTALL)
    if not pattern.search(text):
        raise SystemExit(f"Markers for {marker} not found in {tex_path}")
    replacement = f"{begin}\n{body}\n{end}"
    tex_path.write_text(pattern.sub(lambda _: replacement, text, count=1))


# ── Main ─────────────────────────────────────────────────────────────────────

SPECS = [
    dict(marker="t_resid.tex", stem="t_resid",
         raw="lr_remdezr_w", resid="lr_remdezr_resid",
         caption="Effects on Residualized Wages",
         header_raw=r"Log\\ Wages",
         header_resid=r"Residualized\\ Log\\ Wages",
         wage_label="log December wages"),
    dict(marker="t_resid_hw.tex", stem="t_resid_hw",
         raw="lr_remdezr_h_w", resid="lr_hourly_resid",
         caption="Effects on Residualized Hourly Wages",
         header_raw=r"Log\\ Hourly\\ Wages",
         header_resid=r"Residualized\\ Log\\ Hourly\\ Wages",
         wage_label="log hourly wages"),
]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--suffix", default="_currentconn_age_fullrais_rb")
    ap.add_argument("--mode", choices=["age", "agetenure"], default="age",
                    help="Residualization spec, used to word the table notes.")
    ap.add_argument("--results-dir", default=None,
                    help="Defaults to Tables/currentconn_full/residuals for "
                         "_currentconn* suffixes, else Tables/residuals.")
    ap.add_argument("--update-replication", action="store_true",
                    help="Splice the tables into the Replication .tex.")
    args = ap.parse_args()

    if args.results_dir:
        rdir = Path(args.results_dir)
    elif args.suffix.startswith("_currentconn"):
        rdir = TABLES / "currentconn_full" / "residuals"
    else:
        rdir = TABLES / "residuals"

    panel_a = load_csv(rdir / f"results_direct_panelA_mincer{args.suffix}.csv")
    spill   = load_csv(rdir / f"results_spill_mincer{args.suffix}.csv")

    OUT_DIR.mkdir(parents=True, exist_ok=True)

    for spec in SPECS:
        body = build_table(
            panel_a, spill,
            raw_outcome=spec["raw"], resid_outcome=spec["resid"],
            caption=spec["caption"],
            header_raw=spec["header_raw"], header_resid=spec["header_resid"],
            wage_label=spec["wage_label"], mode=args.mode,
        )
        out = OUT_DIR / f"{spec['stem']}{args.suffix}.tex"
        out.write_text(body + "\n")
        print(f"Wrote {out}")

        if args.update_replication:
            if not REPL_TEX.exists():
                raise SystemExit(f"Replication .tex not found: {REPL_TEX}")
            backup = REPL_TEX.with_suffix(".tex.bak")
            if not backup.exists():
                shutil.copy2(REPL_TEX, backup)
                print(f"  backup -> {backup.name}")
            splice(REPL_TEX, spec["marker"], body)
            print(f"  spliced {spec['marker']} into {REPL_TEX.name}")


if __name__ == "__main__":
    main()
