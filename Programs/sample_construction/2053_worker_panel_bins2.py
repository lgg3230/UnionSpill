"""
011e_worker_panel_bins2.py
==========================
Appends three additional columns to worker_panel_lagos.parquet needed to
complete the Mincer wage-residualization specification:

  - d_male     : 1 = male    (from genero)
  - d_disabled : 1 = declared disability  (from portdefic)
  - hours_ge40 : 1 = contracted hours >= 40  (from horascontr)

All three interact with year as fixed effects in the residualization:
  | d_male^year + d_disabled^year + hours_ge40^year + ...

Input / output
--------------
Data/CBA_RAIS_firm_level/worker_panel_lagos.parquet  (overwritten in place)
"""

import os
import pandas as pd
import numpy as np

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
PROJECT = "/kellogg/proj/lgg3230/UnionSpill"
PARQUET  = os.path.join(PROJECT, "Data/CBA_RAIS_firm_level/worker_panel_lagos.parquet")

# ---------------------------------------------------------------------------
# Load
# ---------------------------------------------------------------------------
print(f"Reading {PARQUET} ...")
df = pd.read_parquet(PARQUET)
print(f"  Rows: {len(df):,}  Columns: {df.shape[1]}")

# ---------------------------------------------------------------------------
# Gap 1: Gender  (genero: 1 = male, 0 = female)
# ---------------------------------------------------------------------------
df["d_male"] = (df["genero"] == 1).astype("int8")
null_rate = df["d_male"].isna().mean() * 100
print(f"\nd_male value_counts:\n{df['d_male'].value_counts(dropna=False).sort_index()}")
print(f"d_male null rate: {null_rate:.2f}%")

# Sanity: share of males should be ~68% in the Lagos RAIS sample
share_male = df["d_male"].mean() * 100
print(f"Share male: {share_male:.1f}%")

# ---------------------------------------------------------------------------
# Gap 2: Hours  (horascontr: contracted weekly hours)
#   hours_ge40 = 1 if >= 40 h/week  (full-time+ group: 44h + 40h = ~82%)
# ---------------------------------------------------------------------------
df["hours_ge40"] = (df["horascontr"] >= 40).astype("int8")
null_rate = df["hours_ge40"].isna().mean() * 100
print(f"\nhours_ge40 value_counts:\n{df['hours_ge40'].value_counts(dropna=False).sort_index()}")
print(f"hours_ge40 null rate: {null_rate:.2f}%")

# Distribution of contracted hours (top values for audit)
print("\nTop contracted-hours values:")
print(df["horascontr"].value_counts(dropna=False).head(10))

share_ge40 = df["hours_ge40"].mean() * 100
print(f"Share hours >= 40: {share_ge40:.1f}%  (expected ~82%)")

# ---------------------------------------------------------------------------
# Gap 3: Disability  (tpdefic: type of disability)
#   portdefic is NOT used — its coding flipped between years:
#     2009-2010: portdefic=1 = no disability (original RAIS code 1=none)
#     2011-2016: portdefic=0 = no disability (rebased coding)
#   tpdefic is consistent across all years:
#     0 = no disability type, 1-6 = physical/hearing/visual/mental/rehab/other
# ---------------------------------------------------------------------------
df["d_disabled"] = (df["tpdefic"] > 0).astype("int8")
null_rate = df["d_disabled"].isna().mean() * 100
print(f"\nd_disabled value_counts:\n{df['d_disabled'].value_counts(dropna=False).sort_index()}")
print(f"d_disabled null rate: {null_rate:.2f}%")

share_disabled = df["d_disabled"].mean() * 100
print(f"Share disabled: {share_disabled:.1f}%  (expected ~2-5%)")

# ---------------------------------------------------------------------------
# Save (overwrite in place)
# ---------------------------------------------------------------------------
print(f"\nSaving to {PARQUET} ...")
df.to_parquet(PARQUET, index=False, engine="pyarrow")
print(f"Done. File size: {os.path.getsize(PARQUET) / 1e9:.2f} GB")
print(f"Total columns: {df.shape[1]}")
print(f"\nNew columns added: d_male, hours_ge40, d_disabled")
print("\nFull specification for Mincer residualization (pyfixest):")
print("""
pf.feols(
    "lr_remdezr ~ 1 "
    "| educ_bin^year + race_group^year + age_bin^year + tenure_bin^year "
    "+ d_male^year + hours_ge40^year + d_disabled^year "
    "+ d_rural^year + d_apprentice^year + d_fixed_term^year "
    "+ d_public^year + d_other_contract^year "
    "+ ocup4^year",
    data=df,
)
""")
