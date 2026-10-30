#!/usr/bin/env python3
"""
4320_figure_joint_spec_es.py
============================
Event studies of the paper's main specification and of the joint specification
(direct effect and connectivity in one regression) on the same axes, one figure
per outcome and effect. Direct and spillover coefficients are never mixed:

  es_direct_<outcome>.pdf   main direct effect (direct_A, zero-connectivity
                            controls) vs joint-spec Post x Treatment (joint_direct)
  es_spill_<outcome>.pdf    main spillover (spill, untreated only) vs joint-spec
                            Post x Connectivity (joint_spill)

Base period 2011 (plotted at zero, no interval); for the number of clauses the
time axis is CBA periods and the base is the 2010-2012 agreement. Bars are 95%
confidence intervals (1.96 x clustered SE). The two series are offset
horizontally and differ in colour, marker and interval line style, so they stay
distinguishable in grayscale. The legend gives each series' pooled Post
coefficient (SE) and its pre-trend F-test p-value.

No title: the panels are meant for subfigures whose captions name the outcome.
Fonts and size follow 4280_figure_pure_control_cutoff.py.

Input (written by 3212_joint_spec.do via 3211_joint_spec.do):
    Tables/joint_spec/joint_spec_es_coefs.csv
    Tables/joint_spec/results_joint_spec.csv

Output:
    Graphs/joint_spec/es_{direct,spill}_<outcome>.pdf   (+ .png copy)
    Graphs/joint_spec/joint_spec_es_figure.tex          standalone preview
    Graphs/joint_spec/joint_spec_es_figure.pdf          with --preview

Usage
-----
    python 4320_figure_joint_spec_es.py [TABLES_DIR] [GRAPHS_DIR] [--preview]
"""

import argparse
import csv
import shutil
import subprocess
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.font_manager as fm
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D

PROJECT = Path(__file__).resolve().parents[3]
FONT_DIR = PROJECT / "Programs" / "fonts"

OUTCOMES = ["lr_remdezr_h_w", "lr_remdezr_w", "l_firm_emp", "numb_clauses"]
OUTCOME_LABEL = {
    "lr_remdezr_h_w": "Log hourly wages",
    "lr_remdezr_w": "Log wages",
    "l_firm_emp": "Log employment",
    "numb_clauses": "Number of clauses",
}
CBA_LABEL = {1: "2009", 2: "2010–12", 3: "2013", 4: "2014", 5: "2015", 6: "2016"}

# effect -> (main section, joint section, main legend name, joint legend name)
EFFECTS = {
    "direct": ("direct_A", "joint_direct",
               "Main specification (zero-connectivity controls)",
               "Joint specification (Post × Treatment)"),
    "spill": ("spill", "joint_spill",
              "Main specification (untreated establishments)",
              "Joint specification (Post × Connectivity)"),
}

BLUE = "#2166AC"
RED = "#B2182B"
OFFSET = 0.12
Z95 = 1.96

for fp in FONT_DIR.glob("*.ttf"):
    fm.fontManager.addfont(str(fp))
plt.rcParams["font.family"] = "Libertinus Serif"
plt.rcParams["pdf.fonttype"] = 42
plt.rcParams["font.size"] = 10


# ── Inputs ────────────────────────────────────────────────────────────────────

def load_es(path):
    """{(section, outcome): [(period, is_base, b, se), ...]} sorted by period."""
    es = {}
    with open(path, newline="") as fh:
        for r in csv.DictReader(fh):
            es.setdefault((r["section"], r["outcome"]), []).append(
                (int(r["period"]), r["base"].strip() == "1", float(r["b"]), float(r["se"])))
    return {k: sorted(v) for k, v in es.items()}


def load_results(path):
    """{(section, outcome, row_type): raw value string} from the project CSV."""
    res = {}
    with open(path) as fh:
        next(fh)
        for line in fh:
            parts = line.strip().replace('"', "").split(";")
            if len(parts) >= 5:
                _, sec, out, rt, val = parts[:5]
                res[(sec, out, rt)] = val.strip()
    return res


def legend_stats(res, sec, outcome):
    b = res.get((sec, outcome, "main"), "--")
    se = res.get((sec, outcome, "main_se"), "--")
    p = res.get((sec, outcome, "pre_pval"), "")
    p = f"{float(p):.2f}" if p else "--"
    b = b.replace("-", "−")
    return f"Post: {b} ({se}); pre-trend p = {p}"


# ── Figure ────────────────────────────────────────────────────────────────────

