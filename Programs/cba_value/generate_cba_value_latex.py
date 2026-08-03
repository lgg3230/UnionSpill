#!/usr/bin/env python3
"""
Generate publication-ready LaTeX table for CBA value analysis.

Layout: one column per sample.
  Columns: (1) Panel A  (2) Panel B  (3) Panel C  (4) Spillover
  Rows:    cba_value block then numb_clauses block

Output: Tables/cba_value/cba_value_tables.tex
"""

import re
from pathlib import Path

def fmt_mean(raw):
    """Pre-treatment mean: CSV keeps 4 decimals, the table shows 3
    (decision 2026-08-01), so precision is reversible without re-estimating."""
    raw = raw.strip()
    if raw in ("--", ""):
        return "--"
    val = float(raw)
    return ("$-$" if val < 0 else "") + f"{abs(val):.3f}"


SPEC = "cba_value"

# ── CSV parsing ───────────────────────────────────────────────────────────────

def load_csv(filepath, outcome):
    """Return dict of row_type -> raw value string for a given outcome."""
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
            _, _, out, row_type, value = parts[0], parts[1], parts[2], parts[3], parts[4]
            if out == outcome:
                data[row_type] = value.strip()
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
    if num_str.startswith("-"):
        num_str = r"$-$" + num_str[1:]
    return f"({num_str})" if is_se else f"{num_str}{stars}"

def get(d, key, **kw):
    return fmt(d.get(key, "--"), **kw)

# ── Helpers ───────────────────────────────────────────────────────────────────

_CONTROLS = (
    r"All regressions include establishment fixed effects and CBA-period fixed "
    r"effects interacted with two-digit industry, microregion, and "
    r"negotiation-month indicators, and quartile-bin controls for pre-treatment "
    r"per-worker pairwise worker flows (2007--2011) and pre-treatment "
    r"establishment size, interacted with CBA-period fixed effects."
)
_STARS = r"*** p$<$0.01, ** p$<$0.05, * p$<$0.10."

# ── Table builder ─────────────────────────────────────────────────────────────

