"""
generate_dotprod_decomposition_latex.py

A/B/C/cross bilinear decomposition with pretrend-aware anchors.

Reads two CSVs and writes two LaTeX tables (one for raw counts, one for
shares). Each table has four outcome columns:
    A         = u_t  . T_t
    B         = u_bar . T_t
    C         = u_t  . T_bar
    cross     = (u_t - u_bar) . (T_t - T_bar)
    B+C+cross = identity check

Verifies beta_A = beta_B + beta_C + beta_cross to machine tolerance
(should hold exactly under firm FE). Reports the residual in the
caption.
"""

import pandas as pd
import numpy as np
from pathlib import Path

tables_dir = Path(__file__).resolve().parent.parent.parent / "Tables" / "cba_similarity"


def parse_val(s):
    """Strip quotes/commas/asterisks and try to float. Returns (number, stars)."""
    s = str(s).strip().strip('"').replace(",", "")
    stars = ""
    while s.endswith("*"):
        stars += "*"
        s = s[:-1]
    try:
        return float(s), stars
    except Exception:
        return np.nan, stars


def fmt_coef(val, stars=""):
    if val is None or (isinstance(val, float) and np.isnan(val)):
        return "---"
    return f"{val:.4f}{stars}"


def fmt_se(val):
    if val is None or (isinstance(val, float) and np.isnan(val)):
        return "---"
    return f"({val:.4f})"


def fmt_n(val):
    if val is None or (isinstance(val, float) and np.isnan(val)):
        return "---"
    return f"{int(val):,}"


def fmt_pval(val):
    if val is None or (isinstance(val, float) and np.isnan(val)):
        return "---"
    return f"{val:.3f}"


def fmt_mean(val):
    if val is None or (isinstance(val, float) and np.isnan(val)):
        return "---"
    return f"{val:.4f}"


def load_csv(path):
    df = pd.read_csv(path, sep=";", header=0,
                     names=["spec", "section", "outcome", "row_type", "value"])
    df["value"] = df["value"].astype(str).str.strip().str.strip('"')
    return df


def get_pair(df, spec, outcome, row_type):
    rows = df[(df.spec == spec) & (df.outcome == outcome) & (df.row_type == row_type)]
    if len(rows) == 0:
        return np.nan, ""
    return parse_val(rows["value"].iloc[0])


def panel_block(df, spec, outcomes):
    rows = {}
    for o in outcomes:
        rows[o] = {
            "main":          parse_val(df.loc[(df.spec == spec) & (df.outcome == o) & (df.row_type == "main"),    "value"].iloc[0])[0]
                              if not df[(df.spec == spec) & (df.outcome == o) & (df.row_type == "main")].empty else np.nan,
            "main_stars":    parse_val(df.loc[(df.spec == spec) & (df.outcome == o) & (df.row_type == "main"),    "value"].iloc[0])[1]
                              if not df[(df.spec == spec) & (df.outcome == o) & (df.row_type == "main")].empty else "",
            "main_se":       parse_val(df.loc[(df.spec == spec) & (df.outcome == o) & (df.row_type == "main_se"), "value"].iloc[0])[0]
                              if not df[(df.spec == spec) & (df.outcome == o) & (df.row_type == "main_se")].empty else np.nan,
            "pre":           parse_val(df.loc[(df.spec == spec) & (df.outcome == o) & (df.row_type == "pre"),     "value"].iloc[0])[0]
                              if not df[(df.spec == spec) & (df.outcome == o) & (df.row_type == "pre")].empty else np.nan,
            "pre_stars":     parse_val(df.loc[(df.spec == spec) & (df.outcome == o) & (df.row_type == "pre"),     "value"].iloc[0])[1]
                              if not df[(df.spec == spec) & (df.outcome == o) & (df.row_type == "pre")].empty else "",
            "pre_se":        parse_val(df.loc[(df.spec == spec) & (df.outcome == o) & (df.row_type == "pre_se"),  "value"].iloc[0])[0]
                              if not df[(df.spec == spec) & (df.outcome == o) & (df.row_type == "pre_se")].empty else np.nan,
            "bmean":         parse_val(df.loc[(df.spec == spec) & (df.outcome == o) & (df.row_type == "baseline_mean"), "value"].iloc[0])[0]
                              if not df[(df.spec == spec) & (df.outcome == o) & (df.row_type == "baseline_mean")].empty else np.nan,
            "n":             parse_val(df.loc[(df.spec == spec) & (df.outcome == o) & (df.row_type == "n_obs"),   "value"].iloc[0])[0]
                              if not df[(df.spec == spec) & (df.outcome == o) & (df.row_type == "n_obs")].empty else np.nan,
            "nest":          parse_val(df.loc[(df.spec == spec) & (df.outcome == o) & (df.row_type == "n_estab"), "value"].iloc[0])[0]
                              if not df[(df.spec == spec) & (df.outcome == o) & (df.row_type == "n_estab")].empty else np.nan,
            "pval":          parse_val(df.loc[(df.spec == spec) & (df.outcome == o) & (df.row_type == "pre_pval"),"value"].iloc[0])[0]
                              if not df[(df.spec == spec) & (df.outcome == o) & (df.row_type == "pre_pval")].empty else np.nan,
        }
    return rows