def draw_series(ax, rows, dx, color, marker, filled, linestyle):
    xs = [i + dx for i in range(len(rows))]
    for x, (_, is_base, b, se) in zip(xs, rows):
        if not is_base and se > 0:
            line = ax.errorbar(x, b, yerr=Z95 * se, fmt="none", ecolor=color,
                               elinewidth=1.1, capsize=2.5, capthick=1.1, zorder=2)
            line[2][0].set_linestyle(linestyle)
    ax.plot(xs, [r[2] for r in rows], linestyle="none", marker=marker, markersize=5.5,
            markerfacecolor=color if filled else "white", markeredgecolor=color,
            markeredgewidth=1.3, zorder=3)


def make_figure(es, res, effect, outcome, out_dir):
    sec_main, sec_joint, name_main, name_joint = EFFECTS[effect]
    main_rows = es.get((sec_main, outcome))
    joint_rows = es.get((sec_joint, outcome))
    if not main_rows or not joint_rows:
        print(f"  WARNING: missing coefficients for {effect} {outcome}; figure skipped")
        return None
    periods = [r[0] for r in main_rows]
    if periods != [r[0] for r in joint_rows]:
        raise SystemExit(f"Period mismatch between {sec_main} and {sec_joint} for {outcome}")

    cba = outcome == "numb_clauses"
    labels = [CBA_LABEL[p] for p in periods] if cba else [str(p) for p in periods]
    base_idx = next(i for i, r in enumerate(main_rows) if r[1])

    fig, ax = plt.subplots(figsize=(4.6, 3.6))
    ax.axhline(0, color="0.55", linewidth=0.8, zorder=1)
    ax.axvline(base_idx + 0.5, color="0.55", linewidth=0.8, linestyle="--", zorder=1)
    draw_series(ax, main_rows, -OFFSET, BLUE, "o", True, "-")
    draw_series(ax, joint_rows, OFFSET, RED, "s", False, "--")

    ax.set_xticks(range(len(periods)))
    ax.set_xticklabels(labels, fontsize=8.5)
    ax.set_xlim(-0.5, len(periods) - 0.5)
    ax.tick_params(axis="y", labelsize=8.5)
    ax.set_ylabel("Event-study coefficient", fontsize=9.5)
    ax.set_xlabel("CBA period" if cba else "Year", fontsize=9.5)
    for side in ("top", "right"):
        ax.spines[side].set_visible(False)

    handles = [
        Line2D([], [], color=BLUE, marker="o", markerfacecolor=BLUE, linestyle="-",
               markersize=5.5, label=f"{name_main}\n{legend_stats(res, sec_main, outcome)}"),
        Line2D([], [], color=RED, marker="s", markerfacecolor="white", linestyle="--",
               markersize=5.5, label=f"{name_joint}\n{legend_stats(res, sec_joint, outcome)}"),
    ]
    ax.legend(handles=handles, loc="upper center", bbox_to_anchor=(0.5, -0.2), ncol=1,
              frameon=False, fontsize=7.5, handlelength=2.6, labelspacing=0.7)

    fig.tight_layout()
    stem = out_dir / f"es_{effect}_{outcome}"
    fig.savefig(stem.with_suffix(".pdf"), bbox_inches="tight")
    fig.savefig(stem.with_suffix(".png"), dpi=200, bbox_inches="tight")
    plt.close(fig)
    return stem.with_suffix(".pdf").name


# ── Standalone preview ────────────────────────────────────────────────────────

FIG_NOTES = {
    "direct": (
        r"Event-study estimates of the direct effect of the 2012 ultractivity reform. Filled "
        r"circles: the paper's main specification, which compares treated establishments with "
        r"untreated establishments with zero connectivity to treated establishments. Hollow "
        r"squares: the coefficient on Treatment $\times$ period from the joint specification, "
        r"which adds Connectivity $\times$ period to the same regression and is estimated on "
        r"treated and all untreated establishments, with connectivity set to zero for treated "
        r"establishments."
    ),
    "spill": (
        r"Event-study estimates of the spillover effect of the 2012 ultractivity reform. Filled "
        r"circles: the paper's main specification, estimated on untreated establishments only. "
        r"Hollow squares: the coefficient on Connectivity $\times$ period from the joint "
        r"specification, which adds Treatment $\times$ period to the same regression and is "
        r"estimated on treated and all untreated establishments, with connectivity set to zero "
        r"for treated establishments. Connectivity is normalized so that 1 is the 90th "
        r"percentile among untreated establishments in 2009."
    ),
}
COMMON_FIG_NOTE = (
    r" The base year is 2011; for the number of clauses, time is measured in CBA periods and "
    r"the base is the 2010--2012 agreement. Vertical bars are 95\% confidence intervals based on "
    r"standard errors clustered at the establishment level. The legend reports each series' "
    r"pooled Post coefficient (standard error) and the $p$-value of the joint pre-trend "
    r"$F$-test. All regressions include the fixed effects and controls of the main specification."
)
FIG_CAPTION = {
    "direct": "Direct Effects: Main and Joint Specifications",
    "spill": "Spillover Effects: Main and Joint Specifications",
}


