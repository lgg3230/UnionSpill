#!/usr/bin/env python3
"""
Robustness table: baseline vs. p99-trimmed estimates for lr_remdezr_w.
Three exercises side by side (Ex1 / Ex2 / Ex3).

Output: Tables/conn_margins/conn_margins_trim_table.tex
"""

import re
from pathlib import Path

script_dir = Path(__file__).resolve().parent
tables_dir = script_dir.parent.parent / "Tables" / "conn_margins"


# ── Helpers ───────────────────────────────────────────────────────────────────

def load_csv(filepath, outcome_filter=None):
    data = {}
    if not filepath.exists():
        print(f"  WARNING: {filepath.name} not found")
        return data
    with open(filepath) as f:
        next(f)
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = line.replace('"', '').split(";")
            if len(parts) < 5:
                continue
            _, _, outcome, row_type, value = parts[0], parts[1], parts[2], parts[3], parts[4]
            if outcome_filter and outcome != outcome_filter:
                continue
            data.setdefault(outcome, {})[row_type] = value.strip()
    return data


def fmt(raw, is_se=False, is_count=False, is_pval=False):
    raw = raw.strip() if raw else "--"
    if raw in ("--", ""):
        return "--"
    if is_count:
        return raw.replace(",", "{,}")
    if is_pval:
        return f"[{raw}]"
    match = re.match(r"^([^*]+?)(\*{1,3})?$", raw)
    if not match:
        return raw
    num_str = match.group(1).strip()
    stars   = match.group(2) or ""
    if is_se:
        return f"({num_str})"
    return f"{num_str}{stars}"


def get(d, key, **kwargs):
    return fmt(d.get(key, "--"), **kwargs)


# ── Load data ─────────────────────────────────────────────────────────────────

outcome = "lr_remdezr_w"

base = {
    "ex1": load_csv(tables_dir / "results_conn_margins_ex1.csv", outcome).get(outcome, {}),
    "ex2": load_csv(tables_dir / "results_conn_margins_ex2.csv", outcome).get(outcome, {}),
    "ex3": load_csv(tables_dir / "results_conn_margins_ex3.csv", outcome).get(outcome, {}),
}
trim = {
    "ex1": load_csv(tables_dir / "results_conn_margins_trim_ex1.csv", outcome).get(outcome, {}),
    "ex2": load_csv(tables_dir / "results_conn_margins_trim_ex2.csv", outcome).get(outcome, {}),
    "ex3": load_csv(tables_dir / "results_conn_margins_trim_ex3.csv", outcome).get(outcome, {}),
}


# ── Table builder ─────────────────────────────────────────────────────────────

def row(*cells):
    return " & ".join(cells) + r" \\" + "\n"


def midrule():
    return r"\midrule" + "\n"


def addspace():
    return r"\\[-4pt]" + "\n"


lines = []

# Preamble
lines.append(r"\documentclass[12pt]{article}" + "\n")
lines.append(r"\usepackage{booktabs,threeparttable,float,geometry}" + "\n")
lines.append(r"\geometry{margin=1in}" + "\n")
lines.append(r"\begin{document}" + "\n\n")

# Table
lines.append(r"\begin{table}[H]" + "\n")
lines.append(r"\centering" + "\n")
lines.append(r"\caption{Robustness: dropping top-1\% connectivity firms --- Log wages (lr\_remdezr\_w)}" + "\n")
lines.append(r"\label{tab:trim_robustness}" + "\n")
lines.append(r"\begin{threeparttable}" + "\n")

# 7 columns: row label + (Baseline, Trimmed) x 3 exercises
lines.append(r"\begin{tabular}{lcccccc}" + "\n")
lines.append(r"\toprule" + "\n")

# Header row 1
lines.append(row(
    "",
    r"\multicolumn{2}{c}{Panel A: Extensive}",
    r"\multicolumn{2}{c}{Panel B: Intensive}",
    r"\multicolumn{2}{c}{Panel C: Saturated}",
))
lines.append(r"\cmidrule(lr){2-3}\cmidrule(lr){4-5}\cmidrule(lr){6-7}" + "\n")

# Header row 2
lines.append(row(
    "",
    "Baseline", "Trimmed",
    "Baseline", "Trimmed",
    "Baseline", "Trimmed",
))
lines.append(r"\midrule" + "\n")

# ── Panel A/B: post coefficient + SE ─────────────────────────────────────────

# Ex1 & Ex2 share same row_type names; Ex3 has _pos and _conn variants
# Post coefficient
lines.append(row(
    r"Post $\times$ Connectivity",
    get(base["ex1"], "main"),
    get(trim["ex1"], "main"),
    get(base["ex2"], "main"),
    get(trim["ex2"], "main"),
    get(base["ex3"], "main_pos"),
    get(trim["ex3"], "main_pos"),
))
lines.append(row(
    "",
    get(base["ex1"], "main_se", is_se=True),
    get(trim["ex1"], "main_se", is_se=True),
    get(base["ex2"], "main_se", is_se=True),
    get(trim["ex2"], "main_se", is_se=True),
    get(base["ex3"], "main_pos_se", is_se=True),
    get(trim["ex3"], "main_pos_se", is_se=True),
))

