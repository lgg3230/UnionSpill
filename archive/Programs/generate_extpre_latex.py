#!/usr/bin/env python3
"""Extended-pre-period (2007-2008) robustness table from Tables/es_coefs_extpre.csv.

One table, two panels (Direct Panel A; Spillover), three outcome columns. Within each
panel, two stacked sub-blocks compare the pooled DiD across sample definitions:
  (a) Unbalanced  = headline balanced-2009-16 firms + 2007-08 where present
  (b) Balanced throughout 2007-16 = firms operating in every year 2007-2016
Each sub-block reports the pooled DiD on the 2009-16 window and on the 2007-16 window,
plus the joint pre-trend F-test (2007-2010). The contrast isolates how much of the
spillover attenuation is composition (entering firms) vs. the added pre-period.

House style per the unionspill-tables skill. Output: Tables/extpre_robustness.tex
"""
from pathlib import Path
import csv

OUTCOMES = ["lr_remdezr_w", "lr_remdezr_h_w", "l_firm_emp"]
COLLABS = [("Log", "Wages"), ("Log Hourly", "Wages"), ("Log", "Employment")]


def load(path):
    rows = {}
    with open(path) as f:
        for r in csv.DictReader(f):
            if int(float(r["year"])) != 2012:
                continue
            rows[(r["sample"], r["effect"], r["outcome"])] = r
    return rows


def stars(p):
    p = float(p)
    return "***" if p < 0.01 else "**" if p < 0.05 else "*" if p < 0.10 else ""


def coef(b, p):
    b = float(b)
    s = f"{abs(b):.4f}"
    s = ("$-$" + s) if b < 0 else s
    return s + stars(p)


def se(x):
    return f"({float(x):.4f})"


def pv(x):
    return f"[{float(x):.2f}]"


def cnt(x):
    return f"{int(round(float(x))):,}".replace(",", "{,}")


def hdr(top, bot):
    return r"\begin{tabular}[c]{@{}c@{}}%s\\%s\end{tabular}" % (top, bot)


def panel_cell(bold, italic):
    return (r"\begin{tabular}[c]{@{}l@{}}\textbf{%s} \textit{%s}\end{tabular}"
            % (bold, italic))


def threecol(fmt, cells):
    return " & ".join(fmt(c) for c in cells)


def subblock(rows, sample, effect, rowvar, title):
    cells = [rows[(sample, effect, o)] for o in OUTCOMES]
    L = []
    L.append(r"\textit{%s} & & & \\" % title)
    # 2009--2016 window: post then pre placebo
    L.append("\\quad Post $\\times$ %s, 2009--2016 & %s \\\\" %
             (rowvar, threecol(lambda c: coef(c["post_head_b"], c["post_head_p"]), cells)))
    L.append(" & %s \\\\" % threecol(lambda c: se(c["post_head_se"]), cells))
    L.append("\\quad Pre $\\times$ %s, 2009--2016 & %s \\\\" %
             (rowvar, threecol(lambda c: coef(c["pre_head_b"], c["pre_head_p"]), cells)))
    L.append(" & %s \\\\" % threecol(lambda c: se(c["pre_head_se"]), cells))
    # 2007--2016 window: post then pre placebo
    L.append("\\quad Post $\\times$ %s, 2007--2016 & %s \\\\" %
             (rowvar, threecol(lambda c: coef(c["post_ext_b"], c["post_ext_p"]), cells)))
    L.append(" & %s \\\\" % threecol(lambda c: se(c["post_ext_se"]), cells))
    L.append("\\quad Pre $\\times$ %s, 2007--2016 & %s \\\\" %
             (rowvar, threecol(lambda c: coef(c["pre_ext_b"], c["pre_ext_p"]), cells)))
    L.append(" & %s \\\\" % threecol(lambda c: se(c["pre_ext_se"]), cells))
    L.append("\\quad Pre-trend $F$ $p$ (2007--2010) & %s \\\\" %
             threecol(lambda c: pv(c["pF_2007_10"]), cells))
    L.append("\\quad Establishments & %s \\\\" %
             threecol(lambda c: cnt(c["n_estab"]), cells))
    return "\n".join(L)


