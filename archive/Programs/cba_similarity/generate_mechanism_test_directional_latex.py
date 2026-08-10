"""
generate_mechanism_test_directional_latex.py

Reads three CSVs:
  Tables/cba_similarity/mechanism_test_results_all.csv          (treated side)
  Tables/cba_similarity/mechanism_test_results_untreated_all.csv (untreated side)
  Tables/cba_similarity/mechanism_test_results_pooled_all.csv    (pooled / interaction)

Produces FOUR LaTeX comparison tables:

  Estab-cluster, year FE only (meeting version):
    Tables/cba_similarity/mechanism_test_directional_yearonly.tex
  Estab-cluster, all 3 FE sub-panels (full version):
    Tables/cba_similarity/mechanism_test_directional.tex
  Firm-cluster, year FE only:
    Tables/cba_similarity/mechanism_test_directional_yearonly_firmcluster.tex
  Firm-cluster, all 3 FE sub-panels:
    Tables/cba_similarity/mechanism_test_directional_firmcluster.tex

Each table has 4 columns (Raw, Gap, Surplus, Joint). Within each panel
(Main / Placebo), each RHS variable has three sub-rows:
  - Treated firms β (SE)
  - Untreated firms β (SE)
  - Diff p-value (β_T = β_U from the pooled interaction term)
"""

from pathlib import Path
import math
import pandas as pd

# ── Paths ─────────────────────────────────────────────────────────────────────
this_dir     = Path(__file__).resolve().parent
project_root = this_dir.parent.parent
tables_dir   = project_root / "Tables" / "cba_similarity"
csv_t        = tables_dir / "mechanism_test_results_all.csv"
csv_u        = tables_dir / "mechanism_test_results_untreated_all.csv"
csv_p        = tables_dir / "mechanism_test_results_pooled_all.csv"

# ── Load all CSVs ─────────────────────────────────────────────────────────────
df_t = pd.read_csv(csv_t)
df_u = pd.read_csv(csv_u)
df_p = pd.read_csv(csv_p)
for d in (df_t, df_u, df_p):
    for c in ["var", "spec", "sample", "fe", "cluster"]:
        d[c] = d[c].astype(str).str.strip()

FE_LABELS = {
    "year":              "Year FE",
    "clause_x_year":     r"Clause type $\times$ year FE",
    "modeunion_x_year":  r"Mode union $\times$ year FE",
}
COL_HEADERS = [
    r"\shortstack{Raw \\ alone}",
    r"\shortstack{Gap \\ alone}",
    r"\shortstack{Surplus \\ alone}",
    r"Joint",
]


def stars(coef, se):
    if pd.isna(coef) or pd.isna(se) or se <= 0:
        return ""
    t = abs(coef / se)
    if t > 2.576: return r"^{***}"
    if t > 1.960: return r"^{**}"
    if t > 1.645: return r"^{*}"
    return ""


def stars_p(p):
    if pd.isna(p):
        return ""
    if p < 0.01:  return r"^{***}"
    if p < 0.05:  return r"^{**}"
    if p < 0.10:  return r"^{*}"
    return ""


def fmt_coef(row):
    if row is None:
        return ""
    return f"${row.coef:.3f}{stars(row.coef, row.se)}$"


def fmt_se(row):
    if row is None:
        return ""
    return f"$({row.se:.3f})$"


def fmt_p(p):
    if pd.isna(p):
        return ""
    s = stars_p(p)
    if p < 1e-3:
        return rf"$<\!0.001{s}$"
    return rf"${p:.3f}{s}$"


def fmt_n(n):
    if n is None or pd.isna(n):
        return ""
    return f"{int(n):,}"


def get_row(df, sample, spec, var, fe, cluster):
    sub = df[(df["sample"] == sample) & (df["spec"] == spec) &
            (df["var"] == var) & (df["fe"] == fe) & (df["cluster"] == cluster)]
    return sub.iloc[0] if len(sub) > 0 else None