def make_row(label, cells, bold=False):
    label_tex = r"\textbf{" + label + r"}" if bold else label
    return label_tex + " & " + " & ".join(cells) + r" \\"


def build_table(version, csv_path, tex_path, title, baseline_label):

    df = load_csv(csv_path)

    outcomes_short = ["A", "B", "C", "cross"]
    outcomes_var   = [f"dot_{version}_{o}" for o in outcomes_short]
    col_labels     = [r"$A$", r"$B$", r"$C$", r"$\text{cross}$", r"$B{+}C{+}\text{cross}$"]
    ncols          = len(col_labels) + 1
    col_spec       = "l" + "c" * len(col_labels)
    col_header     = " & " + " & ".join([f"({i+1})" for i in range(len(col_labels))]) + r" \\"
    col_labels_row = " & " + " & ".join([r"\textbf{" + lbl + r"}" for lbl in col_labels]) + r" \\"

    spec_base  = f"dotprod_{version}"
    spec_union = f"dotprod_{version}_union"

    rows_base  = panel_block(df, spec_base,  outcomes_var)
    rows_union = panel_block(df, spec_union, outcomes_var)

    # Identity check: beta_A = beta_B + beta_C + beta_cross (main)
    def identity_resid(rows):
        return rows[outcomes_var[0]]["main"] - (
            rows[outcomes_var[1]]["main"] + rows[outcomes_var[2]]["main"] + rows[outcomes_var[3]]["main"]
        )
    resid_base  = identity_resid(rows_base)
    resid_union = identity_resid(rows_union)
    print(f"  identity residual ({version}, base FE):  {resid_base:+.3e}")
    print(f"  identity residual ({version}, union FE): {resid_union:+.3e}")

    def panel_rows(rows):
        sumBCcross_main = (rows[outcomes_var[1]]["main"]
                           + rows[outcomes_var[2]]["main"]
                           + rows[outcomes_var[3]]["main"])
        sumBCcross_main_se = np.sqrt(
            (rows[outcomes_var[1]]["main_se"] or 0)**2
            + (rows[outcomes_var[2]]["main_se"] or 0)**2
            + (rows[outcomes_var[3]]["main_se"] or 0)**2
        )
        sumBCcross_pre = (rows[outcomes_var[1]]["pre"]
                          + rows[outcomes_var[2]]["pre"]
                          + rows[outcomes_var[3]]["pre"])
        sumBCcross_pre_se = np.sqrt(
            (rows[outcomes_var[1]]["pre_se"] or 0)**2
            + (rows[outcomes_var[2]]["pre_se"] or 0)**2
            + (rows[outcomes_var[3]]["pre_se"] or 0)**2
        )

        cells_post = [
            fmt_coef(rows[o]["main"], rows[o]["main_stars"]) for o in outcomes_var
        ] + [fmt_coef(sumBCcross_main)]

        cells_post_se = [
            fmt_se(rows[o]["main_se"]) for o in outcomes_var
        ] + [fmt_se(sumBCcross_main_se) + r"$^\dagger$"]

        cells_pre = [
            fmt_coef(rows[o]["pre"], rows[o]["pre_stars"]) for o in outcomes_var
        ] + [fmt_coef(sumBCcross_pre)]

        cells_pre_se = [
            fmt_se(rows[o]["pre_se"]) for o in outcomes_var
        ] + [fmt_se(sumBCcross_pre_se) + r"$^\dagger$"]

        cells_bmean = [fmt_mean(rows[o]["bmean"]) for o in outcomes_var] + ["---"]
        cells_n     = [fmt_n(rows[o]["n"])     for o in outcomes_var] + ["---"]
        cells_nest  = [fmt_n(rows[o]["nest"])  for o in outcomes_var] + ["---"]
        cells_pval  = [fmt_pval(rows[o]["pval"]) for o in outcomes_var] + ["---"]

        return cells_post, cells_post_se, cells_pre, cells_pre_se, cells_bmean, cells_n, cells_nest, cells_pval

    def panel(label_text, rows, identity_resid):
        post, post_se, pre, pre_se, bmean, n, nest, pval = panel_rows(rows)
        return [
            rf"\multicolumn{{{ncols}}}{{l}}{{\textit{{{label_text} \quad (identity residual $= {identity_resid:+.2e}$)}}}} \\",
            make_row(r"Connectivity $\times$ Post", post),
            make_row("", post_se),
            make_row(r"Connectivity $\times$ Pre",  pre),
            make_row("", pre_se),
            make_row(baseline_label, bmean),
            make_row("Observations",        n),
            make_row("Establishments",      nest),
            make_row("Pre-trend $p$-value", pval),
            r"\hline",
        ]

    lines = [
        r"\begin{table}[H]",
        r"\centering",
        rf"\caption{{{title}}}",
        rf"\label{{tab:dotprod_{version}_decomposition}}",
        r"\scriptsize",
        r"\setlength{\tabcolsep}{6pt}",
        r"\begin{tabular}{" + col_spec + r"}",
        r"\hline\hline",
        col_header,
        col_labels_row,
        r"\hline",
        *panel("Panel A: Baseline FE", rows_base, resid_base),
        *panel(r"Panel B: Adding union $\times$ period FE", rows_union, resid_union),
        r"\hline\hline",
        r"\end{tabular}",
        r"\begin{minipage}{\linewidth}",
        r"\smallskip",
        (
            r"\scriptsize\textit{Notes:} This table reports the bilinear A/B/C/cross "
            r"decomposition of the connectivity-driven approximation of untreated firms' "
            r"CBAs toward their treated counterparts' CBAs, using the "
            + ("\\emph{raw clause counts} " if version == "raw" else "\\emph{clause-share vectors} ")
            + r"as the outcome. For each untreated firm $i$ and CBA period $t$, the "
            r"outcomes are: $A = "
            + ("u_t \\cdot T_t" if version == "raw" else "s_{u,t} \\cdot s_{T,t}")
            + r"$ (both moving); $B = "
            + ("\\bar u_i \\cdot T_t" if version == "raw" else "\\bar s_{u,i} \\cdot s_{T,t}")
            + r"$ (focal anchored at pre-treatment average); $C = "
            + ("u_t \\cdot \\bar T_i" if version == "raw" else "s_{u,t} \\cdot \\bar s_{T,i}")
            + r"$ (partners anchored at pre-treatment average); $\text{cross} = "
            + ("(u_t - \\bar u_i) \\cdot (T_t - \\bar T_i)" if version == "raw"
               else "(s_{u,t} - \\bar s_{u,i}) \\cdot (s_{T,t} - \\bar s_{T,i})")
            + r"$ (interaction of focal and partner shifts around their pre-treatment "
            r"anchors). Anchors are firm-specific averages over $t \in \{1, 2\}$; firm "
            r"fixed effects absorb the firm-specific constant $\bar u_i \cdot \bar T_i$ "
            r"(resp.\ $\bar s_{u,i} \cdot \bar s_{T,i}$), so by linearity of OLS the "
            r"identity $\hat\beta_A = \hat\beta_B + \hat\beta_C + \hat\beta_{\text{cross}}$ "
            r"holds exactly; the residual is reported per panel. The "
            r"$B{+}C{+}\text{cross}$ column reports the algebraic sum of the three "
            r"single-outcome coefficients (and the root-sum-of-squared SEs, $^\dagger$, "
            r"which is an upper bound under perfect positive correlation; the true SE "
            r"of the sum is the SE of the $A$ column). Connectivity weights are "
            r"uncorrected per-worker bilateral flows (\texttt{bilateral\_conn\_pw}), "
            r"identical to Exercises A/B/C. Connectivity is scaled to 1 at the 90th "
            r"percentile of the spillover sample at year 2009. Pre regression is the "
            r"placebo on the within-pre-window contrast ($\text{cba\_period} \in \{1,2\}$); "
            r"for the $\text{cross}$ outcome this regression is mechanically degenerate "
            r"because $(u_t - \bar u_i)(T_t - \bar T_i)$ is constant within firm across "
            r"the two pre-periods (the symmetric anchor implies $u_1 - \bar u_i = "
            r"-(u_2 - \bar u_i)$), so we report $\beta_{\text{cross}}^{\text{pre}} \equiv 0$. "
            r"Sample restriction: untreated firms in the lagos balanced spillover panel. "
            r"Panel A includes establishment, industry $\times$ period, mode-month "
            r"$\times$ period, microregion $\times$ period FE; Panel B adds union "
            r"$\times$ period. Standard errors clustered at the establishment level. "
            r"*\,$p<0.10$, **\,$p<0.05$, ***\,$p<0.01$."
        ),
        r"\end{minipage}",
        r"\end{table}",
    ]

    tex_path.write_text("\n".join(lines) + "\n")
    print(f"LaTeX table written to {tex_path}")


