#!/usr/bin/env python3
"""
Generate LaTeX table for industry×microregion robustness exercise.

Columns (1)-(9):
  (1) base      – Baseline
  (2) mi_fe_yr  – + micro-ind × year FE
  (3) mi_fe_tr  – + micro-ind × post FE
  (4) mif_yr    – + local exp (firms) × year
  (5) mif_tr    – + local exp (firms) × post  [with connectivity]
  (6) mif_tr_b  – + local exp (firms) × post  [without connectivity]
  (7) miw_yr    – + local exp (workers) × year
  (8) miw_tr    – + local exp (workers) × post  [with connectivity]
  (9) miw_tr_b  – + local exp (workers) × post  [without connectivity]

Input:  Tables/robustness/results_micro_ind_test.csv
Output: Tables/robustness/micro_ind_table.tex
"""

import re
from pathlib import Path

# Column order
SPECS = ["base", "mi_fe_yr", "mi_fe_tr", "mif_yr", "mif_tr",
         "mif_tr_b", "miw_yr", "miw_tr", "miw_tr_b"]
NCOLS = len(SPECS)

# Which specs have connectivity rows
HAS_CONN  = {"base", "mi_fe_yr", "mi_fe_tr", "mif_yr", "mif_tr", "miw_yr", "miw_tr"}
# Which specs have local-exposure rows
HAS_LOCAL = {"mif_tr", "mif_tr_b", "miw_tr", "miw_tr_b"}

# ── CSV parsing ────────────────────────────────────────────────────────────────

def load_csv(filepath):
    """Returns {spec: {row_type: value}}."""
    data = {}
    if not filepath.exists():
        print(f"  WARNING: {filepath.name} not found.")
        return data
    with open(filepath) as f:
        next(f)  # skip header
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = line.replace('"', '').split(";")
            if len(parts) < 4:
                continue
            spec, _outcome, row_type, value = parts[0], parts[1], parts[2], parts[3]
            data.setdefault(spec, {})[row_type] = value.strip()
    return data


def fmt(raw, is_se=False, is_count=False):
    raw = raw.strip()
    if raw in ("--", ""):
        return ""
    if is_count:
        # Stata %12.0fc already inserts commas; just reformat for LaTeX
        return raw.strip().replace(",", "{,}")
    match = re.match(r"^([^*]+?)(\*{1,3})?$", raw)
    if not match:
        return raw
    num_str = match.group(1).strip()
    stars   = match.group(2) or ""
    if num_str.startswith("-"):
        num_str = r"$-$" + num_str[1:]
    return f"({num_str})" if is_se else f"{num_str}{stars}"


def get(data, spec, row_type, **kw):
    try:
        return fmt(data[spec][row_type], **kw)
    except KeyError:
        return ""


# ── Row builders ───────────────────────────────────────────────────────────────

def data_row(label, cells):
    """Build a LaTeX row: label & c1 & c2 & ... & cN \\"""
    assert len(cells) == NCOLS, f"expected {NCOLS} cells, got {len(cells)}"
    return label + "".join(f" & {c}" for c in cells) + r" \\"


def se_row(cells):
    """Build an SE row (empty label)."""
    assert len(cells) == NCOLS
    return "".join(f" & {c}" for c in cells) + r" \\"


def blank_row():
    return "".join([" & "] * NCOLS) + r"\\"


def ctrl_row(label, x_specs):
    """Build an additional-controls row with X in the given spec positions."""
    cells = [r"\checkmark" if s in x_specs else "" for s in SPECS]
    return data_row(label, cells)


# ── Table builder ──────────────────────────────────────────────────────────────

