#!/usr/bin/env python3
"""
generate_subgroup_latex.py
LaTeX tables for the three subgroup exercises.

Tables produced:
  1. Subgroup-level cosine similarity (Exercise A) — one spillover column
  2. Clause counts by subgroup (Exercise B) — Panels A/B/C + spillover columns
  3. Composition shares by subgroup (Exercise C) — same layout

Output: Tables/clause_types/subgroup_tables.tex
"""

import re
from pathlib import Path

ROOT       = Path(__file__).resolve().parent.parent.parent
tables_dir = ROOT / "Tables" / "clause_types"
out_file   = tables_dir / "subgroup_tables.tex"

# ── Subgroup ordering and labels ──────────────────────────────────────────────

SG_IDS = ["11","12","13","14",
          "21","22","23","24",
          "31","32","33","34",
          "41","42","43","51",
          "61","62",
          "71","72","73",
          "81","82",
          "91"]

LABELS = {
    "11": "Wage adjustments",    "12": "Wage payment",
    "13": "Other wages",         "14": "Other wage rules",
    "21": "Bonuses",             "22": "Pays",
    "23": "Assistances",         "24": "Other incentives",
    "31": "Separations",         "32": "Contract types",
    "33": "Hiring",              "34": "Other contracting",
    "41": "Staffing",            "42": "Working conditions",
    "43": "Empl.\ protections",  "51": "Workday",
    "61": "Injuries",            "62": "Prevention",
    "71": "Vacations",           "72": "Leaves",
    "73": "Other time off",      "81": "Union-firm relations",
    "82": "Union organization",  "91": "Bargaining",
}

BROAD_GROUP = {
    "11": "Wage", "12": "Wage", "13": "Wage", "14": "Wage",
    "21": "Other", "22": "Other", "23": "Other", "24": "Other",
    "31": "Employment", "32": "Employment", "33": "Employment", "34": "Employment",
    "41": "Employment", "42": "Employment", "43": "Employment", "51": "Employment",
    "61": "Other", "62": "Other",
    "71": "Other", "72": "Other", "73": "Other",
    "81": "Other", "82": "Other",
    "91": "Other",
}

# ── CSV parsing ───────────────────────────────────────────────────────────────

def load_csv(path):
    """Return dict: outcome -> row_type -> raw_value_string.
    Handles both 5-field (no label) and 6-field (with label) formats."""
    data = {}
    if not path.exists():
        print(f"  WARNING: {path.name} not found")
        return data
    with open(path) as f:
        next(f)
        for line in f:
            parts = line.strip().replace('"', '').split(';')
            if len(parts) == 5:
                outcome, row_type, value = parts[2].strip(), parts[3].strip(), parts[4].strip()
            elif len(parts) >= 6:
                outcome, row_type, value = parts[2].strip(), parts[4].strip(), parts[5].strip()
            else:
                continue
            data.setdefault(outcome, {})[row_type] = value
    return data

def fmt(raw, is_se=False, is_count=False, is_pval=False):
    raw = (raw or "").strip()
    if raw in ("--", ""):
        return "--"
    if is_count:
        return raw.replace(",", "{,}")
    if is_pval:
        return f"[{raw}]"
    m = re.match(r"^([^*]+?)(\*{1,3})?$", raw)
    if not m:
        return raw
    num = m.group(1).strip()
    stars = m.group(2) or ""
    if num.startswith("-"):
        num = r"$-$" + num[1:]
    return f"({num})" if is_se else f"{num}{stars}"

def get(d, outcome, row_type, **kw):
    return fmt(d.get(outcome, {}).get(row_type, "--"), **kw)

# ── LaTeX helpers ─────────────────────────────────────────────────────────────

