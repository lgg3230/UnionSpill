#!/usr/bin/env python3
"""
Generate LaTeX robustness table for bin-count sensitivity analysis.

One table: outcomes as panels (rows), bin counts as columns.
Spillover effects only, four main outcomes.

Output: Tables/robustness/robustness_bins_tables.tex
"""

import re
from pathlib import Path

SPECS = [
    ("tfpw_07_11_pct_bins10",  "10"),
    ("tfpw_07_11_pct_bins20",  "20"),
    ("tfpw_07_11_pct_bins50",  "50"),
    ("tfpw_07_11_pct_bins100", "100"),
]

OUTCOMES = [
    ("lr_remdezr_w",   r"\textbf{Panel A:} Log Wages"),
    ("lr_remdezr_h_w", r"\textbf{Panel B:} Log Hourly Wages"),
    ("l_firm_emp",     r"\textbf{Panel C:} Log Employment"),
    ("numb_clauses",   r"\textbf{Panel D:} Clause Count"),
]

# ── CSV parsing ───────────────────────────────────────────────────────────────

def load_robustness_csv(filepath):
    """Returns {spec: {outcome: {row_type: value}}}."""
    data = {}
    if not filepath.exists():
        print(f"  WARNING: {filepath.name} not found.")
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
            spec, _section, outcome, row_type, value = parts[0], parts[1], parts[2], parts[3], parts[4]
            data.setdefault(spec, {}).setdefault(outcome, {})[row_type] = value.strip()
    return data


def format_value(raw, is_se=False, is_count=False, is_pval=False):
    raw = raw.strip()
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
    if num_str.startswith("-"):
        num_str = r"$-$" + num_str[1:]
    return f"({num_str})" if is_se else f"{num_str}{stars}"


def get_val(data, spec, outcome, row_type, **kw):
    try:
        raw = data[spec][outcome][row_type]
    except KeyError:
        return "--"
    return format_value(raw, **kw)


# ── Notes ────────────────────────────────────────────────────────────────────

_CONTROLS_NOTE = (
    r"All regressions include establishment fixed effects, year fixed effects "
    r"interacted with two-digit industry, microregion, and negotiation-month "
    r"indicators, and $N$-bin controls for pre-treatment per-worker pairwise "
    r"flows (2007--2011) and pre-treatment log employment interacted with year "
    r"fixed effects. Pre-trend $p$-value is from the pre-treatment placebo DiD "
    r"regression. "
    r"Standard errors clustered at the establishment level in parentheses. "
    r"*** p$<$0.01, ** p$<$0.05, * p$<$0.10."
)

NOTES_SPILL = (
    r"This table assesses the sensitivity of spillover estimates to the "
    r"choice of bin count $N \in \{10, 20, 50, 100\}$. Each column corresponds "
    r"to a different bin count; each panel corresponds to a different outcome. "
    r"The sample is restricted to untreated establishments in the Lagos "
    r"balanced panel. Connectivity is per-worker pairwise flows to treated "
    r"firms (2007--2011), normalized to the 90th percentile. "
    r"Post $\times$ Connectivity captures the average spillover effect for "
    r"2012--2016; Pre $\times$ Connectivity is a placebo test using 2009--2011. "
    r"The clause count outcome uses CBA negotiation periods rather than "
    r"calendar years. " + _CONTROLS_NOTE
)

NOTES_DIRECT = {
    "A": (
        r"This table assesses the sensitivity of direct treatment-effect "
        r"estimates to the choice of bin count $N \in \{10, 20, 50, 100\}$. "
        r"Control group: establishments with \textbf{zero} pre-reform "
        r"worker-flow connectivity to treated firms (Panel~A). "
        r"Post $\times$ Treatment measures the average treatment effect for "
        r"2012--2016; Pre $\times$ Treatment is a placebo test. "
        r"The clause count outcome uses CBA negotiation periods. " + _CONTROLS_NOTE
    ),
    "B": (
        r"This table assesses the sensitivity of direct treatment-effect "
        r"estimates to the choice of bin count $N \in \{10, 20, 50, 100\}$. "
        r"Control group: establishments with \textbf{at most 1\%} pre-reform "
        r"connectivity to treated firms (Panel~B). "
        r"Post $\times$ Treatment measures the average treatment effect for "
        r"2012--2016; Pre $\times$ Treatment is a placebo test. "
        r"The clause count outcome uses CBA negotiation periods. " + _CONTROLS_NOTE
    ),
    "C": (
        r"This table assesses the sensitivity of direct treatment-effect "
        r"estimates to the choice of bin count $N \in \{10, 20, 50, 100\}$. "
        r"Control group: \textbf{all untreated} establishments in the Lagos "
        r"balanced panel (Panel~C). "
        r"Post $\times$ Treatment measures the average treatment effect for "
        r"2012--2016; Pre $\times$ Treatment is a placebo test. "
        r"The clause count outcome uses CBA negotiation periods. " + _CONTROLS_NOTE
    ),
}


