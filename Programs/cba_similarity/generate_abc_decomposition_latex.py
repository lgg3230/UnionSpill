"""
generate_abc_decomposition_latex.py

A/B/C decomposition table for the CBA similarity spillover effect.

Reads three CSVs (one per exercise) and produces ONE LaTeX table that puts
the three exercises in vertically-stacked panels and the four similarity
measures across columns. Same connectivity weights, sample, and FE structure
across all three exercises so the coefficient ratios are directly readable.

  Exercise A (both moving):  S( u_{i,t},  T_{i,t} )
    -> results_spill_cba_similarity_tfpw_07_11.csv
       (spec: cba_similarity_tfpw_07_11)

  Exercise B (focal frozen at p2, partner moving):  S( u_{i,2}, T_{i,t} )
    -> results_spill_focal_frozen_cba_similarity.csv
       (spec: focal_frozen_cba_similarity_tfpw_07_11)

  Exercise C (focal moving, partner frozen at p2):  S( u_{i,t}, T_{i,2} )
    -> results_spill_pretreat_ref_uncorr_w_cba_similarity.csv
       (spec: pretreat_ref_uncorr_w_cba_similarity_tfpw_07_11)

Outputs:
  Tables/cba_similarity/abc_decomposition_cba_similarity_table.tex      (levels)
  Tables/cba_similarity/abc_decomposition_ln_cba_similarity_table.tex   (logs)
"""

import pandas as pd
from pathlib import Path

tables_dir = Path(__file__).resolve().parent.parent.parent / "Tables" / "cba_similarity"

OUTCOMES   = ["cosine", "bray_curtis", "total_variation", "ruzicka"]
COL_LABELS = ["Cosine", "Bray-Curtis", "Total Var.", "Ruzicka"]


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


def load_csv(path):
    df = pd.read_csv(path, sep=";", header=0,
                     names=["spec", "section", "outcome", "row_type", "value"])
    df["value"] = df["value"].str.strip('"')
    return df


def panel_rows(df, spec, outcomes):
    def get(outcome, row_type):
        rows = df[(df.spec == spec) & (df.outcome == outcome) & (df.row_type == row_type)]
        return rows["value"].iloc[0] if len(rows) > 0 else ""
    return dict(
        main    = [fmt_coef(get(o, "main"))    for o in outcomes],
        main_se = [fmt_se(  get(o, "main_se")) for o in outcomes],
        pre     = [fmt_coef(get(o, "pre"))     for o in outcomes],
        pre_se  = [fmt_se(  get(o, "pre_se"))  for o in outcomes],
        n       = [fmt_n(   get(o, "n_obs"))   for o in outcomes],
        nest    = [fmt_n(   get(o, "n_estab")) for o in outcomes],
        pval    = [fmt_pval(get(o, "pre_pval"))            for o in outcomes],
        bmean   = [fmt_mean(get(o, "baseline_mean"))       for o in outcomes],
    )


def row(label, cells, bold=False):
    label_tex = r"\textbf{" + label + r"}" if bold else label
    return label_tex + " & " + " & ".join(cells) + r" \\"


