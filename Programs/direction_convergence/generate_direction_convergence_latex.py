"""
generate_direction_convergence_latex.py

Reads:
  Tables/direction_convergence/direction_convergence_static_results.csv
  Tables/direction_convergence/direction_convergence_treated_static_results.csv

Produces:
  Tables/direction_convergence/direction_convergence_static_table.tex

One LaTeX table with 4 columns (one per similarity outcome). Within each panel,
treated and untreated side-by-side rows let the reader compare directly.
"""

from pathlib import Path
import pandas as pd

this_dir     = Path(__file__).resolve().parent
project_root = this_dir.parent.parent
tables_dir   = project_root / "Tables" / "direction_convergence"
csv_u        = tables_dir / "direction_convergence_static_results.csv"
csv_t        = tables_dir / "direction_convergence_treated_static_results.csv"
out_path     = tables_dir / "direction_convergence_static_table.tex"

OUTCOMES = [
    ("sim_cosine_shares",  r"\shortstack{Cosine \\ (shares)}"),
    ("sim_tv_shares",      r"\shortstack{TV similarity \\ (shares)}"),
    ("sim_ruzicka_counts", r"\shortstack{Ruzicka \\ (counts)}"),
    ("sim_bc_counts",      r"\shortstack{Bray-Curtis \\ (counts)}"),
]

df_u = pd.read_csv(csv_u)
df_t = pd.read_csv(csv_t)
for d in (df_u, df_t):
    for c in ["outcome", "sample"]:
        d[c] = d[c].astype(str).str.strip()


def stars(coef, se):
    if pd.isna(coef) or pd.isna(se) or se <= 0:
        return ""
    t = abs(coef / se)
    if t > 2.576: return r"^{***}"
    if t > 1.960: return r"^{**}"
    if t > 1.645: return r"^{*}"
    return ""


def get(df, sample, outcome):
    sub = df[(df["sample"] == sample) & (df["outcome"] == outcome)]
    return sub.iloc[0] if len(sub) > 0 else None


def fmt_coef(row):
    if row is None: return ""
    return f"${row.coef:.4f}{stars(row.coef, row.se)}$"


def fmt_se(row):
    if row is None: return ""
    return f"$({row.se:.4f})$"


def fmt_n(v):
    if v is None or pd.isna(v): return ""
    return f"{int(v):,}"


def fmt_mean(v):
    if v is None or pd.isna(v): return ""
    return f"{v:.3f}"


def build_panel(sample, label, interaction_label):
    """Treated row + Untreated row + sample-size rows for each outcome."""
    rows_u = [get(df_u, sample, o) for o, _ in OUTCOMES]
    rows_t = [get(df_t, sample, o) for o, _ in OUTCOMES]

    out = []
    out.append(rf"\multicolumn{{5}}{{l}}{{\textit{{{label}}}}} \\")
    out.append(r"\midrule")

    # Untreated row block: each col = β (SE) for that outcome
    out.append(rf"\multicolumn{{5}}{{l}}{{$\text{{connectivity\_treat}}_i \times \text{{{interaction_label}}}_t$ \quad (untreated focal)}} \\")
    out.append(r"$\quad$ Coef.\ & " + " & ".join(fmt_coef(r) for r in rows_u) + r" \\")
    out.append(r" & " + " & ".join(fmt_se(r) for r in rows_u) + r" \\")
    out.append(r"\addlinespace[2pt]")
    out.append(rf"\multicolumn{{5}}{{l}}{{$\text{{connectivity\_untreat}}_j \times \text{{{interaction_label}}}_t$ \quad (treated focal)}} \\")
    out.append(r"$\quad$ Coef.\ & " + " & ".join(fmt_coef(r) for r in rows_t) + r" \\")
    out.append(r" & " + " & ".join(fmt_se(r) for r in rows_t) + r" \\")
    out.append(r"\addlinespace[2pt]")

    out.append(r"Mean dep.\ var.\ (U) & "
               + " & ".join(fmt_mean(r["ymean"] if r is not None else None) for r in rows_u) + r" \\")
    out.append(r"Mean dep.\ var.\ (T) & "
               + " & ".join(fmt_mean(r["ymean"] if r is not None else None) for r in rows_t) + r" \\")
    out.append(r"$N$ (U) & " + " & ".join(fmt_n(r["N"] if r is not None else None) for r in rows_u) + r" \\")
    out.append(r"$N$ (T) & " + " & ".join(fmt_n(r["N"] if r is not None else None) for r in rows_t) + r" \\")
    out.append(r"\# firms (U) & " + " & ".join(fmt_n(r["N_clust"] if r is not None else None) for r in rows_u) + r" \\")
    out.append(r"\# firms (T) & " + " & ".join(fmt_n(r["N_clust"] if r is not None else None) for r in rows_t) + r" \\")
    return "\n".join(out)


