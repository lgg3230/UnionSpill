#!/usr/bin/env python3
"""
Generate publication-ready LaTeX tables for the connectivity margins analysis.

Three panels per table:
  Panel A — Extensive margin (binary pos_conn, full spillover sample)
  Panel B — Intensive margin (continuous conn, positive-connectivity sample)
  Panel C — Saturated model  (pos_conn + conn, full spillover sample)

Output: Tables/conn_margins/conn_margins_tables.tex
"""

import re
from pathlib import Path

# ── LaTeX cell helpers ────────────────────────────────────────────────────────

def hdr(text):
    return r"\begin{tabular}[c]{@{}c@{}}" + text + r"\end{tabular}"


def panel_cell(bold, italic):
    return (r"\begin{tabular}[c]{@{}l@{}}" + bold + r"\\" +
            " " + italic + r"\end{tabular}")


# ── CSV parsing ───────────────────────────────────────────────────────────────

def load_csv(filepath):
    """Parse semicolon-delimited CSV. Returns {outcome: {row_type: value}}."""
    data = {}
    if not filepath.exists():
        print(f"  WARNING: {filepath.name} not found — table will show '--'")
        return data
    with open(filepath) as f:
        next(f)  # skip header
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


def format_value(raw, is_se=False, is_count=False, is_pval=False, is_cl_se=False):
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
    if is_cl_se:
        return f"[{num_str}]"
    return f"({num_str})" if is_se else f"{num_str}{stars}"


def get_val(data, outcome, row_type, **kw):
    try:
        raw = data[outcome][row_type]
    except KeyError:
        return "--"
    return format_value(raw, **kw)


# ── Notes ─────────────────────────────────────────────────────────────────────

_CONTROLS = (
    r"All regressions include establishment fixed effects interacted with "
    r"two-digit industry, microregion, and negotiation-month indicators by year "
    r"(or CBA period), and quartile-bin controls for pre-treatment per-worker "
    r"pairwise worker flows (2007--2011) and pre-treatment establishment size. "
    r"Standard errors clustered at the establishment level in parentheses. "
    r"*** p$<$0.01, ** p$<$0.05, * p$<$0.10."
)

def make_notes(include_cba=False, include_panelD=False):
    cba = (
        r"The clause count column uses CBA negotiation periods rather than "
        r"calendar years; the pre-trend test uses CBA period~1 vs.\ the base "
        r"period~2. "
    ) if include_cba else ""
    panelD = (
        r"\textit{Panel~D} replicates Panel~B but residualizes the outcome on "
        r"the full untreated sample before running the second-step regression "
        r"on positive-connectivity establishments. "
        r"Standard errors in parentheses are bootstrapped (B\,=\,200 "
        r"establishment-level resamples) to account for two-step estimation "
        r"uncertainty; naive cluster standard errors are shown in brackets. "
        r"Stars follow the bootstrap standard errors. "
    ) if include_panelD else ""
    return (
        r"\textit{Panel~A} replaces continuous connectivity with a binary "
        r"indicator (any connection vs.\ none) on the full untreated sample. "
        r"\textit{Panel~B} restricts the sample to establishments with positive "
        r"connectivity and runs the baseline continuous specification. "
        r"\textit{Panel~C} includes both the binary indicator and continuous "
        r"connectivity interacted with post on the full untreated sample "
        r"(note: Conn\,$\times$\,Pos\,$\equiv$\,Conn, so the triple interaction "
        r"is omitted). " +
        panelD +
        cba +
        _CONTROLS
    )


# ── Table preamble / postamble ────────────────────────────────────────────────

def table_preamble(caption, label, col_spec):
    return [
        r"\begin{table}[]",
        r"\centering",
        f"\\caption{{{caption}}}",
        f"\\label{{{label}}}",
        r"\scriptsize",
        r"\begin{threeparttable}",
        f"\\begin{{tabular}}{{{col_spec}}}",
        r"\toprule\toprule",
    ]


def table_postamble(notes):
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


def blank_row(n):
    return " " + " & " * n + r"\\"


# ── Panel A: extensive margin ─────────────────────────────────────────────────

