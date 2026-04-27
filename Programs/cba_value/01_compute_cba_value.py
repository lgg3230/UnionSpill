#!/usr/bin/env python3
"""
Compute the wage-equivalent CBA value score for each firm-year.

The score is a weighted sum of clause-type counts, where the weights are the
wage-equivalent coefficients from clause_variables_cnes.xlsx (Unnamed: 4 column).
Only the 34 clauses with non-zero weights are included.

Output: Data/CBA_RAIS_firm_level/cba_value_firm_year.csv
  - identificad, year, cba_value
"""

from pathlib import Path
import pandas as pd
import numpy as np
import subprocess

ROOT        = Path(__file__).resolve().parent.parent.parent
rais_firm   = ROOT / "Data" / "CBA_RAIS_firm_level"
cba_dir     = ROOT / "Data" / "CBA"
out_file    = rais_firm / "cba_value_firm_year.csv"

# ── Load wage-equivalent weights ─────────────────────────────────────────────

xl  = pd.ExcelFile(cba_dir / "clause_variables_cnes.xlsx")
vdf = xl.parse("variables")
vdf.columns = ["variable", "description", "merged_cba", "var_type", "weight"]

weights = (
    vdf[vdf["weight"].notna() & (vdf["weight"] != 0)]
    .set_index("variable")["weight"]
    .to_dict()
)

print(f"Clause variables with non-zero weights: {len(weights)}")

# ── Load firm-year panel ──────────────────────────────────────────────────────

print("Loading firm-year panel …")
df = pd.read_stata(rais_firm / "lagos_sample_sep24_pct_unionexp_ext_df2.dta",
                   columns=["identificad", "year", "numb_clauses"] + list(weights.keys()))

print(f"  Loaded: {df.shape[0]:,} obs, {df.shape[1]} columns")

# ── Compute CBA value ─────────────────────────────────────────────────────────
# Fill missing clause counts with 0 (absent clause type = 0 clauses).
# Set cba_value to NaN wherever numb_clauses is missing (firm has no CBA).

cl_df = df[list(weights.keys())].fillna(0)
df["cba_value"] = (cl_df * pd.Series(weights)).sum(axis=1)
df.loc[df["numb_clauses"].isna(), "cba_value"] = np.nan

print(f"  cba_value: mean={df['cba_value'].mean():.4f}  "
      f"sd={df['cba_value'].std():.4f}  "
      f"missing={df['cba_value'].isna().sum():,}")

# ── Save ──────────────────────────────────────────────────────────────────────

out = df[["identificad", "year", "cba_value"]].copy()
out.to_csv(out_file, index=False)
print(f"Saved {len(out):,} rows → {out_file}")

# ── Notify ────────────────────────────────────────────────────────────────────

subprocess.run([
    "curl", "-s", "-o", "/dev/null",
    "-H", "Title: cba_value prep done",
    "-d", f"01_compute_cba_value.py finished. {len(out):,} rows saved.",
    "https://ntfy.sh/lgg3230-kellogg"
])
