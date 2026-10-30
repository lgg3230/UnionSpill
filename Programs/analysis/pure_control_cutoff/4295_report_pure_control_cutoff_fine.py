#!/usr/bin/env python3
"""
4295_report_pure_control_cutoff_fine.py
=======================================
Review PDF with every table and figure of the fine pure-control cutoff
analysis, behind a cover page that lists the exhibits, the results of the
three replication checks, and the code that produces each exhibit. The
exhibits are the LaTeX fragments the pipeline already writes, inlined as they
are, so the report shows exactly what would go into the paper.

Input (all written by the 3164 -> 3162 fine run):
    Tables/pure_control_cutoff_fine/t_pure_control_cutoff_deciles.tex        (4271)
    Tables/pure_control_cutoff_fine/t_pure_control_cutoff_deciles_placebo.tex (4271)
    Tables/pure_control_cutoff_fine/t_pure_control_cutoff_size_wide.tex      (4272)
    Graphs/pure_control_cutoff_fine/f_pure_control_cutoff_vingtiles.tex      (4281)
    Graphs/pure_control_cutoff_fine/f_pure_control_cutoff_diff.tex           (4283)
    Graphs/pure_control_cutoff_fine/f_es_pure_control_cutoff.tex             (4282)
    the panel PDFs those figures include (3165, 3167), and
    Tables/pure_control_cutoff_fine/verify_{baseline,es,stacked}.txt

Output:
    Tables/pure_control_cutoff_fine/pure_control_cutoff_review.pdf

Usage
-----
    python 4295_report_pure_control_cutoff_fine.py
"""

import re
from datetime import date

from _pcc_fine_common import GRAPH_DIR, TAB_DIR, compile_preview

BODY_TEX = TAB_DIR / "pure_control_cutoff_review_body.tex"
OUT_PDF = TAB_DIR / "pure_control_cutoff_review.pdf"

# (fragment, one-line description for the cover page), in report order.
EXHIBITS = [
    (TAB_DIR / "t_pure_control_cutoff_size_wide.tex",
     "Pre-treatment establishment size of the treated group and of each comparison group."),
    (TAB_DIR / "t_pure_control_cutoff_deciles.tex",
     "Direct effects by decile cutoff, with stacked-test $p$-values vs.\\ All Untreated."),
    (TAB_DIR / "t_pure_control_cutoff_deciles_placebo.tex",
     "Pre-trend placebo by decile cutoff."),
    (GRAPH_DIR / "f_pure_control_cutoff_vingtiles.tex",
     "Direct effects by vingtile cutoff (P5--P95)."),
    (GRAPH_DIR / "f_pure_control_cutoff_diff.tex",
     "Each vingtile estimate minus the All Untreated estimate, with stacked-test 95\\% CIs."),
    (GRAPH_DIR / "f_es_pure_control_cutoff.tex",
     "Wage event studies at $c = 0$, P10, P20, and P50."),
]
CHECKS = [
    ("verify_baseline.txt", "Replication gate: $c = 0$, $0.01$, and All reproduce the published direct effects"),
    ("verify_es.txt", "Event studies: the $c = 0$ series reproduces the published Panel~A event study"),
    ("verify_stacked.txt", "Stacked tests: differences match the estimates; $c = 0$ $p$-values match the paper"),
]
CODE = "Cluster/UnionSpill/Programs/analysis/pure_control_cutoff/"


def tt(path):
    """\\texttt{} with underscores escaped."""
    return r"\texttt{" + path.replace("_", r"\_") + "}"


def check_result(name):
    path = TAB_DIR / name
    if not path.exists():
        return "not run"
    m = re.search(r"RESULT: (\w+)", path.read_text())
    return m.group(1) if m else "no result line"


def cover():
    exhibit_items = []
    for frag, desc in EXHIBITS:
        label = re.search(r"\\label\{((?:tab|fig):[^}]+)\}", frag.read_text()).group(1)
        kind = "Table" if label.startswith("tab:") else "Figure"
        exhibit_items.append(rf"\item {kind}~\ref{{{label}}}: {desc}")
    check_items = [rf"\item {desc}: \textbf{{{check_result(f)}}} ({tt(f)})"
                   for f, desc in CHECKS]
    return "\n".join([
        r"\begin{center}",
        r"{\Large\bfseries Pure-Control Cutoff Analysis: Review Exhibits}\\[6pt]",
        rf"{date.today():%B %-d, %Y}",
        r"\end{center}",
        r"\vspace{1em}",
        r"\noindent The direct effects of the reform are re-estimated with the comparison "
        r"group widened from zero-connectivity establishments to all untreated "
        r"establishments with connectivity at most $c$, for $c$ at the deciles and "
        r"vingtiles of positive connectivity. Exhibits are numbered R1, R2, \ldots; "
        r"``Table~2'' in the notes is the paper's direct-effects table "
        r"(\texttt{tab:direct\_connectivity\_robust}).",
        r"\subsection*{Exhibits}",
        r"\begin{enumerate}",
        *exhibit_items,
        r"\end{enumerate}",
        r"\subsection*{Checks}",
        r"\begin{itemize}",
        *check_items,
        r"\end{itemize}",
        r"\subsection*{Code and outputs}",
        r"\begin{itemize}",
        rf"\item Code: {tt(CODE)}.",
        rf"\item Full run: {tt('3164_pure_control_cutoff_fine.do')} (about 30 minutes on the Mac).",
        rf"\item Tables and CSVs: {tt('Cluster/UnionSpill/Tables/pure_control_cutoff_fine/')}.",
        rf"\item Figures: {tt('Cluster/UnionSpill/Graphs/pure_control_cutoff_fine/')}.",
        r"\end{itemize}",
    ])


def main():
    parts = [cover()]
    figures = []
    for frag, _ in EXHIBITS:
        if not frag.exists():
            raise SystemExit(f"Missing {frag}. Run 3164_pure_control_cutoff_fine.do first.")
        text = frag.read_text()
        parts += [r"\clearpage", text]
        figures += [GRAPH_DIR / name for name in
                    re.findall(r"\\includegraphics\[[^]]*\]\{Replication/Figures/([^}]+)\}", text)]
    BODY_TEX.write_text("\n".join(parts) + "\n")
    # Report exhibits are R1, R2, ... so they never clash with the paper's Table 2.
    compile_preview(BODY_TEX, OUT_PDF, figures=figures,
                    preamble="\\renewcommand{\\thetable}{R\\arabic{table}}\n"
                             "\\renewcommand{\\thefigure}{R\\arabic{figure}}\n")
    BODY_TEX.unlink()


if __name__ == "__main__":
    main()
