"""
generate_similarity_avg_pos_conn_latex.py

Produces a table comparing the average-treated similarity exercise using a
binary indicator for positive connectivity (pos_conn) against the continuous
connectivity measure, with and without union x period FE.

Four panels:
  Panel A: Continuous connectivity, baseline FE       (from existing avg table)
  Panel B: Continuous connectivity, + union x period  (from existing avg table)
  Panel C: pos_conn dummy, baseline FE                (new)
  Panel D: pos_conn dummy, + union x period           (new)

If the hypothesis holds: effect in C ≈ effect in A (level difference, not
dose-response), and effect in D ≈ 0 (absorbed by union FE just like B).
"""

import pandas as pd
from pathlib import Path

tables_dir = Path(__file__).resolve().parent.parent.parent / "Tables" / "clause_types"

df_cont = pd.read_csv(
    tables_dir / "results_spill_cba_similarity_avg_tfpw_07_11.csv",
    sep=";", header=0,
    names=["spec", "section", "outcome", "row_type", "value"],
)
df_cont["value"] = df_cont["value"].str.strip('"')

df_dummy = pd.read_csv(
    tables_dir / "results_spill_cba_similarity_avg_pos_conn.csv",
    sep=";", header=0,
    names=["spec", "section", "outcome", "row_type", "value"],
)
df_dummy["value"] = df_dummy["value"].str.strip('"')

outcomes   = ["cosine", "bray_curtis", "total_variation", "jaccard"]
col_labels = ["Cosine", "Bray-Curtis", "Total Var.", "Jaccard"]

CONT_BASE  = "cba_similarity_avg_tfpw_07_11"
CONT_UNION = "cba_similarity_avg_tfpw_07_11_union"
DUMMY_BASE  = "avg_pos_conn"
DUMMY_UNION = "avg_pos_conn_union"


def get(df, spec, outcome, row_type, default=""):
    rows = df[(df.spec == spec) & (df.outcome == outcome) & (df.row_type == row_type)]
    return rows["value"].iloc[0] if len(rows) > 0 else default


def fmt_coef(val):
    try:
        s = str(val).strip()
        s_clean = s.rstrip("*")
        v = float(s_clean)
        stars = s[len(s_clean):]
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


def panel_rows(df, spec):
    return dict(
        main    = [fmt_coef(get(df, spec, o, "main"))     for o in outcomes],
        main_se = [fmt_se(  get(df, spec, o, "main_se"))  for o in outcomes],
        pre     = [fmt_coef(get(df, spec, o, "pre"))      for o in outcomes],
        pre_se  = [fmt_se(  get(df, spec, o, "pre_se"))   for o in outcomes],
        n       = [fmt_n(   get(df, spec, o, "n_obs"))    for o in outcomes],
        nest    = [fmt_n(   get(df, spec, o, "n_estab"))  for o in outcomes],
        pval    = [fmt_pval(get(df, spec, o, "pre_pval")) for o in outcomes],
    )


cont_base  = panel_rows(df_cont,  CONT_BASE)
cont_union = panel_rows(df_cont,  CONT_UNION)
dum_base   = panel_rows(df_dummy, DUMMY_BASE)
dum_union  = panel_rows(df_dummy, DUMMY_UNION)

ncols    = len(outcomes) + 1
col_spec = "l" + "c" * len(outcomes)
col_hdr  = " & " + " & ".join([f"({i+1})" for i in range(len(outcomes))]) + r" \\"
col_lbl  = " & " + " & ".join([r"\textbf{" + l + r"}" for l in col_labels]) + r" \\"


def row(label, cells):
    return label + " & " + " & ".join(cells) + r" \\"


def panel_block(title, p):
    return [
        rf"\multicolumn{{{ncols}}}{{l}}{{\textit{{{title}}}}} \\",
        rf"\multicolumn{{{ncols}}}{{l}}{{\textit{{Post-treatment}}}} \\",
        row(r"Connectivity $\times$ Post", p["main"]),
        row("", p["main_se"]),
        rf"\multicolumn{{{ncols}}}{{l}}{{\textit{{Pre-treatment placebo}}}} \\",
        row(r"Connectivity $\times$ Pre", p["pre"]),
        row("", p["pre_se"]),
        r"\hline",
        row("Observations",        p["n"]),
        row("Establishments",      p["nest"]),
        row("Pre-trend $p$-value", p["pval"]),
        r"\hline",
    ]


lines = [
    r"\begin{table}[H]",
    r"\centering",
    r"\caption{Average-Treated Similarity: Continuous vs.\ Binary Connectivity}",
    r"\scriptsize",
    r"\setlength{\tabcolsep}{6pt}",
    r"\begin{tabular}{" + col_spec + r"}",
    r"\hline\hline",
    col_hdr,
    col_lbl,
    r"\hline",
]

lines += panel_block(
    r"Panel A: Continuous connectivity — baseline FE", cont_base)
lines += panel_block(
    r"Panel B: Continuous connectivity — adding union $\times$ period FE", cont_union)
lines += panel_block(
    r"Panel C: Binary connectivity (pos\_conn dummy) — baseline FE", dum_base)
lines += panel_block(
    r"Panel D: Binary connectivity (pos\_conn dummy) — adding union $\times$ period FE", dum_union)

# Remove trailing \hline before \hline\hline
if lines[-1] == r"\hline":
    lines.pop()

lines += [
    r"\hline\hline",
    r"\end{tabular}",
    r"\begin{minipage}{\linewidth}",
    r"\smallskip",
    (r"\scriptsize\textit{Notes:} This table tests whether the average-treated "
     r"similarity effect is driven by an extensive-margin level difference between "
     r"firms with and without any pre-treatment worker flows to treated firms, "
     r"rather than a dose-response relationship with connectivity intensity. "
     r"Panels A--B use the continuous connectivity measure (total flows to treated "
     r"firms per worker, scaled to 1 at the 90th percentile); Panels C--D replace "
     r"it with a binary indicator equal to one if the firm has any positive "
     r"pre-treatment flow to treated firms (\texttt{pos\_conn}). "
     r"Panels B and D add union $\times$ period fixed effects. "
     r"If Panels C and D replicate the pattern in A and B, the effect is an "
     r"extensive-margin phenomenon absorbed by union identity rather than a "
     r"firm-level dose-response. "
     r"All specifications include establishment, industry $\times$ period, "
     r"mode-month $\times$ period, and microregion $\times$ period fixed effects, "
     r"with pre-treatment bins of the outcome, log employment, and total flows "
     r"absorbed. Standard errors clustered at the establishment level. "
     r"*\,$p<0.10$, **\,$p<0.05$, ***\,$p<0.01$."),
    r"\end{minipage}",
    r"\end{table}",
]

tex_path = tables_dir / "cba_similarity_avg_pos_conn_table.tex"
tex_path.write_text("\n".join(lines) + "\n")
print(f"LaTeX table written to {tex_path}")