# ── Generic table builder ─────────────────────────────────────────────────────

def make_table(data, caption, label, post_label, pre_label, notes):
    n = len(SPECS)
    col_spec = "l" + "c" * n
    blank = " " + " & " * n + r"\\"

    lines = [
        r"\begin{table}[H]",
        r"\centering",
        f"\\caption{{{caption}}}",
        f"\\label{{{label}}}",
        r"\scriptsize",
        r"\begin{threeparttable}",
        f"\\begin{{tabular}}{{{col_spec}}}",
        r"\toprule\toprule",
    ]

    col_hdrs = " & ".join(
        r"\begin{tabular}[c]{@{}c@{}}$N = " + nbins + r"$\\\textit{bins}\end{tabular}"
        for _, nbins in SPECS
    )
    lines.append(" & " + col_hdrs + r" \\")
    lines.append(r"\midrule")

    for idx, (outcome, panel_label) in enumerate(OUTCOMES):
        if idx > 0:
            lines.append(blank)
            lines.append(r"\midrule")

        lines.append(r"\multicolumn{" + str(n + 1) + r"}{l}{" + panel_label + r"} \\")
        lines.append(r"\midrule")

        row = post_label + "".join(
            " & " + get_val(data, spec, outcome, "main") for spec, _ in SPECS)
        lines.append(row + r" \\")
        row = "".join(
            " & " + get_val(data, spec, outcome, "main_se", is_se=True) for spec, _ in SPECS)
        lines.append(" " + row + r" \\")
        lines.append(blank)

        row = pre_label + "".join(
            " & " + get_val(data, spec, outcome, "pre") for spec, _ in SPECS)
        lines.append(row + r" \\")
        row = "".join(
            " & " + get_val(data, spec, outcome, "pre_se", is_se=True) for spec, _ in SPECS)
        lines.append(" " + row + r" \\")

        row = r"Pre-trend $p$-value" + "".join(
            " & " + get_val(data, spec, outcome, "pre_pval", is_pval=True) for spec, _ in SPECS)
        lines.append(row + r" \\")
        lines.append(blank)

        row = "Observations" + "".join(
            " & " + get_val(data, spec, outcome, "n_obs", is_count=True) for spec, _ in SPECS)
        lines.append(row + r" \\")
        row = "Establishments" + "".join(
            " & " + get_val(data, spec, outcome, "n_estab", is_count=True) for spec, _ in SPECS)
        lines.append(row + r" \\")

    lines += [
        r"\bottomrule",
        r"\end{tabular}",
        r"\scriptsize",
        r"\begin{tablenotes}",
        r"\item \textit{Notes:} " + notes,
        r"\end{tablenotes}",
        r"\end{threeparttable}",
        r"\end{table}",
    ]

    return "\n".join(lines)


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    script_dir = Path(__file__).resolve().parent
    rob_dir    = script_dir.parent.parent / "Tables" / "robustness"

    spill_data = load_robustness_csv(rob_dir / "results_spill_robustness_bins.csv")
    pa_data    = load_robustness_csv(rob_dir / "results_direct_panelA_robustness_bins.csv")
    pb_data    = load_robustness_csv(rob_dir / "results_direct_panelB_robustness_bins.csv")
    pc_data    = load_robustness_csv(rob_dir / "results_direct_panelC_robustness_bins.csv")

    # Spillover table
    with open(rob_dir / "robustness_bins_tables.tex", "w") as f:
        f.write(make_table(
            spill_data,
            caption    = "Robustness to Bin Count: Spillover Effects",
            label      = "tab:rob_spill_bins",
            post_label = r"Post $\times$ Connectivity",
            pre_label  = r"Pre $\times$ Connectivity",
            notes      = NOTES_SPILL,
        ))

    # Direct effects tables — one per panel
    panel_labels = {
        "A": "Panel A: Zero-Connectivity Controls",
        "B": r"Panel B: $\leq$1\% Connectivity Controls",
        "C": "Panel C: All Untreated Controls",
    }
    for panel, pdata in [("A", pa_data), ("B", pb_data), ("C", pc_data)]:
        fname = f"robustness_bins_direct_{panel}.tex"
        with open(rob_dir / fname, "w") as f:
            f.write(make_table(
                pdata,
                caption    = f"Robustness to Bin Count: Direct Effects ({panel_labels[panel]})",
                label      = f"tab:rob_direct_bins_{panel}",
                post_label = r"Post $\times$ Treatment",
                pre_label  = r"Pre $\times$ Treatment",
                notes      = NOTES_DIRECT[panel],
            ))
        print(f"Generated {fname}")

    print(f"Generated robustness_bins_tables.tex")
    print(f"  4 tables total ({len(OUTCOMES)} outcome panels × {len(SPECS)} bin counts each)")


if __name__ == "__main__":
    main()
