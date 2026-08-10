"""
generate_cba_similarity_decomp_avg_latex.py

Writes the avg-reference counterpart of generate_cba_similarity_decomp_latex.py:

  Tables/cba_similarity/cba_similarity_decomp_avg_table.tex       (body, 2 panels)
  Tables/cba_similarity/cba_similarity_decomp_avg_full_table.tex  (appendix, 5 panels)

Note on interpretation: the average reference T_t does not depend on i, so
the conn x post coefficient on TreatedMove (S(u_{i2}, T_t)) is generally
near zero by construction. The table is informative as a sanity check on
the convergence direction, not as evidence on whether treated firms
themselves moved.
"""

from pathlib import Path

import pandas as pd

tables_dir = Path(__file__).resolve().parent.parent.parent / "Tables" / "cba_similarity"
csv_path   = tables_dir / "results_spill_cba_similarity_decomp_avg.csv"
out_body   = tables_dir / "cba_similarity_decomp_avg_table.tex"
out_full   = tables_dir / "cba_similarity_decomp_avg_full_table.tex"

MEASURES   = ["cosine", "bray_curtis", "total_variation", "ruzicka"]
COL_LABELS = ["Cosine", "Bray-Curtis", "Total Var.", "Ruzicka"]
SPEC       = "cba_similarity_decomp_avg"

OUTCOME_LABELS = {
    "delta": r"$\Delta S$",
    "um":    r"UntreatedMove",
    "tm":    r"TreatedMove",
    "ta":    r"TreatedAdditional",
    "ua":    r"UntreatedAdditional",
}

df = pd.read_csv(csv_path, sep=";", header=0,
                 names=["spec", "section", "outcome", "row_type", "value"])
df["value"] = df["value"].str.strip().str.strip('"')


def get(outcome, row_type, spec=SPEC, default=""):
    rows = df[(df.spec == spec) & (df.outcome == outcome) & (df.row_type == row_type)]
    return rows["value"].iloc[0] if len(rows) > 0 else default


def coef_no_stars(s):
    s = str(s).strip()
    return float(s.rstrip("*")) if s else float("nan")


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


def fmt_resid(v):
    if v != v:
        return "--"
    if abs(v) < 1e-4:
        return f"{v:.2e}"
    return f"{v:.4f}"


def panel_block(prefix, measures, include_n=False, fe_variant=""):
    spec_used = SPEC if fe_variant == "" else f"{SPEC}{fe_variant}"
    outcomes = [f"{prefix}_{m}" for m in measures]
    lines = []
    lines.append(r"\multicolumn{" + str(len(measures) + 1)
                 + r"}{l}{\textit{" + OUTCOME_LABELS[prefix] + r"}} \\")
    cells_b  = [fmt_coef(get(o, "main",    spec=spec_used)) for o in outcomes]
    cells_se = [fmt_se(  get(o, "main_se", spec=spec_used)) for o in outcomes]
    lines.append(r"\quad Connectivity $\times$ Post & " + " & ".join(cells_b) + r" \\")
    lines.append(r"\quad & " + " & ".join(cells_se) + r" \\")
    cells_p  = [fmt_coef(get(o, "pre",     spec=spec_used)) for o in outcomes]
    cells_ps = [fmt_se(  get(o, "pre_se",  spec=spec_used)) for o in outcomes]
    lines.append(r"\quad Connectivity $\times$ Pre  & " + " & ".join(cells_p)  + r" \\")
    lines.append(r"\quad & " + " & ".join(cells_ps) + r" \\")
    if include_n:
        cells_bm = [fmt_mean(get(o, "baseline_mean", spec=spec_used)) for o in outcomes]
        cells_n  = [fmt_n(   get(o, "n_obs",        spec=spec_used)) for o in outcomes]
        cells_ne = [fmt_n(   get(o, "n_estab",      spec=spec_used)) for o in outcomes]
        cells_pv = [fmt_pval(get(o, "pre_pval",     spec=spec_used)) for o in outcomes]
        lines.append(r"\hline")
        lines.append(r"Baseline mean (period 2) & " + " & ".join(cells_bm) + r" \\")
        lines.append(r"Observations           & "   + " & ".join(cells_n)  + r" \\")
        lines.append(r"Establishments         & "   + " & ".join(cells_ne) + r" \\")
        lines.append(r"Pre-trend $p$-value    & "   + " & ".join(cells_pv) + r" \\")
    return lines


ncols    = len(MEASURES) + 1
col_spec = "l" + "c" * len(MEASURES)
col_hdr  = " & " + " & ".join(f"({i+1})" for i in range(len(MEASURES))) + r" \\"
col_lbl  = " & " + " & ".join(r"\textbf{" + l + r"}" for l in COL_LABELS) + r" \\"

