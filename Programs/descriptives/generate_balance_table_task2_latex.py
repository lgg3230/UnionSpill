#!/usr/bin/env python3
"""Render the Task-2 6-column control-effectiveness balance table to LaTeX.

Reads  Tables/descriptives/balance_table_task2.csv  (from balance_table_task2.do)
Writes Tables/descriptives/balance_table_task2.tex   (a \\input-able fragment).

Layout: rows = pre-treatment firm characteristics (2011 cross-section); columns =
three comparisons, each Raw / Controlled:
  (1)(2) Treated vs. all untreated controls
  (3)(4) Treated vs. zero-connectivity controls
  (5)(6) Slope on connectivity within the spillover control sample
Each cell is the coefficient (on Treatment for 1-4, on Connectivity for 5-6) with
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
COLS = [("c1", "c1"), ("c2", "c2"), ("c3", "c3"),
        ("c4", "c4"), ("c5", "c5"), ("c6", "c6")]


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

    L = []
    L.append(r"\begin{table}[H]")
    L.append(r"\centering")
    L.append(r"\caption{Do the Regression Controls Restore Balance? "
             r"Raw vs.\ Control-Adjusted Differences}")
    L.append(r"\label{tab:balance_controls_task2}")
    L.append(r"\scriptsize")
    L.append(r"\begin{threeparttable}")
    L.append(r"\begin{tabular}{lcccccc}")
    L.append(r"\toprule\toprule")
    L.append(r" & \multicolumn{2}{c}{Treated vs.\ All} "
             r"& \multicolumn{2}{c}{Treated vs.\ Zero-Conn.} "
             r"& \multicolumn{2}{c}{Connectivity Slope} \\")
    L.append(r"\cmidrule(lr){2-3}\cmidrule(lr){4-5}\cmidrule(lr){6-7}")
    L.append(r" & Raw & Controlled & Raw & Controlled & Raw & Controlled \\")
    L.append(r" & (1) & (2) & (3) & (4) & (5) & (6) \\")
    L.append(r"\midrule")

    for key, label, scale in ROWS:
        r = df.loc[key]
        coefs = " & ".join(fmt_coef(r[f"{c}_b"], r[f"{c}_p"], scale) for c, _ in COLS)
        ses   = " & ".join(fmt_se(r[f"{c}_se"], scale) for c, _ in COLS)
        L.append(f"{label} & {coefs} \\\\")
        L.append(f" & {ses} \\\\")
    L.append(r" & & & & & & \\")
    L.append(r"\midrule")
    L.append(rf"Establishments & \multicolumn{{2}}{{c}}{{{n_all}}} "
             rf"& \multicolumn{{2}}{{c}}{{{n_zero}}} "
             rf"& \multicolumn{{2}}{{c}}{{{n_spill}}} \\")
    L.append(r"Regression controls & No & Yes & No & Yes & No & Yes \\")
    L.append(r"\bottomrule")
    L.append(r"\end{tabular}")
    L.append(r"\scriptsize")
    L.append(r"\begin{tablenotes}")
    L.append(
        r"\item \textit{Notes:} Each cell reports a single regression coefficient "
        r"with its robust standard error in parentheses, using the 2011 "
        r"pre-treatment cross-section (one observation per establishment). "
        r"In columns (1)--(4) the coefficient is on a treated indicator, so it is "
        r"the treated--control difference in the row characteristic; in columns "
        r"(5)--(6) it is the slope on establishment connectivity within the "
        r"spillover control sample (untreated establishments only). Columns (1), "
        r"(3), and (5) are raw; columns (2), (4), and (6) partial out the paper's "
        r"main-specification controls. Mirroring that specification, which absorbs "
        r"each outcome's own pre-treatment quartile together with an employment "
        r"quartile, the controlled columns condition on a common set applied to "
        r"every row---two-digit industry, microregion, and negotiation-month "
        r"indicators, quartile-bin dummies for pre-treatment per-worker pairwise "
        r"worker flows (2007--2011), and quartile-bin dummies for pre-treatment log "
        r"employment (2009--2010)---plus, for each characteristic, quartile-bin "
        r"dummies of that characteristic's own 2009--2010 mean. These are four "
        r"group indicators, not the lagged level, so they coarsely adjust for "
        r"baseline differences rather than mechanically absorbing the outcome; and "
        r"the 2009--2010 window excludes the 2011 value being compared. The "
        r"employment row's own quartile is the common employment quartile, and the "
        r"worker-flows row's own quartile is the common flows quartile; connectivity "
        r"is a treatment-exposure gradient rather than an outcome, so its row uses "
        r"the common controls only. "
        r"Columns (1)--(2) compare treated establishments to all untreated "
        r"controls; columns (3)--(4) restrict controls to establishments with zero "
        r"pre-reform connectivity. The contrast between the raw and controlled "
        r"columns shows whether the specification brings the samples closer to "
        r"balance: large raw imbalances that collapse toward zero once controls are "
        r"applied indicate the covariates absorb the relevant selection. Tenure and "
        r"age are in years. Connectivity is normalized to the 90th percentile of "
        r"the spillover sample in 2009. Standard errors are heteroskedasticity-"
        r"robust. *** $p<.01$, ** $p<.05$, * $p<.10$.")
    L.append(r"\end{tablenotes}")
    L.append(r"\end{threeparttable}")
    L.append(r"\end{table}")

    out = tdir / "balance_table_task2.tex"
    out.write_text("\n".join(L) + "\n")
    print(f"wrote {out}")


if __name__ == "__main__":
    main()
