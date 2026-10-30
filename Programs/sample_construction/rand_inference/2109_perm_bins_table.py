#!/usr/bin/env python
"""LaTeX table: randomization p-values for the pooled spillover when the treated
label is permuted within industry x negotiation-month cells, alone and split by
pre-treatment size or wage bins (Referee 3). Reads 2093's
perm_spillover_<scheme>.json and 2108's expected_exposure_bins_meta.json.

Output: Tables/rand_inference/perm_bins.tex
"""
import os, json
from pathlib import Path

ROOT = Path(os.environ.get("UNIONSPILL_ROOT", "/gpfs/kellogg/proj/lgg3230/UnionSpill"))
OUT  = ROOT / "Data/rand_inference"
TAB  = ROOT / "Tables/rand_inference"

SCHEMES = [("ind_month", "Industry $\\times$ month"),
           ("ind_month_size4", "\\quad $\\times$ size quartiles"),
           ("ind_month_size10", "\\quad $\\times$ size deciles"),
           ("ind_month_size20", "\\quad $\\times$ size vingtiles"),
           ("ind_month_wage4", "\\quad $\\times$ wage quartiles"),
           ("ind_month_wage10", "\\quad $\\times$ wage deciles"),
           ("ind_month_wage20", "\\quad $\\times$ wage vingtiles")]
OUTS = ["lr_remdezr_h_w", "lr_remdezr_w", "l_firm_emp", "numb_clauses"]

def num(x, d): return f"{x:.{d}f}".replace("-", "$-$")
def cnt(x):    return f"{int(x):,}".replace(",", "{,}")
def hdr(t):    return "\\begin{tabular}[c]{@{}c@{}}" + t + "\\end{tabular}"
def row(cells): return " & ".join(cells) + " \\\\\n"

res  = {s: json.load(open(TAB / f"perm_spillover_{s}.json")) for s, _ in SCHEMES}
meta = json.load(open(OUT / "expected_exposure_bins_meta.json"))
R    = res["ind_month"][OUTS[0]]["R"]
tot  = meta["ind_month"]["spillover"]["treated_total"]

body = row(["Observed $\\hat\\beta$"]
           + [num(res["ind_month"][o]["delta_obs"], 3 if o == "numb_clauses" else 4) for o in OUTS] + [""])
body += row([""] * 6) + row(["\\textit{Randomization $p$-value}"] + [""] * 5)
for s, lab in SCHEMES:
    body += row([lab] + [num(res[s][o]["p_two_sided"], 4) for o in OUTS] + [cnt(meta[s]["spillover"]["swappable"])])

notes = (
    "\\textit{Notes:} This table reports randomization inference for the pooled spillover, "
    "permuting which establishments are labeled treated. In each of "
    f"$R = {cnt(R)}$ replications the treated label is reassigned within cells among the "
    "establishments of the balanced analysis sample, preserving the number of treated "
    "establishments in each cell; directly treated establishments outside the balanced panel are "
    "held fixed. Connectivity of each untreated establishment to the placebo treated set is rebuilt "
    "from the same pre-reform worker flows and the pooled spillover regression is re-estimated. "
    "The first scheme uses industry $\\times$ negotiation-month cells, the cells of the counterfactual "
    "connectivity in Figure~\\ref{fig:rob_logwages_recentered}. The other schemes split each cell "
    "further by bins of pre-treatment establishment size (log mean employment, 2009--2011) or "
    "pre-treatment wages (mean log hourly wage, 2009--2011), with cut points from the 2009 balanced "
    "panel. The $p$-value is two-sided, $(1 + \\#\\{|\\hat\\beta^{(r)}| \\geq |\\hat\\beta|\\})/(R+1)$; "
    f"its smallest attainable value is {1 / (R + 1):.4f}. The last column counts the treated "
    f"establishments, of {cnt(tot)}, that share a cell with at least one untreated establishment and "
    "can therefore be relabeled; the rest are treated in every replication, so finer cells reduce "
    "power mechanically. The clause count uses collective-bargaining-period rather than calendar-year "
    "structure."
)

tex = (
    "\\begin{table}[!tbp]\n\\centering\n"
    "\\caption{Randomization Inference: Permuting the Treated Set Within Size and Wage Cells}\n"
    "\\label{tab:perm_bins}\n\\scriptsize\n\\begin{threeparttable}\n"
    "\\begin{tabular}{lccccc}\n\\toprule\\toprule\n"
    + row(["Permutation cells", hdr("Log Hourly\\\\Wages"), hdr("Log\\\\Wages"), hdr("Log\\\\Employment"),
           hdr("Clause\\\\Count"), hdr("Swappable\\\\treated")])
    + row([""] + [f"({k})" for k in range(1, 6)])
    + "\\midrule\n" + body
    + "\\bottomrule\n\\end{tabular}\n\\scriptsize\n\\begin{tablenotes}\n\\item " + notes
    + "\n\\end{tablenotes}\n\\end{threeparttable}\n\\end{table}\n"
)
TAB.mkdir(parents=True, exist_ok=True)
(TAB / "perm_bins.tex").write_text(tex)
print("wrote", TAB / "perm_bins.tex")
