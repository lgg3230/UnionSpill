"""
Assemble horse race table from 04a_horse_race_occ4.do output.

All four occ4 connectivity variables appear simultaneously in each regression.

Column layout (10 columns):
  Log Dec. wage:   Managers | High-skill | Bur. lower | Low-skill | Firm
  Log employment:  Managers | High-skill | Bur. lower | Low-skill | Firm

Row groups (one per regressor):
  c_lv_r × Post + SE  |  Pre + SE  |  Pre-F p-value

Output:
  output/table_horse_race_occ4.tex
  output/table_horse_race_occ4.csv

Usage:
  python scripts/04b_make_table_horse_race_occ4.py
"""

from pathlib import Path
import pandas as pd

STANDALONE = Path(__file__).resolve().parent.parent
TABLES     = STANDALONE / "output"
CSV_IN     = TABLES / "results_horse_race_occ4.csv"

LAYER_VALS = ["1_mgr", "23_high", "4_bur", "5p_low"]

LAYER_LABELS = {
    "1_mgr":   "Managers",
    "23_high": "High-skill",
    "4_bur":   r"Bur.\ lower",
    "5p_low":  "Low-skill",
}

REGRESSOR_LABELS = {
    "1_mgr":   r"$c_{\text{mgr}}$",
    "23_high": r"$c_{\text{high}}$",
    "4_bur":   r"$c_{\text{bur}}$",
    "5p_low":  r"$c_{\text{low}}$",
}


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


# Column definitions: (col_label, section, outcome_key)
WAGE_COLS = [
    (LAYER_LABELS[lv], "layer_firm_year", f"lr_remdezr_layer_{lv}")
    for lv in LAYER_VALS
] + [("Firm", "firm_firm_year", "lr_remdezr_w")]

EMP_COLS = [
    (LAYER_LABELS[lv], "layer_firm_year", f"l_layer_emp_{lv}")
    for lv in LAYER_VALS
] + [("Firm", "firm_firm_year", "l_firm_emp")]

ALL_COLS = WAGE_COLS + EMP_COLS  # 10 columns


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


