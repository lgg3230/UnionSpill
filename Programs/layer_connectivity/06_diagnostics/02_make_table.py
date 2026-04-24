"""
Assemble diagnostic table from 01_univariate_per_layer_occ4.do output.

Cross-firm spec run separately for each occ4 layer. Compares the sign and
magnitude of the connectivity effect across layers to diagnose whether the
negative wage effect in the pooled within-firm spec is genuine or an artifact
of the occupational wage hierarchy within firms.

Column layout (8 columns):
  Log Dec. wage:   Managers | High-skill | Bur. lower | Low-skill
  Log employment:  Managers | High-skill | Bur. lower | Low-skill

Output:
  Tables/layer_connectivity/06_diagnostics/tex_tables/table_univariate_occ4.tex
  Tables/layer_connectivity/06_diagnostics/table_univariate_occ4.csv

Usage:
  ~/.conda/envs/venv_python312/bin/python Programs/layer_connectivity/06_diagnostics/02_make_table.py
"""

from pathlib import Path
import pandas as pd

PROJ       = Path(__file__).resolve().parent.parent.parent.parent
TABLES     = PROJ / "Tables" / "layer_connectivity" / "06_diagnostics"
TEX_TABLES = TABLES / "tex_tables"
CSV_IN     = TABLES / "results_univariate_occ4.csv"

LAYER_VALS = ["1_mgr", "23_high", "4_bur", "5p_low"]
LAYER_LABELS = {
    "1_mgr":   "Managers",
    "23_high": "High-skill",
    "4_bur":   r"Bur.\ lower",
    "5p_low":  "Low-skill",
}


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
                key = (parts[1], parts[2], parts[3])  # (section, outcome_key, row_type)
                data[key] = parts[4]
    return data


# ── Column definitions ────────────────────────────────────────────────────────
# (col_label, section, outcome_key)
WAGE_COLS = [
    (LAYER_LABELS[lv], "cross_firm", f"lr_remdezr_layer_{lv}")
    for lv in LAYER_VALS
]
EMP_COLS = [
    (LAYER_LABELS[lv], "cross_firm", f"l_layer_emp_{lv}")
    for lv in LAYER_VALS
]
ALL_COLS = WAGE_COLS + EMP_COLS  # 8 columns


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
    s = v.strip()
    if s in ("--", ""):
        return "---"
    try:
        return f"{int(float(s)):,}"
    except ValueError:
        return s