def make_table(data):
    col_nums = " & ".join(f"({i+1})" for i in range(NCOLS))

    notes = (
        r"Spillover effects controlling for treatment intensity within "
        r"microregion$\times$industry cells. Column~(1) shows baseline results. "
        r"Columns~(2)--(3) include microregion$\times$industry FE interacted "
        r"with year or post-reform indicator. "
        r"Columns~(4)--(5) control for \textit{Local Exposure (firms)} $=$ "
        r"share of treated establishments in each microregion$\times$industry "
        r"cell, either interacted with year FE or with the post-reform indicator. "
        r"Column~(6) includes local exposure (firms) interacted with post, "
        r"without connectivity. "
        r"Columns~(7)--(8) control for \textit{Local Exposure (workers)} $=$ "
        r"share of employment in treated establishments within the cell, "
        r"interacted with year FE or the post-reform indicator. "
        r"Column~(9) includes local exposure (workers) interacted with post, "
        r"without connectivity. "
        r"Both connectivity and local exposure measures are normalized by their "
        r"90th percentile among spillover establishments, so coefficients "
        r"represent the effect of moving from the 0th to the 90th percentile "
        r"of each measure. "
        r"All specifications include establishment FE and time-varying controls "
        r"for microregion, industry, negotiation months, pretreatment wages, "
        r"employment, and per-worker pairwise flows (2007--2011), each interacted "
        r"with year. "
        r"Standard errors clustered at the establishment level in parentheses. "
        r"*** p$<$0.01, ** p$<$0.05, * p$<$0.10."
    )

    lines = [
        r"\begin{table}[H]",
        r"\centering",
        r"\caption{Spillover Effects: Robustness to Local Industry $\times$ Microregion Exposure}",
        r"\label{tab:spill_micro_ind}",
        r"\scriptsize",
        r"\begin{threeparttable}",
        r"\begin{tabular}{l" + "c" * NCOLS + "}",
        r"\toprule\toprule",
        r"\textbf{Dependent Var: Log Wages} & " + col_nums + r" \\ \midrule",
        blank_row(),
        # Post × Connectivity
        data_row(r"Post $\times$ Connectivity",
                 [get(data, s, "main") if s in HAS_CONN else "" for s in SPECS]),
        se_row([get(data, s, "main_se", is_se=True) if s in HAS_CONN else "" for s in SPECS]),
        blank_row(),
        # Pre × Connectivity
        data_row(r"Pre $\times$ Connectivity",
                 [get(data, s, "pre") if s in HAS_CONN else "" for s in SPECS]),
        se_row([get(data, s, "pre_se", is_se=True) if s in HAS_CONN else "" for s in SPECS]),
        blank_row(),
        # Post × Local Exp.
        data_row(r"Post $\times$ Local Exp.",
                 [get(data, s, "ctrl_main") if s in HAS_LOCAL else "" for s in SPECS]),
        se_row([get(data, s, "ctrl_main_se", is_se=True) if s in HAS_LOCAL else "" for s in SPECS]),
        blank_row(),
        # Pre × Local Exp.
        data_row(r"Pre $\times$ Local Exp.",
                 [get(data, s, "ctrl_pre") if s in HAS_LOCAL else "" for s in SPECS]),
        se_row([get(data, s, "ctrl_pre_se", is_se=True) if s in HAS_LOCAL else "" for s in SPECS]),
        blank_row(),
        # N rows
        data_row(r"Num Obs",
                 [get(data, s, "n_obs", is_count=True) for s in SPECS]),
        data_row(r"Num Establishments",
                 [get(data, s, "n_estab", is_count=True) for s in SPECS]) + r" \midrule",
        # Additional controls panel
        blank_row(),
        data_row(r"\textbf{Additional Controls}", [""] * NCOLS),
        ctrl_row(r"Micro-Ind $\times$ Year FE",        {"mi_fe_yr"}),
        ctrl_row(r"Micro-Ind $\times$ Post FE",        {"mi_fe_tr"}),
        ctrl_row(r"Local Exp.\ (firms) $\times$ Year", {"mif_yr"}),
        ctrl_row(r"Local Exp.\ (firms) $\times$ Post", {"mif_tr", "mif_tr_b"}),
        ctrl_row(r"Local Exp.\ (wkrs) $\times$ Year",  {"miw_yr"}),
        ctrl_row(r"Local Exp.\ (wkrs) $\times$ Post",  {"miw_tr", "miw_tr_b"}),
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


# ── Main ───────────────────────────────────────────────────────────────────────

def main():
    script_dir  = Path(__file__).resolve().parent
    rob_dir     = script_dir.parent.parent / "Tables" / "robustness"
    output_file = rob_dir / "micro_ind_table.tex"

    data = load_csv(rob_dir / "results_micro_ind_test.csv")
    table = make_table(data)

    with open(output_file, "w") as f:
        f.write(table)

    print(f"Generated {output_file}")


if __name__ == "__main__":
    main()