def panel_A_section(data, outcomes, col_headers):
    n = len(outcomes)
    lines = []

    col_hdrs = " & ".join(hdr(h) for h in col_headers)
    lines.append(
        panel_cell(r"\textbf{Panel A:} \textit{Extensive Margin}",
                   r"\textit{Binary; Full Sample}") +
        " & " + col_hdrs + r" \\"
    )
    nums = " & ".join(f"({i+1})" for i in range(n))
    lines.append(" & " + nums + r" \\")
    lines.append(r"\midrule")

    row = r"Post $\times$ Any Connection" + "".join(
        " & " + get_val(data, o, "main") for o in outcomes)
    lines.append(row + r" \\")
    row = "".join(" & " + get_val(data, o, "main_se", is_se=True) for o in outcomes)
    lines.append(" " + row + r" \\")
    lines.append(blank_row(n))

    row = r"Pre $\times$ Any Connection" + "".join(
        " & " + get_val(data, o, "pre") for o in outcomes)
    lines.append(row + r" \\")
    row = "".join(" & " + get_val(data, o, "pre_se", is_se=True) for o in outcomes)
    lines.append(" " + row + r" \\")
    row = r"Pre-trend $F$-test $p$-value" + "".join(
        " & " + get_val(data, o, "pre_pval", is_pval=True) for o in outcomes)
    lines.append(row + r" \\")
    lines.append(blank_row(n))

    row = "Observations" + "".join(
        " & " + get_val(data, o, "n_obs", is_count=True) for o in outcomes)
    lines.append(row + r" \\")
    row = "Establishments" + "".join(
        " & " + get_val(data, o, "n_estab", is_count=True) for o in outcomes)
    lines.append(row + r" \\")

    return lines


# ── Panel B: intensive margin ─────────────────────────────────────────────────

def panel_B_section(data, outcomes, col_headers):
    n = len(outcomes)
    lines = []

    lines.append(blank_row(n))
    lines.append(r"\midrule")
    col_hdrs = " & ".join(hdr(h) for h in col_headers)
    lines.append(
        panel_cell(r"\textbf{Panel B:} \textit{Intensive Margin}",
                   r"\textit{Continuous; Positive-Conn Sample}") +
        " & " + col_hdrs + r" \\"
    )
    nums = " & ".join(f"({i+1+n})" for i in range(n))
    lines.append(" & " + nums + r" \\")
    lines.append(r"\midrule")

    row = r"Post $\times$ Connectivity" + "".join(
        " & " + get_val(data, o, "main") for o in outcomes)
    lines.append(row + r" \\")
    row = "".join(" & " + get_val(data, o, "main_se", is_se=True) for o in outcomes)
    lines.append(" " + row + r" \\")
    lines.append(blank_row(n))

    row = r"Pre $\times$ Connectivity" + "".join(
        " & " + get_val(data, o, "pre") for o in outcomes)
    lines.append(row + r" \\")
    row = "".join(" & " + get_val(data, o, "pre_se", is_se=True) for o in outcomes)
    lines.append(" " + row + r" \\")
    row = r"Pre-trend $F$-test $p$-value" + "".join(
        " & " + get_val(data, o, "pre_pval", is_pval=True) for o in outcomes)
    lines.append(row + r" \\")
    lines.append(blank_row(n))

    row = "Observations" + "".join(
        " & " + get_val(data, o, "n_obs", is_count=True) for o in outcomes)
    lines.append(row + r" \\")
    row = "Establishments" + "".join(
        " & " + get_val(data, o, "n_estab", is_count=True) for o in outcomes)
    lines.append(row + r" \\")

    return lines


# ── Panel C: saturated ────────────────────────────────────────────────────────