# ── LaTeX builder ─────────────────────────────────────────────────────────────
def build_latex(data: dict) -> str:
    lines = []
    ncols = len(ALL_COLS)  # 8
    n_lv  = len(LAYER_VALS)  # 4

    col_spec = "l" + "c" * ncols
    lines.append(r"\begin{table}[H]")
    lines.append(r"\centering")
    lines.append(
        r"\caption{Univariate cross-firm spillover by occupation layer (diagnostic)}"
    )
    lines.append(r"\label{tab:univariate_occ4_diag}")
    lines.append(r"\resizebox{\textwidth}{!}{%")
    lines.append(r"\begin{tabular}{" + col_spec + r"}")
    lines.append(r"\toprule\toprule")

    # Header row 1: outcome group spans
    lines.append(
        r" & \multicolumn{4}{c}{Log Dec.\ wage}"
        r" & \multicolumn{4}{c}{Log employment} \\"
    )
    lines.append(r"\cmidrule(lr){2-5}\cmidrule(lr){6-9}")

    # Header row 2: layer labels + column numbers
    h2 = [""]
    for ci, (col_label, _, _) in enumerate(ALL_COLS, start=1):
        h2.append(r"\shortstack{" + col_label + r" \\ (" + str(ci) + r")}")
    lines.append(" & ".join(h2) + r" \\")
    lines.append(r"\midrule")

    # Connectivity × Post
    cells = [r"Connectivity $\times$ Post"]
    for _, section, outcome in ALL_COLS:
        cells.append(fmt_coef(get(data, section, outcome, "main")))
    lines.append(" & ".join(cells) + r" \\")

    cells = [""]
    for _, section, outcome in ALL_COLS:
        cells.append(fmt_se(get(data, section, outcome, "main_se")))
    lines.append(" & ".join(cells) + r" \\")

    # Pre-trend placebo
    cells = [r"Pre-trend (placebo)"]
    for _, section, outcome in ALL_COLS:
        cells.append(fmt_coef(get(data, section, outcome, "pre")))
    lines.append(" & ".join(cells) + r" \\")

    cells = [""]
    for _, section, outcome in ALL_COLS:
        cells.append(fmt_se(get(data, section, outcome, "pre_se")))
    lines.append(" & ".join(cells) + r" \\")

    lines.append(r"\midrule")

    # Stats
    for stat_label, rt, fmt_fn in [
        ("Observations",            "n_obs",    fmt_n),
        ("Firms",                   "n_firms",  fmt_n),
        (r"Pre-F $p$-value",        "pre_pval", lambda v: fmt_stat(v, is_pval=True)),
    ]:
        cells = [stat_label]
        for _, section, outcome in ALL_COLS:
            cells.append(fmt_fn(get(data, section, outcome, rt)))
        lines.append(" & ".join(cells) + r" \\")

    lines.append(r"\bottomrule")
    lines.append(r"\end{tabular}}")

    # Notes
    lines.append(r"\begin{minipage}{\linewidth}")
    lines.append(r"\scriptsize\vspace{4pt}")
    lines.append(
        r"\textit{Notes:} Diagnostic table for the occ4 spillover exercise. "
        r"Each column runs a separate cross-firm DiD regression restricted to the indicated "
        r"occupation layer, using only that layer's firm-year observations. "
        r"This eliminates the within-firm cross-occupation comparison present in the pooled "
        r"within-firm specification and identifies spillover effects purely from cross-firm "
        r"variation in connectivity. "
        r"Occupation layers follow CBO 2002 first digit: "
        r"Managers (digit~1), High-skill (digits~2--3), Bureaucrat lower (digit~4), "
        r"Low-skill (digit~5+). "
        r"Fixed effects: firm FE, year FE, microregion$\times$year, industry$\times$year, "
        r"mode$\times$year. "
        r"Connectivity is scaled to the 90th percentile of that layer's control firms at 2009. "
        r"All regressions restricted to untreated, balanced-panel firms in the Lagos sample. "
        r"Standard errors clustered at the firm level. "
        r"$^{***}p<0.01$, $^{**}p<0.05$, $^{*}p<0.10$."
    )
    lines.append(r"\end{minipage}")
    lines.append(r"\end{table}")
    return "\n".join(lines)


# ── CSV builder ───────────────────────────────────────────────────────────────
def build_csv(data: dict) -> pd.DataFrame:
    rows = []
    for rt in ["main", "main_se", "pre", "pre_se", "n_obs", "n_firms", "pre_pval"]:
        for col_label, section, outcome in ALL_COLS:
            rows.append({
                "outcome":   outcome,
                "col_label": col_label,
                "section":   section,
                "row_type":  rt,
                "value":     get(data, section, outcome, rt),
            })
    return pd.DataFrame(rows)


# ── Main ──────────────────────────────────────────────────────────────────────
if not CSV_IN.exists():
    raise SystemExit(
        f"ERROR: results file not found — run 01_univariate_per_layer_occ4.do first:\n  {CSV_IN}"
    )

data = load_csv(CSV_IN)
print(f"Loaded {len(data)} entries from {CSV_IN.name}")

TABLES.mkdir(parents=True, exist_ok=True)
TEX_TABLES.mkdir(parents=True, exist_ok=True)

tex_out = TEX_TABLES / "table_univariate_occ4.tex"
csv_out = TABLES     / "table_univariate_occ4.csv"

tex_out.write_text(build_latex(data))
print(f"Wrote: {tex_out}")

df_out = build_csv(data)
df_out.to_csv(csv_out, index=False)
print(f"Wrote: {csv_out}")
print()
print(df_out[df_out["row_type"].isin(["main","pre","pre_pval"])].to_string(index=False))
