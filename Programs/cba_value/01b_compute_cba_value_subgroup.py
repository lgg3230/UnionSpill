#!/usr/bin/env python3
"""
Rebuild cba_value_firm_year.csv using subgroup-level Lagos weights.

Steps:
  1. Fill sub_group column in clause_variables_cnes.xlsx using Table A3 ID→name mapping.
  2. Map Lagos wage-equivalent values (from lagos_clause_values.csv) to each clause
     variable via its subgroup. Clauses in non-selected subgroups get weight 0.
  3. Recompute cba_value as weighted sum of clause counts and save.

Output: Data/CBA_RAIS_firm_level/cba_value_firm_year.csv
"""

from pathlib import Path
import pandas as pd
import numpy as np
import subprocess

ROOT      = Path(__file__).resolve().parent.parent.parent
rais_firm = ROOT / "Data" / "CBA_RAIS_firm_level"
cba_dir   = ROOT / "Data" / "CBA"
out_file  = rais_firm / "cba_value_firm_year.csv"

# ── Table A3: sub_group_id → subgroup name ────────────────────────────────────

SUBGROUP_NAMES = {
    0:  "void",
    11: "Wage adjustments",
    12: "Wage payment",
    13: "Other wages",
    14: "Other wage rules",
    21: "Bonuses",
    22: "Pays",
    23: "Assistances",
    24: "Other incentives",
    31: "Separations",
    32: "Contract types",
    33: "Hiring",
    34: "Other contracting",
    41: "Staffing",
    42: "Working conditions",
    43: "Employment protections",
    51: "Workday",
    61: "Injuries",
    62: "Prevention",
    71: "Vacations",
    72: "Leaves",
    73: "Other time off provisions",
    81: "Union-firm relations",
    82: "Union organization",
    91: "Bargaining",
}

# ── Load Lagos subgroup weights ───────────────────────────────────────────────

lagos = pd.read_csv(rais_firm / "lagos_clause_values.csv")
SUBGROUP_WEIGHTS = dict(zip(lagos["subgroup"], lagos["wage_equivalent_value"]))
print("Lagos subgroup weights loaded:")
for k, v in SUBGROUP_WEIGHTS.items():
    print(f"  {k}: {v}")

# ── Update Excel: fill sub_group and value columns ───────────────────────────

xl_path = cba_dir / "clause_variables_cnes.xlsx"
vdf = pd.read_excel(xl_path)

# Fill sub_group from SUBGROUP_NAMES using sub_group_id
vdf["sub_group"] = vdf["sub_group_id"].map(
    lambda x: SUBGROUP_NAMES.get(int(x), np.nan) if pd.notna(x) else np.nan
)

# Update value column: subgroup weight for each clause, 0 if subgroup not selected
vdf["value"] = vdf["sub_group"].map(
    lambda sg: SUBGROUP_WEIGHTS.get(sg, 0.0) if pd.notna(sg) else 0.0
)

# Save updated Excel
with pd.ExcelWriter(xl_path, engine="openpyxl", mode="w") as writer:
    vdf.to_excel(writer, index=False)

print(f"\nUpdated {xl_path.name}:")
print(vdf[["Variable", "sub_group_id", "sub_group", "value"]].to_string())

# ── Build weights dict from updated Excel ─────────────────────────────────────

weights = (
    vdf[vdf["value"].notna() & (vdf["value"] != 0) & vdf["Variable"].notna()]
    .set_index("Variable")["value"]
    .to_dict()
)
# Exclude non-clause rows (void, codigo_municipio)
weights = {k: v for k, v in weights.items() if str(k).startswith("cl_")}

print(f"\nClause variables with non-zero weights: {len(weights)}")
for k, v in sorted(weights.items()):
    print(f"  {k}: {v}")

# ── Load firm-year panel ──────────────────────────────────────────────────────

print("\nLoading firm-year panel …")
df = pd.read_stata(
    rais_firm / "lagos_sample_sep24_pct_unionexp_ext_df2.dta",
    columns=["identificad", "year", "numb_clauses"] + list(weights.keys())
)
print(f"  Loaded: {df.shape[0]:,} obs, {df.shape[1]} columns")

# ── Compute CBA value ─────────────────────────────────────────────────────────

cl_df = df[list(weights.keys())].fillna(0)
df["cba_value"] = (cl_df * pd.Series(weights)).sum(axis=1)
df.loc[df["numb_clauses"].isna(), "cba_value"] = np.nan

print(f"\n  cba_value: mean={df['cba_value'].mean():.4f}  "
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
    "-d", f"01b_compute_cba_value_subgroup.py finished. {len(out):,} rows saved.",
    "https://ntfy.sh/lgg3230-kellogg"
])
