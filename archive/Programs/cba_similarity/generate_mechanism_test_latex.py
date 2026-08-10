"""
generate_mechanism_test_latex.py

Reads Tables/cba_similarity/mechanism_test_results_all.csv and produces TWO
LaTeX tables, both clustered at the firm level (14-digit identificad):

  Year FE only (meeting version):
    Tables/cba_similarity/mechanism_test_table_yearonly.tex
  All 3 FE sub-panels (full version):
    Tables/cba_similarity/mechanism_test_table.tex

Each table has 4 columns — one regression each: raw-alone, gap-alone,
surplus-alone, joint. Sym-test p-value is reported in the joint column.
# firms is N_clust from the firm-cluster regression (= count of distinct
14-digit identificad in the sample).

Note: in the master CSV, `cluster=estab` refers to vce(cluster identificad)
(14-digit) — which is this project's "firm" level. The legacy `cluster=firm`
rows (identificad8 = 8-digit CNPJ root) are not used here.
"""

from pathlib import Path
import pandas as pd

# ── Paths ─────────────────────────────────────────────────────────────────────
this_dir     = Path(__file__).resolve().parent
project_root = this_dir.parent.parent
tables_dir   = project_root / "Tables" / "cba_similarity"
csv_path     = tables_dir / "mechanism_test_results_all.csv"

# ── Load master CSV ───────────────────────────────────────────────────────────
df = pd.read_csv(csv_path)
for c in ["var", "spec", "sample", "fe", "cluster"]:
    df[c] = df[c].astype(str).str.strip()

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
    if p < 1e-3:
        return r"$<\!0.001$"
    return f"${p:.3f}$"


def fmt_n(n):
    if n is None or pd.isna(n):
        return ""
    return f"{int(n):,}"


def get_row(sample, spec, var, fe, cluster):
    sub = df[(df["sample"] == sample) & (df["spec"] == spec) &
             (df["var"] == var) & (df["fe"] == fe) & (df["cluster"] == cluster)]
    return sub.iloc[0] if len(sub) > 0 else None


def build_subpanel(sample, fe, cluster, show_fe_label):
    """Build one FE sub-panel (4 columns x several rows). If show_fe_label,
    prepend a sub-panel italic header naming the FE structure."""
    suffix = "post" if sample == "main" else "placebo"
    interact_label = suffix
    gap_var     = f"gap_{suffix}"
    surplus_var = f"surplus_{suffix}"
    raw_var     = f"raw_gap_{suffix}"

    g1 = get_row(sample, "alone", gap_var,     fe, cluster)
    s2 = get_row(sample, "alone", surplus_var, fe, cluster)
    r3 = get_row(sample, "alone", raw_var,     fe, cluster)
    g4 = get_row(sample, "joint", gap_var,     fe, cluster)
    s4 = get_row(sample, "joint", surplus_var, fe, cluster)

    out = []
    if show_fe_label:
        out.append(r"\multicolumn{5}{l}{\textit{" + FE_LABELS[fe] + r"}} \\")

    # raw_gap × T
    out.append(rf"$\text{{raw\_gap}} \times \text{{{interact_label}}}$ & "
               f"{fmt_coef(r3)} &  &  &  \\\\")
    out.append(rf" & {fmt_se(r3)} &  &  &  \\")

    # gap × T
    out.append(rf"$\text{{gap}} \times \text{{{interact_label}}}$ & "
               f" & {fmt_coef(g1)} &  & {fmt_coef(g4)} \\\\")
    out.append(rf" &  & {fmt_se(g1)} &  & {fmt_se(g4)} \\")

    # surplus × T
    out.append(rf"$\text{{surplus}} \times \text{{{interact_label}}}$ & "
               f" &  & {fmt_coef(s2)} & {fmt_coef(s4)} \\\\")
    out.append(rf" &  &  & {fmt_se(s2)} & {fmt_se(s4)} \\")

    # N and # firms — per-column. If all four regressions share the same N
    # (and same # firms), repeat the value in each column; otherwise show each.
    col_rows = [r3, g1, s2, g4]  # one regression per displayed column
    n_per_col = [int(rw["N"]) if rw is not None else None for rw in col_rows]

    # # firms = N_clust from the corresponding firm-cluster regression.
    def get_nfirms_for(spec, var):
        rw = get_row(sample, spec, var, fe, "firm")
        return int(rw["N_clust"]) if rw is not None else None
    nf_per_col = [
        get_nfirms_for("alone", raw_var),
        get_nfirms_for("alone", gap_var),
        get_nfirms_for("alone", surplus_var),
        get_nfirms_for("joint", gap_var),  # joint reg shared by gap & surplus
    ]

    def per_col_row(label, vals):
        cells = [fmt_n(v) for v in vals]
        return rf"{label} & " + " & ".join(cells) + r" \\"

    out.append(per_col_row(r"$N$", n_per_col))
    out.append(per_col_row(r"\# firms", nf_per_col))

    return "\n".join(out)


