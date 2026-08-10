"""
generate_sample_check_latex.py

Produces a comparison table to diagnose whether the union x period FE result
in the average-treated similarity exercise is driven by sample selection from
the bilateral exercise.

Three panels:
  Panel A: Avg similarity, full sample, baseline FE
  Panel B: Avg similarity, full sample, + union x period FE
  Panel C: Avg similarity, restricted to bilateral sample, baseline FE
  Panel D: Avg similarity, restricted to bilateral sample, + union x period FE

If the effect disappears from C to D, union FE is doing real work even on the
bilateral sample -> NOT a sample-selection story.
If the effect is already gone in C, sample selection is (partly) responsible.
"""

import pandas as pd
from pathlib import Path

tables_dir = Path(__file__).resolve().parent.parent.parent / "Tables" / "cba_similarity"

# Full-sample avg results (already produced by cba_similarity_avg.do)
df_full = pd.read_csv(
    tables_dir / "results_spill_cba_similarity_avg_tfpw_07_11.csv",
    sep=";", header=0,
    names=["spec", "section", "outcome", "row_type", "value"],
)
df_full["value"] = df_full["value"].str.strip('"')

# Bilateral-sample results (produced by cba_similarity_sample_check.do)
df_check = pd.read_csv(
    tables_dir / "results_sample_check_cba_similarity.csv",
    sep=";", header=0,
    names=["spec", "section", "outcome", "row_type", "value"],
)
df_check["value"] = df_check["value"].str.strip('"')

outcomes   = ["cosine", "bray_curtis", "total_variation", "ruzicka"]
col_labels = ["Cosine", "Bray-Curtis", "Total Var.", "Ruzicka"]

FULL_BASE_SPEC  = "cba_similarity_avg_tfpw_07_11"
FULL_UNION_SPEC = "cba_similarity_avg_tfpw_07_11_union"
BILAT_BASE_SPEC  = "avg_bilat_sample"
BILAT_UNION_SPEC = "avg_bilat_sample_union"


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


def fmt_mean(val):
    try:
        return f"{float(val):.4f}"
    except Exception:
        return str(val)


def row(label, cells):
    return label + " & " + " & ".join(cells) + r" \\"


def panel_rows(df, spec):
    return dict(
        main    = [fmt_coef(get(df, spec, o, "main"))    for o in outcomes],
        main_se = [fmt_se(  get(df, spec, o, "main_se")) for o in outcomes],
        pre     = [fmt_coef(get(df, spec, o, "pre"))     for o in outcomes],
        pre_se  = [fmt_se(  get(df, spec, o, "pre_se"))  for o in outcomes],
        n       = [fmt_n(   get(df, spec, o, "n_obs"))   for o in outcomes],
        nest    = [fmt_n(   get(df, spec, o, "n_estab")) for o in outcomes],
        bmean   = [fmt_mean(get(df, spec, o, "baseline_mean")) for o in outcomes],
    )


full_base  = panel_rows(df_full,  FULL_BASE_SPEC)
full_union = panel_rows(df_full,  FULL_UNION_SPEC)
bilat_base  = panel_rows(df_check, BILAT_BASE_SPEC)
bilat_union = panel_rows(df_check, BILAT_UNION_SPEC)

ncols    = len(outcomes) + 1
col_spec = "l" + "c" * len(outcomes)
col_hdr  = " & " + " & ".join([f"({i+1})" for i in range(len(outcomes))]) + r" \\"
col_lbl  = " & " + " & ".join([r"\textbf{" + l + r"}" for l in col_labels]) + r" \\"