_STARS  = r"*** p$<$0.01, ** p$<$0.05, * p$<$0.10."
_ABSORB = (r"All regressions include establishment fixed effects and "
           r"CBA-period fixed effects interacted with two-digit industry, "
           r"microregion, and negotiation-month indicators, and quartile-bin "
           r"controls for pre-treatment per-worker pairwise flows (2007--2011) "
           r"and pre-treatment establishment size. "
           r"Standard errors clustered at the establishment level in parentheses. ")

def preamble(caption, label, col_spec):
    return [
        r"\begin{table}[H]",
        r"\centering",
        f"\\caption{{{caption}}}",
        f"\\label{{{label}}}",
        r"\scriptsize",
        r"\begin{threeparttable}",
        f"\\begin{{tabular}}{{{col_spec}}}",
        r"\toprule\toprule",
    ]

def postamble(notes):
    return [
        r"\bottomrule",
        r"\end{tabular}",
        r"\scriptsize",
        r"\begin{tablenotes}",
        r"\item \textit{Notes:} " + notes,
        r"\end{tablenotes}",
        r"\end{threeparttable}",
        r"\end{table}",
    ]

# ── Table builders ────────────────────────────────────────────────────────────

def make_subgroup_table(dA, dB, dC, dS, dU, dR, prefix,
                        caption, label, outcome_notes):
    """
    Six-column longtable: spans multiple pages.
    prefix: 'sg' for counts, 'sh' for shares.
    """
    col_spec = r"l cccccc"
    blank    = r" & & & & & & \\"
    ncols    = 7

    hdr_cols = (r" & \shortstack{Panel A\\Zero\\Connectivity}"
                r" & \shortstack{Panel B\\$\leq$1\%\\Connectivity}"
                r" & \shortstack{Panel C\\All\\Untreated}"
                r" & \shortstack{Spillover\\(4)}"
                r" & \shortstack{Spillover\\+ Union FE\\(5)}"
                r" & \shortstack{Baseline\\Restr.\ sample\\(6)}"
                r" \\")
    num_row  = r" & (1) & (2) & (3) & (4) & (5) & (6) \\"

    notes = (
        f"This table presents difference-in-differences estimates of the "
        f"effects of Brazil's 2012 ultractivity reform on {outcome_notes} "
        f"for each of the 24 Sistema Mediador clause subgroups. "
        r"Columns (1)--(3) report direct effects on treated establishments "
        r"relative to control groups of increasing breadth. "
        r"Column (4) reports the baseline spillover effect. "
        r"Column (5) repeats column (4) adding modal-union $\times$ CBA-period "
        r"fixed effects. "
        r"Column (6) runs the baseline spec (no union FE) on the same sample "
        r"used in column (5), isolating sample selection from the FE itself. "
        r"Each subgroup block shows the post-treatment coefficient (top row), "
        r"its standard error (second row), the pre-treatment placebo "
        r"coefficient (third row), and its standard error (fourth row). "
        + _ABSORB + _STARS
    )

    lines = [
        r"\scriptsize",
        rf"\begin{{longtable}}{{{col_spec}}}",
        rf"\caption{{{caption}}} \label{{{label}}} \\",
        r"\toprule\toprule",
        hdr_cols,
        num_row,
        r"\midrule",
        r"\endfirsthead",
        rf"\multicolumn{{{ncols}}}{{l}}{{\small\textit{{(continued from previous page)}}}} \\",
        r"\toprule\toprule",
        hdr_cols,
        num_row,
        r"\midrule",
        r"\endhead",
        r"\midrule",
        rf"\multicolumn{{{ncols}}}{{r}}{{\small\textit{{Continued on next page\ldots}}}} \\",
        r"\endfoot",
        r"\bottomrule",
        rf"\multicolumn{{{ncols}}}{{p{{\linewidth}}}}{{\scriptsize\textit{{Notes:}} {notes}}} \\",
        r"\endlastfoot",
    ]

    prev_broad = None
    for sg in SG_IDS:
        oc    = f"{prefix}{sg}"
        broad = BROAD_GROUP[sg]
        lbl   = LABELS[sg]

        if broad != prev_broad:
            lines.append(r"\midrule")
            lines.append(rf"\multicolumn{{{ncols}}}{{l}}{{\textit{{{broad} amenities}}}} \\")
            prev_broad = broad

        lines.append(
            f"\\quad {lbl}"
            f" & {get(dA, oc, 'main')}"
            f" & {get(dB, oc, 'main')}"
            f" & {get(dC, oc, 'main')}"
            f" & {get(dS, oc, 'main')}"
            f" & {get(dU, oc, 'main')}"
            f" & {get(dR, oc, 'main')}"
            r" \\"
        )
        lines.append(
            f"  & {get(dA, oc, 'main_se', is_se=True)}"
            f" & {get(dB, oc, 'main_se', is_se=True)}"
            f" & {get(dC, oc, 'main_se', is_se=True)}"
            f" & {get(dS, oc, 'main_se', is_se=True)}"
            f" & {get(dU, oc, 'main_se', is_se=True)}"
            f" & {get(dR, oc, 'main_se', is_se=True)}"
            r" \\"
        )
        lines.append(
            f"  & {get(dA, oc, 'pre')}"
            f" & {get(dB, oc, 'pre')}"
            f" & {get(dC, oc, 'pre')}"
            f" & {get(dS, oc, 'pre')}"
            f" & {get(dU, oc, 'pre')}"
            f" & {get(dR, oc, 'pre')}"
            r" \\"
        )
        lines.append(
            f"  & {get(dA, oc, 'pre_se', is_se=True)}"
            f" & {get(dB, oc, 'pre_se', is_se=True)}"
            f" & {get(dC, oc, 'pre_se', is_se=True)}"
            f" & {get(dS, oc, 'pre_se', is_se=True)}"
            f" & {get(dU, oc, 'pre_se', is_se=True)}"
            f" & {get(dR, oc, 'pre_se', is_se=True)}"
            r" \\"
        )
        lines.append(blank)

    lines.append(r"\end{longtable}")
    return "\n".join(lines)