def write_preview(files, out_dir):
    lines = [
        r"% Event studies: main vs joint specification. Panels from",
        r"% Programs/analysis/joint_spec/4320_figure_joint_spec_es.py.",
        r"% Standalone preview: compile in this folder (e.g. tectonic joint_spec_es_figure.tex).",
        r"\documentclass[11pt]{article}",
        r"\usepackage[left=0.75in,right=0.75in,top=0.6in,bottom=0.6in]{geometry}",
        r"\usepackage{lmodern}",
        r"\usepackage[T1]{fontenc}",
        r"\usepackage{amsmath}",
        r"\usepackage{graphicx, subcaption}",
        r"\usepackage[flushleft]{threeparttable}",
        r"\usepackage{caption}",
        r"\captionsetup{font=small, labelfont=bf, justification=justified}",
        r"\pagestyle{empty}",
        r"\begin{document}",
        "",
    ]
    for effect in ("direct", "spill"):
        lines += [
            r"\begin{figure}[!htbp]",
            r"\centering",
            rf"\caption{{{FIG_CAPTION[effect]}}}",
            rf"\label{{fig:joint_spec_{effect}}}",
            r"\begin{threeparttable}",
        ]
        for k, outcome in enumerate(OUTCOMES):
            f = files.get((effect, outcome))
            if f is None:
                continue
            lines += [
                r"    \begin{subfigure}[t]{0.48\textwidth}",
                r"        \centering",
                rf"        \caption{{{OUTCOME_LABEL[outcome]}}}",
                rf"        \includegraphics[width=\textwidth]{{{f}}}",
                r"    \end{subfigure}",
                r"    \hfill" if k % 2 == 0 else r"    \vspace{0.6em}",
                "",
            ]
        lines += [
            r"    \begin{tablenotes}[flushleft]",
            r"        \scriptsize",
            r"        \item \textit{Notes:} " + FIG_NOTES[effect] + COMMON_FIG_NOTE,
            r"    \end{tablenotes}",
            r"\end{threeparttable}",
            r"\end{figure}",
            r"\clearpage",
            "",
        ]
    lines.append(r"\end{document}")
    path = out_dir / "joint_spec_es_figure.tex"
    path.write_text("\n".join(lines) + "\n")
    return path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("tables_dir", nargs="?", default=str(PROJECT / "Tables" / "joint_spec"))
    ap.add_argument("graphs_dir", nargs="?", default=str(PROJECT / "Graphs" / "joint_spec"))
    ap.add_argument("--preview", action="store_true", help="compile the standalone PDF")
    args = ap.parse_args()

    tables, graphs = Path(args.tables_dir), Path(args.graphs_dir)
    graphs.mkdir(parents=True, exist_ok=True)
    for p in (tables / "joint_spec_es_coefs.csv", tables / "results_joint_spec.csv"):
        if not p.exists():
            raise SystemExit(f"Missing input: {p}. Run 3211_joint_spec.do first.")
    es = load_es(tables / "joint_spec_es_coefs.csv")
    res = load_results(tables / "results_joint_spec.csv")

    files = {}
    for effect in EFFECTS:
        for outcome in OUTCOMES:
            f = make_figure(es, res, effect, outcome, graphs)
            if f:
                files[(effect, outcome)] = f
                print(f"Wrote {graphs / f}")

    prev = write_preview(files, graphs)
    print(f"Wrote {prev}")
    if args.preview:
        engine = shutil.which("tectonic") or shutil.which("pdflatex")
        if engine is None:
            print("  No tectonic or pdflatex on PATH; preview .tex written but not compiled.")
            return
        cmd = [engine, prev.name] if engine.endswith("tectonic") else \
              [engine, "-interaction=nonstopmode", prev.name]
        subprocess.run(cmd, cwd=graphs, check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print(f"Wrote {prev.with_suffix('.pdf')}")


if __name__ == "__main__":
    main()