lines = [
    r"\begin{table}[H]",
    r"\centering",
    r"\caption{Sample-Selection Check: Average-Treated Similarity on Bilateral Sample}",
    r"\scriptsize",
    r"\setlength{\tabcolsep}{6pt}",
    r"\begin{tabular}{" + col_spec + r"}",
    r"\hline\hline",
    col_hdr,
    col_lbl,
    r"\hline",
    # Panel A
    rf"\multicolumn{{{ncols}}}{{l}}{{\textit{{Panel A: Full sample — baseline FE}}}} \\",
    rf"\multicolumn{{{ncols}}}{{l}}{{\textit{{Post-treatment}}}} \\",
    row(r"Connectivity $\times$ Post", full_base["main"]),
    row("", full_base["main_se"]),
    rf"\multicolumn{{{ncols}}}{{l}}{{\textit{{Pre-treatment placebo}}}} \\",
    row(r"Connectivity $\times$ Pre", full_base["pre"]),
    row("", full_base["pre_se"]),
    r"\hline",
    row("Baseline mean (period 2)", full_base["bmean"]),
    row("Observations",   full_base["n"]),
    row("Establishments", full_base["nest"]),
    r"\hline",
    # Panel B
    rf"\multicolumn{{{ncols}}}{{l}}{{\textit{{Panel B: Full sample — adding union $\times$ period FE}}}} \\",
    rf"\multicolumn{{{ncols}}}{{l}}{{\textit{{Post-treatment}}}} \\",
    row(r"Connectivity $\times$ Post", full_union["main"]),
    row("", full_union["main_se"]),
    rf"\multicolumn{{{ncols}}}{{l}}{{\textit{{Pre-treatment placebo}}}} \\",
    row(r"Connectivity $\times$ Pre", full_union["pre"]),
    row("", full_union["pre_se"]),
    r"\hline",
    row("Baseline mean (period 2)", full_union["bmean"]),
    row("Observations",   full_union["n"]),
    row("Establishments", full_union["nest"]),
    r"\hline",
    # Panel C
    rf"\multicolumn{{{ncols}}}{{l}}{{\textit{{Panel C: Bilateral sample — baseline FE}}}} \\",
    rf"\multicolumn{{{ncols}}}{{l}}{{\textit{{Post-treatment}}}} \\",
    row(r"Connectivity $\times$ Post", bilat_base["main"]),
    row("", bilat_base["main_se"]),
    rf"\multicolumn{{{ncols}}}{{l}}{{\textit{{Pre-treatment placebo}}}} \\",
    row(r"Connectivity $\times$ Pre", bilat_base["pre"]),
    row("", bilat_base["pre_se"]),
    r"\hline",
    row("Baseline mean (period 2)", bilat_base["bmean"]),
    row("Observations",   bilat_base["n"]),
    row("Establishments", bilat_base["nest"]),
    r"\hline",
    # Panel D
    rf"\multicolumn{{{ncols}}}{{l}}{{\textit{{Panel D: Bilateral sample — adding union $\times$ period FE}}}} \\",
    rf"\multicolumn{{{ncols}}}{{l}}{{\textit{{Post-treatment}}}} \\",
    row(r"Connectivity $\times$ Post", bilat_union["main"]),
    row("", bilat_union["main_se"]),
    rf"\multicolumn{{{ncols}}}{{l}}{{\textit{{Pre-treatment placebo}}}} \\",
    row(r"Connectivity $\times$ Pre", bilat_union["pre"]),
    row("", bilat_union["pre_se"]),
    r"\hline",
    row("Baseline mean (period 2)", bilat_union["bmean"]),
    row("Observations",   bilat_union["n"]),
    row("Establishments", bilat_union["nest"]),
    r"\hline\hline",
    r"\end{tabular}",
    r"\begin{minipage}{\linewidth}",
    r"\smallskip",
    (r"\scriptsize\textit{Notes:} This table tests whether the attenuation of the "
     r"average-treated similarity effect under union $\times$ period fixed effects "
     r"(Panel B) is driven by sample selection from the bilateral exercise. "
     r"Panels C and D replicate Panels A and B on the sample of establishments "
     r"retained by the bilateral (flow-weighted) regression — firms with positive "
     r"pre-treatment bilateral connectivity to treated firms that are not dropped as "
     r"singletons by the baseline bilateral specification. "
     r"If the effect disappears from Panel C to Panel D, the union fixed effect is "
     r"doing genuine work even on the bilateral sample, ruling out sample selection "
     r"as the driver. If the effect is already absent in Panel C, selection into "
     r"the bilateral sample is (partly) responsible. "
     r"All specifications include establishment, industry $\times$ period, "
     r"mode-month $\times$ period, and microregion $\times$ period fixed effects, "
     r"with pre-treatment bins of the outcome, log employment, and total flows "
     r"absorbed. Panels B and D additionally absorb union $\times$ period fixed "
     r"effects. Standard errors clustered at the establishment level. "
     r"*\,$p<0.10$, **\,$p<0.05$, ***\,$p<0.01$."),
    r"\end{minipage}",
    r"\end{table}",
]

tex_path = tables_dir / "cba_similarity_sample_check_table.tex"
tex_path.write_text("\n".join(lines) + "\n")
print(f"LaTeX table written to {tex_path}")