# Body table: UntreatedMove + TreatedMove
body = [
    r"\begin{table}[H]",
    r"\centering",
    r"\caption{Ordered Decomposition of CBA Similarity: Average-Treated Reference}",
    r"\scriptsize",
    r"\setlength{\tabcolsep}{8pt}",
    r"\begin{tabular}{" + col_spec + r"}",
    r"\hline\hline",
    col_hdr,
    col_lbl,
    r"\hline",
    *panel_block("um", MEASURES, include_n=True),
    r"\hline",
    *panel_block("tm", MEASURES, include_n=True),
    r"\hline\hline",
    r"\end{tabular}",
    r"\begin{minipage}{\linewidth}",
    r"\smallskip",
    (r"\scriptsize\textit{Notes:} Average-reference counterpart of the "
     r"ordered decomposition table. $T_t$ is the simple unweighted mean of "
     r"clause vectors across treated firms with a CBA at $t$, $T_2$ is the "
     r"same at period 2. \textsc{UntreatedMove} regresses $S(u_{it}, T_2)$ "
     r"on connectivity $\times$ post; \textsc{TreatedMove} regresses "
     r"$S(u_{i2}, T_t)$. Because $T_t$ does not depend on $i$, the "
     r"\textsc{TreatedMove} coefficient identifies whether the universal "
     r"shift in the avg treated CBA happens to align with high-connectivity "
     r"firms' period-2 profiles; a near-zero coefficient is expected by "
     r"construction and is best read as a sanity check. Sample is the full "
     r"untreated lagos balanced panel with a CBA at period 2; fixed effects "
     r"include establishment, industry $\times$ period, mode-month $\times$ "
     r"period, microregion $\times$ period, and pre-treatment "
     r"outcome/employment/total-flow quartile fixed effects. Standard "
     r"errors clustered at the establishment level. "
     r"*\,$p<0.10$, **\,$p<0.05$, ***\,$p<0.01$."),
    r"\end{minipage}",
    r"\end{table}",
]

out_body.write_text("\n".join(body) + "\n")
print(f"Body table written to {out_body}")


# Full table
ident1_cells, ident2_cells = [], []
for m in MEASURES:
    b_delta = coef_no_stars(get(f"delta_{m}", "main"))
    b_um    = coef_no_stars(get(f"um_{m}",    "main"))
    b_tm    = coef_no_stars(get(f"tm_{m}",    "main"))
    b_ta    = coef_no_stars(get(f"ta_{m}",    "main"))
    b_ua    = coef_no_stars(get(f"ua_{m}",    "main"))
    ident1_cells.append(fmt_resid(b_delta - b_um - b_ta))
    ident2_cells.append(fmt_resid(b_delta - b_tm - b_ua))

full = [
    r"\begin{table}[H]",
    r"\centering",
    r"\caption{Ordered Decomposition (Average Reference): Full Five-Outcome Breakdown}",
    r"\scriptsize",
    r"\setlength{\tabcolsep}{8pt}",
    r"\begin{tabular}{" + col_spec + r"}",
    r"\hline\hline",
    col_hdr,
    col_lbl,
    r"\hline",
    *panel_block("delta", MEASURES, include_n=False),
    r"\hline",
    *panel_block("um", MEASURES, include_n=False),
    r"\hline",
    *panel_block("tm", MEASURES, include_n=False),
    r"\hline",
    *panel_block("ta", MEASURES, include_n=False),
    r"\hline",
    *panel_block("ua", MEASURES, include_n=True),
    r"\hline",
    r"\multicolumn{" + str(ncols) + r"}{l}{\textit{Coefficient identity (decomposition residuals)}} \\",
    r"\quad $\hat\beta_{\Delta S} - \hat\beta_{\text{UM}} - \hat\beta_{\text{TA}}$ & "
        + " & ".join(ident1_cells) + r" \\",
    r"\quad $\hat\beta_{\Delta S} - \hat\beta_{\text{TM}} - \hat\beta_{\text{UA}}$ & "
        + " & ".join(ident2_cells) + r" \\",
    r"\hline\hline",
    r"\end{tabular}",
    r"\begin{minipage}{\linewidth}",
    r"\smallskip",
    (r"\scriptsize\textit{Notes:} Avg-reference appendix table with all "
     r"five decomposition outcomes. $\Delta S$ headline regression on "
     r"$S(u_{it}, T_t)$. Identity rows verify $\hat\beta_{\Delta S} = "
     r"\hat\beta_{\text{UM}} + \hat\beta_{\text{TA}} = \hat\beta_{\text{TM}} "
     r"+ \hat\beta_{\text{UA}}$ at machine precision. Standard errors "
     r"clustered at the establishment level."),
    r"\end{minipage}",
    r"\end{table}",
]

out_full.write_text("\n".join(full) + "\n")
print(f"Full table written to {out_full}")
