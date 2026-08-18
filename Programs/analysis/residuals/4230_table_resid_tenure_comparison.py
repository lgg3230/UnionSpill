"""
04_make_comparison_table.py
===========================
Build the 6-column "Effects on Residualized Wages" table comparing, for log
December wages, the raw outcome against TWO whole-RAIS (national) Mincer
residualizations — age-only (without tenure) and age+tenure quartic (with
tenure) — for both Direct (Panel A) and Spillover effects.

Same visual format as tab:resid_raw_base in Main_Results.tex, extended from
4 to 6 columns.

Inputs (produced by Main_Results_mincer.do with the two suffixes):
  Tables/residuals/results_direct_panelA_mincer_age_fullrais.csv   (age-only)
  Tables/residuals/results_direct_panelA_mincer_ten_fullrais.csv   (age+tenure; also raw)
  Tables/residuals/results_spill_mincer_age_fullrais.csv
  Tables/residuals/results_spill_mincer_ten_fullrais.csv

Output:
  Tables/mincer_tenure_fullrais/resid_tenure_comparison.tex
"""

import argparse
from pathlib import Path

RES = Path("/kellogg/proj/lgg3230/UnionSpill/Tables/residuals")
OUT_DIR = Path("/kellogg/proj/lgg3230/UnionSpill/Tables/mincer_tenure_fullrais")


def load(fname):
    d = {}
    with open(RES / fname) as fh:
        next(fh)
        for line in fh:
            p = line.strip().replace('"', "").split(";")
            if len(p) < 5:
                continue
            d.setdefault(p[2], {})[p[3]] = p[4].strip()
    return d


def neg(s):
    """Render a signed number with LaTeX minus."""
    s = s.strip()
    return ("$-$" + s[1:]) if s.startswith("-") else s


def coef(cell):
    """coefficient + stars, minus-aware (stars already in the value)."""
    return neg(cell)


def se(cell):
    return "(" + neg(cell) + ")"


