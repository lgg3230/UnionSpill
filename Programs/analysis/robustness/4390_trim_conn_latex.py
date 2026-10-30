#!/usr/bin/env python3
"""
4390_trim_conn_latex.py
=======================
Table for the connectivity-tail robustness checks (3292_trim_conn.do): log
hourly wage spillover effects after trimming (mode trim: drop exposed firms) or
winsorizing (mode winsor: cap their connectivity) the left, right, or both
tails (5%, 10%, 20%) of the connectivity distribution among exposed untreated
firms; zero-connectivity firms are always kept.

Input (written by 3292_trim_conn.do via 3291_trim_conn.do or 3293_winsor_conn.do):
    Tables/<stem>/<stem>.csv, <stem>_groups.csv, <stem>_cutoffs.csv
    (stem = trim_conn or winsor_conn)
Output:
    Tables/<stem>/t_<stem>.tex          table fragment (tab:<stem>)
    Tables/<stem>/<stem>_summary.csv    flat summary, change vs baseline
    Tables/<stem>/<stem>_preview.tex    standalone preview document

Usage: python 4390_trim_conn_latex.py [TABLES_DIR] [trim|winsor]
"""

import csv
import math
import sys
from pathlib import Path

SIDES = [("left", "Left tail (lowest connectivity)"),
         ("right", "Right tail (highest connectivity)"),
         ("both", "Both tails")]
LEVELS = [5, 10, 20]


def hdr(text):
    return r"\begin{tabular}[c]{@{}c@{}}" + text + r"\end{tabular}"


def panel_cell(bold, italic):
    return r"\begin{tabular}[c]{@{}l@{}}" + bold + r"\\ " + italic + r"\end{tabular}"


def num(x, d=4):
    s = f"{x:.{d}f}"
    return r"$-$" + s[1:] if s.startswith("-") else s


def stars(p):
    return "" if p is None or math.isnan(p) else "***" if p < 0.01 else "**" if p < 0.05 else "*" if p < 0.10 else ""


def count(x):
    return f"{int(round(x)):,}".replace(",", "{,}")


def fl(s):
    try:
        return float(s)
    except (TypeError, ValueError):
        return float("nan")


def load(tables, stem):
    res = {}
    with open(tables / f"{stem}.csv", newline="") as f:
        for r in csv.DictReader(f):
            res.setdefault(r["spec"], {})[r["row_type"]] = fl(r["value"])
    grp = {}
    with open(tables / f"{stem}_groups.csv", newline="") as f:
        for r in csv.DictReader(f):
            grp[r["variant"]] = {k: fl(v) for k, v in r.items() if k != "variant"}
    p90 = None
    with open(tables / f"{stem}_cutoffs.csv", newline="") as f:
        for r in csv.DictReader(f):
            if fl(r["value_raw"]) > 0:
                p90 = fl(r["value_raw"]) / fl(r["value_scaled"])
    return res, grp, p90


def row(label, cells):
    return label + " & " + " & ".join(cells) + r" \\"


