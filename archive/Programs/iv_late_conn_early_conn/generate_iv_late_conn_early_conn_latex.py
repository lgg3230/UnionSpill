#!/usr/bin/env python3
"""
Generate publication-ready LaTeX tables for the IV exercise:
  late pre-treatment connectivity (2009-10 + 2010-11) instrumented by
  early pre-treatment connectivity (2007-08 + 2008-09).

Two tables:
  Table 1 — Spillover effects: IV and OLS side-by-side (paired columns per outcome)
  Table 2 — First stage: coefficient, SE, KP F-stat, N in one row

Output: Tables/iv_late_conn_early_conn/iv_late_conn_early_conn_tables.tex
"""

import re
import math
from pathlib import Path

# ── Paths ─────────────────────────────────────────────────────────────────────

script_dir   = Path(__file__).resolve().parent
tables_dir   = script_dir.parent.parent / "Tables"
pipeline_dir = tables_dir / "iv_late_conn_early_conn"
output_file  = pipeline_dir / "iv_late_conn_early_conn_tables.tex"

SPILL_CSV = pipeline_dir / "results_iv_spillover.csv"
FS_CSV    = pipeline_dir / "results_iv_firststage.csv"

OUTCOMES = ["lr_remdezr_w", "lr_remdezr_h_w", "l_firm_emp"]
COL_LABELS = [
    r"Log \\ Wages",
    r"Log Hourly \\ Wages",
    r"Log \\ Employment",
]

# ── CSV parsers ───────────────────────────────────────────────────────────────

def load_spill_csv(filepath):
    """outcome;row_type;value  →  {outcome_key: {row_type: raw}}"""
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
            if len(parts) < 3:
                continue
            key, row_type, value = parts[0], parts[1], parts[2]
            data.setdefault(key, {})[row_type] = value.strip()
    return data


def load_fs_csv(filepath):
    """statistic;value  →  {statistic: raw}"""
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
            if len(parts) >= 2:
                data[parts[0]] = parts[1].strip()
    return data

# ── Formatting ────────────────────────────────────────────────────────────────

def _fix_sign(s):
    """Replace leading minus with LaTeX minus."""
    return r"$-$" + s[1:] if s.startswith("-") else s


def fmt_coef(raw):
    """Format coefficient: extract number and stars."""
    raw = (raw or "").strip()
    if raw in ("", "--"):
        return "--"
    m = re.match(r"^([^*]+?)(\*{1,3})?$", raw)
    if not m:
        return raw
    num, stars = m.group(1).strip(), m.group(2) or ""
    return _fix_sign(num) + stars


def fmt_se(raw):
    """Format standard error in parentheses."""
    raw = (raw or "").strip()
    if raw in ("", "--"):
        return "--"
    m = re.match(r"^([^*]+?)(\*{1,3})?$", raw)
    if not m:
        return raw
    num = m.group(1).strip()
    return "(" + _fix_sign(num) + ")"


def fmt_count(raw):
    raw = (raw or "").strip()
    if raw in ("", "--"):
        return "--"
    return raw.replace(",", "{,}")


def fmt_stat(raw):
    """Plain float for F-stat, etc."""
    raw = (raw or "").strip()
    if raw in ("", "--"):
        return "--"
    return _fix_sign(raw)


def stars_from_tstat(coef_raw, se_raw):
    """Compute significance stars from coef and SE strings."""
    try:
        coef = float(re.sub(r"\*+", "", coef_raw or "").strip())
        se   = float(re.sub(r"\*+", "", se_raw  or "").strip())
        t    = abs(coef / se)
        if t > 2.576:  return "***"
        if t > 1.960:  return "**"
        if t > 1.645:  return "*"
    except (ValueError, ZeroDivisionError):
        pass
    return ""


def get(data, key, row_type, fmt_fn=fmt_coef):
    try:
        return fmt_fn(data[key][row_type])
    except KeyError:
        return "--"

# ── LaTeX boilerplate ─────────────────────────────────────────────────────────

def hdr(text):
    return r"\begin{tabular}[c]{@{}c@{}}" + text + r"\end{tabular}"


def multicol(n_cols, align, text):
    return rf"\multicolumn{{{n_cols}}}{{{align}}}{{{text}}}"


def cmidrule(lo, hi):
    return rf"\cmidrule(lr){{{lo}-{hi}}}"

# ── Notes ─────────────────────────────────────────────────────────────────────

_CONTROLS = (
    r"All regressions include establishment fixed effects, year fixed effects "
    r"interacted with two-digit industry, microregion, and negotiation-month "
    r"indicators, and quartile-bin controls for pre-treatment per-worker "
    r"pairwise worker flows (2007--2011) and pre-treatment establishment size, "
    r"interacted with year fixed effects."
)

