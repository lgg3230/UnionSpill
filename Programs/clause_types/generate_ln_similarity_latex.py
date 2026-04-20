"""
generate_ln_similarity_latex.py
Reads results_spill_ln_cba_similarity_tfpw_07_11.csv and produces a LaTeX table
with one column per log-similarity measure (bilateral flow-weighted reference).
"""

import pandas as pd
from pathlib import Path

tables_dir = Path(__file__).resolve().parent.parent.parent / "Tables" / "clause_types"
csv_path   = tables_dir / "results_spill_ln_cba_similarity_tfpw_07_11.csv"
tex_path   = tables_dir / "ln_cba_similarity_table.tex"

# ── Load CSV ──────────────────────────────────────────────────────────────────
df = pd.read_csv(csv_path, sep=";", header=0,
                 names=["spec", "section", "outcome", "row_type", "value"])
df["value"] = df["value"].str.strip('"')

outcomes   = ["ln_cosine", "ln_bray_curtis", "ln_total_variation", "ln_jaccard"]
col_labels = ["Cosine", "Bray-Curtis", "Total Var.", "Jaccard"]

def get(outcome, row_type, default=""):
    rows = df[(df.outcome == outcome) & (df.row_type == row_type)]
    return rows["value"].iloc[0] if len(rows) > 0 else default

def fmt_coef(val):
    try:
        s = str(val).strip()
        s_no_stars = s.rstrip("*")
        v = float(s_no_stars)
        stars = s[len(s_no_stars):]
        return f"{v:.4f}{stars}"
    except Exception:
        return str(val)

def fmt_se(val):
    try:
        return f"({float(val):.4f})"
    except Exception:
        return f"({val})"

def fmt_n(val):
    try:
        return f"{int(float(val)):,}"
    except Exception:
        return str(val)

def fmt_pval(val):
    try:
        p = float(val)
        return f"{p:.3f}"
    except Exception:
        return str(val)

# ── Build table ───────────────────────────────────────────────────────────────
col_spec = "l" + "c" * len(outcomes)
col_header = " & " + " & ".join([f"({i+1})" for i in range(len(outcomes))]) + r" \\"
col_labels_row = " & " + " & ".join([r"\textbf{" + lbl + r"}" for lbl in col_labels]) + r" \\"

rows_main    = [fmt_coef(get(o, "main"))    for o in outcomes]
rows_main_se = [fmt_se(get(o, "main_se"))   for o in outcomes]
rows_pre     = [fmt_coef(get(o, "pre"))     for o in outcomes]
rows_pre_se  = [fmt_se(get(o, "pre_se"))    for o in outcomes]
rows_n       = [fmt_n(get(o, "n_obs"))      for o in outcomes]
rows_nest    = [fmt_n(get(o, "n_estab"))    for o in outcomes]
rows_pval    = [fmt_pval(get(o, "pre_pval")) for o in outcomes]

def row(label, cells, bold=False):
    label_tex = r"\textbf{" + label + r"}" if bold else label
    return label_tex + " & " + " & ".join(cells) + r" \\"

lines = [
    r"\begin{table}[H]",
    r"\centering",
    r"\caption{Log CBA Content Similarity and Connectivity: Bilateral Flow-Weighted Reference}",
    r"\scriptsize",
    r"\setlength{\tabcolsep}{8pt}",
    r"\begin{tabular}{" + col_spec + r"}",
    r"\hline\hline",
    col_header,
    col_labels_row,
    r"\hline",
    r"\multicolumn{5}{l}{\textit{Post-treatment}} \\",
    row(r"Connectivity $\times$ Post", rows_main),
    row("", rows_main_se),
    r"\multicolumn{5}{l}{\textit{Pre-treatment placebo}} \\",
    row(r"Connectivity $\times$ Pre", rows_pre),
    row("", rows_pre_se),
    r"\hline",
    row("Observations",  rows_n),
    row("Establishments", rows_nest),
    row("Pre-trend $p$-value", rows_pval),
    r"\hline\hline",
    r"\end{tabular}",
    r"\begin{minipage}{\linewidth}",
    r"\smallskip",
    (r"\scriptsize\textit{Notes:} This table reports spillover-effect estimates of "
     r"log CBA content similarity on connectivity. The outcome is the natural log of "
     r"each similarity measure; observations with similarity equal to zero are excluded. "
     r"The coefficient is interpretable as the percentage change in similarity "
     r"associated with a one-unit increase in connectivity. "
     r"For each untreated firm $i$ and CBA period $t$, similarity is computed against "
     r"a \emph{flow-weighted average} of the clause vectors of treated "
     r"firms with pre-treatment worker flows to $i$; the weights are proportional "
     r"to the bilateral worker-flow volume. Only untreated firms with at least one "
     r"treated counterpart in the bilateral flow data enter the sample. "
     r"Connectivity is scaled to 1 at the 90th percentile of "
     r"the spillover sample. All specifications include establishment, "
     r"industry $\times$ period, mode-month $\times$ period, and "
     r"microregion $\times$ period fixed effects, with pre-treatment bins of "
     r"the outcome, log employment, and total flows absorbed. "
     r"Standard errors clustered at the establishment level. "
     r"*\,$p<0.10$, **\,$p<0.05$, ***\,$p<0.01$."),
    r"\end{minipage}",
    r"\end{table}",
]

tex_path.write_text("\n".join(lines) + "\n")
print(f"LaTeX table written to {tex_path}")
