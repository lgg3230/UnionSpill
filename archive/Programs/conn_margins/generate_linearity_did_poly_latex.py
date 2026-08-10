#!/usr/bin/env python3
"""
LaTeX table for the polynomial linearity test of the spillover dose-response.

Augments the headline spillover DiD (Main_Results PART D) with quadratic and
cubic terms in connectivity (each interacted with Post) and reports a joint
F-test that the two higher-order coefficients are jointly zero. This is a
parametric complement to the Cattaneo et al. (2024) sup-norm binstest.

Input:  Tables/conn_margins/linearity_did_poly_test.csv
Output: Tables/conn_margins/linearity_did_poly_table.tex
"""

import pandas as pd
from pathlib import Path

script_dir = Path(__file__).resolve().parent
tables_dir = script_dir.parent.parent / "Tables" / "conn_margins"

OUTCOME_ORDER = ["lr_remdezr_w", "lr_remdezr_h_w", "l_firm_emp", "numb_clauses"]
OUTCOME_LABELS = {
    "lr_remdezr_w":   "Log Dec.\\ wage",
    "lr_remdezr_h_w": "Log hourly wage",
    "l_firm_emp":     "Log employment",
    "numb_clauses":   "\\# CBA clauses",
}

df = pd.read_csv(tables_dir / "linearity_did_poly_test.csv")
d = df.pivot(index="outcome", columns="row_type", values="value")


def fmt_c(v, dec=4):
    return f"{float(v):.{dec}f}"


def fmt_se(v, dec=4):
    return f"({float(v):.{dec}f})"


def fmt_n(v):
    return f"{int(round(float(v))):,}".replace(",", "{,}")


def fmt_p(v):
    v = float(v)
    if v < 0.001:
        return "$<0.001$"
    s = f"{v:.3f}"
    return r"\textbf{" + s + r"}" if v < 0.10 else s


lines = [
    r"\begin{table}[H]",
    r"\centering",
    r"\caption{Polynomial Linearity Test of the Spillover Dose--Response}",
    r"\label{tab:linearity_did_poly}",
    r"\scriptsize",
    r"\begin{tabular}{lccccc}",
    r"\toprule\toprule",
    (r"Outcome & \shortstack{Linear\\$\widehat{\beta}_1$} & "
     r"\shortstack{Quadratic\\$\widehat{\beta}_2$} & "
     r"\shortstack{Cubic\\$\widehat{\beta}_3$} & "
     r"\shortstack{Joint $F$\\$(2,\,\cdot)$} & $p$-value \\"),
    r"\midrule",
]

for oc in OUTCOME_ORDER:
    r = d.loc[oc]
    lab = OUTCOME_LABELS[oc]
    # coefficient line
    lines.append(
        f"{lab} & {fmt_c(r['b_lin'])} & {fmt_c(r['b_quad'])} & "
        f"{fmt_c(r['b_cube'])} & {float(r['joint_F']):.3f} & "
        f"{fmt_p(r['joint_p'])} \\\\"
    )
    # standard-error line
    lines.append(
        f" & {fmt_se(r['se_lin'])} & {fmt_se(r['se_quad'])} & "
        f"{fmt_se(r['se_cube'])} & & \\\\"
    )

lines += [
    r"\midrule",
    (r"\multicolumn{6}{l}{\textit{Memo:} linear-only headline slope "
     r"$\widehat{\beta}^{\,\text{lin}}$ (s.e.):} \\"),
]

memo = []
for oc in OUTCOME_ORDER:
    r = d.loc[oc]
    memo.append(f"{OUTCOME_LABELS[oc]} {fmt_c(r['b_lin0'])} "
                f"({fmt_c(r['se_lin0'])})")
lines.append(r"\multicolumn{6}{l}{\hspace{1em}" + r";\quad ".join(memo) + r"} \\")

# establishment / observation counts
est = "; ".join(
    f"{OUTCOME_LABELS[oc].split(chr(92))[0].strip()} ${fmt_n(d.loc[oc]['n_estab'])}$"
    for oc in OUTCOME_ORDER
)

lines += [
    r"\bottomrule",
    r"\end{tabular}",
    r"\begin{minipage}{\linewidth}",
    r"\footnotesize\vspace{4pt}",
    (r"\textit{Notes:} This table tests the linear functional form of the "
     r"spillover dose--response by augmenting the headline difference-in-"
     r"differences specification (Main Results, spillover panel) with quadratic "
     r"and cubic terms in connectivity. For each outcome the estimating equation "
     r"is $Y_{jt} = \beta_1\,(C_j\!\times\!\text{Post}_t) + \beta_2\,"
     r"(C_j^2\!\times\!\text{Post}_t) + \beta_3\,(C_j^3\!\times\!\text{Post}_t) "
     r"+ \alpha_j + \gamma_{g(j)t} + \varepsilon_{jt}$, estimated on the balanced "
     r"panel of untreated (spillover) firms, where $C_j$ is the firm's "
     r"connectivity to treated firms (flows per worker, scaled to the 90th "
     r"percentile of the spillover sample in 2009). Each specification holds "
     r"fixed the establishment, industry, month-of-year, microregion, and "
     r"pre-treatment quartile fixed effects (interacted with year, or with CBA "
     r"period for clause counts) of the headline regression. The reported $F$-"
     r"statistic tests $H_0\!:\beta_2=\beta_3=0$ (the dose--response is linear "
     r"in connectivity); failure to reject supports the linear specification. The "
     r"\textit{Memo} row gives the slope from the linear-only headline regression "
     r"($\beta_2=\beta_3=0$ imposed), which reproduces the published spillover "
     r"coefficient. The wage and employment outcomes use annual data (post $=$ "
     r"2012--2016, pre $=$ 2009--2011); clause counts are negotiated on the CBA "
     r"calendar and use the published firm $\times$ CBA-period DiD (post $=$ "
     r"post-reform CBA rounds). Standard errors, clustered by establishment, are "
     r"in parentheses. $p$-values below $0.10$ are bolded. Establishments: " + est +
     r".")
    ,
    r"\end{minipage}",
    r"\end{table}",
]

out = tables_dir / "linearity_did_poly_table.tex"
out.write_text("\n".join(lines) + "\n")
print(f"Saved: {out}\n")

print(f"{'outcome':16s} {'lin0':>9} {'lin':>9} {'quad':>10} {'cubic':>10} "
      f"{'F':>7} {'p':>7}")
for oc in OUTCOME_ORDER:
    r = d.loc[oc]
    print(f"{oc:16s} {r['b_lin0']:9.5f} {r['b_lin']:9.5f} {r['b_quad']:10.5f} "
          f"{r['b_cube']:10.5f} {r['joint_F']:7.3f} {r['joint_p']:7.4f}")