_NOTES_MAIN = (
    r"This table presents spillover effects of the ultractivity reform on control "
    r"establishments using \textit{late} pre-treatment connectivity "
    r"(average per-worker flow share to treated firms across year-pairs 2009--10 "
    r"and 2010--11), instrumented by \textit{early} pre-treatment connectivity "
    r"(year-pairs 2007--08 and 2008--09). "
    r"Both connectivity measures are normalized so that a value of 1 corresponds "
    r"to the 90th percentile of the spillover sample distribution. "
    r"Post $\times$ Connectivity measures the differential effect in years "
    r"2012--2016 for establishments at the 90th percentile of connectivity "
    r"relative to those with zero connectivity. Pre-treatment tests for "
    r"differential pre-trends (2009--2011). "
    + _CONTROLS + r" "
    r"Standard errors clustered at the establishment level are in parentheses. "
    r"* $p<0.10$, ** $p<0.05$, *** $p<0.01$."
)

_NOTES_FS = (
    r"This table reports first-stage results for the instrumental variables "
    r"specification. The endogenous regressor is late pre-treatment connectivity "
    r"(year-pairs 2009--10 and 2010--11) interacted with the post-treatment "
    r"indicator; the instrument is the analogous interaction with early "
    r"pre-treatment connectivity (year-pairs 2007--08 and 2008--09). "
    r"The first-stage coefficient and standard error are obtained from a direct "
    r"estimation of the first stage using \texttt{reghdfe} with establishment "
    r"fixed effects and controls for industry, microregion, negotiation month, "
    r"pre-treatment outcomes, and per-worker pairwise flows (all interacted with "
    r"year indicators). Standard errors are clustered at the establishment level. "
    r"The Kleibergen--Paap rk Wald F-statistic assesses instrument strength under "
    r"heteroskedasticity and clustering. "
    r"* $p<0.10$, ** $p<0.05$, *** $p<0.01$."
)

# ── Table 1: OLS and IV side-by-side ─────────────────────────────────────────

def make_main_table(data):
    n = len(OUTCOMES)
    n_cols = 2 * n  # IV + OLS per outcome

    # Column spec: l  cc  @{hskip}  cc  @{hskip}  cc
    col_spec = "l" + ("cc@{\\hskip 0.8cm}" * (n - 1)) + "cc"

    lines = []
    lines.append(r"\begin{table}[H]")
    lines.append(r"\centering")
    lines.append(r"\caption{Spillover Effects (IV and OLS)}")
    lines.append(r"\label{tab:spill_iv_ols_late_early}")
    lines.append(r"\footnotesize")
    lines.append(r"\begin{threeparttable}")
    lines.append(rf"\begin{{tabular}}{{{col_spec}}}")
    lines.append(r"\toprule\toprule")

    # Multi-column outcome headers
    hdr_parts = []
    cmidrule_parts = []
    col_idx = 2
    for label in COL_LABELS:
        hdr_parts.append(multicol(2, "c", hdr(label)))
        cmidrule_parts.append(cmidrule(col_idx, col_idx + 1))
        col_idx += 2
    lines.append("& " + "& ".join(hdr_parts) + r" \\")
    lines.append(" ".join(cmidrule_parts))

    # IV / OLS sub-headers
    sub = "& " + "& ".join("IV & OLS" for _ in OUTCOMES) + r" \\"
    lines.append(sub)

    # Column numbers
    nums = "& " + "& ".join(
        f"({2*i+1}) & ({2*i+2})" for i in range(n)
    ) + r" \\"
    lines.append(nums)
    lines.append(r"\midrule")

    blank = "&" * (n_cols + 1) + r"\\"

    # Post × Connectivity row
    row = r"Post $\times$ Connectivity"
    for o in OUTCOMES:
        row += " & " + get(data, f"{o}_iv", "main")
        row += " & " + get(data, f"{o}_ols", "main")
    lines.append(row + r" \\")

    # SE row
    row = ""
    for o in OUTCOMES:
        row += " & " + get(data, f"{o}_iv", "main_se", fmt_fn=fmt_se)
        row += " & " + get(data, f"{o}_ols", "main_se", fmt_fn=fmt_se)
    lines.append(row + r" \\")
    lines.append(blank)

    # Pre-treatment row
    row = r"Pre-treatment"
    for o in OUTCOMES:
        row += " & " + get(data, f"{o}_iv", "pre")
        row += " & " + get(data, f"{o}_ols", "pre")
    lines.append(row + r" \\")

    # Pre SE row
    row = ""
    for o in OUTCOMES:
        row += " & " + get(data, f"{o}_iv", "pre_se", fmt_fn=fmt_se)
        row += " & " + get(data, f"{o}_ols", "pre_se", fmt_fn=fmt_se)
    lines.append(row + r" \\")
    lines.append(blank)

    # Observations
    row = "Observations"
    for o in OUTCOMES:
        row += " & " + get(data, f"{o}_iv", "n_obs",   fmt_fn=fmt_count)
        row += " & " + get(data, f"{o}_ols", "n_obs",  fmt_fn=fmt_count)
    lines.append(row + r" \\")

    # Establishments
    row = "Establishments"
    for o in OUTCOMES:
        row += " & " + get(data, f"{o}_iv", "n_estab",  fmt_fn=fmt_count)
        row += " & " + get(data, f"{o}_ols", "n_estab", fmt_fn=fmt_count)
    lines.append(row + r" \\")

    lines.append(r"\bottomrule")
    lines.append(r"\end{tabular}")
    lines.append(r"\scriptsize")
    lines.append(r"\begin{tablenotes}")
    lines.append(r"\item \textit{Notes:} " + _NOTES_MAIN)
    lines.append(r"\end{tablenotes}")
    lines.append(r"\end{threeparttable}")
    lines.append(r"\end{table}")

    return "\n".join(lines)