def cnt(cell):
    return cell.replace(",", "{,}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--age-suffix", default="_age_fullrais",
                    help="results suffix for the age-only (no-tenure) residual")
    ap.add_argument("--ten-suffix", default="_ten_fullrais",
                    help="results suffix for the age+tenure residual")
    ap.add_argument("--out", default="resid_tenure_comparison.tex")
    ap.add_argument("--label", default="tab:resid_tenure_fullrais")
    ap.add_argument("--caption", default="Effects on Residualized Wages: With and Without Tenure")
    ap.add_argument("--polyword", default="quartic",
                    help="degree word for the age polynomial in the notes (quartic/cubic)")
    args = ap.parse_args()
    a, t, poly = args.age_suffix, args.ten_suffix, args.polyword

    dA_age = load(f"results_direct_panelA_mincer{a}.csv")
    dA_ten = load(f"results_direct_panelA_mincer{t}.csv")
    sp_age = load(f"results_spill_mincer{a}.csv")
    sp_ten = load(f"results_spill_mincer{t}.csv")

    # column sources: (data, outcome) for cols 1..6
    # 1 Direct raw | 2 Direct age-resid | 3 Direct age+ten-resid
    # 4 Spill raw  | 5 Spill age-resid  | 6 Spill age+ten-resid
    cols = [
        (dA_ten, "lr_remdezr_w"),      # raw (identical across suffixes)
        (dA_age, "lr_remdezr_resid"),  # age-only national
        (dA_ten, "lr_remdezr_resid"),  # age+tenure national
        (sp_ten, "lr_remdezr_w"),
        (sp_age, "lr_remdezr_resid"),
        (sp_ten, "lr_remdezr_resid"),
    ]

    def row_main(rt, fmt):
        return " & ".join(fmt(c[0][c[1]][rt]) for c in cols)

    # direct coefficient appears in cols 1-3 only; spillover in cols 4-6 only
    def split_row(rt, fmt):
        vals = [fmt(c[0][c[1]][rt]) for c in cols]
        direct = " & ".join(vals[:3]) + " & " + " & ".join([""] * 3)
        spill  = " & ".join([""] * 3) + " & " + " & ".join(vals[3:])
        return direct, spill

    post_d = " & ".join([coef(cols[i][0][cols[i][1]]["main"]) for i in range(3)] + [""] * 3)
    post_d_se = " & ".join([se(cols[i][0][cols[i][1]]["main_se"]) for i in range(3)] + [""] * 3)
    post_s = " & ".join([""] * 3 + [coef(cols[i][0][cols[i][1]]["main"]) for i in range(3, 6)])
    post_s_se = " & ".join([""] * 3 + [se(cols[i][0][cols[i][1]]["main_se"]) for i in range(3, 6)])

    obs   = " & ".join(cnt(cols[i][0][cols[i][1]]["n_obs"]) for i in range(6))
    estab = " & ".join(cnt(cols[i][0][cols[i][1]]["n_estab"]) for i in range(6))
    pre   = " & ".join(coef(cols[i][0][cols[i][1]]["pre"]) for i in range(6))
    pre_se = " & ".join(se(cols[i][0][cols[i][1]]["pre_se"]) for i in range(6))

    H = r"\begin{tabular}[c]{@{}c@{}}"
    E = r"\end{tabular}"
    hdr = (f"{H}Log\\\\Wages{E} & {H}Resid.\\\\(Age){E} & {H}Resid.\\\\(Age $+$ Ten.){E} & "
           f"{H}Log\\\\Wages{E} & {H}Resid.\\\\(Age){E} & {H}Resid.\\\\(Age $+$ Ten.){E}")

    notes = (
        r"\textit{Notes:} This table presents difference-in-differences estimates of the "
        r"ultractivity reform's effects on establishment-level log December wages. "
        r"Columns~(1)--(3) report direct effects, comparing directly treated establishments "
        r"to untreated establishments with zero pre-reform connectivity (Panel~A). "
        r"Columns~(4)--(6) report spillover effects on the full sample of untreated "
        r"establishments, using continuous connectivity to treated firms as the exposure "
        r"measure, normalized so that a value of~1 corresponds to the 90th percentile. "
        r"Columns~(1) and~(4) use raw log December wages. Columns~(2) and~(5) use a "
        r"Mincer-residualized log wage, and columns~(3) and~(6) add a quartic firm-tenure "
        r"polynomial to the residualization. In both residualizations the worker-level "
        r"residuals are obtained by projecting log wages onto a quartic age polynomial "
        r"(columns~2,~5) or a quartic age polynomial and a quartic tenure polynomial "
        r"(columns~3,~6) within race~$\times$~education~$\times$~gender~$\times$~year cells, "
        r"with education measured using all eleven categories recorded in RAIS; the cells "
        r"are estimated over the \emph{entire} RAIS worker panel (all establishments "
        r"nationwide, one selected spell per worker-year), and the establishment-level "
        r"outcome is the average of worker-level residuals. Cells with fewer worker-spell "
        r"observations than regressors are dropped. Post~$\times$~Treatment and "
        r"Post~$\times$~Connectivity measure average effects for 2012--2016. Pre-trend "
        r"(placebo) reports the coefficient from a placebo regression estimated on "
        r"pre-treatment data only (2009--2010 relative to 2011). All regressions include "
        r"establishment fixed effects and year fixed effects interacted with two-digit "
        r"industry, microregion, and negotiation-month indicators, as well as quartile-bin "
        r"controls for pre-treatment per-worker flows and establishment size interacted "
        r"with year fixed effects. Standard errors clustered at the establishment level in "
        r"parentheses. *** p$<$0.01, ** p$<$0.05, * p$<$0.10."
    )
    # swap the age-polynomial degree word (leaves "quartic tenure" untouched)
    notes = notes.replace("quartic age", f"{poly} age")

    tex = rf"""\begin{{table}}[htbp]
\centering
\caption{{{args.caption}}}
\label{{{args.label}}}
\footnotesize
\begin{{tabular}}{{lcccccc}}
\toprule\toprule
 & \multicolumn{{3}}{{c}}{{Direct Effects}} & \multicolumn{{3}}{{c}}{{Spillover Effects}} \\
 \cmidrule(lr){{2-4}} \cmidrule(lr){{5-7}}
 & {hdr} \\
 & (1) & (2) & (3) & (4) & (5) & (6) \\
\midrule
Post $\times$ Treatment & {post_d} \\
 & {post_d_se} \\
  &  &  &  &  &  &  \\
Post $\times$ Connectivity & {post_s} \\
 & {post_s_se} \\
 &  &  &  &  &  &  \\
Observations & {obs} \\
Establishments & {estab} \\
\midrule
Pre-trend (placebo) & {pre} \\
 & {pre_se} \\
\bottomrule\bottomrule
\end{{tabular}}

\begin{{minipage}}{{\linewidth}}
    \scriptsize\vspace{{4pt}}
{notes}
\end{{minipage}}
\end{{table}}
"""
    out_path = OUT_DIR / args.out
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(tex)
    print(f"Wrote {out_path}")
    print(tex)


if __name__ == "__main__":
    main()