def build_latex(data: dict, caption: str, label: str) -> str:
    lines = []
    ncols = len(ALL_COLS)  # 10
    n_lv  = len(LAYER_VALS)  # 4

    col_spec = "l" + "c" * ncols
    lines.append(r"\begin{table}[H]")
    lines.append(r"\centering")
    lines.append(r"\caption{" + caption + r"}")
    lines.append(r"\label{" + label + r"}")
    lines.append(r"\resizebox{\textwidth}{!}{%")
    lines.append(r"\begin{tabular}{" + col_spec + r"}")
    lines.append(r"\toprule\toprule")

    # Header row 1: outcome group spans (5 cols each)
    lines.append(
        r" & \multicolumn{5}{c}{Log Dec.\ wage}"
        r" & \multicolumn{5}{c}{Log employment} \\"
    )
    lines.append(r"\cmidrule(lr){2-6}\cmidrule(lr){7-11}")

    # Header row 2: column labels + numbers
    h2 = [""]
    for ci, (col_label, _, _) in enumerate(ALL_COLS, start=1):
        h2.append(r"\shortstack{" + col_label + r" \\ (" + str(ci) + r")}")
    lines.append(" & ".join(h2) + r" \\")
    lines.append(r"\midrule")

    # One row-group per regressor
    for lv_r in LAYER_VALS:
        reg_label = REGRESSOR_LABELS[lv_r]

        cells = [reg_label + r" $\times$ Post"]
        for _, section, outcome in ALL_COLS:
            cells.append(fmt_coef(get(data, section, outcome, f"c_{lv_r}_main")))
        lines.append(" & ".join(cells) + r" \\")

        cells = [""]
        for _, section, outcome in ALL_COLS:
            cells.append(fmt_se(get(data, section, outcome, f"c_{lv_r}_main_se")))
        lines.append(" & ".join(cells) + r" \\")

        cells = [r"Pre: " + reg_label]
        for _, section, outcome in ALL_COLS:
            cells.append(fmt_coef(get(data, section, outcome, f"c_{lv_r}_pre")))
        lines.append(" & ".join(cells) + r" \\")

        cells = [""]
        for _, section, outcome in ALL_COLS:
            cells.append(fmt_se(get(data, section, outcome, f"c_{lv_r}_pre_se")))
        lines.append(" & ".join(cells) + r" \\")

        cells = [r"Pre-F $p$: " + reg_label]
        for _, section, outcome in ALL_COLS:
            cells.append(fmt_stat(get(data, section, outcome, f"c_{lv_r}_pre_ftest"), is_pval=True))
        end = r" \\[4pt]" if lv_r != LAYER_VALS[-1] else r" \\"
        lines.append(" & ".join(cells) + end)

    lines.append(r"\midrule")

    for stat_label, rt, fmt_fn in [
        ("Observations", "n_obs",   fmt_n),
        ("Firms",        "n_firms", fmt_n),
    ]:
        cells = [stat_label]
        for _, section, outcome in ALL_COLS:
            cells.append(fmt_fn(get(data, section, outcome, rt)))
        lines.append(" & ".join(cells) + r" \\")

    lines.append(r"\midrule")
    layer_marks = [r"\checkmark"] * n_lv + ["---"] + [r"\checkmark"] * n_lv + ["---"]
    firm_marks  = ["---"] * n_lv + [r"\checkmark"] + ["---"] * n_lv + [r"\checkmark"]
    all_marks   = [r"\checkmark"] * ncols

    for row_label, marks in [
        ("Firm FE",     all_marks),
        ("Year FE",     all_marks),
        ("Layer-level", layer_marks),
        ("Firm-level",  firm_marks),
    ]:
        cells = [row_label] + marks
        lines.append(" & ".join(cells) + r" \\")

    lines.append(r"\bottomrule")
    lines.append(r"\end{tabular}}")

    lines.append(r"\begin{minipage}{\linewidth}")
    lines.append(r"\scriptsize\vspace{4pt}")
    lines.append(
        r"\textit{Notes:} This table includes all four occupation-layer connectivity variables "
        r"simultaneously in each regression. "
        r"Occupation layers follow CBO 2002 first digit: "
        r"Managers (digit~1), High-skill (digits~2--3), Bureaucrat lower (digit~4), "
        r"Low-skill (digit~5+). "
        r"Columns (1)--(4) and (6)--(9) are layer-level regressions restricted to the indicated "
        r"worker layer and absorb firm$\times$layer FE, year FE, and "
        r"industry$\times$year, microregion$\times$year, mode$\times$year FE. "
        r"Columns (5) and (10) are firm-level regressions that collapse to firm$\times$year "
        r"and absorb firm FE, year FE, and the same market-level FE. "
        r"The post-treatment indicator equals one for years $\geq 2012$ (S\'{u}mula 277 reform). "
        r"All regressions are restricted to untreated, balanced-panel firms in the Lagos sample. "
        r"Connectivity is scaled to the 90th percentile of the control sample at 2009. "
        r"Standard errors clustered at the firm level. "
        r"$^{***}p<0.01$, $^{**}p<0.05$, $^{*}p<0.10$."
    )
    lines.append(r"\end{minipage}")
    lines.append(r"\end{table}")
    return "\n".join(lines)


def build_csv(data: dict) -> pd.DataFrame:
    rows = []
    row_types = (
        [(f"c_{lv_r}_main",      "coef") for lv_r in LAYER_VALS] +
        [(f"c_{lv_r}_main_se",   "se")   for lv_r in LAYER_VALS] +
        [(f"c_{lv_r}_pre",       "coef") for lv_r in LAYER_VALS] +
        [(f"c_{lv_r}_pre_se",    "se")   for lv_r in LAYER_VALS] +
        [(f"c_{lv_r}_pre_ftest", "pval") for lv_r in LAYER_VALS] +
        [("n_obs", "stat"), ("n_firms", "stat")]
    )
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


if not CSV_IN.exists():
    raise SystemExit(
        f"ERROR: results file not found — run 04a_horse_race_occ4.do first:\n  {CSV_IN}"
    )

data = load_csv(CSV_IN)
print(f"Loaded {len(data)} entries from {CSV_IN.name}")

TABLES.mkdir(parents=True, exist_ok=True)

caption = r"Horse race: occupation-layer connectivity simultaneously (occ4)"
label   = "tab:horse_race_occ4"

tex_out = TABLES / "table_horse_race_occ4.tex"
csv_out = TABLES / "table_horse_race_occ4.csv"

tex = build_latex(data, caption, label)
tex_out.write_text(tex)
print(f"Wrote: {tex_out}")

df_out = build_csv(data)
df_out.to_csv(csv_out, index=False)
print(f"Wrote: {csv_out}")
print()
print(df_out.to_string(index=False))