def panel(rows, effect, label_bold, label_ital, rowvar):
    L = []
    L.append("%s & %s & %s & %s \\\\" %
             (panel_cell(label_bold, label_ital),
              hdr(*COLLABS[0]), hdr(*COLLABS[1]), hdr(*COLLABS[2])))
    L.append(" & (1) & (2) & (3) \\\\")
    L.append(r"\midrule")
    L.append(subblock(rows, "unbal", effect, rowvar, "(a) Unbalanced (2009--16 firms)"))
    L.append(" & & & \\\\")
    L.append(subblock(rows, "bal", effect, rowvar, "(b) Balanced throughout 2007--16"))
    return "\n".join(L)


def main():
    sd = Path(__file__).resolve().parent
    td = sd.parent / "Tables"
    rows = load(td / "es_coefs_extpre.csv")

    notes = (
        r"\textit{Notes:} This table assesses the robustness of the headline "
        r"difference-in-differences estimates to extending the pre-treatment window back to 2007. "
        r"Firm-year outcomes for 2007--2008 are reconstructed from the full RAIS following the "
        r"same worker-selection and deflation procedure as the main sample, and reproduce the 2009 "
        r"values to machine precision. The reform (Brazil's 2012 ultractivity ruling, effective "
        r"September~25, 2012) extended existing CBAs indefinitely upon expiration. "
        r"Each panel reports the pooled estimate on the published 2009--2016 window and on the extended "
        r"2007--2016 window, under two sample definitions: \textit{(a)} the headline balanced-2009--2016 "
        r"firms with 2007--2008 observations added where the firm operated (pre-period unbalanced), and "
        r"\textit{(b)} firms operating in every year 2007--2016 (balanced throughout). Comparing the "
        r"2009--2016 rows across \textit{(a)} and \textit{(b)} isolates the role of firms entering after "
        r"2007; comparing the 2009--2016 and 2007--2016 rows within a sample isolates the added pre-period. "
        r"``Post~$\times$~Treatment/Connectivity'' is the pooled post-reform estimate ($t\geq2012$ versus the "
        r"pre-period); ``Pre~$\times$~Treatment/Connectivity'' is the corresponding placebo, which replaces the "
        r"post indicator with one for the pre-treatment years (2009--2010 in the 2009--2016 window, 2007--2010 in "
        r"the 2007--2016 window) relative to the 2011 reference. "
        r"The pre-trend $F$ $p$-value is a joint test that the dynamic event-study coefficients for "
        r"2007--2010 are zero (2011 is the omitted base). All regressions include establishment fixed "
        r"effects, year fixed effects interacted with two-digit industry, microregion, and "
        r"negotiation-month indicators, and quartile-bin controls for pre-treatment per-worker pairwise "
        r"worker flows and establishment size interacted with year. The direct panel uses Panel~A "
        r"(zero-connectivity controls); the spillover panel uses untreated firms with connectivity "
        r"normalized to the 90th percentile of the spillover sample in 2009. Standard errors clustered at "
        r"the establishment level in parentheses. *** $p<.01$, ** $p<.05$, * $p<.10$."
    )

    out = []
    out.append(r"\begin{table}[!htbp]")
    out.append(r"\centering")
    out.append(r"\caption{Robustness to extending the pre-treatment window to 2007}")
    out.append(r"\label{tab:extpre_robustness}")
    out.append(r"\scriptsize")
    out.append(r"\begin{threeparttable}")
    out.append(r"\begin{tabular}{lccc}")
    out.append(r"\toprule\toprule")
    out.append(panel(rows, "direct_A", "Panel A:",
                     "Direct Effects (Zero-Connectivity Controls)", "Treatment"))
    out.append(r"\midrule")
    out.append(r" & & & \\")
    out.append(panel(rows, "spill", "Panel B:",
                     "Spillover Effects (Untreated Connected Firms)", "Connectivity"))
    out.append(r"\bottomrule")
    out.append(r"\end{tabular}")
    out.append(r"\scriptsize")
    out.append(r"\begin{tablenotes}")
    out.append(r"\item " + notes)
    out.append(r"\end{tablenotes}")
    out.append(r"\end{threeparttable}")
    out.append(r"\end{table}")

    content = "\n".join(out) + "\n"
    (td / "extpre_robustness.tex").write_text(content)
    print("wrote", td / "extpre_robustness.tex")

    # also write into the paper's Tables/ dir so the manuscript stays in sync
    paper_tab = sd.parents[2] / "UnionSpill_paper" / "Tables"
    if paper_tab.is_dir():
        (paper_tab / "extpre_robustness.tex").write_text(content)
        print("wrote", paper_tab / "extpre_robustness.tex")


if __name__ == "__main__":
    main()
