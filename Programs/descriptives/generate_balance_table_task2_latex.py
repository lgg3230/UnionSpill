#!/usr/bin/env python3
"""Render the Task-2 9-column control-effectiveness balance table to LaTeX.

Reads  Tables/descriptives/balance_table_task2.csv  (from balance_table_task2.do)
Writes Tables/descriptives/balance_table_task2.tex   (a \\input-able fragment).

Layout: rows = pre-treatment firm characteristics (2011 cross-section); columns =
three comparisons, each at three control levels (Raw / Main / +Own):
  (1)(2)(3) Treated vs. all untreated controls
  (4)(5)(6) Treated vs. zero-connectivity controls
  (7)(8)(9) Slope on connectivity within the spillover control sample
Each cell is the coefficient (on Treatment for 1-6, on Connectivity for 7-9) with
significance stars, and the robust SE in parentheses on the line below.
"""
from pathlib import Path
import pandas as pd

# ---- rows: (csv key, LaTeX label, scale) -- scale converts units where needed
ROWS = [
    ("lr_remdezr_w",            r"Log wages",                  1.0),
    ("l_firm_emp",              r"Log employment",             1.0),
    ("hs_c",                    r"High-school share",          1.0),
    ("sup_c",                   r"Higher-education share",     1.0),
    ("prop_female",             r"Share female",               1.0),
    ("prop_non_white",          r"Share non-white",            1.0),
    ("mean_age",                r"Mean worker age (years)",    1.0),
    ("avg_tenure",              r"Mean tenure (years)",        1.0/12.0),  # months -> years
    ("numb_clauses",            r"CBA clause count",           1.0),
    ("totaltreat_pw_norm",      r"Connectivity",               1.0),
    ("totalflows_pw_pre_07_11", r"Worker flows (p.w.)",        1.0),
]
# three comparison groups, each with three levels (Raw / Main / +Own)
GROUPS = [
    (r"Treated vs.\ All",        ["c1", "c2", "c3"]),
    (r"Treated vs.\ Zero-Conn.", ["c4", "c5", "c6"]),
    (r"Connectivity Slope",      ["c7", "c8", "c9"]),
]
SUBLABELS = ["Raw", "Main", "$+$Own"]


def stars(p):
    if pd.isna(p):
        return ""
    return "***" if p < .01 else "**" if p < .05 else "*" if p < .10 else ""


def fmt_coef(b, p, scale):
    if pd.isna(b):
        return "---"
    b = b * scale
    s = f"{abs(b):.4f}"
    s = (r"$-$" + s) if b < 0 else s
    return s + stars(p)


def fmt_se(se, scale):
    if pd.isna(se):
        return ""
    return f"({abs(se) * scale:.4f})"


