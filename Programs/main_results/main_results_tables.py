"""
main_results_tables.py
Produces two LaTeX tables from main_results pipeline outputs:

  1. direct_effects_table.tex  — Panels A, B, C × 4 outcomes
  2. spillover_table.tex        — Spillover effect × 4 outcomes

Sources:
  Tables/results_direct_panelA_tfpw_07_11_pct.csv  (existing)
  Tables/results_direct_panelB_tfpw_07_11_pct.csv  (existing)
  Tables/main_results/panelC.csv                    (new)
  Tables/main_results/did_spill.csv                 (from main_results.do)
  Tables/main_results/spill_numb_clauses.csv        (new)
"""

from pathlib import Path
import pandas as pd
import re

# ── Paths ─────────────────────────────────────────────────────────────────────

root         = Path(__file__).resolve().parent.parent.parent
tables_root  = root / "Tables"
pipeline_dir = tables_root / "main_results"

# ── Helpers ───────────────────────────────────────────────────────────────────

def stars(p: float) -> str:
    if p < 0.01:  return r"$^{***}$"
    if p < 0.05:  return r"$^{**}$"
    if p < 0.10:  return r"$^{*}$"
    return ""

def load_csv(path: Path) -> pd.DataFrame:
    """Load a semicolon-delimited results CSV, stripping quotes and trailing chars."""
    df = pd.read_csv(path, sep=";", header=0, skipinitialspace=True)
    for col in df.columns:
        df[col] = df[col].astype(str).str.strip().str.strip('"')
    df.columns = [c.strip() for c in df.columns]
    return df

def parse_value(s: str):
    """Strip stars/quotes and convert to float."""
    cleaned = re.sub(r'[*"]+', '', str(s)).strip()
    try:
        return float(cleaned)
    except ValueError:
        return float("nan")

def get(df: pd.DataFrame, outcome: str, row_type: str):
    mask = (df["outcome"] == outcome) & (df["row_type"] == row_type)
    rows = df[mask]
    if rows.empty:
        return float("nan")
    return parse_value(rows["value"].iloc[0])

def fmt(val, decimals: int = 4) -> str:
    if pd.isna(val):
        return "---"
    return f"{val:.{decimals}f}"

def cell(val, p_val, decimals: int = 4) -> str:
    if pd.isna(val):
        return "---"
    return fmt(val, decimals) + stars(p_val)

def se_cell(val, decimals: int = 4) -> str:
    if pd.isna(val):
        return ""
    return f"({fmt(val, decimals)})"

def n_cell(val) -> str:
    if pd.isna(val):
        return "---"
    return f"{int(val):,}"

def row(label, cells, end=r"\\") -> str:
    return label + " & " + " & ".join(cells) + f" {end}\n"

def se_row(cells, end=r"\\[4pt]") -> str:
    return " & " + " & ".join(cells) + f" {end}\n"

# ── Load data ─────────────────────────────────────────────────────────────────

dfA = load_csv(tables_root / "results_direct_panelA_tfpw_07_11_pct.csv")
dfB = load_csv(tables_root / "results_direct_panelB_tfpw_07_11_pct.csv")
dfC = load_csv(pipeline_dir / "panelC.csv")
dfS = load_csv(pipeline_dir / "did_spill.csv")
dfSN= load_csv(pipeline_dir / "spill_numb_clauses.csv")

OUTCOMES = ["lr_remdezr_w", "lr_remdezr_h_w", "l_firm_emp", "numb_clauses"]
HEADERS  = {
    "lr_remdezr_w":   r"Log Dec.\ Wages",
    "lr_remdezr_h_w": r"Log Hourly Wages",
    "l_firm_emp":     r"Log Employment",
    "numb_clauses":   r"\# CBA Clauses",
}

# ── Helper: compute p-value from coef + SE stored in same CSV ─────────────────
# (old CSVs store stars in the value string; we infer p-value direction from them
#  and use pre_pval for the pre-trend F-test)

def infer_p(val_str: str) -> float:
    """Rough p-value from stars embedded in value string (for old-format CSVs)."""
    s = str(val_str)
    if "***" in s: return 0.005
    if "**"  in s: return 0.025
    if "*"   in s: return 0.075
    return 0.5

def get_p(df, outcome, row_type):
    mask = (df["outcome"] == outcome) & (df["row_type"] == row_type)
    rows = df[mask]
    if rows.empty:
        return float("nan")
    return infer_p(rows["value"].iloc[0])

# ── TABLE 1: Direct Effects ───────────────────────────────────────────────────

lines = []
lines.append(r"\begin{table}[H]")
lines.append(r"\scriptsize")
lines.append(r"\centering")
lines.append(r"\begin{tabular}{lcccc}")
lines.append(r"\hline\hline")
lines.append(row(" ", ["(1)", "(2)", "(3)", "(4)"]))
lines.append(row(" ", [HEADERS[o] for o in OUTCOMES], end=r"\\"))
lines.append(r"\hline")

