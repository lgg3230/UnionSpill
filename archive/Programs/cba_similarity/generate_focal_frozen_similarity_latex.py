"""
generate_focal_frozen_similarity_latex.py

Exercise B of the A/B/C decomposition.

Reads results_spill_focal_frozen_cba_similarity.csv and produces a LaTeX
table with one column per similarity measure. Outcome: similarity between
the focal (spillover) firm's clauses FIXED at cba_period == 2 and a
MOVING flow-weighted average of treated partners' clauses at cba_period t.
Weights are uncorrected bilateral_conn_pw, identical to Exercises A and C.
"""

import pandas as pd
from pathlib import Path

tables_dir = Path(__file__).resolve().parent.parent.parent / "Tables" / "cba_similarity"
csv_path   = tables_dir / "results_spill_focal_frozen_cba_similarity.csv"
tex_path   = tables_dir / "focal_frozen_cba_similarity_table.tex"

df = pd.read_csv(csv_path, sep=";", header=0,
                 names=["spec", "section", "outcome", "row_type", "value"])
df["value"] = df["value"].str.strip('"')

outcomes   = ["cosine", "bray_curtis", "total_variation", "ruzicka"]
col_labels = ["Cosine", "Bray-Curtis", "Total Var.", "Ruzicka"]

base_spec  = "focal_frozen_cba_similarity_tfpw_07_11"
union_spec = "focal_frozen_cba_similarity_tfpw_07_11_union"

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
    r"\caption{CBA Content Similarity: Focal Firm Frozen at Period 2, Treated Partners Moving}",
    r"\label{tab:focal_frozen_cba_similarity}",
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
    row("Baseline mean (period 2)", base["bmean"]),
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
    row("Baseline mean (period 2)", union["bmean"]),
    row("Observations",       union["n"]),
    row("Establishments",     union["nest"]),
    row("Pre-trend $p$-value", union["pval"]),
    r"\hline\hline",
    r"\end{tabular}",
    r"\begin{minipage}{\linewidth}",
    r"\smallskip",
    (r"\scriptsize\textit{Notes:} This table reports Exercise B of the "
     r"A/B/C decomposition: the focal (spillover) firm's clause vector is "
     r"\emph{frozen} at \textbf{cba\_period $= 2$} (the last pre-Sumula 277 "
     r"negotiation cycle), while the treated-partner reference \emph{moves} "
     r"with the current cba\_period $t$. For each untreated firm $i$ and "
     r"period $t$, the outcome measures similarity between $u_{i,2}$ (firm "
     r"$i$'s clauses at period 2) and $T_{i,t} = \sum_k w_{ik} x_{k,t} / "
     r"\sum_k w_{ik}$, the flow-weighted average of treated partners' "
     r"clauses at period $t$. Weights $w_{ik}$ are the uncorrected per-worker "
     r"bilateral connectivity (\texttt{bilateral\_conn\_pw}), identical to "
     r"Exercises A and C so that coefficients are directly comparable across "
     r"the three decomposition pieces. Only untreated firms with period-2 "
     r"clauses and at least one treated counterpart with positive flow weight "
     r"enter the sample. Connectivity is scaled to 1 at the 90th percentile "
     r"of the spillover sample at year 2009. Panel A includes establishment, "
     r"industry $\times$ period, mode-month $\times$ period, and "
     r"microregion $\times$ period fixed effects, with pre-treatment quartile "
     r"bins of the outcome, log employment, and total flows interacted with "
     r"period. Panel B additionally absorbs union $\times$ period fixed effects. "
     r"Standard errors clustered at the establishment level. "
     r"*\,$p<0.10$, **\,$p<0.05$, ***\,$p<0.01$."),
    r"\end{minipage}",
    r"\end{table}",
]

tex_path.write_text("\n".join(lines) + "\n")
print(f"LaTeX table written to {tex_path}")