def panel_C_section(data, outcomes, col_headers):
    n = len(outcomes)
    lines = []

    lines.append(blank_row(n))
    lines.append(r"\midrule")
    col_hdrs = " & ".join(hdr(h) for h in col_headers)
    lines.append(
        panel_cell(r"\textbf{Panel C:} \textit{Saturated Model}",
                   r"\textit{Extensive + Intensive; Full Sample}") +
        " & " + col_hdrs + r" \\"
    )
    nums = " & ".join(f"({i+1+2*n})" for i in range(n))
    lines.append(" & " + nums + r" \\")
    lines.append(r"\midrule")

    row = r"Post $\times$ Any Connection" + "".join(
        " & " + get_val(data, o, "main_pos") for o in outcomes)
    lines.append(row + r" \\")
    row = "".join(" & " + get_val(data, o, "main_pos_se", is_se=True) for o in outcomes)
    lines.append(" " + row + r" \\")

    row = r"Post $\times$ Connectivity" + "".join(
        " & " + get_val(data, o, "main_conn") for o in outcomes)
    lines.append(row + r" \\")
    row = "".join(" & " + get_val(data, o, "main_conn_se", is_se=True) for o in outcomes)
    lines.append(" " + row + r" \\")
    lines.append(blank_row(n))

    row = r"Pre $\times$ Any Connection" + "".join(
        " & " + get_val(data, o, "pre_pos") for o in outcomes)
    lines.append(row + r" \\")
    row = "".join(" & " + get_val(data, o, "pre_pos_se", is_se=True) for o in outcomes)
    lines.append(" " + row + r" \\")

    row = r"Pre $\times$ Connectivity" + "".join(
        " & " + get_val(data, o, "pre_conn") for o in outcomes)
    lines.append(row + r" \\")
    row = "".join(" & " + get_val(data, o, "pre_conn_se", is_se=True) for o in outcomes)
    lines.append(" " + row + r" \\")

    row = r"Pre-trend $F$-test: Any Connection" + "".join(
        " & " + get_val(data, o, "pre_pval_pos", is_pval=True) for o in outcomes)
    lines.append(row + r" \\")
    row = r"Pre-trend $F$-test: Connectivity" + "".join(
        " & " + get_val(data, o, "pre_pval_conn", is_pval=True) for o in outcomes)
    lines.append(row + r" \\")
    lines.append(blank_row(n))

    row = "Observations" + "".join(
        " & " + get_val(data, o, "n_obs", is_count=True) for o in outcomes)
    lines.append(row + r" \\")
    row = "Establishments" + "".join(
        " & " + get_val(data, o, "n_estab", is_count=True) for o in outcomes)
    lines.append(row + r" \\")

    return lines


# ── Panel D: full-sample residualization + bootstrap SE ──────────────────────

def panel_D_section(data, outcomes, col_headers, offset):
    n = len(outcomes)
    lines = []

    lines.append(blank_row(n))
    lines.append(r"\midrule")
    col_hdrs = " & ".join(hdr(h) for h in col_headers)
    lines.append(
        panel_cell(r"\textbf{Panel D:} \textit{Full-Sample Residualization}",
                   r"\textit{Continuous; Positive-Conn Sample; Bootstrap SE}") +
        " & " + col_hdrs + r" \\"
    )
    nums = " & ".join(f"({i+1+offset})" for i in range(n))
    lines.append(" & " + nums + r" \\")
    lines.append(r"\midrule")

    # Post coefficient + bootstrap SE (parentheses) + cluster SE (brackets)
    row = r"Post $\times$ Connectivity" + "".join(
        " & " + get_val(data, o, "main") for o in outcomes)
    lines.append(row + r" \\")
    row = "".join(" & " + get_val(data, o, "main_se", is_se=True) for o in outcomes)
    lines.append(" " + row + r" \\")
    row = "".join(" & " + get_val(data, o, "main_se_cl", is_cl_se=True) for o in outcomes)
    lines.append(" " + row + r" \\")
    lines.append(blank_row(n))

    # Pre coefficient + bootstrap SE + cluster SE
    row = r"Pre $\times$ Connectivity" + "".join(
        " & " + get_val(data, o, "pre") for o in outcomes)
    lines.append(row + r" \\")
    row = "".join(" & " + get_val(data, o, "pre_se", is_se=True) for o in outcomes)
    lines.append(" " + row + r" \\")
    row = "".join(" & " + get_val(data, o, "pre_se_cl", is_cl_se=True) for o in outcomes)
    lines.append(" " + row + r" \\")
    row = r"Pre-trend $F$-test $p$-value" + "".join(
        " & " + get_val(data, o, "pre_pval", is_pval=True) for o in outcomes)
    lines.append(row + r" \\")
    lines.append(blank_row(n))

    row = "Observations" + "".join(
        " & " + get_val(data, o, "n_obs", is_count=True) for o in outcomes)
    lines.append(row + r" \\")
    row = "Establishments" + "".join(
        " & " + get_val(data, o, "n_estab", is_count=True) for o in outcomes)
    lines.append(row + r" \\")

    return lines


# ── Full table builder ────────────────────────────────────────────────────────

