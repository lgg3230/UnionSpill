#!/usr/bin/env python3
"""
Connectivity-trimming table for the ATT section of the referee analyses, in the
layout of tab:trim_sides_spill (one row of columns: untrimmed, then the left,
right and both tails at 5, 10 and 20%), log hourly wage spillover effects.

Reads  Tables/trim_conn/trim_conn.csv          (3291 -> 3292_trim_conn.do)
       Tables/trim_conn/trim_conn_groups.csv
       Tables/trim_conn/trim_conn_cutoffs.csv
Writes Tables/trim_conn/t_trim_conn_paper.tex   table float, label tab:trim_conn

Usage: python 4391_table_trim_conn_paper.py
"""

import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
TAB = ROOT / "Tables" / "trim_conn"
OUT = TAB / "t_trim_conn_paper.tex"

VARIANTS = ["base", "left5", "left10", "left20", "right5", "right10", "right20",
            "both5", "both10", "both20"]
# variant -> (lower, upper) percentile of connectivity among exposed establishments
CUTS = {"left5": ("p5", None), "left10": ("p10", None), "left20": ("p20", None),
        "right5": (None, "p95"), "right10": (None, "p90"), "right20": (None, "p80"),
        "both5": ("p5", "p95"), "both10": ("p10", "p90"), "both20": ("p20", "p80")}


def load():
    for f in ("trim_conn.csv", "trim_conn_groups.csv", "trim_conn_cutoffs.csv"):
        if not (TAB / f).exists():
            raise SystemExit(f"Missing input: {TAB / f}. Run 3291_trim_conn.do first.")
    res = {}
    with open(TAB / "trim_conn.csv", newline="") as fh:
        for r in csv.DictReader(fh):
            if r["outcome"] == "lr_remdezr_h_w":
                res.setdefault(r["spec"], {})[r["row_type"]] = float(r["value"])
    with open(TAB / "trim_conn_groups.csv", newline="") as fh:
        groups = {r["variant"]: {k: float(v) if v.strip() not in ("", ".") else None
                                 for k, v in r.items() if k != "variant"}
                  for r in csv.DictReader(fh)}
    with open(TAB / "trim_conn_cutoffs.csv", newline="") as fh:
        cuts = {r["percentile"]: float(r["value_scaled"]) for r in csv.DictReader(fh)}
    missing = [v for v in VARIANTS if v not in res or v not in groups]
    if missing:
        raise SystemExit(f"Variants missing from the trim_conn outputs: {missing}")
    return res, groups, cuts


def num(x, digits=4):
    s = f"{x:.{digits}f}"
    return r"$-$" + s[1:] if s.startswith("-") else s


def stars(p):
    return "***" if p < 0.01 else "**" if p < 0.05 else "*" if p < 0.10 else ""


def count(x):
    return f"{int(x):,}".replace(",", "{,}")


def row(label, cells):
    return label + "".join(f" & {c}" for c in cells) + r"\\"


