#!/usr/bin/env python
"""LaTeX table: spillover estimates controlling for counterfactual connectivity
under each reshuffle scheme (Referee 3). Reads 4153's recentered_bins.csv and
2108's expected_exposure_bins_meta.json (cell counts).

Usage: python 4154_recentered_bins_table.py [randdir] [tables_dir]
Output: Tables/rand_inference/recentered_bins.tex
"""
import sys, json, math
from pathlib import Path
import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
RAND = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "Data/rand_inference"
TAB  = Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT / "Tables/rand_inference"

SCHEMES = [("ind_month", "Industry $\\times$ month"),
           ("ind_month_size4", "\\quad $\\times$ size quartiles"),
           ("ind_month_size10", "\\quad $\\times$ size deciles"),
           ("ind_month_size20", "\\quad $\\times$ size vingtiles"),
           ("ind_month_wage4", "\\quad $\\times$ wage quartiles"),
           ("ind_month_wage10", "\\quad $\\times$ wage deciles"),
           ("ind_month_wage20", "\\quad $\\times$ wage vingtiles")]
OUTS = ["lr_remdezr_h_w", "lr_remdezr_w"]

def stars(b, se):
    p = math.erfc(abs(b / se) / math.sqrt(2))
    return "***" if p < 0.01 else "**" if p < 0.05 else "*" if p < 0.10 else ""
def num(x):   return f"{x:.4f}".replace("-", "$-$")
def coef(b, se): return num(b) + stars(b, se)
def se_(x):   return f"({x:.4f})"
def pv(x):    return f"[{x:.3f}]"
def cnt(x):   return f"{int(x):,}".replace(",", "{,}")
def hdr(t):   return "\\begin{tabular}[c]{@{}c@{}}" + t + "\\end{tabular}"
def row(cells): return " & ".join(cells) + " \\\\\n"

res  = pd.read_csv(TAB / "recentered_bins.csv").set_index(["outcome", "mu"])
meta = json.load(open(RAND / "expected_exposure_bins_meta.json"))
r = lambda o, s: res.loc[(o, f"mu_C_{s}")]
blank = row([""] * 7)

body = ""
m = {o: r(o, "ind_month") for o in OUTS}
body += row(["No counterfactual control"] + sum([[coef(m[o].b_main, m[o].se_main), ""] for o in OUTS], []) + ["", ""])
body += row([""] + sum([[se_(m[o].se_main), ""] for o in OUTS], []) + ["", ""])
body += row(["\\quad Pre-trend $F$-test $p$-value"] + sum([[pv(m[o].p_main), ""] for o in OUTS], []) + ["", ""])
for s, lab in SCHEMES:
    body += blank
    x ={o: r(o, s) for o in OUTS}; c = meta[s]["spillover"]
    body += row([lab] + sum([[coef(x[o].b_adj, x[o].se_adj), coef(x[o].b_mu, x[o].se_mu)] for o in OUTS], [])
                + [cnt(c["swappable"]), cnt(c["treated_fixed"])])
    body += row([""] + sum([[se_(x[o].se_adj), se_(x[o].se_mu)] for o in OUTS], []) + ["", ""])
    body += row(["\\quad Pre-trend $F$-test $p$-value"] + sum([[pv(x[o].p_adj), pv(x[o].p_mu)] for o in OUTS], [])
                + ["", ""])
body += blank
n = {o: m[o] for o in OUTS}
body += row(["Observations"] + sum([[cnt(n[o].n_obs), ""] for o in OUTS], []) + ["", ""])
body += row(["Establishments"] + sum([[cnt(n[o].n_estab), ""] for o in OUTS], []) + ["", ""])

tot = meta["ind_month"]["spillover"]["treated_total"]
notes = (
    "\\textit{Notes:} This table reports the pooled spillover of the 2012 ultractivity reform on "
    "untreated establishments when the specification controls for counterfactual connectivity "
    "$\\mu_i \\times$ Post, for several reshuffle schemes. Counterfactual connectivity is an "
    "establishment's expected connectivity to the treated set when the treated label is reassigned "
    "within cells, holding the number of treated establishments per cell fixed and recomputing "
    "connectivity from the same pre-reform worker flows. The first scheme uses industry $\\times$ "
    "negotiation-month cells, as in Figure~\\ref{fig:rob_logwages_recentered}. The other schemes "
    "split each cell further by bins of pre-treatment establishment size (log mean employment, "
    "2009--2011) or pre-treatment wages (mean log hourly wage, 2009--2011), with cut points from "
    "the 2009 balanced panel; quartiles are the bins of the main specification. "
    "Columns (1) and (3) report Post $\\times$ Connectivity and columns (2) and (4) report Post "
    "$\\times$ Counterfactual connectivity. The first row omits the counterfactual control and "
    "reproduces Table~\\ref{tab:spill_main_4tf_out}. Square brackets give $p$-values of the joint "
    "test that the 2009 and 2010 event-study coefficients of each term are zero. Column (5) counts "
    f"the treated establishments, of {cnt(tot)} in the balanced panel, that share a cell with at "
    "least one untreated establishment and can therefore be reassigned; column (6) counts those in "
    "cells with no untreated establishment, which are treated in every reshuffle. "
    "All specifications include establishment fixed effects and year fixed effects interacted with "
    "three-digit industry, microregion, and negotiation-month indicators and with quartile bins of "
    "pre-treatment firm size, per-worker flows, and the outcome. Standard errors clustered at the "
    "establishment level in parentheses. *** p$<$0.01, ** p$<$0.05, * p$<$0.10."
)

tex = (
    "\\begin{table}[!tbp]\n\\centering\n"
    "\\caption{Hourly and Monthly Wage Spillovers: Counterfactual Connectivity by Reshuffle Cell}\n"
    "\\label{tab:recentered_bins}\n\\scriptsize\n\\begin{threeparttable}\n"
    "\\begin{tabular}{lcccccc}\n\\toprule\\toprule\n"
    + row(["", "\\multicolumn{2}{c}{Log Hourly Wages}", "\\multicolumn{2}{c}{Log Wages}", "", ""])
    + "\\cmidrule(lr){2-3}\\cmidrule(lr){4-5}\n"
    + row(["Reshuffle cells", hdr("Post $\\times$\\\\Connectivity"), hdr("Post $\\times$\\\\Counterfactual"),
           hdr("Post $\\times$\\\\Connectivity"), hdr("Post $\\times$\\\\Counterfactual"),
           hdr("Swappable\\\\treated"), hdr("Always\\\\treated")])
    + row([""] + [f"({k})" for k in range(1, 7)])
    + "\\midrule\n" + body
    + "\\bottomrule\n\\end{tabular}\n\\scriptsize\n\\begin{tablenotes}\n\\item " + notes
    + "\n\\end{tablenotes}\n\\end{threeparttable}\n\\end{table}\n"
)
(TAB / "recentered_bins.tex").write_text(tex)
print("wrote", TAB / "recentered_bins.tex")
