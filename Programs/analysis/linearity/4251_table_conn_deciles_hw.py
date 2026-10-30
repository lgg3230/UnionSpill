#!/usr/bin/env python3
"""
Decile table for the ATT section of the referee analyses: log hourly wage
spillover effects by decile of positive connectivity, with the pre-treatment
placebo and mean pre-treatment employment of each decile. Zero-connectivity
establishments are the omitted group.

Columns: (1) Post x decile, (2) placebo (decile x 2009-2010, on 2009-2011 data),
         (3) mean scaled connectivity and (4) mean pre-treatment employment
         (2009-2011), both in the Post estimation sample.

Reads  Tables/linearity/linearity_bins_dec.csv           (3154 -> 3152_linearity_bins.do)
       Tables/linearity/linearity_bins_cutoffs_dec.csv
Writes Tables/linearity/t_linearity_bins_dec_hw.tex       table float, label tab:linearity_bins_dec

Usage: python 4251_table_conn_deciles_hw.py
"""

import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
TAB = ROOT / "Tables" / "linearity"
CSV_IN = TAB / "linearity_bins_dec.csv"
CUTS_IN = TAB / "linearity_bins_cutoffs_dec.csv"
OUT = TAB / "t_linearity_bins_dec_hw.tex"

OUTCOME = "lr_remdezr_h_w"
K = 10


def load():
    for f in (CSV_IN, CUTS_IN):
        if not f.exists():
            raise SystemExit(f"Missing input: {f}. Run 3154_linearity_bins_deciles.do first.")
    with open(CSV_IN, newline="") as fh:
        rows = {int(r["group"]): r for r in csv.DictReader(fh)
                if r["outcome"] == OUTCOME and int(r["breakdown"]) == K}
    if "pre_coef" not in rows[1]:
        raise SystemExit("CSV has no placebo columns. Re-run 3154_linearity_bins_deciles.do.")
    with open(CUTS_IN, newline="") as fh:
        cuts = [float(r["cutoff_norm"]) for r in sorted(
            (r for r in csv.DictReader(fh) if int(r["breakdown"]) == K), key=lambda r: int(r["cut"]))]
    return rows, cuts


def num(x, digits=4):
    s = f"{float(x):.{digits}f}"
    return r"$-$" + s[1:] if s.startswith("-") else s


def stars(p):
    p = float(p)
    return "***" if p < 0.01 else "**" if p < 0.05 else "*" if p < 0.10 else ""


def count(x):
    return f"{int(float(x)):,}".replace(",", "{,}")


def join_and(vals):
    return ", ".join(vals[:-1]) + f", and {vals[-1]}"


def build(rows, cuts):
    hdr = (r" & \begin{tabular}[c]{@{}c@{}}Post-Reform\\Effect\end{tabular}"
           r" & \begin{tabular}[c]{@{}c@{}}Pre-Trend\\Placebo\end{tabular}"
           r" & \begin{tabular}[c]{@{}c@{}}Mean Scaled\\Connectivity\end{tabular}"
           r" & \begin{tabular}[c]{@{}c@{}}Mean Pre-Treatment\\Employment\end{tabular}")
    r0 = rows[0]
    lines = [
        r"\begin{table}[H]",
        r"\centering",
        r"\caption{Spillover Effects on Log Hourly Wages by Connectivity Decile}",
        r"\label{tab:linearity_bins_dec}",
        r"\footnotesize",
        r"\begin{tabular}{lcccc}",
        r"\toprule\toprule",
        hdr + r"\\",
        r" & (1) & (2) & (3) & (4)\\",
        r"\midrule",
        rf"Zero connectivity (omitted group) & -- & -- & {float(r0['mean_conn']):.2f} & {float(r0['mean_emp']):.1f}\\",
        r" & & & & \\",
    ]
    for g in range(1, K + 1):
        r = rows[g]
        lines.append(rf"Decile {g} & {num(r['coef'])}{stars(r['pval'])} & "
                     rf"{num(r['pre_coef'])}{stars(r['pre_pval'])} & {float(r['mean_conn']):.2f} & "
                     rf"{float(r['mean_emp']):.1f}\\")
        lines.append(rf" & ({num(r['se'])}) & ({num(r['pre_se'])}) & & \\")
        if g < K:
            lines.append(r" & & & & \\")
    lines += [
        r"\midrule",
        rf"Equal group effects, $p$-value & {float(r0['p_equal']):.3f} & & & \\",
        rf"Placebo jointly zero, $p$-value & & {float(r0['p_pre_joint']):.3f} & & \\",
        rf"Observations & {count(r0['n_obs'])} & {count(r0['n_obs_pre'])} & & \\",
        rf"Establishments & {count(r0['n_estab'])} & & & \\",
        r"\bottomrule\bottomrule",
        r"\end{tabular}",
        "",
        r"\begin{minipage}{\linewidth}",
        r"\scriptsize\vspace{4pt}",
        NOTES.replace("@@CUTS@@", join_and([f"{c:.3f}" for c in cuts])),
        r"\end{minipage}",
        r"\end{table}",
    ]
    return "\n".join(lines) + "\n"


NOTES = (
    r"\textit{Notes:} This table reports difference-in-differences estimates of the reform's spillover "
    r"effects on log hourly wages in which the linear term Post $\times$ Connectivity of equation "
    r"(\ref{eq:spill_spec}) is replaced by indicators for deciles of positive connectivity interacted with "
    r"Post. The omitted group consists of untreated establishments with zero connectivity, so each "
    r"coefficient in column~(1) is the 2012--2016 effect for a decile relative to them. Column~(2) reports "
    r"the placebo: the same regression estimated on 2009--2011 data only, with the decile indicators "
    r"interacted with an indicator for 2009--2010, so each coefficient compares 2009--2010 with 2011. "
    r"Columns~(3) and~(4) report the mean scaled connectivity and the mean pre-treatment employment "
    r"(2009--2011) of the establishments in each group in the column~(1) estimation sample. Scaled "
    r"connectivity equals 1 at the 90th percentile among untreated establishments, and in these units "
    r"the decile cutoffs are @@CUTS@@. The equal-group-effects row tests that the ten "
    r"coefficients of column~(1) are equal; the placebo row tests that the ten coefficients of "
    r"column~(2) are jointly zero. All specifications include establishment fixed effects and year fixed "
    r"effects interacted with three-digit industry, microregion, and negotiation-month indicators and "
    r"with quartile bins of pre-treatment firm size, per-worker flows, and the outcome. Standard errors "
    r"clustered at the establishment level in parentheses. *** p$<$0.01, ** p$<$0.05, * p$<$0.10."
)


def main():
    OUT.write_text(build(*load()))
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    main()