def main():
    sd = Path(__file__).resolve().parent          # Programs/descriptives
    tdir = sd.parent.parent / "Tables" / "descriptives"
    df = pd.read_csv(tdir / "balance_table_task2.csv").set_index("characteristic")

    n_all   = f"{int(df['n_all'].iloc[0]):,}".replace(",", "{,}")
    n_zero  = f"{int(df['n_zero'].iloc[0]):,}".replace(",", "{,}")
    n_spill = f"{int(df['n_spill'].dropna().iloc[0]):,}".replace(",", "{,}")

    keys = [k for _, ks in GROUPS for k in ks]     # flat c1..c9

    L = []
    L.append(r"\begin{table}[H]")
    L.append(r"\centering")
    L.append(r"\caption{Do the Regression Controls Restore Balance? "
             r"Raw, Main-Specification, and Own-Prior-Adjusted Differences}")
    L.append(r"\label{tab:balance_controls_task2}")
    L.append(r"\scriptsize")
    L.append(r"\begin{threeparttable}")
    L.append(r"\setlength{\tabcolsep}{4pt}")
    L.append(r"\resizebox{\textwidth}{!}{%")
    L.append(r"\begin{tabular}{lccccccccc}")
    L.append(r"\toprule\toprule")
    L.append(" & " + " & ".join(rf"\multicolumn{{3}}{{c}}{{{g}}}" for g, _ in GROUPS) + r" \\")
    L.append(r"\cmidrule(lr){2-4}\cmidrule(lr){5-7}\cmidrule(lr){8-10}")
    L.append(" & " + " & ".join(SUBLABELS * 3) + r" \\")
    L.append(" & " + " & ".join(f"({i})" for i in range(1, 10)) + r" \\")
    L.append(r"\midrule")

    for key, label, scale in ROWS:
        r = df.loc[key]
        coefs = " & ".join(fmt_coef(r[f"{k}_b"], r[f"{k}_p"], scale) for k in keys)
        ses   = " & ".join(fmt_se(r[f"{k}_se"], scale) for k in keys)
        L.append(f"{label} & {coefs} \\\\")
        L.append(f" & {ses} \\\\")
    L.append(r" & " + " & ".join([""] * 9) + r" \\")
    L.append(r"\midrule")
    L.append(rf"Establishments & \multicolumn{{3}}{{c}}{{{n_all}}} "
             rf"& \multicolumn{{3}}{{c}}{{{n_zero}}} & \multicolumn{{3}}{{c}}{{{n_spill}}} \\")
    L.append(r"\bottomrule")
    L.append(r"\end{tabular}}")
    L.append(r"\scriptsize")
    L.append(r"\begin{tablenotes}")
    L.append(
        r"\item \textit{Notes:} Each cell reports a single regression coefficient "
        r"with its robust standard error in parentheses, on the 2011 pre-treatment "
        r"cross-section (one observation per establishment). In columns (1)--(6) the "
        r"coefficient is on a treated indicator (the treated--control difference in "
        r"the row characteristic); in columns (7)--(9) it is the slope on "
        r"establishment connectivity within the spillover control sample (untreated "
        r"establishments only). Each comparison is shown at three control levels. "
        r"\textit{Raw}: no controls. \textit{Main}: the controls common to every "
        r"main-specification regression---two-digit industry, microregion, and "
        r"negotiation-month indicators, and quartile-bin dummies for pre-treatment "
        r"per-worker pairwise worker flows (2007--2011) and pre-treatment log "
        r"employment (2009--2010). \textit{$+$Own}: \textit{Main} plus quartile-bin "
        r"dummies of the row characteristic's own pre-treatment level, mirroring the "
        r"main specification's own-outcome control. The own window is 2007--2010 for "
        r"log wages and log employment (reconstructed pre-period data) and 2009--2010 "
        r"otherwise; it always excludes the 2011 value being compared. Own quartiles "
        r"are four group indicators, not the lagged level, so they coarsely adjust "
        r"for baseline differences rather than mechanically absorbing the outcome. "
        r"Connectivity is a treatment-exposure gradient rather than an outcome, so its "
        r"row uses the common controls only ($+$Own $=$ Main); the worker-flows row's "
        r"own quartile is the common flows quartile. Comparing \textit{Main} against "
        r"\textit{$+$Own} shows how much of the residual balance comes from "
        r"conditioning a characteristic on its own prior level. "
        r"Columns (1)--(3) compare treated establishments to all untreated controls; "
        r"columns (4)--(6) restrict controls to establishments with zero pre-reform "
        r"connectivity. Tenure and age are in years; connectivity is normalized to "
        r"the 90th percentile of the spillover sample in 2009. Standard errors are "
        r"heteroskedasticity-robust. *** $p<.01$, ** $p<.05$, * $p<.10$.")
    L.append(r"\end{tablenotes}")
    L.append(r"\end{threeparttable}")
    L.append(r"\end{table}")

    out = tdir / "balance_table_task2.tex"
    out.write_text("\n".join(L) + "\n")
    print(f"wrote {out}")


if __name__ == "__main__":
    main()