def _norm_cdf(x):
    return 0.5 * (1.0 + math.erf(x / math.sqrt(2.0)))


def _diff_p_row(df, sample, spec, var, fe, cluster):
    """Two-sided z-test that the pooled interaction coefficient is zero
    (i.e. treated and untreated convergence rates are equal)."""
    rw = get_row(df, sample, spec, var, fe, cluster)
    if rw is None or pd.isna(rw.coef) or pd.isna(rw.se) or rw.se <= 0:
        return None
    z = abs(rw.coef / rw.se)
    return 2 * (1 - _norm_cdf(z))


def build_subpanel(sample, fe, cluster, show_fe_label):
    """Build one FE sub-panel: 4 cols × Treated/Untreated/Diff rows for
    raw_gap, gap, surplus interactions."""
    suffix = "post" if sample == "main" else "placebo"
    interact_label = suffix
    gap_var     = f"gap_{suffix}"
    surplus_var = f"surplus_{suffix}"
    raw_var     = f"raw_gap_{suffix}"

    # Treated side rows
    t_g_alone   = get_row(df_t, sample, "alone", gap_var,     fe, cluster)
    t_s_alone   = get_row(df_t, sample, "alone", surplus_var, fe, cluster)
    t_r_alone   = get_row(df_t, sample, "alone", raw_var,     fe, cluster)
    t_g_joint   = get_row(df_t, sample, "joint", gap_var,     fe, cluster)
    t_s_joint   = get_row(df_t, sample, "joint", surplus_var, fe, cluster)

    # Untreated side rows
    u_g_alone   = get_row(df_u, sample, "alone", gap_var,     fe, cluster)
    u_s_alone   = get_row(df_u, sample, "alone", surplus_var, fe, cluster)
    u_r_alone   = get_row(df_u, sample, "alone", raw_var,     fe, cluster)
    u_g_joint   = get_row(df_u, sample, "joint", gap_var,     fe, cluster)
    u_s_joint   = get_row(df_u, sample, "joint", surplus_var, fe, cluster)

    # Pooled interaction p-values: var = <var>_xT (two-sided z-test β_xT = 0).
    p_g_alone = _diff_p_row(df_p, sample, "alone", f"gap_{suffix}_xT",     fe, cluster)
    p_s_alone = _diff_p_row(df_p, sample, "alone", f"surplus_{suffix}_xT", fe, cluster)
    p_r_alone = _diff_p_row(df_p, sample, "alone", f"raw_gap_{suffix}_xT", fe, cluster)
    p_g_joint = _diff_p_row(df_p, sample, "joint", f"gap_{suffix}_xT",     fe, cluster)
    p_s_joint = _diff_p_row(df_p, sample, "joint", f"surplus_{suffix}_xT", fe, cluster)

    out = []
    if show_fe_label:
        out.append(r"\multicolumn{5}{l}{\textit{" + FE_LABELS[fe] + r"}} \\")

    def block(varname, coef_label, t_alone, u_alone, t_joint, u_joint,
              p_alone, p_joint, col_alone):
        """Emit one RHS-variable block (Treated row, Untreated row, Diff p-row)
        with values placed in `col_alone` (1, 2, or 3) and in col 4 for joint
        (only if t_joint is not None)."""
        rows = []
        # Header row for this RHS variable (italic, spans label column only)
        rows.append(rf"\multicolumn{{5}}{{l}}{{$\text{{{varname}}} \times \text{{{interact_label}}}$}} \\")
        # Treated coef row
        cells = ["", "", "", ""]
        cells[col_alone - 1] = fmt_coef(t_alone)
        if t_joint is not None:
            cells[3] = fmt_coef(t_joint)
        rows.append(rf"$\quad$ Treated & " + " & ".join(cells) + r" \\")
        cells = ["", "", "", ""]
        cells[col_alone - 1] = fmt_se(t_alone)
        if t_joint is not None:
            cells[3] = fmt_se(t_joint)
        rows.append(rf" & " + " & ".join(cells) + r" \\")
        # Untreated coef row
        cells = ["", "", "", ""]
        cells[col_alone - 1] = fmt_coef(u_alone)
        if u_joint is not None:
            cells[3] = fmt_coef(u_joint)
        rows.append(rf"$\quad$ Untreated & " + " & ".join(cells) + r" \\")
        cells = ["", "", "", ""]
        cells[col_alone - 1] = fmt_se(u_alone)
        if u_joint is not None:
            cells[3] = fmt_se(u_joint)
        rows.append(rf" & " + " & ".join(cells) + r" \\")
        # Diff p-value row
        cells = ["", "", "", ""]
        cells[col_alone - 1] = fmt_p(p_alone)
        if p_joint is not None:
            cells[3] = fmt_p(p_joint)
        rows.append(rf"$\quad$ T = U $p$-val & " + " & ".join(cells) + r" \\")
        return "\n".join(rows)

    out.append(block("raw\\_gap", "raw_gap",
                     t_r_alone, u_r_alone, None,      None,
                     p_r_alone, None,
                     col_alone=1))
    out.append(r"\addlinespace[2pt]")
    out.append(block("gap",       "gap",
                     t_g_alone, u_g_alone, t_g_joint, u_g_joint,
                     p_g_alone, p_g_joint,
                     col_alone=2))
    out.append(r"\addlinespace[2pt]")
    out.append(block("surplus",   "surplus",
                     t_s_alone, u_s_alone, t_s_joint, u_s_joint,
                     p_s_alone, p_s_joint,
                     col_alone=3))

    # Sample sizes — per column (regression-specific). N and # establishments
    # both come from the displayed-cluster regression (which is always estab,
    # i.e. 14-digit identificad).
    col_t_rows = [t_r_alone, t_g_alone, t_s_alone, t_g_joint]
    col_u_rows = [u_r_alone, u_g_alone, u_s_alone, u_g_joint]
    n_t  = [int(rw["N"])       if rw is not None else None for rw in col_t_rows]
    n_u  = [int(rw["N"])       if rw is not None else None for rw in col_u_rows]
    nf_t = [int(rw["N_clust"]) if rw is not None else None for rw in col_t_rows]
    nf_u = [int(rw["N_clust"]) if rw is not None else None for rw in col_u_rows]

    def _per_col_row(label, vals):
        return rf"{label} & " + " & ".join(fmt_n(v) for v in vals) + r" \\"

    out.append(r"\addlinespace[2pt]")
    out.append(_per_col_row(r"$N$ (T)",                n_t))
    out.append(_per_col_row(r"$N$ (U)",                n_u))
    out.append(_per_col_row(r"\# establishments (T)",  nf_t))
    out.append(_per_col_row(r"\# establishments (U)",  nf_u))

    return "\n".join(out)


