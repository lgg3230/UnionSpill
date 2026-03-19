#!/usr/bin/env python3
"""
Generate publication-ready LaTeX tables for workforce composition analysis,
baseline-scaled outcome specification.

Outcomes are divided by the relevant group's pre-treatment (2009-2011) mean:
  - Direct effects:  scaled by treated firms' pre-treatment mean
  - Spillover:       scaled by all untreated firms' pre-treatment mean

Two tables: direct effects (Panels A/B/C) and spillover effects.
Outcomes: tenure, demographics, education shares (7 columns).

Output: UnionSpill/Tables/composition/composition_scale_tables.tex
"""

import re
from pathlib import Path

SPEC = "composition_scale"

# ── LaTeX cell helpers ────────────────────────────────────────────────────────

def hdr(text):
    return r"\begin{tabular}[c]{@{}c@{}}" + text + r"\end{tabular}"

def panel_cell(bold, italic):
    return (r"\begin{tabular}[c]{@{}l@{}}" + bold + r"\\" +
            " " + italic + r"\end{tabular}")

# ── CSV parsing ───────────────────────────────────────────────────────────────

def load_csv(filepath):
    data = {}
    if not filepath.exists():
        return data
    with open(filepath, "r") as f:
        next(f)
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = line.replace('"', '').split(";")
            if len(parts) < 5:
                continue
            _, _, outcome, row_type, value = (
                parts[0], parts[1], parts[2], parts[3], parts[4]
            )
            data.setdefault(outcome, {})[row_type] = value.strip()
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


def get_val(data, outcome, row_type, **kw):
    try:
        raw = data[outcome][row_type]
    except KeyError:
        return "--"
    return format_value(raw, **kw)


# ── Notes ─────────────────────────────────────────────────────────────────────

_CONTROLS = (
    r"All regressions include establishment fixed effects, year fixed effects, "
    r"year fixed effects interacted with two-digit industry, microregion, and "
    r"negotiation-month indicators, and quartile-bin controls for pre-treatment "
    r"per-worker pairwise worker flows (2007--2011) and pre-treatment "
    r"establishment size, interacted with year fixed effects."
)
_STARS = r"*** p$<$0.01, ** p$<$0.05, * p$<$0.10."


def notes_direct(outcome_desc):
    return (
        r"This table presents difference-in-differences estimates of the direct "
        r"effects of Brazil's 2012 ultractivity reform on " + outcome_desc + r". "
        r"Each outcome is divided by the full panel sample's average value "
        r"over the pre-treatment period (2009--2011), where the sample "
        r"corresponds to each panel's control group definition combined with "
        r"treated establishments. Coefficients therefore represent effects as a "
        r"fraction of that panel-specific baseline mean. "
        r"Post $\times$ Treatment measures the average treatment effect for "
        r"2012--2016; Pre $\times$ Treatment is a placebo test using 2009--2011. " +
        _CONTROLS + r" "
        r"Panel~A restricts the control group to establishments with zero "
        r"pre-reform worker-flow connectivity to treated firms; Panel~B to "
        r"at most 1\%; Panel~C includes all untreated establishments. "
        r"Mean (2011) is the unweighted mean of the scaled outcome for untreated "
        r"control firms in 2011. "
        r"Standard errors clustered at the establishment level in parentheses. " +
        _STARS
    )


def notes_spill(outcome_desc):
    return (
        r"This table estimates spillover effects of Brazil's 2012 ultractivity "
        r"reform on " + outcome_desc + r" at untreated establishments connected "
        r"to treated firms. Each outcome is divided by all untreated "
        r"establishments' average value over the pre-treatment period "
        r"(2009--2011), so coefficients represent effects as a fraction of that "
        r"baseline mean. "
        r"Connectivity is normalized to the 90th percentile of the spillover "
        r"sample distribution. "
        r"Post $\times$ Connectivity captures the average spillover effect for "
        r"2012--2016; Pre $\times$ Connectivity is a placebo test using 2009--2011. " +
        _CONTROLS + r" "
        r"Mean (2011) is the unweighted mean of the scaled outcome for the "
        r"spillover sample in 2011. "
        r"Standard errors clustered at the establishment level in parentheses. " +
        _STARS
    )


# ── Outcome groups ────────────────────────────────────────────────────────────

