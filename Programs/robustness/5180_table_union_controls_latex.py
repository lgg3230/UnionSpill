#!/usr/bin/env python3
"""
Generate LaTeX table for union controls robustness (outcome: lr_remdezr_w).

Structure matches the user-provided template:
  - Rows: Post × Connectivity, (SE), Pre × Connectivity, (SE), N obs, N estab
  - Columns (1)-(4): baseline, union FE, union exp firm, union emp exp
  - Footer panel: "Additional Controls" with X marks

Output: Tables/robustness/union_controls_table.tex
"""

import re
from pathlib import Path

# ── CSV parsing ───────────────────────────────────────────────────────────────

def load_csv(filepath):
    """Returns {col: {row_type: value}} for outcome lr_remdezr_w."""
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
            if len(parts) < 4:
                continue
            _outcome, col, row_type, value = parts[0], parts[1], parts[2], parts[3]
            data.setdefault(col, {})[row_type] = value.strip()
    return data


def fmt(raw, is_se=False, is_count=False):
    raw = raw.strip()
    if raw in ("--", ""):
        return "--"
    if is_count:
        return raw.replace(",", "{,}")
    match = re.match(r"^([^*]+?)(\*{1,3})?$", raw)
    if not match:
        return raw
    num_str = match.group(1).strip()
    stars   = match.group(2) or ""
    if num_str.startswith("-"):
        num_str = r"$-$" + num_str[1:]
    return f"({num_str})" if is_se else f"{num_str}{stars}"


def get(data, col, row_type, **kw):
    try:
        return fmt(data[str(col)][row_type], **kw)
    except KeyError:
        return "--"


# ── Table builder ─────────────────────────────────────────────────────────────

def make_table(data):
    COLS = [1, 2, 3, 4, 5, 6]
    blank = " & " * len(COLS) + r"\\"

    notes = (
        r"This table tests whether the spillover effect of Brazil's 2012 "
        r"ultractivity reform on log wages is robust to controlling for union "
        r"coverage of treated firms. The sample is restricted to untreated "
        r"establishments in the Lagos balanced panel. Connectivity is "
        r"per-worker pairwise flows to treated firms (2007--2011), normalized "
        r"to the 90th percentile. Column~(1) is the baseline specification. "
        r"Column~(2) adds union $\times$ year fixed effects to the absorb, "
        r"absorbing all time-varying union-level heterogeneity. "
        r"Column~(3) controls for \textit{Union Exposure (firm)} $=$ "
        r"(treated establishments in union) / (total establishments in union), "
        r"interacted with year. "
        r"Column~(4) controls for \textit{Union Exposure (workers)} $=$ "
        r"(employment in treated establishments) / (total union employment), "
        r"interacted with year. "
        r"Columns~(5) and~(6) replace the linear union-exposure controls of "
        r"columns~(3) and~(4) with indicators for the quartile of union "
        r"exposure to treated firms and to treated employees, respectively, "
        r"each interacted with year. "
        r"All specifications include establishment fixed effects, year fixed "
        r"effects interacted with two-digit industry, microregion, and "
        r"negotiation-month indicators, and quartile-bin controls for "
        r"pre-treatment log wages, log employment, and per-worker pairwise "
        r"flows (2007--2011), each interacted with year. "
        r"Standard errors clustered at the establishment level in parentheses. "
        r"*** p$<$0.01, ** p$<$0.05, * p$<$0.10."
    )

    col_nums = " & ".join(f"({c})" for c in COLS)

    lines = [
        r"\begin{table}[]",
        r"\centering",
        r"\caption{Spillover Effects: Robustness to Union Controls}",
        r"\label{tab:spill_union_controls}",
        r"\footnotesize",
        r"\begin{threeparttable}",
        r"\begin{tabular}{lcccccc}",
        r"\toprule\toprule",
        r"\textbf{Dependent Var: Log Wages} & " + col_nums + r" \\ \midrule",
        " & " + blank,
        # Post
        r"Post $\times$ Connectivity" + "".join(
            " & " + get(data, c, "main") for c in COLS) + r" \\",
        " & " + " & ".join(get(data, c, "main_se", is_se=True) for c in COLS) + r" \\",
        " & " + blank,
        # Pre
        r"Pre $\times$ Connectivity" + "".join(
            " & " + get(data, c, "pre") for c in COLS) + r" \\",
        " & " + " & ".join(get(data, c, "pre_se", is_se=True) for c in COLS) + r" \\",
        " & " + blank,
        # N
        r"Num Obs" + "".join(
            " & " + get(data, c, "n_obs", is_count=True) for c in COLS) + r" \\",
        r"Num Establishments" + "".join(
            " & " + get(data, c, "n_estab", is_count=True) for c in COLS) + r" \\ \midrule",
        # Additional controls panel
        r" & " * len(COLS) + r"\\",
        r"\textbf{Additional Controls} & & & & & & \\",
        r"Union FE $\times$ Year FE & & X & & & & \\",
        r"Union Exposure (firm) $\times$ Year FE & & & X & & & \\",
        r"Union Exposure (workers) $\times$ Year FE & & & & X & & \\",
        r"Union Exposure (firm), quartiles $\times$ Year FE & & & & & X & \\",
        r"Union Exposure (workers), quartiles $\times$ Year FE & & & & & & X \\",
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
    script_dir  = Path(__file__).resolve().parent
    rob_dir     = script_dir.parent.parent / "Tables" / "robustness"
    output_file = rob_dir / "union_controls_table.tex"

    data = load_csv(rob_dir / "results_spill_union_controls.csv")
    table = make_table(data)

    with open(output_file, "w") as f:
        f.write(table)

    print(f"Generated {output_file}")


if __name__ == "__main__":
    main()