# ── Run for both versions ─────────────────────────────────────────────────────
build_table(
    version          = "raw",
    csv_path         = tables_dir / "results_spill_dotprod_raw.csv",
    tex_path         = tables_dir / "dotprod_raw_decomposition_table.tex",
    title            = "Bilinear A/B/C/Cross Decomposition: Raw Clause Counts (Pretrend-Anchored)",
    baseline_label   = "Baseline mean (period 2)",
)

build_table(
    version          = "shares",
    csv_path         = tables_dir / "results_spill_dotprod_shares.csv",
    tex_path         = tables_dir / "dotprod_shares_decomposition_table.tex",
    title            = "Bilinear A/B/C/Cross Decomposition: Clause Shares (Pretrend-Anchored)",
    baseline_label   = "Baseline mean (period 2)",
)


# ── Cosine A/B/C (pretrend-anchored) — no bilinear identity ──────────────────
def build_cosine_table():
    csv_path = tables_dir / "results_spill_cosine_pretrend_anchored.csv"
    tex_path = tables_dir / "cosine_pretrend_anchored_table.tex"

    df = load_csv(csv_path)
    outcomes_var = ["cos_A", "cos_B", "cos_C"]
    col_labels   = [r"$A:\,\cos(u_t,\,T_t)$",
                    r"$B:\,\cos(\bar u_i,\,T_t)$",
                    r"$C:\,\cos(u_t,\,\bar T_i)$"]
    ncols        = len(col_labels) + 1
    col_spec     = "l" + "c" * len(col_labels)
    col_header   = " & " + " & ".join([f"({i+1})" for i in range(len(col_labels))]) + r" \\"
    col_labels_row = " & " + " & ".join([r"\textbf{" + lbl + r"}" for lbl in col_labels]) + r" \\"

    rows_base  = panel_block(df, "cosine_pretrend_anchored",       outcomes_var)
    rows_union = panel_block(df, "cosine_pretrend_anchored_union", outcomes_var)

    def panel(label_text, rows):
        cells_post    = [fmt_coef(rows[o]["main"], rows[o]["main_stars"]) for o in outcomes_var]
        cells_post_se = [fmt_se(  rows[o]["main_se"])                     for o in outcomes_var]
        cells_pre     = [fmt_coef(rows[o]["pre"],  rows[o]["pre_stars"])  for o in outcomes_var]
        cells_pre_se  = [fmt_se(  rows[o]["pre_se"])                      for o in outcomes_var]
        cells_bmean   = [fmt_mean(rows[o]["bmean"]) for o in outcomes_var]
        cells_n       = [fmt_n(rows[o]["n"])        for o in outcomes_var]
        cells_nest    = [fmt_n(rows[o]["nest"])     for o in outcomes_var]
        cells_pval    = [fmt_pval(rows[o]["pval"])  for o in outcomes_var]

        return [
            rf"\multicolumn{{{ncols}}}{{l}}{{\textit{{{label_text}}}}} \\",
            make_row(r"Connectivity $\times$ Post", cells_post),
            make_row("", cells_post_se),
            make_row(r"Connectivity $\times$ Pre",  cells_pre),
            make_row("", cells_pre_se),
            make_row("Baseline mean (period 2)",   cells_bmean),
            make_row("Observations",        cells_n),
            make_row("Establishments",      cells_nest),
            make_row("Pre-trend $p$-value", cells_pval),
            r"\hline",
        ]

    lines = [
        r"\begin{table}[H]",
        r"\centering",
        r"\caption{Cosine A/B/C with Pretrend-Corrected Anchors}",
        r"\label{tab:cosine_pretrend_anchored}",
        r"\scriptsize",
        r"\setlength{\tabcolsep}{8pt}",
        r"\begin{tabular}{" + col_spec + r"}",
        r"\hline\hline",
        col_header,
        col_labels_row,
        r"\hline",
        *panel("Panel A: Baseline FE",                     rows_base),
        *panel(r"Panel B: Adding union $\times$ period FE", rows_union),
        r"\hline\hline",
        r"\end{tabular}",
        r"\begin{minipage}{\linewidth}",
        r"\smallskip",
        (r"\scriptsize\textit{Notes:} This table reproduces the A/B/C cosine "
         r"decomposition but with anchors replaced by firm-specific pre-treatment "
         r"averages $\bar u_i$, $\bar T_i$ over $t \in \{1,2\}$, mirroring the "
         r"\texttt{pre\_treat\_cba} window used elsewhere in the pipeline. "
         r"Cosine is non-linear (denominator $\lVert u\rVert\,\lVert T\rVert$ is "
         r"non-linear in $u, T$), so the bilinear identity "
         r"$\hat\beta_A = \hat\beta_B + \hat\beta_C + \hat\beta_{\text{cross}}$ does "
         r"\emph{not} hold here; only three regressions are reported. Connectivity "
         r"weights, sample, and FE structure are identical to the bilinear "
         r"decomposition tables. Standard errors clustered at the establishment "
         r"level. *\,$p<0.10$, **\,$p<0.05$, ***\,$p<0.01$."),
        r"\end{minipage}",
        r"\end{table}",
    ]

    tex_path.write_text("\n".join(lines) + "\n")
    print(f"LaTeX table written to {tex_path}")


