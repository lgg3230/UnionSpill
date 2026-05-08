"""
generate_pretreat_ref_uncorr_w_similarity_latex.py
MIRROR of generate_similarity_latex.py.

Reads results_spill_pretreat_ref_uncorr_w_cba_similarity.csv and produces a LaTeX table
with one column per similarity measure (untreated firms vs. fixed
pre-treatment treated reference vector).
"""

import pandas as pd
from pathlib import Path

tables_dir = Path(__file__).resolve().parent.parent.parent / "Tables" / "cba_similarity"
csv_path   = tables_dir / "results_spill_pretreat_ref_uncorr_w_cba_similarity.csv"
tex_path   = tables_dir / "pretreat_ref_uncorr_w_cba_similarity_table.tex"

# ── Load CSV ──────────────────────────────────────────────────────────────────
df = pd.read_csv(csv_path, sep=";", header=0,
                 names=["spec", "section", "outcome", "row_type", "value"])
df["value"] = df["value"].str.strip('"')

outcomes   = ["cosine", "bray_curtis", "total_variation", "ruzicka"]
col_labels = ["Cosine", "Bray-Curtis", "Total Var.", "Ruzicka"]

base_spec  = "pretreat_ref_uncorr_w_cba_similarity_tfpw_07_11"
union_spec = "pretreat_ref_uncorr_w_cba_similarity_tfpw_07_11_union"

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
    r"\caption{CBA Content Similarity to Fixed Pre-Treatment Treated Reference}",
    r"\label{tab:pretreat_ref_uncorr_w_cba_similarity}",
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
    (r"\scriptsize\textit{Notes:} This table reports spillover-effect estimates "
     r"of CBA content similarity on connectivity, where the reference vector is "
     r"\emph{fixed} at the partners' \textit{pre-Sumula 277} contracts. "
     r"For each untreated firm $i$ and CBA period $t$, the outcome is the "
     r"similarity between firm $i$'s clause vector at period $t$ and a "
     r"flow-weighted average of the clause vectors of treated firms with "
     r"pre-treatment worker flows to $i$, evaluated at \textbf{cba\_period $= 2$} "
     r"(the last pre-Sumula 277 negotiation cycle). Weights are the "
     r"\emph{uncorrected} per-worker bilateral connectivity "
     r"(\texttt{bilateral\_conn\_pw} from \texttt{bilateral\_connectivity.m}), "
     r"which uses the smaller-ID firm's average employment as denominator "
     r"regardless of which firm is the focal --- i.e., this is the i$<$j-biased "
     r"weight, paired here with the fixed period-2 reference for direct "
     r"comparison against the focal-firm-corrected pretreat-reference table. "
     r"Only untreated firms with at least one "
     r"treated counterpart with period-2 clauses enter the sample. "
     r"Connectivity is scaled to 1 at the 90th percentile of "
     r"the spillover sample at year 2009. Panel A includes establishment, "
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