lines.append(addspace())

# Ex3 conn row (only relevant for Panel C)
lines.append(row(
    r"Post $\times$ Conn.\ (continuous)",
    "", "",
    "", "",
    get(base["ex3"], "main_conn"),
    get(trim["ex3"], "main_conn"),
))
lines.append(row(
    "",
    "", "",
    "", "",
    get(base["ex3"], "main_conn_se", is_se=True),
    get(trim["ex3"], "main_conn_se", is_se=True),
))

lines.append(midrule())

# Pre-trend coefficient + SE
lines.append(row(
    r"Pre-trend",
    get(base["ex1"], "pre"),
    get(trim["ex1"], "pre"),
    get(base["ex2"], "pre"),
    get(trim["ex2"], "pre"),
    get(base["ex3"], "pre_pos"),
    get(trim["ex3"], "pre_pos"),
))
lines.append(row(
    "",
    get(base["ex1"], "pre_se", is_se=True),
    get(trim["ex1"], "pre_se", is_se=True),
    get(base["ex2"], "pre_se", is_se=True),
    get(trim["ex2"], "pre_se", is_se=True),
    get(base["ex3"], "pre_pos_se", is_se=True),
    get(trim["ex3"], "pre_pos_se", is_se=True),
))

lines.append(addspace())

lines.append(row(
    r"Pre-trend (continuous)",
    "", "",
    "", "",
    get(base["ex3"], "pre_conn"),
    get(trim["ex3"], "pre_conn"),
))
lines.append(row(
    "",
    "", "",
    "", "",
    get(base["ex3"], "pre_conn_se", is_se=True),
    get(trim["ex3"], "pre_conn_se", is_se=True),
))

lines.append(midrule())

# Pre-trend F-test p-values
lines.append(row(
    r"Pre-trend $p$-value",
    get(base["ex1"], "pre_pval", is_pval=True),
    get(trim["ex1"], "pre_pval", is_pval=True),
    get(base["ex2"], "pre_pval", is_pval=True),
    get(trim["ex2"], "pre_pval", is_pval=True),
    get(base["ex3"], "pre_pval_pos", is_pval=True),
    get(trim["ex3"], "pre_pval_pos", is_pval=True),
))

lines.append(midrule())

# Observations
lines.append(row(
    "Observations",
    get(base["ex1"], "n_obs", is_count=True),
    get(trim["ex1"], "n_obs", is_count=True),
    get(base["ex2"], "n_obs", is_count=True),
    get(trim["ex2"], "n_obs", is_count=True),
    get(base["ex3"], "n_obs", is_count=True),
    get(trim["ex3"], "n_obs", is_count=True),
))
lines.append(row(
    "Establishments",
    get(base["ex1"], "n_estab", is_count=True),
    get(trim["ex1"], "n_estab", is_count=True),
    get(base["ex2"], "n_estab", is_count=True),
    get(trim["ex2"], "n_estab", is_count=True),
    get(base["ex3"], "n_estab", is_count=True),
    get(trim["ex3"], "n_estab", is_count=True),
))

lines.append(r"\bottomrule" + "\n")
lines.append(r"\end{tabular}" + "\n")

# Notes
lines.append(r"\begin{tablenotes}[flushleft]\footnotesize" + "\n")
lines.append(r"\item \textit{Notes:} Outcome is log December wages (lr\_remdezr\_w). " +
             r"Panels A--C reproduce the connectivity margins exercises on the full sample " +
             r"(baseline) and after dropping establishments in the top 1\% of normalized " +
             r"connectivity ($\geq 4.44\times$ the 90th percentile), " +
             r"which are predominantly tiny branches of multi-establishment firms. " +
             r"All specifications include establishment, industry$\times$year, " +
             r"bargaining-month$\times$year, and microregion$\times$year fixed effects, " +
             r"plus 4-bin pre-treatment controls interacted with year. " +
             r"Standard errors clustered at the establishment level in parentheses. " +
             r"$p$-values in brackets are from a joint $F$-test on pre-period interactions. " +
             r"$^{*}p<0.10$, $^{**}p<0.05$, $^{***}p<0.01$." + "\n")
lines.append(r"\end{tablenotes}" + "\n")
lines.append(r"\end{threeparttable}" + "\n")
lines.append(r"\end{table}" + "\n\n")
lines.append(r"\end{document}" + "\n")

# ── Write output ──────────────────────────────────────────────────────────────

out = tables_dir / "conn_margins_trim_table.tex"
with open(out, "w") as f:
    f.writelines(lines)
print(f"Saved: {out}")