build_cosine_table()


# ── Ruzicka A/B/C (pretrend-anchored) — no bilinear identity ─────────────────
def build_ruzicka_table():
    csv_path = tables_dir / "results_spill_ruzicka_pretrend_anchored.csv"
    tex_path = tables_dir / "ruzicka_pretrend_anchored_table.tex"

    df = load_csv(csv_path)
    outcomes_var = ["ruz_A", "ruz_B", "ruz_C"]
    col_labels   = [r"$A:\,\text{ruz}(u_t,\,T_t)$",
                    r"$B:\,\text{ruz}(\bar u_i,\,T_t)$",
                    r"$C:\,\text{ruz}(u_t,\,\bar T_i)$"]
    ncols        = len(col_labels) + 1
    col_spec     = "l" + "c" * len(col_labels)
    col_header   = " & " + " & ".join([f"({i+1})" for i in range(len(col_labels))]) + r" \\"
    col_labels_row = " & " + " & ".join([r"\textbf{" + lbl + r"}" for lbl in col_labels]) + r" \\"

    rows_base  = panel_block(df, "ruzicka_pretrend_anchored",       outcomes_var)
    rows_union = panel_block(df, "ruzicka_pretrend_anchored_union", outcomes_var)

    def panel(label_text, rows):
        cells_post    = [fmt_coef(rows[o]["main"], rows[o]["main_stars"]) for o in outcomes_var]
        cells_post_se = [fmt_se(  rows[o]["main_se"])                     for o in outcomes_var]
        cells_pre     = [fmt_coef(rows[o]["pre"],  rows[o]["pre_stars"])  for o in outcomes_var]
        cells_pre_se  = [fmt_se(  rows[o]["pre_se"])                      for o in outcomes_var]
        cells_bmean   = [fmt_mean(rows[o]["bmean"]) for o in outcomes_var]
        cells_n       = [fmt_n(rows[o]["n"])        for o in outcomes_var]
        cells_nest    = [fmt_n(rows[o]["nest"])     for o in outcomes_var]
        cells_pval    = [fmt_pval(rows[o]["pval"])  for o in outcomes_var]

        return [
            rf"\multicolumn{{{ncols}}}{{l}}{{\textit{{{label_text}}}}} \\",
            make_row(r"Connectivity $\times$ Post", cells_post),
            make_row("", cells_post_se),
            make_row(r"Connectivity $\times$ Pre",  cells_pre),
            make_row("", cells_pre_se),
            make_row("Baseline mean (period 2)",   cells_bmean),
            make_row("Observations",        cells_n),
            make_row("Establishments",      cells_nest),
            make_row("Pre-trend $p$-value", cells_pval),
            r"\hline",
        ]

    lines = [
        r"\begin{table}[H]",
        r"\centering",
        r"\caption{Ruzicka (Weighted Jaccard) A/B/C with Pretrend-Corrected Anchors}",
        r"\label{tab:ruzicka_pretrend_anchored}",
        r"\scriptsize",
        r"\setlength{\tabcolsep}{8pt}",
        r"\begin{tabular}{" + col_spec + r"}",
        r"\hline\hline",
        col_header,
        col_labels_row,
        r"\hline",
        *panel("Panel A: Baseline FE",                     rows_base),
        *panel(r"Panel B: Adding union $\times$ period FE", rows_union),
        r"\hline\hline",
        r"\end{tabular}",
        r"\begin{minipage}{\linewidth}",
        r"\smallskip",
        (r"\scriptsize\textit{Notes:} This table reports the Ruzicka A/B/C "
         r"decomposition with firm-specific pre-treatment averages $\bar u_i$, "
         r"$\bar T_i$ over $t \in \{1,2\}$. Ruzicka similarity is "
         r"$\sum_k \min(u_k, T_k) / \sum_k \max(u_k, T_k)$ --- magnitude-sensitive "
         r"(unlike cosine, which is L2-normalized) and stricter than Bray-Curtis "
         r"(max in denominator rather than sum). Ruzicka is non-linear, so the "
         r"bilinear identity does \emph{not} hold; only three regressions are "
         r"reported. Connectivity weights, sample, and FE structure are identical "
         r"to the bilinear decomposition tables. Standard errors clustered at the "
         r"establishment level. *\,$p<0.10$, **\,$p<0.05$, ***\,$p<0.01$."),
        r"\end{minipage}",
        r"\end{table}",
    ]

    tex_path.write_text("\n".join(lines) + "\n")
    print(f"LaTeX table written to {tex_path}")


build_ruzicka_table()
