"""
generate_corr_w_ln_similarity_latex.py
MIRROR of generate_ln_similarity_latex.py.

Reads results_spill_corr_w_ln_cba_similarity.csv and produces a LaTeX table
with one column per log-similarity measure (untreated firms vs. moving
per-period reference, with ORIENTATION-CORRECTED connectivity weights).
"""

import pandas as pd
from pathlib import Path

tables_dir = Path(__file__).resolve().parent.parent.parent / "Tables" / "cba_similarity"
csv_path   = tables_dir / "results_spill_corr_w_ln_cba_similarity.csv"
tex_path   = tables_dir / "corr_w_ln_cba_similarity_table.tex"

df = pd.read_csv(csv_path, sep=";", header=0,
                 names=["spec", "section", "outcome", "row_type", "value"])
df["value"] = df["value"].str.strip('"')

outcomes   = ["ln_cosine", "ln_bray_curtis", "ln_total_variation", "ln_ruzicka"]
col_labels = ["Cosine", "Bray-Curtis", "Total Var.", "Ruzicka"]

base_spec  = "corr_w_ln_cba_similarity_tfpw_07_11"
union_spec = "corr_w_ln_cba_similarity_tfpw_07_11_union"

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
        return f"{float(val):.3f}"
    except Exception:
        return str(val)

def fmt_mean(val):
    try:
        return f"{float(val):.4f}"
    except Exception:
        return str(val)

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
        bmean   = [fmt_mean(get(o, "baseline_mean", spec)) for o in outcomes],
    )

base  = panel_rows(base_spec)
union = panel_rows(union_spec)

def row(label, cells, bold=False):
    label_tex = r"\textbf{" + label + r"}" if bold else label
    return label_tex + " & " + " & ".join(cells) + r" \\"

lines = [
    r"\begin{table}[H]",
    r"\centering",
    r"\caption{Log CBA Similarity to Moving Treated Reference (Orientation-Corrected Weights)}",
    r"\label{tab:corr_w_ln_cba_similarity}",
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
    row("Baseline log-mean (period 2)", base["bmean"]),
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
    row("Baseline log-mean (period 2)", union["bmean"]),
    row("Observations",       union["n"]),
    row("Establishments",     union["nest"]),
    row("Pre-trend $p$-value", union["pval"]),
    r"\hline\hline",
    r"\end{tabular}",
    r"\begin{minipage}{\linewidth}",
    r"\smallskip",
    (r"\scriptsize\textit{Notes:} This table reproduces the spillover "
     r"\emph{log} similarity exercise (CBA content similarity vs.\ flow-weighted "
     r"treated reference) with \textbf{orientation-corrected connectivity "
     r"weights}. Outcomes are $\ln(\text{sim}_{it})$ for $\text{sim} \in "
     r"\{\text{cosine}, \text{Bray-Curtis}, \text{total variation}, "
     r"\text{Ruzicka}\}$, dropping firm-period observations with zero "
     r"similarity. Sample, weight definition, and fixed-effects structure are "
     r"identical to Table~\ref{tab:corr_w_cba_similarity}; see notes there. "
     r"Standard errors clustered at the establishment level. "
     r"*\,$p<0.10$, **\,$p<0.05$, ***\,$p<0.01$."),
    r"\end{minipage}",
    r"\end{table}",
]

tex_path.write_text("\n".join(lines) + "\n")
print(f"LaTeX table written to {tex_path}")
