"""
generate_cba_similarity_decomp_latex.py

Writes two LaTeX tables for the ordered-decomposition exercise
(weighted reference):

  Tables/cba_similarity/cba_similarity_decomp_table.tex
      Body table: two panels (UntreatedMove, TreatedMove) x four measures.
      Same row layout as cba_similarity_table.tex.

  Tables/cba_similarity/cba_similarity_decomp_full_table.tex
      Appendix: five sub-panels (delta, um, tm, ta, ua) x four measures.
      Ends with a coefficient-identity row:
         beta(delta) - beta(um) - beta(ta)   and   beta(delta) - beta(tm) - beta(ua).

Reads:
  Tables/cba_similarity/results_spill_cba_similarity_decomp.csv
"""

from pathlib import Path

import pandas as pd

tables_dir = Path(__file__).resolve().parent.parent.parent / "Tables" / "cba_similarity"
csv_path   = tables_dir / "results_spill_cba_similarity_decomp.csv"
out_body   = tables_dir / "cba_similarity_decomp_table.tex"
out_full   = tables_dir / "cba_similarity_decomp_full_table.tex"

MEASURES   = ["cosine", "bray_curtis", "total_variation", "ruzicka"]
COL_LABELS = ["Cosine", "Bray-Curtis", "Total Var.", "Ruzicka"]
SPEC       = "cba_similarity_decomp"

OUTCOME_LABELS = {
    "delta": r"$\Delta S$",
    "um":    r"UntreatedMove",
    "tm":    r"TreatedMove",
    "ta":    r"TreatedAdditional",
    "ua":    r"UntreatedAdditional",
}

# ── Load CSV ──────────────────────────────────────────────────────────────────
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
    if v != v:  # NaN
        return "--"
    if abs(v) < 1e-4:
        return f"{v:.2e}"
    return f"{v:.4f}"


# ── Build single-outcome panel (rows shared by both tables) ──────────────────
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


# ── Body table: UntreatedMove + TreatedMove (base FE only) ───────────────────
ncols    = len(MEASURES) + 1
col_spec = "l" + "c" * len(MEASURES)
col_hdr  = " & " + " & ".join(f"({i+1})" for i in range(len(MEASURES))) + r" \\"
col_lbl  = " & " + " & ".join(r"\textbf{" + l + r"}" for l in COL_LABELS) + r" \\"

body = [
    r"\begin{table}[H]",
    r"\centering",
    r"\caption{Ordered Decomposition of CBA Similarity: Who Moved?}",
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
    (r"\scriptsize\textit{Notes:} This table decomposes the change in CBA-content "
     r"similarity into two ordered counterfactuals. For each untreated focal firm "
     r"$i$ and CBA period $t$, let $u_{it}$ be its clause vector, $T_{it}$ the "
     r"flow-weighted average clause vector of connected treated partners with a "
     r"CBA at $t$, and $u_{i2}$ and $T_{i2}$ the corresponding period-2 anchors. "
     r"\textsc{UntreatedMove} regresses $S(u_{it}, T_{i2})$ on connectivity "
     r"$\times$ post, holding the treated reference frozen at its last "
     r"pre-reform value. \textsc{TreatedMove} regresses $S(u_{i2}, T_{it})$, "
     r"holding the focal firm frozen at its last pre-reform CBA. With "
     r"establishment fixed effects the constant $S(u_{i2}, T_{i2})$ is absorbed. "
     r"All regressions use the spillover sample (lagos balanced panel, untreated "
     r"focal with at least one treated partner having a CBA in both period $t$ "
     r"and period $2$) and include establishment, industry $\times$ period, "
     r"mode-month $\times$ period, microregion $\times$ period, and "
     r"pre-treatment outcome/employment/total-flow quartile fixed effects. "
     r"Connectivity is scaled to 1 at the 90th percentile of the spillover "
     r"sample. Standard errors clustered at the establishment level. "
     r"*\,$p<0.10$, **\,$p<0.05$, ***\,$p<0.01$."),
    r"\end{minipage}",
    r"\end{table}",
]

out_body.write_text("\n".join(body) + "\n")
print(f"Body table written to {out_body}")


# ── Full / appendix table: all five outcomes + identity check ────────────────
# Compute identity residuals from the CSV: beta(delta) - beta(um) - beta(ta)
identity_lines = []
ident1_cells = []
ident2_cells = []
for m in MEASURES:
    b_delta = coef_no_stars(get(f"delta_{m}", "main"))
    b_um    = coef_no_stars(get(f"um_{m}",    "main"))
    b_tm    = coef_no_stars(get(f"tm_{m}",    "main"))
    b_ta    = coef_no_stars(get(f"ta_{m}",    "main"))
    b_ua    = coef_no_stars(get(f"ua_{m}",    "main"))
    ident1 = b_delta - b_um - b_ta
    ident2 = b_delta - b_tm - b_ua
    ident1_cells.append(fmt_resid(ident1))
    ident2_cells.append(fmt_resid(ident2))

full = [
    r"\begin{table}[H]",
    r"\centering",
    r"\caption{Ordered Decomposition: Full Five-Outcome Breakdown}",
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
    (r"\scriptsize\textit{Notes:} This appendix table reports all five outcomes "
     r"in the ordered decomposition of the CBA-similarity change. $\Delta S$ is "
     r"the headline similarity $S(u_{it}, T_{it})$, with the period-2 constant "
     r"$S(u_{i2}, T_{i2})$ absorbed by establishment fixed effects. "
     r"\textsc{UntreatedMove} ($S(u_{it}, T_{i2})$) and \textsc{TreatedMove} "
     r"($S(u_{i2}, T_{it})$) hold one side fixed at the pre-reform anchor. "
     r"\textsc{TreatedAdditional} $\equiv \Delta S - \textsc{UntreatedMove}$ and "
     r"\textsc{UntreatedAdditional} $\equiv \Delta S - \textsc{TreatedMove}$ "
     r"complete the two ordered decompositions algebraically. Because OLS is "
     r"linear and all five regressions share the same sample and fixed-effect "
     r"structure, $\hat\beta_{\Delta S} = \hat\beta_{\text{UM}} + "
     r"\hat\beta_{\text{TA}} = \hat\beta_{\text{TM}} + \hat\beta_{\text{UA}}$ "
     r"holds to machine precision; the last two rows verify this. Standard "
     r"errors clustered at the establishment level. *\,$p<0.10$, "
     r"**\,$p<0.05$, ***\,$p<0.01$."),
    r"\end{minipage}",
    r"\end{table}",
]

out_full.write_text("\n".join(full) + "\n")
print(f"Full table written to {out_full}")
