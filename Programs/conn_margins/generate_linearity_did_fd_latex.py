#!/usr/bin/env python3
"""
LaTeX table for the spillover dose-response linearity test.

Calendar outcomes (wage, hourly wage, employment) use the first-difference
cross-section test (linearity_did_fd_test.csv). Clause counts live on the
irregular CBA calendar, so the clause row uses the headline residualized
firm x CBA-period panel test (linearity_did_resid_cba_test.csv), with the
establishment count taken from its exported cross-section.

Inputs:  Tables/conn_margins/linearity_did_fd_test.csv
         Tables/conn_margins/linearity_did_resid_cba_test.csv
         Tables/conn_margins/linearity_did_resid_cba_numb_clauses.csv
Output:  Tables/conn_margins/linearity_did_fd_table.tex
"""

import pandas as pd
from pathlib import Path

script_dir = Path(__file__).resolve().parent
tables_dir = script_dir.parent.parent / "Tables" / "conn_margins"

OUTCOME_LABELS = {
    "lr_remdezr_w":   "Log Dec.\\ wage",
    "lr_remdezr_h_w": "Log hourly wage",
    "l_firm_emp":     "Log employment",
    "numb_clauses":   "\\# CBA clauses",
}

# ── First-difference rows: the three calendar outcomes ────────────────────────
fd = pd.read_csv(tables_dir / "linearity_did_fd_test.csv")
fd = fd[fd["outcome"] != "numb_clauses"].copy()
fd["estab"] = fd["n"].astype(int)        # FD cross-section: one row per firm

# ── Clause row: headline residualized 6-level panel test ──────────────────────
cl = pd.read_csv(tables_dir / "linearity_did_resid_cba_test.csv").iloc[0]
cl_xs = pd.read_csv(tables_dir / "linearity_did_resid_cba_numb_clauses.csv")
cl_estab    = int(cl_xs["identificad"].nunique())   # establishments
cl_firmperi = int(cl["n"])                          # firm-period observations

clause_row = {
    "outcome": "numb_clauses",
    "estab": cl_estab,
    "nbins": int(cl["nbins"]),
    "stat_supt": float(cl["stat_supt"]),
    "pval": float(cl["pval"]),
}

rows = fd[["outcome", "estab", "nbins", "stat_supt", "pval"]].to_dict("records")
rows.append(clause_row)


def fmt_n(v):
    return f"{int(v):,}".replace(",", "{,}")


def fmt_pval(v):
    v = float(v)
    if v < 0.001:
        return "$<0.001$"
    s = f"{v:.3f}"
    return r"\textbf{" + s + r"}" if v < 0.10 else s


lines = [
    r"\begin{table}[H]",
    r"\centering",
    r"\caption{Linearity Test of the Spillover Dose--Response}",
    r"\label{tab:linearity_did_fd}",
    r"\scriptsize",
    r"\begin{tabular}{lcccc}",
    r"\toprule\toprule",
    (r"Outcome & Establishments & \shortstack{Bins\\(req.\ 50)} & "
     r"\shortstack{Sup-$t$\\stat} & $p$-value \\"),
    r"\midrule",
]

for row in rows:
    lines.append(
        f"{OUTCOME_LABELS.get(row['outcome'], row['outcome'])} & "
        f"${fmt_n(row['estab'])}$ & {int(row['nbins'])} & "
        f"{float(row['stat_supt']):.3f} & {fmt_pval(row['pval'])} \\\\"
    )

lines += [
    r"\bottomrule",
    r"\end{tabular}",
    r"\begin{minipage}{\linewidth}",
    r"\footnotesize\vspace{4pt}",
    (r"\textit{Notes:} This table reports Cattaneo, Crump, Farrell, and Feng "
     r"(2024) sup-$t$ tests of the null hypothesis that the spillover treatment "
     r"effect is a degree-1 polynomial (linear) in connectivity, on the balanced "
     r"panel of untreated firms. For the calendar outcomes (wage and employment) "
     r"the test runs on the firm-level first difference $\Delta Y_j = "
     r"\overline{Y}_j^{\,post} - \overline{Y}_j^{\,pre}$ (post $=$ 2012--2016, "
     r"pre $=$ 2009--2011), which removes the firm fixed effect of the panel DiD "
     r"exactly, so each establishment contributes one observation. Clause counts "
     r"are negotiated on the irregular CBA calendar rather than annually, so the "
     r"clause test runs directly on the published firm $\times$ CBA-period panel "
     r"DiD (six period fixed effects): the clause count and the connectivity "
     r"$\times$ post term are residualized on the firm, and on the industry, "
     r"month-of-year, microregion, and pre-treatment quartile fixed effects "
     r"interacted with CBA period (all additive, so the projection is "
     r"within-exact and the test is size-valid under the linear null), and the "
     r"residuals are binned. The clause test uses "
     f"${fmt_n(cl_firmperi)}$ firm-period observations across "
     f"${fmt_n(cl_estab)}$ establishments and reproduces the published spillover "
     r"slope to machine precision. In every case the OLS slope reproduces the "
     r"panel spillover coefficient. Standard errors are clustered by "
     r"establishment for the clause panel and heteroskedasticity-robust for the "
     r"first-difference outcomes; inference uses 2{,}000 simulation draws on a "
     r"grid of 50 points per bin. $p$-values below $0.10$ are bolded.")
    ,
    r"\end{minipage}",
    r"\end{table}",
]

out = tables_dir / "linearity_did_fd_table.tex"
out.write_text("\n".join(lines) + "\n")
print(f"Saved: {out}")
for row in rows:
    print(f"  {row['outcome']:16s} estab={row['estab']:>6} bins={row['nbins']:>3} "
          f"supt={row['stat_supt']:.3f} p={row['pval']:.4f}")