def table(res, grp, p90, mode):
    win = mode == "winsor"
    verb = "Winsorize" if win else "Trim"
    L = [r"\begin{table}[!htbp]", r"\centering",
         r"\caption{Spillover Effects on Log Hourly Wages: " + ("Winsorizing" if win else "Trimming") +
         r" the Tails of Connectivity}",
         r"\label{tab:" + ("winsor_conn" if win else "trim_conn") + "}", r"\scriptsize",
         r"\begin{threeparttable}",
         r"\begin{tabular}{lcccc}", r"\toprule\toprule"]
    for i, (side, desc) in enumerate(SIDES):
        variants = ["base"] + [f"{side}{q}" for q in LEVELS]
        cols = [hdr(r"Baseline")] + [hdr(rf"{verb}\\{q}\%") for q in LEVELS]
        if i:
            L += [r"\midrule"]
        L += [row(panel_cell(rf"\textbf{{Panel {'ABC'[i]}:}}", rf"\textit{{{desc}}}"), cols),
              row("", [f"({k})" for k in range(1, 5)]), r"\midrule"]
        g = lambda v, k: res.get(v, {}).get(k, float("nan"))
        L += [row(r"Post $\times$ Connectivity", [num(g(v, "main")) + stars(g(v, "main_p")) for v in variants]),
              row("", ["(" + num(g(v, "main_se")) + ")" for v in variants]),
              row(r"Pre $\times$ Connectivity", [num(g(v, "pre")) + stars(g(v, "pre_p")) for v in variants]),
              row("", ["(" + num(g(v, "pre_se")) + ")" for v in variants]),
              row(r"Pre-trend $F$-test $p$-value", [f"[{g(v, 'pre_pval'):.2f}]" for v in variants]),
              " & & & & \\\\"]
        lo = [("--" if math.isnan(grp[v]["lo"]) else num(grp[v]["lo"] / p90, 3)) for v in variants]
        hi = [("--" if math.isnan(grp[v]["hi"]) else num(grp[v]["hi"] / p90, 3)) for v in variants]
        L += [row("Lower cap" if win else "Connectivity kept: lower cutoff", lo),
              row("Upper cap" if win else "Connectivity kept: upper cutoff", hi),
              row("Mean connectivity, exposed" + ("" if win else " kept"),
                  [num(grp[v]["mean_conn"], 3) for v in variants])]
        if not win:
            L += [row("Median employment, exposed kept", [num(grp[v]["p50_emp"], 1) for v in variants])]
        L += [
              row("Exposed establishments", [count(g(v, "n_exposed")) for v in variants]),
              row("Establishments", [count(g(v, "n_estab")) for v in variants]),
              row("Observations", [count(g(v, "n_obs")) for v in variants])]
    nz = count(grp["base"]["n_zero"])
    what = (
        r"after winsorizing the tails of the connectivity distribution: every establishment is kept, "
        r"and the connectivity of exposed establishments beyond a cutoff is set to the cutoff. "
        r"Cutoffs are percentiles of connectivity among untreated establishments with positive "
        r"connectivity (the exposed): column~2 raises connectivity below the 5th percentile to it "
        r"(Panel~A), caps it at the 95th (Panel~B), or both (Panel~C); columns~3 and~4 do the same at "
        r"10\% and 20\%. The " + nz + r" untreated establishments with zero connectivity keep zero"
        if win else
        r"after trimming the tails of the connectivity distribution. Cutoffs are percentiles of "
        r"connectivity among untreated establishments with positive connectivity (the exposed): "
        r"column~2 drops exposed establishments below the 5th percentile (Panel~A), above the 95th "
        r"(Panel~B), or both (Panel~C); columns~3 and~4 do the same at 10\% and 20\%. The " + nz +
        r" untreated establishments with zero connectivity are always kept"
    )
    notes = (
        r"This table re-estimates the spillover effect of the 2012 ultractivity reform on log hourly "
        r"wages " + what + r": they are the comparison group, and 46\% of the spillover sample has zero "
        r"connectivity, so percentiles over the whole sample would leave the left tail undefined. "
        r"Connectivity is scaled to the 90th percentile of the unmodified 2009 distribution among "
        r"untreated establishments, as in the main spillover regressions, so every column is per unit "
        r"of the same regressor; cutoffs and means are reported in that unit" +
        ("" if win else r", and median employment is the 2009--2011 mean employment of the exposed "
                        r"establishments kept") + r". "
        r"Post $\times$ Connectivity measures the average effect for 2012--2016; "
        r"Pre $\times$ Connectivity is a placebo test using 2009--2011; the pre-trend $F$-test is on the "
        r"2009 and 2010 event-study coefficients (base 2011). All regressions include establishment "
        r"fixed effects, year fixed effects interacted with industry, microregion, and negotiation-month "
        r"indicators, and quartile-bin controls for the pre-treatment outcome, pre-treatment "
        r"establishment size and pre-treatment per-worker pairwise worker flows (2007--2011), interacted "
        r"with year; outcome, size and flow bins are those of the full sample. Column~1 reproduces "
        r"the main spillover estimate. Standard errors clustered at the establishment level in "
        r"parentheses. *** p$<$0.01, ** p$<$0.05, * p$<$0.10."
    )
    L += [r"\bottomrule", r"\end{tabular}", r"\scriptsize", r"\begin{tablenotes}",
          r"\item \textit{Notes:} " + notes, r"\end{tablenotes}", r"\end{threeparttable}",
          r"\end{table}"]
    return L


def summary(res, grp, path):
    base = res["base"]
    with open(path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["variant", "b", "se", "p", "pre", "pre_se", "pre_pval", "diff_vs_base",
                    "n_exposed", "n_estab", "mean_conn_exposed"])
        for v, r in res.items():
            w.writerow([v, r["main"], r["main_se"], r["main_p"], r["pre"], r["pre_se"], r["pre_pval"],
                        r["main"] - base["main"], int(r["n_exposed"]), int(r["n_estab"]),
                        grp[v]["mean_conn"]])


def main():
    mode = sys.argv[2] if len(sys.argv) > 2 else "trim"
    stem = "winsor_conn" if mode == "winsor" else "trim_conn"
    tables = Path(sys.argv[1]) if len(sys.argv) > 1 else \
        Path(__file__).resolve().parents[3] / "Tables" / stem
    res, grp, p90 = load(tables, stem)
    (tables / f"t_{stem}.tex").write_text("\n".join(table(res, grp, p90, mode)) + "\n")
    summary(res, grp, tables / f"{stem}_summary.csv")
    (tables / f"{stem}_preview.tex").write_text("\n".join([
        r"\documentclass[12pt,letterpaper]{article}", r"\usepackage[margin=0.8in]{geometry}",
        r"\usepackage{booktabs}", r"\usepackage{threeparttable}", r"\usepackage{amsmath}",
        r"\begin{document}", r"\input{t_" + stem + r".tex}", r"\end{document}"]) + "\n")
    print(f"Generated {tables / f't_{stem}.tex'} and {tables / f'{stem}_summary.csv'}")


if __name__ == "__main__":
    main()
