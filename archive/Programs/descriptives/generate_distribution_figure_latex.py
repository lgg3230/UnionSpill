#!/usr/bin/env python3
"""
Generate LaTeX code for the distribution plots figure.
Three plots stacked vertically: region, broad industry, mode base month.
Output: Graphs/descriptives/distribution_plots_figure.tex
"""

from pathlib import Path

ROOT     = Path(__file__).resolve().parent.parent.parent
OUT_FILE = ROOT / "Graphs" / "descriptives" / "distribution_plots_figure.tex"
OUT_FILE.parent.mkdir(parents=True, exist_ok=True)

OVERLEAF_PATH = "Results - Tables and Figures/Plots_Feb242026"

FIGURES = [
    ("distro_region.pdf",          "Distribution by Region",          "fig:distro_region"),
    ("distro_broad_industry.pdf",  "Distribution by Broad Industry",  "fig:distro_industry"),
    ("distro_mode_base_month.pdf", "Distribution by Negotiation Month", "fig:distro_month"),
]

NOTES = (
    r"\textit{Notes:} This figure shows the distribution of establishments across "
    r"regions, broad industry groups, and CBA negotiation months, separately for "
    r"treated firms, all untreated firms, and zero-connectivity control firms. "
    r"The sample is restricted to the Lagos sample balanced panel at 2011."
)

lines = []
lines.append(r"\begin{figure}[H]")
lines.append(r"\centering")
lines.append(r"\caption{Distribution of Establishments by Characteristics Across Treatment Groups}")
lines.append(r"\begin{threeparttable}")

for i, (fname, caption, label) in enumerate(FIGURES):
    fpath = f"{OVERLEAF_PATH}/{fname}"
    lines.append(r"  \begin{subfigure}[t]{0.55\textwidth}")
    lines.append(f"    \\includegraphics[width=\\textwidth]{{{fpath}}}")
    lines.append(f"    \\caption{{{caption}}}")
    lines.append(f"    \\label{{{label}}}")
    lines.append(r"  \end{subfigure}")
    if i < len(FIGURES) - 1:
        lines.append("")
        lines.append(r"  \vspace{0.5em}")
        lines.append("")

lines.append("")
lines.append(r"  \begin{tablenotes}[flushleft]")
lines.append(r"    \scriptsize")
lines.append(f"    {NOTES}")
lines.append(r"  \end{tablenotes}")
lines.append(r"\end{threeparttable}")
lines.append(r"\label{fig:distribution_plots}")
lines.append(r"\end{figure}")

tex = "\n".join(lines) + "\n"

OUT_FILE.write_text(tex)
print(f"Saved: {OUT_FILE}")
print()
print(tex)