OUTCOME_GROUPS = [
    dict(
        key="composition_scale",
        direct_caption=(
            r"Direct Effects of the Ultractivity Reform on Workforce Composition "
            r"(Scaled by Panel Pre-Treatment Mean)"
        ),
        spill_caption=(
            r"Spillover Effects of the Ultractivity Reform on Workforce Composition "
            r"(Scaled by Untreated Pre-Treatment Mean)"
        ),
        outcomes=[
            "avg_tenure", "male_prop", "white_prop",
            "prop_nhs", "prop_hs", "prop_sup", "prop_hs_plus",
            "avg_age",
        ],
        col_headers=[
            r"Avg.\\Tenure", r"Male\\Share", r"White\\Share",
            r"No High\\School", r"High\\School", r"College+",
            r"HS or\\Above",
            r"Avg.\\Age",
        ],
        direct_notes=notes_direct(
            r"workforce composition: average tenure (months), share male, "
            r"share white, share with no high school, share with completed "
            r"high school, share with college degree or higher, "
            r"and average worker age"
        ),
        spill_notes=notes_spill(
            r"workforce composition: average tenure, share male, share white, "
            r"share with no high school, share with completed high school, "
            r"share with college degree or higher, and average worker age"
        ),
    ),
]


# ── Panel section builder ─────────────────────────────────────────────────────

def panel_section(pdata, outcomes, panel_bold, panel_italic, col_headers,
                  post_label, pre_label):
    n = len(outcomes)
    blank = " " + " & " * n + r"\\"
    lines = []

    col_hdrs = " & ".join(hdr(h) for h in col_headers)
    lines.append(panel_cell(panel_bold, panel_italic) + " & " + col_hdrs + r" \\")
    nums = " & ".join(f"({i+1})" for i in range(n))
    lines.append(" & " + nums + r" \\")
    lines.append(r"\midrule")

    row = post_label + "".join(
        " & " + get_val(pdata, o, "main") for o in outcomes)
    lines.append(row + r" \\")
    row = "".join(
        " & " + get_val(pdata, o, "main_se", is_se=True) for o in outcomes)
    lines.append(" " + row + r" \\")
    lines.append(blank)

    row = pre_label + "".join(
        " & " + get_val(pdata, o, "pre") for o in outcomes)
    lines.append(row + r" \\")
    row = "".join(
        " & " + get_val(pdata, o, "pre_se", is_se=True) for o in outcomes)
    lines.append(" " + row + r" \\")
    row = r"Pre-trend $F$-test $p$-value" + "".join(
        " & " + get_val(pdata, o, "pre_pval", is_pval=True) for o in outcomes)
    lines.append(row + r" \\")
    lines.append(blank)

    row = r"Mean (2011)" + "".join(
        " & " + get_val(pdata, o, "mean_pre") for o in outcomes)
    lines.append(row + r" \\")
    row = "Observations" + "".join(
        " & " + get_val(pdata, o, "n_obs", is_count=True) for o in outcomes)
    lines.append(row + r" \\")
    row = "Establishments" + "".join(
        " & " + get_val(pdata, o, "n_estab", is_count=True) for o in outcomes)
    lines.append(row + r" \\")

    return lines


# ── Table builders ────────────────────────────────────────────────────────────

def table_preamble(caption, label, col_spec):
    return [
        r"\begin{table}[H]",
        r"\centering",
        f"\\caption{{{caption}}}",
        f"\\label{{{label}}}",
        r"\begin{threeparttable}",
        r"\resizebox{\textwidth}{!}{%",
        r"\scriptsize",
        f"\\begin{{tabular}}{{{col_spec}}}",
        r"\toprule\toprule",
    ]


def table_postamble(notes):
    return [
        r"\bottomrule",
        r"\end{tabular}%",
        r"}",  # close \resizebox
        r"\scriptsize",
        r"\begin{tablenotes}",
        r"\item \textit{Notes:} " + notes,
        r"\end{tablenotes}",
        r"\end{threeparttable}",
        r"\end{table}",
    ]