def build_table(cluster, fe_list, output_path, table_label, table_caption):
    show_fe = len(fe_list) > 1

    header_nums = " & ".join([""] + [f"({i+1})" for i in range(4)]) + r" \\"
    header_lbls = " & ".join([""] + COL_HEADERS) + r" \\"

    panels = []
    panels.append(r"\multicolumn{5}{l}{\textit{Panel A: Main sample. $\text{post} = \mathbf{1}\{cba\_period \geq 3\}$}} \\")
    panels.append(r"\midrule")
    for i, fe in enumerate(fe_list):
        panels.append(build_subpanel("main", fe, cluster, show_fe_label=show_fe))
        if i < len(fe_list) - 1:
            panels.append(r"\addlinespace")
    panels.append(r"\midrule")
    panels.append(r"\multicolumn{5}{l}{\textit{Panel B: Placebo (pre-period only). $\text{placebo} = \mathbf{1}\{cba\_period = 1\}$ (cba\_period 2 = base)}} \\")
    panels.append(r"\midrule")
    for i, fe in enumerate(fe_list):
        panels.append(build_subpanel("placebo", fe, cluster, show_fe_label=show_fe))
        if i < len(fe_list) - 1:
            panels.append(r"\addlinespace")

    cluster_note = (
        r"Standard errors clustered at the establishment level "
        r"(\texttt{identificad}, 14-digit CNPJ)."
    )

    note = (
        r"\textit{Notes:} This table compares the gap-filling response on the treated and untreated "
        r"sides of the worker-flow network. The Treated row reports $\beta$ from "
        r"$cl\_count_{ict} = \beta\,(X_{ic} \times T_t) + \alpha_{ic} + \alpha_{ft} + \varepsilon_{ict}$ "
        r"on treated balanced-panel firms, where $\bar c_{-i,c}$ in $X_{ic}$ averages over $i$'s "
        r"\textit{untreated} worker-flow partners. The Untreated row reports the mirror specification "
        r"on untreated balanced-panel firms, where $\bar c_{-i,c}$ averages over $i$'s \textit{treated} "
        r"worker-flow partners. The T = U $p$-value comes from a pooled regression that stacks both "
        r"sides and includes a triple interaction $X_{ic} \times T_t \times \text{Treated}_i$; the "
        r"$p$-value is the Wald test that the triple-interaction coefficient is zero, i.e.\ that both "
        r"sides converge at the same rate. $X_{ic}$ is one of: "
        r"$\text{gap}_{ic} = \max(0, \bar{c}_{-i,c} - c^{\text{pre}}_{ic})$, "
        r"$\text{surplus}_{ic} = \max(0, c^{\text{pre}}_{ic} - \bar{c}_{-i,c})$, or "
        r"$\text{raw\_gap}_{ic} = \bar{c}_{-i,c} - c^{\text{pre}}_{ic}$. "
        r"Connectivity weights are the average of the four pre-treatment year-pair flow ratios in "
        r"2007--2011. $\alpha_{ic}$ is an establishment $\times$ clause-type fixed effect. "
        r"\# establishments is the count of distinct \texttt{identificad} (14-digit CNPJ) in the "
        r"regression sample. The placebo panel restricts to $cba\_period \in \{1, 2\}$ and replaces "
        r"$T_t$ with $\mathbf{1}\{cba\_period = 1\}$ (cycle 2 is the base period). " + cluster_note + " "
        r"$^{***}p<0.01$, $^{**}p<0.05$, $^{*}p<0.10$."
    )

    panels_str = "\n".join(panels)
    tex = (
        r"\begin{table}[H]" + "\n"
        r"\centering" + "\n"
        rf"\caption{{{table_caption}}}" + "\n"
        rf"\label{{{table_label}}}" + "\n"
        r"\scriptsize" + "\n"
        r"\begin{tabular}{lcccc}" + "\n"
        r"\toprule\toprule" + "\n"
        f"{header_nums}\n"
        f"{header_lbls}\n"
        r"\midrule" + "\n"
        f"{panels_str}\n"
        r"\bottomrule" + "\n"
        r"\end{tabular}" + "\n"
        r"\begin{minipage}{\linewidth}" + "\n"
        r"\footnotesize\vspace{4pt}" + "\n"
        f"{note}\n"
        r"\end{minipage}" + "\n"
        r"\end{table}" + "\n"
    )
    output_path.write_text(tex)
    print(f"Wrote {output_path.name}")


# ── Generate 2 tables (estab cluster only — 14-digit identificad) ─────────────
build_table(
    cluster="estab",
    fe_list=["year"],
    output_path=tables_dir / "mechanism_test_directional_yearonly.tex",
    table_label="tab:mechanism_test_directional_yearonly",
    table_caption="Directional mechanism test (year FE only): treated vs.\\ untreated convergence rates",
)
build_table(
    cluster="estab",
    fe_list=["year", "clause_x_year", "modeunion_x_year"],
    output_path=tables_dir / "mechanism_test_directional.tex",
    table_label="tab:mechanism_test_directional",
    table_caption="Directional mechanism test: treated vs.\\ untreated convergence rates",
)
