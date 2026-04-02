#!/usr/bin/env python3
"""
Generate combined LaTeX table for demographic robustness — direct effects Panel A
(outcome: lr_remdezr_w).

Columns:
  (1) Baseline                  — bins csv col 1
  (2) Quartile bins × Year      — bins csv col 2 (all demographics, absorbed)
  (3) Linear × Year             — linear csv col 2 (all demographics, covariates)

Output: Tables/robustness/demo_direct_table.tex
"""

import re
from pathlib import Path

# ── CSV parsing ───────────────────────────────────────────────────────────────

def load_csv(filepath):
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

def make_table(bins, linear):
    # (data_source, csv_col)
    cols = [
        ("bins",   "1"),   # (1) baseline
        ("bins",   "2"),   # (2) all quartile bins absorbed
        ("linear", "2"),   # (3) all linear covariates
    ]

    sources = {"bins": bins, "linear": linear}

    def cell(src, col, row_type, **kw):
        return get(sources[src], col, row_type, **kw)

    blank = r" &  &  & \\"

    notes = (
        r"This table tests whether the direct effect of Brazil's 2012 "
        r"ultractivity reform on log wages is robust to controlling for "
        r"pre-treatment workforce demographics. The sample is Panel~A: "
        r"treated establishments and untreated establishments with zero "
        r"pre-treatment worker flows to treated firms "
        r"(i.e., the zero-connectivity control group), "
        r"restricted to the Lagos balanced panel. "
        r"Column~(1) is the baseline specification. "
        r"Column~(2) adds quartile-bin controls (absorbed as fixed effects, "
        r"interacted with year) for gender (\% male), race (\% white), "
        r"education (\% with at least high school), average age, and average "
        r"tenure. Column~(3) adds the same five characteristics as continuous "
        r"linear controls interacted with year dummies. "
        r"All specifications include establishment fixed effects, year fixed "
        r"effects interacted with two-digit industry, microregion, and "
        r"negotiation-month indicators, and quartile-bin controls for "
        r"pre-treatment log wages, log employment, and per-worker pairwise "
        r"flows (2007--2011), each interacted with year. "
        r"Standard errors clustered at the establishment level in parentheses. "
        r"*** p$<$0.01, ** p$<$0.05, * p$<$0.10."
    )

    lines = [
        r"\begin{table}[H]",
        r"\centering",
        r"\caption{Direct Effects: Robustness to Workforce Demographic Controls}",
        r"\label{tab:direct_demo_combined}",
        r"\scriptsize",
        r"\begin{threeparttable}",
        r"\begin{tabular}{lccc}",
        r"\toprule\toprule",
        r"\textbf{Dependent Var: Log Wages} & (1) & (2) & (3) \\ \midrule",
        blank,
        # Post
        r"Post $\times$ Treated"
            + "".join(" & " + cell(s, c, "main") for s, c in cols) + r" \\",
        " & "
            + " & ".join(cell(s, c, "main_se", is_se=True) for s, c in cols) + r" \\",
        blank,
        # Pre
        r"Pre $\times$ Treated"
            + "".join(" & " + cell(s, c, "pre") for s, c in cols) + r" \\",
        " & "
            + " & ".join(cell(s, c, "pre_se", is_se=True) for s, c in cols) + r" \\",
        blank,
        # N
        r"Num Obs"
            + "".join(" & " + cell(s, c, "n_obs", is_count=True) for s, c in cols) + r" \\",
        r"Num Establishments"
            + "".join(" & " + cell(s, c, "n_estab", is_count=True) for s, c in cols) + r" \\ \midrule",
        # Controls panel
        r" &  &  & \\",
        r"\textbf{Demographic Controls $\times$ Year} & & & \\",
        r"Quartile bins (absorbed) &   & \checkmark &   \\",
        r"Linear (covariate)       &   &   & \checkmark \\",
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

    bins   = load_csv(rob_dir / "results_direct_demo_bins.csv")
    linear = load_csv(rob_dir / "results_direct_demo_linear.csv")

    table = make_table(bins, linear)

    output_file = rob_dir / "demo_direct_table.tex"
    with open(output_file, "w") as f:
        f.write(table)

    print(f"Generated {output_file}")


if __name__ == "__main__":
    main()
