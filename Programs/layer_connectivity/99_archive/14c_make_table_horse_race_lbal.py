"""
Assemble horse race table from 13c_horse_race_edu2_lbal.do output.
Layer-balanced panel: firms must have positive employment in BOTH layers
in ALL years 2009–2016.

Both c_no_hs and c_has_hs appear simultaneously in each regression.

Column layout (6 columns):
  Log Dec. wage:   no_hs layer | has_hs layer | firm-level
  Log employment:  no_hs layer | has_hs layer | firm-level

Rows:
  c_no_hs × Post     + SE
  c_has_hs × Post    + SE
  Pre: c_no_hs       + SE
  Pre: c_has_hs      + SE
  Observations
  Firms
  Pre-F: c_no_hs
  Pre-F: c_has_hs

Output:
  Tables/layer_connectivity/table_horse_race_edu2_lbal.tex / .csv

Usage:
  ~/.conda/envs/venv_python312/bin/python Programs/layer_connectivity/14c_make_table_horse_race_lbal.py
"""

from pathlib import Path
import pandas as pd

PROJ   = Path(__file__).resolve().parent.parent.parent
TABLES = PROJ / "Tables" / "layer_connectivity"
TEX_TABLES = TABLES / "tex_tables"
CSV_IN = TABLES / "results_horse_race_edu2_lbal.csv"

# ── CSV loader ────────────────────────────────────────────────────────────────
def load_csv(path: Path) -> dict:
    data = {}
    with open(path) as f:
        for i, line in enumerate(f):
            line = line.rstrip("\n")
            if i == 0:
                continue
            parts = [p.strip('"') for p in line.split(";")]
            if len(parts) >= 5:
                key = (parts[1], parts[2], parts[3])  # (section, outcome, row_type)
                data[key] = parts[4]
    return data

# ── Column definitions ────────────────────────────────────────────────────────
# (col_label, section, outcome_key)
WAGE_COLS = [
    ("No HS",  "layer_firm_year", "lr_remdezr_layer_no_hs"),
    ("Has HS", "layer_firm_year", "lr_remdezr_layer_has_hs"),
    ("Firm",   "firm_firm_year",  "lr_remdezr_w"),
]
EMP_COLS = [
    ("No HS",  "layer_firm_year", "l_layer_emp_no_hs"),
    ("Has HS", "layer_firm_year", "l_layer_emp_has_hs"),
    ("Firm",   "firm_firm_year",  "l_firm_emp"),
]
ALL_COLS = WAGE_COLS + EMP_COLS  # 6 columns total

# ── Formatting ────────────────────────────────────────────────────────────────
def get(data, section, outcome, row_type, default="--"):
    return data.get((section, outcome, row_type), default)

def fmt_coef(v: str) -> str:
    return v.strip() if v.strip() not in ("--", "") else "--"

def fmt_se(v: str) -> str:
    s = v.strip()
    if s in ("--", ""):
        return "--"
    try:
        return f"({float(s):.4f})"
    except ValueError:
        return s

def fmt_stat(v: str, is_pval: bool = False) -> str:
    s = v.strip()
    if s in ("--", ""):
        return "---"
    if is_pval:
        try:
            return f"{float(s):.3f}"
        except ValueError:
            return s
    return s

def fmt_n(v: str) -> str:
    """Format observation counts with comma separators."""
    s = v.strip()
    if s in ("--", ""):
        return "---"
    try:
        return f"{int(float(s)):,}"
    except ValueError:
        return s