def make_direct_table(group):
    key         = group["key"]
    outcomes    = group["outcomes"]
    col_headers = group["col_headers"]
    n           = len(outcomes)
    col_spec    = "l" + "c" * n
    blank       = " " + " & " * n + r"\\"

    lines = table_preamble(group["direct_caption"], f"tab:direct_{key}", col_spec)

    panel_defs = [
        (r"\textbf{Panel A:} \textit{Only Control Firms}",
         r"\textit{with Zero Connectivity}", "panel_a"),
        (r"\textbf{Panel B:} \textit{Control Firms with}",
         r"\textit{$\leq$1\% Connectivity}", "panel_b"),
        (r"\textbf{Panel C:} \textit{All Untreated}",
         r"\textit{Control Firms}", "panel_c"),
    ]

    for idx, (bold, italic, data_key) in enumerate(panel_defs):
        lines += panel_section(
            group[data_key], outcomes, bold, italic, col_headers,
            r"Post $\times$ Treatment", r"Pre $\times$ Treatment",
        )
        if idx < len(panel_defs) - 1:
            lines.append(blank)
            lines.append(r"\midrule")

    lines += table_postamble(group["direct_notes"])
    return "\n".join(lines)


def make_spill_table(group):
    key         = group["key"]
    outcomes    = group["outcomes"]
    col_headers = group["col_headers"]
    n           = len(outcomes)
    col_spec    = "l" + "c" * n
    blank       = " " + " & " * n + r"\\"

    lines = table_preamble(group["spill_caption"], f"tab:spill_{key}", col_spec)

    col_hdrs = " & ".join(hdr(h) for h in col_headers)
    lines.append(" & " + col_hdrs + r" \\")
    nums = " & ".join(f"({i+1})" for i in range(n))
    lines.append(" & " + nums + r" \\")
    lines.append(r"\midrule")

    pdata = group["spill"]

    row = r"Post $\times$ Connectivity" + "".join(
        " & " + get_val(pdata, o, "main") for o in outcomes)
    lines.append(row + r" \\")
    row = "".join(
        " & " + get_val(pdata, o, "main_se", is_se=True) for o in outcomes)
    lines.append(" " + row + r" \\")
    lines.append(blank)

    row = r"Pre $\times$ Connectivity" + "".join(
        " & " + get_val(pdata, o, "pre") for o in outcomes)
    lines.append(row + r" \\")
    row = "".join(
        " & " + get_val(pdata, o, "pre_se", is_se=True) for o in outcomes)
    lines.append(" " + row + r" \\")
    row = r"Pre-trend $F$-test $p$-value" + "".join(
        " & " + get_val(pdata, o, "pre_pval", is_pval=True) for o in outcomes)
    lines.append(row + r" \\")
    lines.append(blank)

    row = r"Mean (2011)" + "".join(
        " & " + get_val(pdata, o, "mean_pre") for o in outcomes)
    lines.append(row + r" \\")
    row = "Observations" + "".join(
        " & " + get_val(pdata, o, "n_obs", is_count=True) for o in outcomes)
    lines.append(row + r" \\")
    row = "Establishments" + "".join(
        " & " + get_val(pdata, o, "n_estab", is_count=True) for o in outcomes)
    lines.append(row + r" \\")

    lines += table_postamble(group["spill_notes"])
    return "\n".join(lines)


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    script_dir   = Path(__file__).resolve().parent
    tables_dir   = script_dir.parent.parent / "Tables"
    pipeline_dir = tables_dir / "composition"
    output_file  = pipeline_dir / "composition_scale_tables.tex"

    pa_file = pipeline_dir / f"results_direct_panelA_{SPEC}.csv"
    pb_file = pipeline_dir / f"results_direct_panelB_{SPEC}.csv"
    pc_file = pipeline_dir / f"results_direct_panelC_{SPEC}.csv"
    sp_file = pipeline_dir / f"results_spill_{SPEC}.csv"

    missing = [f.name for f in [pa_file, pb_file, pc_file, sp_file] if not f.exists()]
    if missing:
        print(f"  WARNING: Missing CSV files: {', '.join(missing)}")

    panel_a = load_csv(pa_file)
    panel_b = load_csv(pb_file)
    panel_c = load_csv(pc_file)
    spill   = load_csv(sp_file)

    for g in OUTCOME_GROUPS:
        g["panel_a"] = panel_a
        g["panel_b"] = panel_b
        g["panel_c"] = panel_c
        g["spill"]   = spill

    doc = []

    table_count = 0
    for g in OUTCOME_GROUPS:
        doc.append(make_direct_table(g))
        doc.append("")
        doc.append("")
        doc.append(make_spill_table(g))
        doc.append("")
        table_count += 2

    content = "\n".join(doc)
    with open(output_file, "w") as f:
        f.write(content)

    print(f"Generated {output_file}")
    print(f"  {table_count} tables ({len(OUTCOME_GROUPS)} outcome groups × direct + spillover)")


if __name__ == "__main__":
    main()
