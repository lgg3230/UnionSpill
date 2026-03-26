#!/usr/bin/env python3
"""
Robustness table: main spillover regression for lr_remdezr_w,
baseline vs. p99-trimmed sample.

Output: Tables/conn_margins/spill_trim_robustness_table.tex
"""

import re
from pathlib import Path

script_dir = Path(__file__).resolve().parent
tables_dir = script_dir.parent.parent / "Tables" / "conn_margins"


def load_csv(filepath):
    """Returns {spec: {row_type: value}} for lr_remdezr_w."""
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
            spec, _, outcome, row_type, value = parts[0], parts[1], parts[2], parts[3], parts[4]
            if outcome != "lr_remdezr_w":
                continue
            data.setdefault(spec, {})[row_type] = value.strip()
    return data


def fmt(raw, is_se=False, is_pval=False, is_count=False):
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


# ── Load ──────────────────────────────────────────────────────────────────────

data = load_csv(tables_dir / "results_spill_trim_robustness.csv")
base = data.get("baseline", {})
trim = data.get("trim", {})
wins = data.get("winsorized", {})

# ── Build table ───────────────────────────────────────────────────────────────

def row(*cells):
    return " & ".join(cells) + r" \\" + "\n"

lines = []

lines.append(r"\documentclass[12pt]{article}" + "\n")
lines.append(r"\usepackage{booktabs,threeparttable,float,geometry}" + "\n")
lines.append(r"\geometry{margin=1in}" + "\n")
lines.append(r"\begin{document}" + "\n\n")

lines.append(r"\begin{table}[H]" + "\n")
lines.append(r"\centering" + "\n")
lines.append(r"\caption{Robustness: dropping top-1\% connectivity firms --- Main spillover regression}" + "\n")
lines.append(r"\label{tab:spill_trim}" + "\n")
lines.append(r"\begin{threeparttable}" + "\n")
lines.append(r"\begin{tabular}{lccc}" + "\n")
lines.append(r"\toprule" + "\n")

# Headers
lines.append(row("", "Baseline", "Trimmed (p99)", "Winsorized (p99)"))
lines.append(r"\midrule" + "\n")

# Post coefficient
lines.append(row(
    r"Post $\times$ Connectivity",
    get(base, "main"),
    get(trim, "main"),
    get(wins, "main"),
))
lines.append(row(
    "",
    get(base, "main_se", is_se=True),
    get(trim, "main_se", is_se=True),
    get(wins, "main_se", is_se=True),
))

lines.append(r"\\[-4pt]" + "\n")

# Pre-trend
lines.append(row(
    r"Pre-trend",
    get(base, "pre"),
    get(trim, "pre"),
    get(wins, "pre"),
))
lines.append(row(
    "",
    get(base, "pre_se", is_se=True),
    get(trim, "pre_se", is_se=True),
    get(wins, "pre_se", is_se=True),
))

lines.append(r"\midrule" + "\n")

# Pre-trend F-test p-value
lines.append(row(
    r"Pre-trend $p$-value",
    get(base, "pre_pval", is_pval=True),
    get(trim, "pre_pval", is_pval=True),
    get(wins, "pre_pval", is_pval=True),
))

lines.append(r"\midrule" + "\n")

# Sample info
lines.append(row(
    "Observations",
    get(base, "n_obs", is_count=True),
    get(trim, "n_obs", is_count=True),
    get(wins, "n_obs", is_count=True),
))
lines.append(row(
    "Establishments",
    get(base, "n_estab", is_count=True),
    get(trim, "n_estab", is_count=True),
    get(wins, "n_estab", is_count=True),
))

lines.append(r"\bottomrule" + "\n")
lines.append(r"\end{tabular}" + "\n")

lines.append(r"\begin{tablenotes}[flushleft]\footnotesize" + "\n")
lines.append(
    r"\item \textit{Notes:} Outcome is log December wages (lr\_remdezr\_w). "
    r"All columns use the full untreated sample and the same fixed effects. "
    r"\textit{Trimmed} drops the 41 establishments ($\approx$1\%) "
    r"with normalized connectivity $\geq 5.26\times$ the 90th percentile "
    r"(predominantly tiny branches of multi-establishment firms). "
    r"\textit{Winsorized} retains all establishments but caps normalized "
    r"connectivity at the same p99 threshold. "
    r"The specification includes establishment, industry$\times$year, "
    r"bargaining-month$\times$year, and microregion$\times$year fixed effects, "
    r"plus 4-bin pre-treatment controls for wages, employment, and total flows, "
    r"each interacted with year. "
    r"Standard errors clustered at the establishment level in parentheses. "
    r"$p$-value in brackets is from a joint $F$-test on the 2009 and 2010 "
    r"pre-period connectivity interactions. "
    r"$^{*}p<0.10$, $^{**}p<0.05$, $^{***}p<0.01$." + "\n"
)
lines.append(r"\end{tablenotes}" + "\n")
lines.append(r"\end{threeparttable}" + "\n")
lines.append(r"\end{table}" + "\n\n")
lines.append(r"\end{document}" + "\n")

out = tables_dir / "spill_trim_robustness_table.tex"
with open(out, "w") as f:
    f.writelines(lines)
print(f"Saved: {out}")