def make_table(pa_cv, pb_cv, pc_cv, sp_cv):
    """One table, 4 sample columns, two outcome blocks."""

    col_spec = r"l cccc"
    blank    = r" & & & & \\"

    # column headers
    hdr_row  = (r" & \shortstack{Panel A\\Zero\\Connectivity}"
                r" & \shortstack{Panel B\\$\leq$1\%\\Connectivity}"
                r" & \shortstack{Panel C\\All\\Untreated}"
                r" & \shortstack{Spillover\\Connected\\Untreated}"
                r" \\")
    num_row  = r" & (1) & (2) & (3) & (4) \\"

    def outcome_block(dA, dB, dC, dS, post_label, pre_label, outcome_label):
        lines = []
        lines.append(r"\midrule")
        lines.append(rf"\multicolumn{{5}}{{l}}{{\textit{{{outcome_label}}}}} \\")
        # post
        lines.append(post_label
                     + " & " + get(dA, "main")
                     + " & " + get(dB, "main")
                     + " & " + get(dC, "main")
                     + " & " + get(dS, "main")
                     + r" \\")
        lines.append("  & "  + get(dA, "main_se", is_se=True)
                     + " & " + get(dB, "main_se", is_se=True)
                     + " & " + get(dC, "main_se", is_se=True)
                     + " & " + get(dS, "main_se", is_se=True)
                     + r" \\")
        lines.append(blank)
        # pre placebo
        lines.append(pre_label
                     + " & " + get(dA, "pre")
                     + " & " + get(dB, "pre")
                     + " & " + get(dC, "pre")
                     + " & " + get(dS, "pre")
                     + r" \\")
        lines.append("  & "  + get(dA, "pre_se", is_se=True)
                     + " & " + get(dB, "pre_se", is_se=True)
                     + " & " + get(dC, "pre_se", is_se=True)
                     + " & " + get(dS, "pre_se", is_se=True)
                     + r" \\")
        lines.append(r"Pre-trend $F$-test $p$-value"
                     + " & " + get(dA, "pre_pval", is_pval=True)
                     + " & " + get(dB, "pre_pval", is_pval=True)
                     + " & " + get(dC, "pre_pval", is_pval=True)
                     + " & " + get(dS, "pre_pval", is_pval=True)
                     + r" \\")
        lines.append(blank)
        # stats
        lines.append(r"Pre-treatment mean"
                     + " & " + fmt_mean(dA.get("mean_pre", "--"))
                     + " & " + fmt_mean(dB.get("mean_pre", "--"))
                     + " & " + fmt_mean(dC.get("mean_pre", "--"))
                     + " & " + fmt_mean(dS.get("mean_pre", "--"))
                     + r" \\")
        lines.append(r"Observations"
                     + " & " + get(dA, "n_obs", is_count=True)
                     + " & " + get(dB, "n_obs", is_count=True)
                     + " & " + get(dC, "n_obs", is_count=True)
                     + " & " + get(dS, "n_obs", is_count=True)
                     + r" \\")
        lines.append(r"Establishments"
                     + " & " + get(dA, "n_estab", is_count=True)
                     + " & " + get(dB, "n_estab", is_count=True)
                     + " & " + get(dC, "n_estab", is_count=True)
                     + " & " + get(dS, "n_estab", is_count=True)
                     + r" \\")
        return lines

    notes = (
        r"This table presents difference-in-differences estimates of the effects "
        r"of Brazil's 2012 ultractivity reform on CBA content. "
        r"The CBA Value Score is the wage-equivalent weighted sum of subgroup "
        r"clause counts, using the subgroup-level weights estimated in Lagos (2026). "
        r"Clause Count is the total number of clauses in the CBA (unweighted). "
        r"Columns (1)--(3) report direct effects on treated establishments relative "
        r"to control groups of increasing breadth. "
        r"Column (4) reports the spillover effect for untreated establishments: "
        r"the interaction of post-reform indicator with pre-reform connectivity "
        r"(share of workforce overlapping with treated firms, normalized to the "
        r"90th percentile). "
        + _CONTROLS + r" "
        r"Standard errors clustered at the establishment level in parentheses. "
        + _STARS
    )

    lines = [
        r"\begin{table}[H]",
        r"\centering",
        r"\caption{Effects of the Ultractivity Reform on CBA Content}",
        r"\label{tab:cba_value}",
        r"\scriptsize",
        r"\begin{threeparttable}",
        rf"\begin{{tabular}}{{{col_spec}}}",
        r"\toprule\toprule",
        hdr_row,
        num_row,
    ]

    lines += outcome_block(
        pa_cv, pb_cv, pc_cv, sp_cv,
        r"Post $\times$ Treatment",
        r"Pre $\times$ Treatment",
        r"CBA Value Score"
    )

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
    script_dir   = Path(__file__).resolve().parent
    tables_dir   = script_dir.parent.parent / "Tables"
    pipeline_dir = tables_dir / "cba_value"
    output_file  = pipeline_dir / "cba_value_tables.tex"

    pa_cv = load_csv(pipeline_dir / f"results_direct_panelA_{SPEC}.csv", "cba_value")
    pb_cv = load_csv(pipeline_dir / f"results_direct_panelB_{SPEC}.csv", "cba_value")
    pc_cv = load_csv(pipeline_dir / f"results_direct_panelC_{SPEC}.csv", "cba_value")
    sp_cv = load_csv(pipeline_dir / f"results_spill_{SPEC}.csv",         "cba_value")

    doc = "\n".join([
        r"\documentclass[12pt,letterpaper]{article}",
        r"\usepackage[margin=1in]{geometry}",
        r"\usepackage{booktabs}",
        r"\usepackage{threeparttable}",
        r"\usepackage{amsmath}",
        r"\usepackage{amssymb}",
        r"\usepackage{float}",
        r"\begin{document}",
        "",
        make_table(pa_cv, pb_cv, pc_cv, sp_cv),
        "",
        r"\end{document}",
    ])

    with open(output_file, "w") as f:
        f.write(doc)
    print(f"Generated {output_file}")

if __name__ == "__main__":
    main()