header_nums = " & ".join([""] + [f"({i+1})" for i in range(4)]) + r" \\"
header_lbls = " & ".join([""] + [lbl for _, lbl in OUTCOMES]) + r" \\"

panel_a = build_panel("main",    r"Panel A: Main sample. $\text{post}_t = \mathbf{1}\{cba\_period_t \geq 3\}$.", "post")
panel_b = build_panel("placebo", r"Panel B: Placebo (pre-period only). $\text{placebo}_t = \mathbf{1}\{cba\_period_t = 1\}$ (cba\_period 2 = base).", "placebo")

note = (
    r"\textit{Notes:} Direction-of-convergence test. The untreated-focal block reports "
    r"$\beta$ from $\text{Sim}(x^U_{it}, \bar c^{T,2}_i) = \alpha_i + \lambda_t + \beta\,(\text{connectivity\_treat}_i \times T_t) + \delta_{m(i),t} + \varepsilon_{it}$, "
    r"where $\bar c^{T,2}_i = \sum_j w_{ij,\text{pre}} \, c^T_{j,2} / \sum_j w_{ij,\text{pre}}$ is the connectivity-weighted "
    r"average of $i$'s connected treated partners' clause vectors in cba\_period 2 (last pre-Súmula cycle); "
    r"$\text{connectivity\_treat}_i = \sum_j w_{ij,\text{pre}}$. The treated-focal block reports the mirror: "
    r"focal = treated firm $j$, benchmark = $\bar c^{U,2}_j$ (connectivity-weighted average of $j$'s connected "
    r"\textit{untreated} partners' cba\_period 2 clauses), and $\text{connectivity\_untreat}_j = \sum_i w_{ji,\text{pre}}$. "
    r"Connectivity weights use \texttt{bilateral\_conn\_pw} from 2007--2011 worker-flow data. Each regression "
    r"includes firm and cba\_period fixed effects and \texttt{mode\_base\_month} $\times$ cba\_period FE. "
    r"Standard errors clustered at the firm level (\texttt{identificad}). "
    r"$^{***}p<0.01$, $^{**}p<0.05$, $^{*}p<0.10$."
)

tex = (
    r"\begin{table}[H]" + "\n"
    r"\centering" + "\n"
    r"\caption{Direction of convergence: untreated and treated firms moving toward their connected counterparts' fixed pre-Súmula benchmark}" + "\n"
    r"\label{tab:direction_convergence_static}" + "\n"
    r"\scriptsize" + "\n"
    r"\begin{tabular}{lcccc}" + "\n"
    r"\toprule\toprule" + "\n"
    f"{header_nums}\n"
    f"{header_lbls}\n"
    r"\midrule" + "\n"
    f"{panel_a}\n"
    r"\midrule" + "\n"
    f"{panel_b}\n"
    r"\bottomrule" + "\n"
    r"\end{tabular}" + "\n"
    r"\begin{minipage}{\linewidth}" + "\n"
    r"\footnotesize\vspace{4pt}" + "\n"
    f"{note}\n"
    r"\end{minipage}" + "\n"
    r"\end{table}" + "\n"
)

out_path.write_text(tex)
print(f"Wrote {out_path.name}")