# ── Table 2: First stage ──────────────────────────────────────────────────────

def make_fs_table(fs):
    fs_coef_raw = fs.get("fs_coef", "")
    fs_se_raw   = fs.get("fs_se",   "")
    kp_f_raw    = fs.get("kp_F",    "")
    n_obs_raw   = fs.get("n_obs",   "")
    n_clust_raw = fs.get("n_clust", "")

    # Compute stars for first-stage coefficient
    stars = stars_from_tstat(fs_coef_raw, fs_se_raw)
    coef_cell = _fix_sign(fs_coef_raw.strip()) + stars if fs_coef_raw else "--"
    se_cell   = fmt_se(fs_se_raw)

    lines = []
    lines.append(r"\begin{table}[!htbp]")
    lines.append(r"\centering")
    lines.append(r"\caption{First Stage: Instrument Strength}")
    lines.append(r"\label{tab:iv_firststage_late_early}")
    lines.append(r"\footnotesize")
    lines.append(r"\begin{threeparttable}")
    lines.append(r"\begin{tabular}{lcccc}")
    lines.append(r"\toprule\toprule")

    lines.append(
        r"& " + hdr(r"First-Stage\\Coefficient")
        + r"& " + hdr(r"Std.\\Error")
        + r"& " + hdr(r"KP rk Wald\\F-statistic")
        + r"& " + hdr(r"Observations")
        + r" \\"
    )
    lines.append(r"\midrule")

    instr_label = hdr(r"Early Connectivity\\(Instrument)")
    data_row = (
        instr_label
        + " & " + coef_cell
        + " & " + se_cell
        + " & " + fmt_stat(kp_f_raw)
        + " & " + fmt_count(n_obs_raw)
        + r" \\"
    )
    lines.append(data_row)

    lines.append(r"\bottomrule")
    lines.append(r"\end{tabular}")
    lines.append(r"\scriptsize")
    lines.append(r"\begin{tablenotes}")
    lines.append(r"\item \textit{Notes:} " + _NOTES_FS)
    lines.append(r"\end{tablenotes}")
    lines.append(r"\end{threeparttable}")
    lines.append(r"\end{table}")

    return "\n".join(lines)

# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    data = load_spill_csv(SPILL_CSV)
    fs   = load_fs_csv(FS_CSV)

    doc = [
        r"\documentclass[12pt,letterpaper]{article}",
        r"",
        r"\usepackage[margin=1in]{geometry}",
        r"\usepackage{booktabs}",
        r"\usepackage{threeparttable}",
        r"\usepackage{amsmath}",
        r"\usepackage{amssymb}",
        r"\usepackage{hyperref}",
        r"\usepackage{float}",
        r"",
        r"\hypersetup{colorlinks=true,linkcolor=blue,citecolor=blue,urlcolor=blue}",
        r"",
        r"\begin{document}",
        r"",
        make_main_table(data),
        r"",
        r"\clearpage",
        r"",
        make_fs_table(fs),
        r"",
        r"\end{document}",
    ]

    pipeline_dir.mkdir(parents=True, exist_ok=True)
    output_file.write_text("\n".join(doc))
    print(f"Generated {output_file}")


if __name__ == "__main__":
    main()
