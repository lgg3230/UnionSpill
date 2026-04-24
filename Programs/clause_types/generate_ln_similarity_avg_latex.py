"""
generate_ln_similarity_avg_latex.py
Reads results_spill_ln_cba_similarity_avg_tfpw_07_11.csv and produces a LaTeX table
with one column per log-similarity measure (average treated reference).
"""

import pandas as pd
from pathlib import Path

tables_dir = Path(__file__).resolve().parent.parent.parent / "Tables" / "clause_types"
csv_path   = tables_dir / "results_spill_ln_cba_similarity_avg_tfpw_07_11.csv"
tex_path   = tables_dir / "ln_cba_similarity_avg_table.tex"

# ── Load CSV ──────────────────────────────────────────────────────────────────
df = pd.read_csv(csv_path, sep=";", header=0,
                 names=["spec", "section", "outcome", "row_type", "value"])
df["value"] = df["value"].str.strip('"')

outcomes   = ["ln_cosine", "ln_bray_curtis", "ln_total_variation", "ln_jaccard"]
col_labels = ["Cosine", "Bray-Curtis", "Total Var.", "Jaccard"]

base_spec  = "ln_cba_similarity_avg_tfpw_07_11"
union_spec = "ln_cba_similarity_avg_tfpw_07_11_union"

def get(outcome, row_type, spec, default=""):
    rows = df[(df.spec == spec) & (df.outcome == outcome) & (df.row_type == row_type)]
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
ncols = len(outcomes) + 1
col_spec = "l" + "c" * len(outcomes)
col_header = " & " + " & ".join([f"({i+1})" for i in range(len(outcomes))]) + r" \\"
col_labels_row = " & " + " & ".join([r"\textbf{" + lbl + r"}" for lbl in col_labels]) + r" \\"

def panel_rows(spec):
    return dict(
        main    = [fmt_coef(get(o, "main",    spec)) for o in outcomes],
        main_se = [fmt_se(  get(o, "main_se", spec)) for o in outcomes],
        pre     = [fmt_coef(get(o, "pre",     spec)) for o in outcomes],
        pre_se  = [fmt_se(  get(o, "pre_se",  spec)) for o in outcomes],
        n       = [fmt_n(   get(o, "n_obs",   spec)) for o in outcomes],
        nest    = [fmt_n(   get(o, "n_estab", spec)) for o in outcomes],
        pval    = [fmt_pval(get(o, "pre_pval",spec)) for o in outcomes],
    )

base  = panel_rows(base_spec)
union = panel_rows(union_spec)

def row(label, cells, bold=False):
    label_tex = r"\textbf{" + label + r"}" if bold else label
    return label_tex + " & " + " & ".join(cells) + r" \\"

lines = [
    r"\begin{table}[H]",
    r"\centering",
    r"\caption{Log CBA Content Similarity and Connectivity: Average Treated Reference}",
    r"\scriptsize",
    r"\setlength{\tabcolsep}{8pt}",
    r"\begin{tabular}{" + col_spec + r"}",
    r"\hline\hline",
    col_header,
    col_labels_row,
    r"\hline",
    rf"\multicolumn{{{ncols}}}{{l}}{{\textit{{Panel A: Baseline}}}} \\",
    rf"\multicolumn{{{ncols}}}{{l}}{{\textit{{Post-treatment}}}} \\",
    row(r"Connectivity $\times$ Post", base["main"]),
    row("", base["main_se"]),
    rf"\multicolumn{{{ncols}}}{{l}}{{\textit{{Pre-treatment placebo}}}} \\",
    row(r"Connectivity $\times$ Pre", base["pre"]),
    row("", base["pre_se"]),
    r"\hline",
    row("Observations",       base["n"]),
    row("Establishments",     base["nest"]),
    row("Pre-trend $p$-value", base["pval"]),
    r"\hline",
    rf"\multicolumn{{{ncols}}}{{l}}{{\textit{{Panel B: Adding union $\times$ period FE}}}} \\",
    rf"\multicolumn{{{ncols}}}{{l}}{{\textit{{Post-treatment}}}} \\",
    row(r"Connectivity $\times$ Post", union["main"]),
    row("", union["main_se"]),
    rf"\multicolumn{{{ncols}}}{{l}}{{\textit{{Pre-treatment placebo}}}} \\",
    row(r"Connectivity $\times$ Pre", union["pre"]),
    row("", union["pre_se"]),
    r"\hline",
    row("Observations",       union["n"]),
    row("Establishments",     union["nest"]),
    row("Pre-trend $p$-value", union["pval"]),
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
     r"the \emph{simple (unweighted) average} clause vector across \emph{all} treated "
     r"firms in period $t$; every untreated firm receives a reference vector regardless "
     r"of its bilateral connectivity to treated firms. "
     r"Connectivity is scaled to 1 at the 90th percentile of "
     r"the spillover sample. Panel A includes establishment, "
     r"industry $\times$ period, mode-month $\times$ period, and "
     r"microregion $\times$ period fixed effects, with pre-treatment bins of "
     r"the outcome, log employment, and total flows absorbed. "
     r"Panel B additionally absorbs union $\times$ period fixed effects. "
     r"Standard errors clustered at the establishment level. "
     r"*\,$p<0.10$, **\,$p<0.05$, ***\,$p<0.01$."),
    r"\end{minipage}",
    r"\end{table}",
]

tex_path.write_text("\n".join(lines) + "\n")
print(f"LaTeX table written to {tex_path}")