# ── LaTeX builder ─────────────────────────────────────────────────────────────
def build_latex(data: dict, caption: str, label: str) -> str:
    lines = []
    ncols = len(ALL_COLS)  # 6

    col_spec = "l" + "c" * ncols
    lines.append(r"\begin{table}[H]")
    lines.append(r"\centering")
    lines.append(r"\caption{" + caption + r"}")
    lines.append(r"\label{" + label + r"}")
    lines.append(r"\resizebox{\textwidth}{!}{%")
    lines.append(r"\begin{tabular}{" + col_spec + r"}")
    lines.append(r"\toprule\toprule")

    # Header row 1: outcome group spans
    lines.append(
        r" & \multicolumn{3}{c}{Log Dec.\ wage} & \multicolumn{3}{c}{Log employment} \\"
    )
    lines.append(r"\cmidrule(lr){2-4}\cmidrule(lr){5-7}")

    # Header row 2: column labels + numbers
    h2 = [""]
    for ci, (col_label, _, _) in enumerate(ALL_COLS, start=1):
        h2.append(r"\shortstack{" + col_label + r" \\ (" + str(ci) + r")}")
    lines.append(" & ".join(h2) + r" \\")
    lines.append(r"\midrule")

    def two_rows(label_no, label_has, rt_no_coef, rt_no_se, rt_has_coef, rt_has_se):
        """Emit coef+se for c_no_hs, then coef+se for c_has_hs."""
        result = []
        # c_no_hs coef
        cells = [label_no]
        for _, section, outcome in ALL_COLS:
            cells.append(fmt_coef(get(data, section, outcome, rt_no_coef)))
        result.append(" & ".join(cells) + r" \\")
        # c_no_hs SE
        cells = [""]
        for _, section, outcome in ALL_COLS:
            cells.append(fmt_se(get(data, section, outcome, rt_no_se)))
        result.append(" & ".join(cells) + r" \\")
        # c_has_hs coef
        cells = [label_has]
        for _, section, outcome in ALL_COLS:
            cells.append(fmt_coef(get(data, section, outcome, rt_has_coef)))
        result.append(" & ".join(cells) + r" \\")
        # c_has_hs SE
        cells = [""]
        for _, section, outcome in ALL_COLS:
            cells.append(fmt_se(get(data, section, outcome, rt_has_se)))
        result.append(" & ".join(cells) + r" \\")
        return result

    # Main coefficients
    lines += two_rows(
        r"$c_{\text{no\_hs}} \times \text{Post}$",
        r"$c_{\text{has\_hs}} \times \text{Post}$",
        "c_no_hs_main", "c_no_hs_main_se",
        "c_has_hs_main", "c_has_hs_main_se",
    )

    # Pre-trend placebo
    lines += two_rows(
        r"Pre: $c_{\text{no\_hs}}$",
        r"Pre: $c_{\text{has\_hs}}$",
        "c_no_hs_pre", "c_no_hs_pre_se",
        "c_has_hs_pre", "c_has_hs_pre_se",
    )

    # Stats rows
    for stat_label, rt, fmt_fn in [
        ("Observations",               "n_obs",              fmt_n),
        ("Firms",                      "n_firms",            fmt_n),
        ("Pre-F $p$: $c_{\\text{no\\_hs}}$",  "c_no_hs_pre_ftest",  lambda v: fmt_stat(v, is_pval=True)),
        ("Pre-F $p$: $c_{\\text{has\\_hs}}$", "c_has_hs_pre_ftest", lambda v: fmt_stat(v, is_pval=True)),
    ]:
        cells = [stat_label]
        for _, section, outcome in ALL_COLS:
            cells.append(fmt_fn(get(data, section, outcome, rt)))
        lines.append(" & ".join(cells) + r" \\")

    # Spec rows
    lines.append(r"\midrule")
    checkmarks_layer = [r"\checkmark", r"\checkmark", "---", r"\checkmark", r"\checkmark", "---"]
    checkmarks_firm  = ["---", "---", r"\checkmark", "---", "---", r"\checkmark"]
    checkmarks_all   = [r"\checkmark"] * 6

    for row_label, marks in [
        ("Firm FE",          checkmarks_all),
        ("Year FE",          checkmarks_all),
        ("Layer-level",      checkmarks_layer),
        ("Firm-level",       checkmarks_firm),
    ]:
        cells = [row_label] + marks
        lines.append(" & ".join(cells) + r" \\")

    lines.append(r"\bottomrule")
    lines.append(r"\end{tabular}}")

    # Notes
    lines.append(r"\begin{minipage}{\linewidth}")
    lines.append(r"\scriptsize\vspace{4pt}")
    lines.append(
        r"\textit{Notes:} This table includes both education layer connectivity variables "
        r"($c_{\text{no\_hs}}$ and $c_{\text{has\_hs}}$) simultaneously in each regression. "
        r"Columns (1)--(2) and (4)--(5) are layer-level regressions restricted to the indicated "
        r"worker layer and absorb firm$\times$layer FE and year FE. "
        r"Columns (3) and (6) are firm-level regressions that collapse to firm$\times$year "
        r"and absorb firm FE and year FE. "
        r"The post-treatment indicator equals one for years $\geq 2012$ (S\'{u}mula 277 reform). "
        r"All regressions are restricted to untreated, balanced-panel firms. "
        r"All firms must have positive employment in both education layers in every year 2009--2016 "
        r"(layer-balanced panel). "
        r"Connectivity is scaled to the 90th percentile of the control sample at 2009. "
        r"Standard errors clustered at the firm level. "
        r"$^{***}p<0.01$, $^{**}p<0.05$, $^{*}p<0.10$."
    )
    lines.append(r"\end{minipage}")
    lines.append(r"\end{table}")
    return "\n".join(lines)


# ── CSV builder ───────────────────────────────────────────────────────────────
def build_csv(data: dict) -> pd.DataFrame:
    rows = []
    row_types = [
        ("c_no_hs_main",       "coef"),
        ("c_no_hs_main_se",    "se"),
        ("c_has_hs_main",      "coef"),
        ("c_has_hs_main_se",   "se"),
        ("c_no_hs_pre",        "coef"),
        ("c_no_hs_pre_se",     "se"),
        ("c_has_hs_pre",       "coef"),
        ("c_has_hs_pre_se",    "se"),
        ("c_no_hs_pre_ftest",  "pval"),
        ("c_has_hs_pre_ftest", "pval"),
        ("n_obs",              "stat"),
        ("n_firms",            "stat"),
    ]
    for rt, rt_type in row_types:
        for col_label, section, outcome in ALL_COLS:
            rows.append({
                "outcome":    outcome,
                "col_label":  col_label,
                "section":    section,
                "row_type":   rt,
                "value_type": rt_type,
                "value":      get(data, section, outcome, rt),
            })
    return pd.DataFrame(rows)


# ── Main ──────────────────────────────────────────────────────────────────────
if not CSV_IN.exists():
    raise SystemExit(f"ERROR: results file not found — run 13c_horse_race_edu2_lbal.do first:\n  {CSV_IN}")

data = load_csv(CSV_IN)
print(f"Loaded {len(data)} entries from {CSV_IN.name}")

TABLES.mkdir(parents=True, exist_ok=True)

caption = r"Horse race: $c_{\text{no\_hs}}$ vs.\ $c_{\text{has\_hs}}$ simultaneously (layer-balanced panel)"
label   = "tab:horse_race_edu2_lbal"

tex_out = TEX_TABLES / "table_horse_race_edu2_lbal.tex"
csv_out = TABLES / "table_horse_race_edu2_lbal.csv"

tex = build_latex(data, caption, label)
tex_out.write_text(tex)
print(f"Wrote: {tex_out}")

df_out = build_csv(data)
df_out.to_csv(csv_out, index=False)
print(f"Wrote: {csv_out}")
print()
print(df_out.to_string(index=False))