for panel_lbl, df, note in [
    ("A", dfA, r"Treated + zero-flow controls ($\mathtt{totaltreat\_pw\_n}=0$)"),
    ("B", dfB, r"Treated + low-flow controls ($\mathtt{totaltreat\_pw\_n}\leq 0.01$)"),
    ("C", dfC, r"Treated + all non-treated controls"),
]:
    lines.append(
        r"\multicolumn{5}{l}{\textit{Panel " + panel_lbl + r": " + note + r"}} \\[3pt]"
    )
    coef_cells = [cell(get(df, o, "main"), get_p(df, o, "main")) for o in OUTCOMES]
    se_cells   = [se_cell(get(df, o, "main_se")) for o in OUTCOMES]
    pre_cells  = [cell(get(df, o, "pre"),  get_p(df, o, "pre"))  for o in OUTCOMES]
    prese_cells= [se_cell(get(df, o, "pre_se")) for o in OUTCOMES]

    lines.append(row(r"Treated $\times$ Post", coef_cells))
    lines.append(se_row(se_cells))
    lines.append(row(r"Pre-trend", pre_cells))
    lines.append(se_row(prese_cells, end=r"\\[2pt]"))
    lines.append(row("Observations",  [n_cell(get(df, o, "n_obs"))   for o in OUTCOMES], end=r"\\"))
    lines.append(row("Establishments",[n_cell(get(df, o, "n_estab")) for o in OUTCOMES], end=r"\\[4pt]"))

lines.append(r"\hline\hline")
lines.append(
    r"\multicolumn{5}{p{0.92\linewidth}}{\scriptsize "
    r"This table reports DiD estimates of the direct union wage and employment effects "
    r"of Brazil's S\'{u}mula~277 reform across three control-group definitions. "
    r"Panel~A uses only firms with zero pre-treatment worker flows to treated firms; "
    r"Panel~B expands to firms with flows $\leq 1\%$ of the workforce; "
    r"Panel~C uses all non-treated firms in the Lagos sample. "
    r"All specifications include firm, industry$\times$year, seasonality$\times$year, "
    r"and microregion$\times$year fixed effects, plus quartile bins of pre-treatment "
    r"outcome, employment, and total flows interacted with year. "
    r"\textit{\# CBA Clauses} uses CBA negotiation periods instead of calendar years. "
    r"Standard errors clustered by firm. *** $p<0.01$, ** $p<0.05$, * $p<0.10$.}"
)
lines.append(r"\end{tabular}")
lines.append(r"\end{table}")

out1 = pipeline_dir / "direct_effects_table.tex"
out1.write_text("\n".join(lines) + "\n")
print(f"Written: {out1}")

# ── TABLE 2: Spillover Effects ────────────────────────────────────────────────

# Combine did_spill (wages + employment) with spill_numb_clauses
dfSC = pd.concat([dfS, dfSN], ignore_index=True)

lines2 = []
lines2.append(r"\begin{table}[H]")
lines2.append(r"\scriptsize")
lines2.append(r"\centering")
lines2.append(r"\begin{tabular}{lcccc}")
lines2.append(r"\hline\hline")
lines2.append(row(" ", ["(1)", "(2)", "(3)", "(4)"]))
lines2.append(row(" ", [HEADERS[o] for o in OUTCOMES], end=r"\\"))
lines2.append(r"\hline")

coef_cells  = [cell(get(dfSC, o, "main"), get_p(dfSC, o, "main")) for o in OUTCOMES]
se_cells    = [se_cell(get(dfSC, o, "main_se")) for o in OUTCOMES]
pre_cells   = [cell(get(dfSC, o, "pre"),  get_p(dfSC, o, "pre"))  for o in OUTCOMES]
prese_cells = [se_cell(get(dfSC, o, "pre_se")) for o in OUTCOMES]

lines2.append(row(r"Spillover $\times$ Post", coef_cells))
lines2.append(se_row(se_cells))
lines2.append(row(r"Pre-trend", pre_cells))
lines2.append(se_row(prese_cells, end=r"\\[2pt]"))
lines2.append(row("Observations",  [n_cell(get(dfSC, o, "n_obs"))   for o in OUTCOMES], end=r"\\"))
lines2.append(row("Establishments",[n_cell(get(dfSC, o, "n_estab")) for o in OUTCOMES], end=r"\\"))
lines2.append(r"\hline\hline")
lines2.append(
    r"\multicolumn{5}{p{0.92\linewidth}}{\scriptsize "
    r"This table reports DiD estimates of the spillover effect of Brazil's "
    r"S\'{u}mula~277 reform on non-union firms. The treatment variable is "
    r"pre-treatment worker flows to treated firms, normalized by the 90th percentile "
    r"of the spillover distribution. Sample: non-treated firms in the Lagos balanced "
    r"panel. All specifications include firm, industry$\times$year, "
    r"seasonality$\times$year, and microregion$\times$year fixed effects, plus "
    r"quartile bins of pre-treatment outcome, employment, and total flows interacted "
    r"with year. \textit{\# CBA Clauses} uses CBA negotiation periods instead of "
    r"calendar years. Standard errors clustered by firm. "
    r"*** $p<0.01$, ** $p<0.05$, * $p<0.10$.}"
)
lines2.append(r"\end{tabular}")
lines2.append(r"\end{table}")

out2 = pipeline_dir / "spillover_table.tex"
out2.write_text("\n".join(lines2) + "\n")
print(f"Written: {out2}")