def build_table(cluster, fe_list, output_path, table_label, table_caption):
    show_fe = len(fe_list) > 1

    header_nums = " & ".join([""] + [f"({i+1})" for i in range(4)]) + r" \\"
    header_lbls = " & ".join([""] + COL_HEADERS) + r" \\"

    panels = []
    # Panel A: Main
    panels.append(r"\multicolumn{5}{l}{\textit{Panel A: Main sample. $\text{post} = \mathbf{1}\{cba\_period \geq 3\}$}} \\")
    panels.append(r"\midrule")
    for i, fe in enumerate(fe_list):
        panels.append(build_subpanel("main", fe, cluster, show_fe_label=show_fe))
        if i < len(fe_list) - 1:
            panels.append(r"\addlinespace")
    panels.append(r"\midrule")
    # Panel B: Placebo
    panels.append(r"\multicolumn{5}{l}{\textit{Panel B: Placebo (pre-period only). $\text{placebo} = \mathbf{1}\{cba\_period = 1\}$ (cba\_period 2 = base)}} \\")
    panels.append(r"\midrule")
    for i, fe in enumerate(fe_list):
        panels.append(build_subpanel("placebo", fe, cluster, show_fe_label=show_fe))
        if i < len(fe_list) - 1:
            panels.append(r"\addlinespace")

    cluster_note = (
        r"Standard errors clustered at the establishment level (\texttt{identificad})."
        if cluster == "estab" else
        r"Standard errors clustered at the firm level (\texttt{identificad8}, the 8-digit CNPJ root)."
    )

    note = (
        r"\textit{Notes:} This table reports estimates of $\beta$ from "
        r"$cl\_count_{ict} = \beta\,(X_{ic} \times T_t) + \alpha_{ic} + \alpha_{ft} + \varepsilon_{ict}$ "
        r"on the long panel of treated balanced-panel firms reshaped over their 139 clause types. "
        r"$X_{ic}$ is one of the pre-treatment mismatch measures: "
        r"$\text{gap}_{ic} = \max(0, \bar{c}_{-i,c} - c^{\text{pre}}_{ic})$, "
        r"$\text{surplus}_{ic} = \max(0, c^{\text{pre}}_{ic} - \bar{c}_{-i,c})$, or "
        r"$\text{raw\_gap}_{ic} = \bar{c}_{-i,c} - c^{\text{pre}}_{ic}$. "
        r"$\bar{c}_{-i,c}$ is the connectivity-weighted average of the clause-$c$ count among "
        r"firm $i$'s connected, untreated, worker-flow partners; weights are the average of "
        r"the four pre-treatment year-pair flow ratios in 2007--2011. $\alpha_{ic}$ is a firm "
        r"$\times$ clause-type fixed effect; $\alpha_{ft}$ is the sub-panel-specific time effect. "
        r"Each column is a separate regression. Column~(4) is a joint regression with both "
        r"$\text{gap}_{ic} \times T_t$ and $\text{surplus}_{ic} \times T_t$. "
        r"\# firms is the count of distinct \texttt{identificad8} (8-digit CNPJ root) in the "
        r"regression sample. The placebo panel restricts to $cba\_period \in \{1, 2\}$ and "
        r"replaces $T_t$ with $\mathbf{1}\{cba\_period = 1\}$, treating $cba\_period = 2$ "
        r"(the cycle immediately before Súmula~277) as the base period — a test for "
        r"differential pre-trends. " + cluster_note + " "
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


# ── Generate 4 tables ─────────────────────────────────────────────────────────
# Meeting version (year FE only)
build_table(
    cluster="estab",
    fe_list=["year"],
    output_path=tables_dir / "mechanism_test_table_yearonly.tex",
    table_label="tab:mechanism_test_yearonly",
    table_caption="Mechanism test (year FE only): treated firms' clause-type expansion vs.\\ pre-treatment gap to connected partners",
)
build_table(
    cluster="firm",
    fe_list=["year"],
    output_path=tables_dir / "mechanism_test_table_yearonly_firmcluster.tex",
    table_label="tab:mechanism_test_yearonly_firmcluster",
    table_caption="Mechanism test (year FE only, firm-cluster SEs): treated firms' clause-type expansion vs.\\ pre-treatment gap",
)

# Full version (3 FE sub-panels)
build_table(
    cluster="estab",
    fe_list=["year", "clause_x_year", "modeunion_x_year"],
    output_path=tables_dir / "mechanism_test_table.tex",
    table_label="tab:mechanism_test",
    table_caption="Mechanism test: treated firms' clause-type expansion vs.\\ pre-treatment gap to connected partners",
)
build_table(
    cluster="firm",
    fe_list=["year", "clause_x_year", "modeunion_x_year"],
    output_path=tables_dir / "mechanism_test_table_firmcluster.tex",
    table_label="tab:mechanism_test_firmcluster",
    table_caption="Mechanism test (firm-cluster SEs): treated firms' clause-type expansion vs.\\ pre-treatment gap",
)