def make_table(caption, label, outcomes, col_headers, ex1, ex2, ex3, notes, ex4=None):
    n        = len(outcomes)
    col_spec = "l" + "c" * n

    lines = table_preamble(caption, label, col_spec)
    lines += panel_A_section(ex1, outcomes, col_headers)
    lines += panel_B_section(ex2, outcomes, col_headers)
    lines += panel_C_section(ex3, outcomes, col_headers)
    if ex4 is not None:
        lines += panel_D_section(ex4, outcomes, col_headers, offset=3 * n)
    lines += table_postamble(notes)

    return "\n".join(lines)


# ── Wage-only side-by-side table ─────────────────────────────────────────────

def make_wage_table(ex1, ex2, ex3):
    """
    Side-by-side layout: panels as column groups, wage outcomes as sub-columns.

    Columns: Panel A (Ex1) × 2 | Panel B (Ex2) × 2 | Panel C (Ex3) × 2
    Rows: coefficient rows (blanks where a term doesn't apply to a panel).
    """
    outcomes = ["lr_remdezr_w", "lr_remdezr_h_w"]
    BLANK = "--"

    def v(data, o, rt, **kw):
        return get_val(data, o, rt, **kw)

    def se(data, o, rt):
        return get_val(data, o, rt, is_se=True)

    # col_spec: label col + 2+2+2 data cols
    col_spec = "l" + "cc" + "cc" + "cc"

    lines = []
    lines += table_preamble(
        caption=(
            r"Connectivity Margins and Wage Spillovers: "
            r"Extensive, Intensive, and Saturated Specifications"
        ),
        label="tab:conn_margins_wages",
        col_spec=col_spec,
    )

    # ── Panel headers ─────────────────────────────────────────────────────────
    lines.append(
        r" & \multicolumn{2}{c}{\textbf{Panel A: Extensive}} "
        r"& \multicolumn{2}{c}{\textbf{Panel B: Intensive}} "
        r"& \multicolumn{2}{c}{\textbf{Panel C: Saturated}} \\"
    )
    lines.append(
        r" & \multicolumn{2}{c}{\textit{Binary; Full Sample}} "
        r"& \multicolumn{2}{c}{\textit{Continuous; Pos-Conn Sample}} "
        r"& \multicolumn{2}{c}{\textit{Extensive + Intensive; Full Sample}} \\"
    )
    lines.append(
        r"\cmidrule(lr){2-3}\cmidrule(lr){4-5}\cmidrule(lr){6-7}"
    )
    lines.append(
        r" & " + r" & ".join(
            [hdr(r"Log\\Wages"), hdr(r"Log Hourly\\Wages")] * 3
        ) + r" \\"
    )
    lines.append(
        r" & (1) & (2) & (3) & (4) & (5) & (6) \\"
    )
    lines.append(r"\midrule")

    blank6 = r" & & & & & & \\"

    # ── Post coefficients ─────────────────────────────────────────────────────

    # Post × Any Connection (Panel A cols 1-2, Panel C cols 5-6; blank for B)
    lines.append(
        r"Post $\times$ Any Connection"
        + "".join(f" & {v(ex1, o, 'main')}"       for o in outcomes)
        + f" & {BLANK} & {BLANK}"
        + "".join(f" & {v(ex3, o, 'main_pos')}"    for o in outcomes)
        + r" \\"
    )
    lines.append(
        r" "
        + "".join(f" & {se(ex1, o, 'main_se')}"    for o in outcomes)
        + r" & & "
        + "".join(f" & {se(ex3, o, 'main_pos_se')}" for o in outcomes)
        + r" \\"
    )

    # Post × Connectivity (blank for A, Panel B cols 3-4, Panel C cols 5-6)
    lines.append(
        r"Post $\times$ Connectivity"
        + f" & {BLANK} & {BLANK}"
        + "".join(f" & {v(ex2, o, 'main')}"        for o in outcomes)
        + "".join(f" & {v(ex3, o, 'main_conn')}"   for o in outcomes)
        + r" \\"
    )
    lines.append(
        r" "
        + r" & & "
        + "".join(f" & {se(ex2, o, 'main_se')}"    for o in outcomes)
        + "".join(f" & {se(ex3, o, 'main_conn_se')}" for o in outcomes)
        + r" \\"
    )

    lines.append(blank6)

    # ── Pre coefficients ──────────────────────────────────────────────────────

    lines.append(
        r"Pre $\times$ Any Connection"
        + "".join(f" & {v(ex1, o, 'pre')}"          for o in outcomes)
        + f" & {BLANK} & {BLANK}"
        + "".join(f" & {v(ex3, o, 'pre_pos')}"      for o in outcomes)
        + r" \\"
    )
    lines.append(
        r" "
        + "".join(f" & {se(ex1, o, 'pre_se')}"      for o in outcomes)
        + r" & & "
        + "".join(f" & {se(ex3, o, 'pre_pos_se')}"  for o in outcomes)
        + r" \\"
    )

    lines.append(
        r"Pre $\times$ Connectivity"
        + f" & {BLANK} & {BLANK}"
        + "".join(f" & {v(ex2, o, 'pre')}"           for o in outcomes)
        + "".join(f" & {v(ex3, o, 'pre_conn')}"      for o in outcomes)
        + r" \\"
    )
    lines.append(
        r" "
        + r" & & "
        + "".join(f" & {se(ex2, o, 'pre_se')}"       for o in outcomes)
        + "".join(f" & {se(ex3, o, 'pre_conn_se')}"  for o in outcomes)
        + r" \\"
    )

    # ── Pre-trend F-tests ─────────────────────────────────────────────────────

    lines.append(
        r"Pre-trend $F$: Any Connection"
        + "".join(f" & {v(ex1, o, 'pre_pval', is_pval=True)}" for o in outcomes)
        + f" & {BLANK} & {BLANK}"
        + "".join(f" & {v(ex3, o, 'pre_pval_pos', is_pval=True)}" for o in outcomes)
        + r" \\"
    )
    lines.append(
        r"Pre-trend $F$: Connectivity"
        + f" & {BLANK} & {BLANK}"
        + "".join(f" & {v(ex2, o, 'pre_pval', is_pval=True)}"      for o in outcomes)
        + "".join(f" & {v(ex3, o, 'pre_pval_conn', is_pval=True)}" for o in outcomes)
        + r" \\"
    )

    lines.append(blank6)

    # ── Sample sizes ──────────────────────────────────────────────────────────

    lines.append(
        r"Observations"
        + "".join(f" & {v(ex1, o, 'n_obs', is_count=True)}"  for o in outcomes)
        + "".join(f" & {v(ex2, o, 'n_obs', is_count=True)}"  for o in outcomes)
        + "".join(f" & {v(ex3, o, 'n_obs', is_count=True)}"  for o in outcomes)
        + r" \\"
    )
    lines.append(
        r"Establishments"
        + "".join(f" & {v(ex1, o, 'n_estab', is_count=True)}" for o in outcomes)
        + "".join(f" & {v(ex2, o, 'n_estab', is_count=True)}" for o in outcomes)
        + "".join(f" & {v(ex3, o, 'n_estab', is_count=True)}" for o in outcomes)
        + r" \\"
    )

    # ── Notes ─────────────────────────────────────────────────────────────────
    notes = (
        r"\textit{Panel~A} replaces continuous connectivity with a binary "
        r"indicator on the full untreated sample. "
        r"\textit{Panel~B} restricts to establishments with positive "
        r"connectivity and runs the baseline continuous specification. "
        r"\textit{Panel~C} includes both the binary indicator and continuous "
        r"connectivity interacted with post on the full untreated sample. " +
        _CONTROLS
    )

    lines += table_postamble(notes)
    return "\n".join(lines)