def make_similarity_table(dS, dU, dR):
    """Three-column table: baseline spillover, + union FE, baseline on restricted sample."""
    col_spec = r"l ccc"

    lines = preamble(
        r"Spillover Effect on Subgroup-Level CBA Similarity",
        "tab:subgroup_similarity", col_spec
    )
    lines += [r" & Spillover & \shortstack{Spillover\\+ Union FE} & \shortstack{Baseline\\Restr.\ sample} \\",
              r" & (1) & (2) & (3) \\", r"\midrule"]

    oc = "cosine_sg"
    lines.append(r"Post $\times$ Connectivity"
                 f" & {get(dS, oc, 'main')} & {get(dU, oc, 'main')} & {get(dR, oc, 'main')} \\\\")
    lines.append(f"  & {get(dS, oc, 'main_se', is_se=True)}"
                 f" & {get(dU, oc, 'main_se', is_se=True)}"
                 f" & {get(dR, oc, 'main_se', is_se=True)} \\\\")
    lines.append(r" & & & \\")
    lines.append(r"Pre $\times$ Connectivity"
                 f" & {get(dS, oc, 'pre')} & {get(dU, oc, 'pre')} & {get(dR, oc, 'pre')} \\\\")
    lines.append(f"  & {get(dS, oc, 'pre_se', is_se=True)}"
                 f" & {get(dU, oc, 'pre_se', is_se=True)}"
                 f" & {get(dR, oc, 'pre_se', is_se=True)} \\\\")
    lines.append(r"Pre-trend $F$-test $p$-value"
                 f" & {get(dS, oc, 'pre_pval', is_pval=True)}"
                 f" & {get(dU, oc, 'pre_pval', is_pval=True)}"
                 f" & {get(dR, oc, 'pre_pval', is_pval=True)} \\\\")
    lines.append(r" & & & \\")
    lines.append(r"Mean (pre-treatment)"
                 f" & {get(dS, oc, 'mean_pre')} & {get(dU, oc, 'mean_pre')} & {get(dR, oc, 'mean_pre')} \\\\")
    lines.append(r"Observations"
                 f" & {get(dS, oc, 'n_obs', is_count=True)}"
                 f" & {get(dU, oc, 'n_obs', is_count=True)}"
                 f" & {get(dR, oc, 'n_obs', is_count=True)} \\\\")
    lines.append(r"Establishments"
                 f" & {get(dS, oc, 'n_estab', is_count=True)}"
                 f" & {get(dU, oc, 'n_estab', is_count=True)}"
                 f" & {get(dR, oc, 'n_estab', is_count=True)} \\\\")

    notes = (
        r"This table presents the spillover effect of Brazil's 2012 "
        r"ultractivity reform on subgroup-level cosine similarity. "
        r"Column (2) adds modal-union $\times$ CBA-period fixed effects. "
        r"Column (3) runs the baseline spec (no union FE) on the exact sample "
        r"used by column (2), separating sample selection from the FE. "
        + _ABSORB + _STARS
    )

    lines += postamble(notes)
    return "\n".join(lines)

# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    # Exercise A
    dS_sim = load_csv(tables_dir / "results_spill_subgroup_similarity.csv")
    dU_sim = load_csv(tables_dir / "results_spill_subgroup_similarity_union.csv")
    dR_sim = load_csv(tables_dir / "results_spill_subgroup_similarity_restricted.csv")

    # Exercise B — counts
    dA_cnt = load_csv(tables_dir / "results_A_subgroup_counts.csv")
    dB_cnt = load_csv(tables_dir / "results_B_subgroup_counts.csv")
    dC_cnt = load_csv(tables_dir / "results_C_subgroup_counts.csv")
    dS_cnt = load_csv(tables_dir / "results_spill_subgroup_counts.csv")
    dU_cnt = load_csv(tables_dir / "results_spill_subgroup_counts_union.csv")
    dR_cnt = load_csv(tables_dir / "results_spill_subgroup_counts_restricted.csv")

    # Exercise C — shares
    dA_shr = load_csv(tables_dir / "results_A_subgroup_shares.csv")
    dB_shr = load_csv(tables_dir / "results_B_subgroup_shares.csv")
    dC_shr = load_csv(tables_dir / "results_C_subgroup_shares.csv")
    dS_shr = load_csv(tables_dir / "results_spill_subgroup_shares.csv")
    dU_shr = load_csv(tables_dir / "results_spill_subgroup_shares_union.csv")
    dR_shr = load_csv(tables_dir / "results_spill_subgroup_shares_restricted.csv")

    doc = [
        r"\documentclass[12pt,letterpaper]{article}",
        r"\usepackage[margin=1in]{geometry}",
        r"\usepackage{booktabs}",
        r"\usepackage{longtable}",
        r"\usepackage{threeparttable}",
        r"\usepackage{amsmath}",
        r"\usepackage{amssymb}",
        r"\usepackage{float}",
        r"\begin{document}",
        "",
        make_similarity_table(dS_sim, dU_sim, dR_sim),
        r"\clearpage",
        "",
        make_subgroup_table(
            dA_cnt, dB_cnt, dC_cnt, dS_cnt, dU_cnt, dR_cnt, "sg",
            r"Effects of the Ultractivity Reform on Clause Counts by Subgroup",
            "tab:subgroup_counts",
            "the number of clauses"
        ),
        r"\clearpage",
        "",
        make_subgroup_table(
            dA_shr, dB_shr, dC_shr, dS_shr, dU_shr, dR_shr, "sh",
            r"Effects of the Ultractivity Reform on Clause Composition by Subgroup",
            "tab:subgroup_shares",
            "the share of total clauses"
        ),
        "",
        r"\end{document}",
    ]

    with open(out_file, "w") as f:
        f.write("\n".join(doc))
    print(f"Generated {out_file}")

if __name__ == "__main__":
    main()