def build(res, groups, cuts):
    R = [res[v] for v in VARIANTS]
    G = [groups[v] for v in VARIANTS]

    def cut(v, side):
        if v == "base" or CUTS[v][side] is None:
            return "--"
        return f"{cuts[CUTS[v][side]]:.3f}"

    blank = row("", [""] * len(VARIANTS))
    lines = [
        r"\begin{table}[H]",
        r"\centering",
        r"\caption{Spillover Effects on Log Hourly Wages under Tail Trimming of Connectivity}",
        r"\label{tab:trim_conn}",
        r"\scriptsize",
        r"\setlength{\tabcolsep}{4pt}",
        r"\resizebox{\textwidth}{!}{%",
        r"\begin{tabular}{lcccccccccc}",
        r"\toprule\toprule",
        r" & \multicolumn{1}{c}{Untrimmed} & \multicolumn{3}{c}{Left tail} & \multicolumn{3}{c}{Right tail} & \multicolumn{3}{c}{Both tails}\\",
        r"\cmidrule(lr){2-2} \cmidrule(lr){3-5} \cmidrule(lr){6-8} \cmidrule(lr){9-11}",
        r" & Baseline & 5\% & 10\% & 20\% & 5\% & 10\% & 20\% & 5\% & 10\% & 20\%\\",
        row("", [f"({i})" for i in range(1, 11)]),
        r"\midrule",
        row(r"Post $\times$ Connectivity", [num(r["main"]) + stars(r["main_p"]) for r in R]),
        row("", [f"({num(r['main_se'])})" for r in R]),
        blank,
        row("Mean", [f"{r['mean_pre']:.3f}" for r in R]),
        row("Observations", [count(r["n_obs"]) for r in R]),
        row("Establishments", [count(r["n_estab"]) for r in R]),
        row("Exposed establishments", [count(r["n_exposed"]) for r in R]),
        r"\midrule",
        row("Pre-trend (placebo)", [num(r["pre"]) + stars(r["pre_p"]) for r in R]),
        row("", [f"({num(r['pre_se'])})" for r in R]),
        row(r"Pre-trend $F$-test $p$-value", [f"[{r['pre_pval']:.2f}]" for r in R]),
        r"\midrule",
        row("Lower connectivity cutoff", [cut(v, 0) for v in VARIANTS]),
        row("Upper connectivity cutoff", [cut(v, 1) for v in VARIANTS]),
        row("Mean connectivity, exposed kept", [f"{g['mean_conn']:.3f}" for g in G]),
        row("Mean employment, exposed kept", [f"{g['mean_emp']:.1f}" for g in G]),
        r"\bottomrule\bottomrule",
        r"\end{tabular}}",
        "",
        r"\begin{minipage}{\textwidth}",
        r"\scriptsize\vspace{4pt}",
        NOTES.replace("@@NZERO@@", count(G[0]["n_zero"])),
        r"\end{minipage}",
        r"\end{table}",
    ]
    return "\n".join(lines) + "\n"


NOTES = (
    r"\textit{Notes:} This table reports difference-in-differences estimates of the reform's spillover "
    r"effects on the log hourly wages of untreated establishments after trimming the tails of the "
    r"connectivity distribution; column~(1) reproduces Table~\ref{tab:spill_main_4tf_out}. Cutoffs are "
    r"percentiles of connectivity among untreated establishments with positive connectivity (the exposed): "
    r"each column drops exposed establishments below the 5th, 10th, or 20th percentile (left tail), above "
    r"the 95th, 90th, or 80th percentile (right tail), or both. The @@NZERO@@ untreated establishments "
    r"with zero connectivity are always kept, since they are the comparison group. Connectivity is "
    r"per-worker worker flows to treated establishments (2007--2011), scaled so that 1 is the 90th "
    r"percentile among untreated establishments in 2009 (untrimmed sample), so every column is per unit "
    r"of the same regressor; cutoffs and means are reported in that unit. Mean employment is the "
    r"2009--2011 mean employment of the exposed establishments kept. Post reports the average effect over "
    r"2012--2016; the placebo is the coefficient from a placebo regression estimated on pre-treatment data "
    r"only; the pre-trend $F$-test $p$-value tests that the 2009 and 2010 event-study coefficients are "
    r"jointly zero. Mean reports the average of the dependent variable over 2009--2011 in each column's "
    r"estimation sample; observations and establishments are those of the Post regression. Specifications "
    r"are identical to the main tables: establishment fixed effects and year fixed effects interacted with "
    r"three-digit industry, microregion, and negotiation-month indicators and with quartile bins of "
    r"pre-treatment firm size, per-worker flows, and the outcome, all bins and the connectivity "
    r"normalization built on the untrimmed sample. Standard errors clustered at the establishment level in "
    r"parentheses. *** p$<$0.01, ** p$<$0.05, * p$<$0.10."
)


def main():
    OUT.write_text(build(*load()))
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    main()