def build_table(label_suffix, log_prefix, outcomes,
                csv_A, csv_B, csv_C, spec_A, spec_B, spec_C,
                title, baseline_label):
    df_A = load_csv(csv_A)
    df_B = load_csv(csv_B)
    df_C = load_csv(csv_C)

    A = panel_rows(df_A, spec_A, outcomes)
    B = panel_rows(df_B, spec_B, outcomes)
    C = panel_rows(df_C, spec_C, outcomes)

    ncols = len(outcomes) + 1
    col_spec = "l" + "c" * len(outcomes)
    col_header     = " & " + " & ".join([f"({i+1})" for i in range(len(outcomes))]) + r" \\"
    col_labels_row = " & " + " & ".join([r"\textbf{" + lbl + r"}" for lbl in COL_LABELS]) + r" \\"

    def panel(label_text, P):
        return [
            rf"\multicolumn{{{ncols}}}{{l}}{{\textit{{{label_text}}}}} \\",
            row(r"Connectivity $\times$ Post", P["main"]),
            row("", P["main_se"]),
            row(r"Connectivity $\times$ Pre",  P["pre"]),
            row("", P["pre_se"]),
            row(baseline_label,        P["bmean"]),
            row("Observations",        P["n"]),
            row("Establishments",      P["nest"]),
            row("Pre-trend $p$-value", P["pval"]),
            r"\hline",
        ]

    lines = [
        r"\begin{table}[H]",
        r"\centering",
        rf"\caption{{{title}}}",
        rf"\label{{tab:abc_decomposition_{label_suffix}}}",
        r"\scriptsize",
        r"\setlength{\tabcolsep}{8pt}",
        r"\begin{tabular}{" + col_spec + r"}",
        r"\hline\hline",
        col_header,
        col_labels_row,
        r"\hline",
        *panel(r"Panel A: Both moving  ---  $S(u_{i,t},\, T_{i,t})$", A),
        *panel(r"Panel B: Focal frozen at $p_2$, partners moving  ---  $S(u_{i,2},\, T_{i,t})$", B),
        *panel(r"Panel C: Focal moving, partners frozen at $p_2$  ---  $S(u_{i,t},\, T_{i,2})$", C),
        r"\hline\hline",
        r"\end{tabular}",
        r"\begin{minipage}{\linewidth}",
        r"\smallskip",
        (r"\scriptsize\textit{Notes:} This table decomposes the connectivity-driven "
         r"approximation of untreated firms' CBAs toward their treated counterparts' "
         r"CBAs into the contributions of focal-side movement (Panel C), "
         r"partner-side movement (Panel B), and the combined movement (Panel A). "
         r"Each cell reports the coefficient on connectivity $\times$ post (or pre) "
         r"from a separate spillover regression of the indicated " + log_prefix +
         r"similarity measure on connectivity, "
         r"in a sample of untreated firms with at least one treated counterpart "
         r"sharing pre-treatment worker flows. All three exercises use the "
         r"\emph{uncorrected} per-worker bilateral connectivity "
         r"(\texttt{bilateral\_conn\_pw}) as the weighting kernel; connectivity is "
         r"scaled to 1 at the 90th percentile of the spillover sample at year 2009. "
         r"All regressions absorb establishment, industry $\times$ period, "
         r"mode-month $\times$ period, and microregion $\times$ period fixed effects, "
         r"and include pre-treatment quartile bins of the outcome, log employment, "
         r"and total flows interacted with period. Standard errors clustered at "
         r"the establishment level. "
         r"*\,$p<0.10$, **\,$p<0.05$, ***\,$p<0.01$."),
        r"\end{minipage}",
        r"\end{table}",
    ]

    return "\n".join(lines) + "\n"


# ── Levels ────────────────────────────────────────────────────────────────────
levels_tex = build_table(
    label_suffix    = "cba_similarity",
    log_prefix      = "",
    outcomes        = OUTCOMES,
    csv_A           = tables_dir / "results_spill_cba_similarity_tfpw_07_11.csv",
    csv_B           = tables_dir / "results_spill_focal_frozen_cba_similarity.csv",
    csv_C           = tables_dir / "results_spill_pretreat_ref_uncorr_w_cba_similarity.csv",
    spec_A          = "cba_similarity_tfpw_07_11",
    spec_B          = "focal_frozen_cba_similarity_tfpw_07_11",
    spec_C          = "pretreat_ref_uncorr_w_cba_similarity_tfpw_07_11",
    title           = "A/B/C Decomposition: CBA Content Similarity to Treated Partners",
    baseline_label  = "Baseline mean (period 2)",
)
out_levels = tables_dir / "abc_decomposition_cba_similarity_table.tex"
out_levels.write_text(levels_tex)
print(f"LaTeX table written to {out_levels}")

# ── Logs ──────────────────────────────────────────────────────────────────────
ln_outcomes = [f"ln_{o}" for o in OUTCOMES]
logs_tex = build_table(
    label_suffix    = "ln_cba_similarity",
    log_prefix      = "log ",
    outcomes        = ln_outcomes,
    csv_A           = tables_dir / "results_spill_ln_cba_similarity_tfpw_07_11.csv",
    csv_B           = tables_dir / "results_spill_focal_frozen_ln_cba_similarity.csv",
    csv_C           = tables_dir / "results_spill_pretreat_ref_uncorr_w_ln_cba_similarity.csv",
    spec_A          = "ln_cba_similarity_tfpw_07_11",
    spec_B          = "focal_frozen_ln_cba_similarity_tfpw_07_11",
    spec_C          = "pretreat_ref_uncorr_w_ln_cba_similarity_tfpw_07_11",
    title           = "A/B/C Decomposition: Log CBA Content Similarity to Treated Partners",
    baseline_label  = "Baseline log-mean (period 2)",
)
out_logs = tables_dir / "abc_decomposition_ln_cba_similarity_table.tex"
out_logs.write_text(logs_tex)
print(f"LaTeX table written to {out_logs}")
