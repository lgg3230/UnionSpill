"""
direct_contamination_test_table.py
Reads contamination_test.csv and writes contamination_test.tex.

Table layout (4 columns: lr_remdezr_w, lr_remdezr_h_w, l_firm_emp, numb_clauses):
  Panel A  — β4 (direct effect vs. pure controls)
  Panel B  — β5 (contamination bias)
  Implied  — β_C = β4 − β5
  Pre-trend row
  N rows
"""

from pathlib import Path
import pandas as pd

# ── Paths ─────────────────────────────────────────────────────────────────────

tables_dir   = Path(__file__).resolve().parent.parent.parent / "Tables"
pipeline_dir = tables_dir / "main_results"
csv_path     = pipeline_dir / "contamination_test.csv"
tex_path     = pipeline_dir / "contamination_test.tex"

# ── Load CSV ──────────────────────────────────────────────────────────────────

df = pd.read_csv(csv_path, sep=";", names=["outcome", "row_type", "value"],
                 header=0, skipinitialspace=True)
df["outcome"]  = df["outcome"].str.strip('"')
df["row_type"] = df["row_type"].str.strip('"')
df["value"]    = pd.to_numeric(df["value"].str.strip('"'), errors="coerce")

# Pivot to wide: index=outcome, columns=row_type
wide = df.pivot(index="outcome", columns="row_type", values="value")

OUTCOMES = ["lr_remdezr_w", "lr_remdezr_h_w", "l_firm_emp", "numb_clauses"]

# ── Formatting helpers ────────────────────────────────────────────────────────

def stars(p: float) -> str:
    if p < 0.01:
        return r"$^{***}$"
    elif p < 0.05:
        return r"$^{**}$"
    elif p < 0.10:
        return r"$^{*}$"
    return ""

def fmt_coef(outcome: str, b_col: str, p_col: str, decimals: int = 4) -> str:
    b = wide.loc[outcome, b_col]
    p = wide.loc[outcome, p_col]
    return f"{b:.{decimals}f}{stars(p)}"

def fmt_se(outcome: str, se_col: str, decimals: int = 4) -> str:
    se = wide.loc[outcome, se_col]
    return f"({se:.{decimals}f})"

def fmt_plain(outcome: str, b_col: str, decimals: int = 4) -> str:
    return f"{wide.loc[outcome, b_col]:.{decimals}f}"

def fmt_n(outcome: str, col: str) -> str:
    return f"{int(wide.loc[outcome, col]):,}"

# ── Column headers ────────────────────────────────────────────────────────────

HEADERS = {
    "lr_remdezr_w":   r"Log Dec.\ Wages",
    "lr_remdezr_h_w": r"Log Hourly Wages",
    "l_firm_emp":     r"Log Employment",
    "numb_clauses":   r"\# CBA Clauses",
}

# ── Build table ───────────────────────────────────────────────────────────────

def row(label: str, cells: list[str], end: str = r"\\") -> str:
    return label + " & " + " & ".join(cells) + f" {end}\n"

def se_row(cells: list[str], end: str = r"\\[4pt]") -> str:
    return " & " + " & ".join(cells) + f" {end}\n"

lines = []
lines.append(r"\begin{table}[H]")
lines.append(r"\scriptsize")
lines.append(r"\centering")
lines.append(r"\begin{tabular}{lcccc}")
lines.append(r"\hline\hline")

# Header rows
lines.append(row(" ", ["(1)", "(2)", "(3)", "(4)"]))
lines.append(row(" ", [HEADERS[o] for o in OUTCOMES], end=r"\\"))
lines.append(r"\hline")

# Panel A
lines.append(r"\multicolumn{5}{l}{\textit{Direct effect vs.\ pure controls "
             r"($\hat{\beta}_4 = \tau_T$)}} \\[3pt]")
lines.append(row(r"Treated $\times$ Post",
                 [fmt_coef(o, "b4", "p4") for o in OUTCOMES]))
lines.append(se_row([fmt_se(o, "se4") for o in OUTCOMES]))

# Panel B
lines.append(r"\multicolumn{5}{l}{\textit{Contamination bias "
             r"($\hat{\beta}_5 = \tau_D$)}} \\[3pt]")
lines.append(row(r"Contaminated $\times$ Post",
                 [fmt_coef(o, "b5", "p5") for o in OUTCOMES]))
lines.append(se_row([fmt_se(o, "se5") for o in OUTCOMES]))

# Implied β_C
lines.append(r"\multicolumn{5}{l}{\textit{Implied $\hat{\beta}_C = "
             r"\hat{\beta}_4 - \hat{\beta}_5$}} \\[3pt]")
lines.append(se_row([fmt_plain(o, "bc") for o in OUTCOMES], end=r"\\[4pt]"))

lines.append(r"\hline")

# Pre-trend
lines.append(row(r"Pre-trend (Treated)",
                 [fmt_coef(o, "b_pre", "p_pre") for o in OUTCOMES]))
lines.append(se_row([fmt_se(o, "se_pre") for o in OUTCOMES], end=r"\\"))

lines.append(r"\hline")

# Counts
lines.append(row("Observations",  [fmt_n(o, "n_obs")   for o in OUTCOMES], end=r"\\"))
lines.append(row("Establishments",[fmt_n(o, "n_estab") for o in OUTCOMES], end=r"\\"))

lines.append(r"\hline\hline")
lines.append(
    r"\multicolumn{5}{p{0.92\linewidth}}{\scriptsize "
    r"This table reports estimates from a three-group DiD. "
    r"The treated group ($T$) comprises firms covered by a CBA affected by "
    r"Brazil's S\'{u}mula~277 reform. Pure controls ($C$) are firms with zero "
    r"pre-treatment worker flows to treated firms. Contaminated controls ($D$) "
    r"are all remaining non-treated firms. $\hat{\beta}_4$ estimates the direct "
    r"union wage effect against the cleanest counterfactual; $\hat{\beta}_5$ "
    r"measures the spillover onto contaminated controls, which equals the "
    r"attenuation bias in $\hat{\beta}_C = \hat{\beta}_4 - \hat{\beta}_5$. "
    r"All specifications include firm, industry$\times$year, "
    r"seasonality$\times$year, and microregion$\times$year fixed effects, plus "
    r"quartile bins of pre-treatment outcome, employment, and total flows "
    r"interacted with year. \textit{\# CBA Clauses} uses CBA negotiation "
    r"periods instead of calendar years. Standard errors clustered by firm. "
    r"*** $p<0.01$, ** $p<0.05$, * $p<0.10$.}"
)
lines.append(r"\end{tabular}")
lines.append(r"\end{table}")

# ── Write ─────────────────────────────────────────────────────────────────────

tex_path.write_text("\n".join(lines) + "\n")
print(f"Written: {tex_path}")