# ── Wage-only side-by-side table v2 (placebo at bottom, minipage notes) ───────

def make_wage_table_v2(ex1, ex2, ex3):
    """
    Side-by-side layout following the project's canonical table format:
      - Post coefficients in the main body
      - Observations / Establishments
      - \\midrule
      - Pre-trend (placebo) section at the bottom
      - Notes in \\begin{minipage}{\\linewidth}
      - No F-test rows
    """
    outcomes = ["lr_remdezr_w", "lr_remdezr_h_w"]
    BLANK = "--"

    def v(data, o, rt, **kw):
        return get_val(data, o, rt, **kw)

    def se(data, o, rt):
        return get_val(data, o, rt, is_se=True)

    col_spec = "l" + "cc" + "cc" + "cc"
    blank6   = r" & & & & & & \\"

    lines = []
    lines += [
        r"\begin{table}[]",
        r"\centering",
        r"\caption{Connectivity Margins and Wage Spillovers of the Ultractivity Reform}",
        r"\label{tab:conn_margins_wages_v2}",
        r"\footnotesize",
        f"\\begin{{tabular}}{{{col_spec}}}",
        r"\toprule\toprule",
    ]

    # ── Panel headers ─────────────────────────────────────────────────────────
    lines.append(
        r" & \multicolumn{2}{c}{\textbf{Panel A: Extensive}}"
        r" & \multicolumn{2}{c}{\textbf{Panel B: Intensive}}"
        r" & \multicolumn{2}{c}{\textbf{Panel C: Saturated}} \\"
    )
    lines.append(
        r" & \multicolumn{2}{c}{\textit{Binary; Full Sample}}"
        r" & \multicolumn{2}{c}{\textit{Continuous; Pos-Conn Sample}}"
        r" & \multicolumn{2}{c}{\textit{Extensive + Intensive; Full Sample}} \\"
    )
    lines.append(r"\cmidrule(lr){2-3}\cmidrule(lr){4-5}\cmidrule(lr){6-7}")
    lines.append(
        r" & " + r" & ".join(
            [hdr(r"Log\\Wages"), hdr(r"Log Hourly\\Wages")] * 3
        ) + r" \\"
    )
    lines.append(r" & (1) & (2) & (3) & (4) & (5) & (6) \\")
    lines.append(r"\midrule")

    # ── Post coefficients ─────────────────────────────────────────────────────
    lines.append(
        r"Post $\times$ Any Connection"
        + "".join(f" & {v(ex1, o, 'main')}"        for o in outcomes)
        + f" & {BLANK} & {BLANK}"
        + "".join(f" & {v(ex3, o, 'main_pos')}"    for o in outcomes)
        + r" \\"
    )
    lines.append(
        r" "
        + "".join(f" & {se(ex1, o, 'main_se')}"    for o in outcomes)
        + r" & & "
        + "".join(f" & {se(ex3, o, 'main_pos_se')}" for o in outcomes)
        + r" \\"
    )

    lines.append(
        r"Post $\times$ Connectivity"
        + f" & {BLANK} & {BLANK}"
        + "".join(f" & {v(ex2, o, 'main')}"        for o in outcomes)
        + "".join(f" & {v(ex3, o, 'main_conn')}"   for o in outcomes)
        + r" \\"
    )
    lines.append(
        r" "
        + r" & & "
        + "".join(f" & {se(ex2, o, 'main_se')}"    for o in outcomes)
        + "".join(f" & {se(ex3, o, 'main_conn_se')}" for o in outcomes)
        + r" \\"
    )

    lines.append(blank6)

    # ── Sample sizes ──────────────────────────────────────────────────────────
    lines.append(
        r"Observations"
        + "".join(f" & {v(ex1, o, 'n_obs', is_count=True)}"  for o in outcomes)
        + "".join(f" & {v(ex2, o, 'n_obs', is_count=True)}"  for o in outcomes)
        + "".join(f" & {v(ex3, o, 'n_obs', is_count=True)}"  for o in outcomes)
        + r" \\"
    )
    lines.append(
        r"Establishments"
        + "".join(f" & {v(ex1, o, 'n_estab', is_count=True)}" for o in outcomes)
        + "".join(f" & {v(ex2, o, 'n_estab', is_count=True)}" for o in outcomes)
        + "".join(f" & {v(ex3, o, 'n_estab', is_count=True)}" for o in outcomes)
        + r" \\"
    )

    # ── Pre-trend placebo section ─────────────────────────────────────────────
    lines.append(r"\midrule")

    lines.append(
        r"Pre-trend (placebo): Any Connection"
        + "".join(f" & {v(ex1, o, 'pre')}"          for o in outcomes)
        + f" & {BLANK} & {BLANK}"
        + "".join(f" & {v(ex3, o, 'pre_pos')}"      for o in outcomes)
        + r" \\"
    )
    lines.append(
        r" "
        + "".join(f" & {se(ex1, o, 'pre_se')}"      for o in outcomes)
        + r" & & "
        + "".join(f" & {se(ex3, o, 'pre_pos_se')}"  for o in outcomes)
        + r" \\"
    )

    lines.append(
        r"Pre-trend (placebo): Connectivity"
        + f" & {BLANK} & {BLANK}"
        + "".join(f" & {v(ex2, o, 'pre')}"           for o in outcomes)
        + "".join(f" & {v(ex3, o, 'pre_conn')}"      for o in outcomes)
        + r" \\"
    )
    lines.append(
        r" "
        + r" & & "
        + "".join(f" & {se(ex2, o, 'pre_se')}"       for o in outcomes)
        + "".join(f" & {se(ex3, o, 'pre_conn_se')}"  for o in outcomes)
        + r" \\"
    )

    lines += [
        r"\bottomrule\bottomrule",
        r"\end{tabular}",
        r"\begin{minipage}{\linewidth}",
        r"\footnotesize\vspace{4pt}",
        (
            r"\textit{Notes:} "
            r"\textit{Panel~A} replaces continuous connectivity with a binary "
            r"indicator (any connection vs.\ none) on the full untreated sample. "
            r"\textit{Panel~B} restricts to establishments with positive "
            r"connectivity and runs the baseline continuous specification. "
            r"\textit{Panel~C} includes both the binary indicator and continuous "
            r"connectivity interacted with post on the full untreated sample. "
            r"Pre-trend (placebo) reports coefficients from pooled placebo "
            r"regressions estimated on pre-treatment data only (2009--2010 "
            r"relative to 2011). " +
            _CONTROLS
        ),
        r"\end{minipage}",
        r"\end{table}",
    ]

    return "\n".join(lines)


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    script_dir  = Path(__file__).resolve().parent
    tables_dir  = script_dir.parent.parent / "Tables" / "conn_margins"
    output_file = tables_dir / "conn_margins_tables.tex"

    ex1_file = tables_dir / "results_conn_margins_ex1.csv"
    ex2_file = tables_dir / "results_conn_margins_ex2.csv"
    ex3_file = tables_dir / "results_conn_margins_ex3.csv"
    ex4_file = tables_dir / "results_conn_margins_ex4.csv"

    ex1 = load_csv(ex1_file)
    ex2 = load_csv(ex2_file)
    ex3 = load_csv(ex3_file)
    ex4 = load_csv(ex4_file)

    outcomes    = ["lr_remdezr_w", "lr_remdezr_h_w", "l_firm_emp", "numb_clauses"]
    col_headers = [
        r"Log\\Wages", r"Log Hourly\\Wages", r"Log\\Employment", r"Clause\\Count",
    ]

    has_ex4 = bool(ex4)
    table = make_table(
        caption=r"Connectivity Margins and Spillover Effects of the Ultractivity Reform",
        label="tab:conn_margins",
        outcomes=outcomes,
        col_headers=col_headers,
        ex1=ex1, ex2=ex2, ex3=ex3,
        notes=make_notes(include_cba=True, include_panelD=has_ex4),
        ex4=ex4 if has_ex4 else None,
    )

    doc = []
    doc.append(r"""\documentclass[12pt,letterpaper]{article}

\usepackage[margin=1in]{geometry}
\usepackage{booktabs}
\usepackage{threeparttable}
\usepackage{amsmath}
\usepackage{amssymb}
\usepackage{hyperref}
\usepackage{float}

\hypersetup{colorlinks=true,linkcolor=blue,citecolor=blue,urlcolor=blue}

\begin{document}

\begin{titlepage}
\centering
\vspace*{2cm}
{\Huge\bfseries Union Spillovers:\\Connectivity Margins Analysis\par}
\vspace{2cm}
{\Large Extensive vs.\ Intensive Margin of Worker-Flow Connectivity\par}
\vspace{1cm}
{\large \today\par}
\vfill
{\large Luis de Azevedo-Gomes \& Guilherme Neri\\Northwestern University\par}
\end{titlepage}

\tableofcontents
\clearpage
""")

    wage_table = make_wage_table(ex1, ex2, ex3)

    doc.append(table)
    doc.append("")
    doc.append(r"\clearpage")
    doc.append("")
    doc.append(wage_table)
    doc.append("")
    doc.append(r"\clearpage")
    doc.append("")

    wage_table_v2 = make_wage_table_v2(ex1, ex2, ex3)
    doc.append(wage_table_v2)
    doc.append("")
    doc.append(r"\clearpage")
    doc.append("")
    doc.append(r"\end{document}")

    content = "\n".join(doc)
    with open(output_file, "w") as f:
        f.write(content)

    print(f"Generated {output_file}")
    print("  Table 1: conn_margins (Panels A/B/C[/D] stacked × 4 outcomes)")
    print("  Table 2: conn_margins_wages (Panels A/B/C side-by-side × 2 wage outcomes)")
    print("  Table 3: conn_margins_wages_v2 (side-by-side, no F-tests, placebo at bottom)")


if __name__ == "__main__":
    main()
