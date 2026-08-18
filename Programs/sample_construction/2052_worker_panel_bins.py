"""
011d_worker_panel_bins.py
=========================
Adds derived categorical variables to worker_panel_lagos.parquet for use
in Mincer-type wage regressions:

  - educ_bin        : education tier (0_no_hs / 1_hs / 2_higher)
  - race_group      : race / colour category
  - age             : computed age (unified from idade / dtnascimento)
  - age_bin         : age bracket
  - tenure_bin      : tenure bracket (from tempempr in months)
  - d_rural         : tpvinculo dummy
  - d_apprentice    : tpvinculo dummy
  - d_fixed_term    : tpvinculo dummy
  - d_public        : tpvinculo dummy
  - d_other_contract: tpvinculo dummy
  - ocup4           : 4-digit occupation (ocup2002 // 100)

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
PARQUET = os.path.join(PROJECT, "Data/CBA_RAIS_firm_level/worker_panel_lagos.parquet")

# ---------------------------------------------------------------------------
# Load
# ---------------------------------------------------------------------------
print(f"Reading {PARQUET} ...")
df = pd.read_parquet(PARQUET)
print(f"  Rows: {len(df):,}  Columns: {df.shape[1]}")

# ---------------------------------------------------------------------------
# Education bin  (from grinstrucao)
#   0_no_hs  : codes 1–6
#   1_hs     : codes 7–8
#   2_higher : codes 9–11
# ---------------------------------------------------------------------------
df["educ_bin"] = pd.cut(
    df["grinstrucao"],
    bins=[0, 6, 8, 11],
    labels=["0_no_hs", "1_hs", "2_higher"],
    right=True,
)
print(f"\neduc_bin value_counts:\n{df['educ_bin'].value_counts(dropna=False).sort_index()}")
null_rate = df["educ_bin"].isna().mean() * 100
print(f"educ_bin null rate: {null_rate:.2f}%")

# ---------------------------------------------------------------------------
# Race group  (from raca_cor)
#   branca        : 2
#   parda         : 8
#   preta         : 4
#   other_missing : 1, 6, 9, -1, 99 (and anything else / NaN)
# ---------------------------------------------------------------------------
race_map = {2: "branca", 8: "parda", 4: "preta"}
df["race_group"] = df["raca_cor"].map(race_map).fillna("other_missing")
print(f"\nrace_group value_counts:\n{df['race_group'].value_counts(dropna=False).sort_index()}")

# ---------------------------------------------------------------------------
# Age  (unified from idade and dtnascimento)
#   - 2011–2016: idade is present
#   - 2009–2010: idade absent; derive from dtnascimento (DDMMYYYY, 8 chars)
# ---------------------------------------------------------------------------
dtnasc = df["dtnascimento"] if "dtnascimento" in df.columns else None
idade_col = df["idade"] if "idade" in df.columns else None

if idade_col is not None and dtnasc is not None:
    birth_year = pd.to_numeric(
        dtnasc.where(dtnasc.str.len() == 8, other=None).str[4:8],
        errors="coerce",
    )
    age_from_dob = df["year"] - birth_year
    df["age"] = np.where(
        idade_col.notna(),
        idade_col,
        np.where(birth_year.notna(), age_from_dob, np.nan),
    )
elif idade_col is not None:
    df["age"] = idade_col
elif dtnasc is not None:
    birth_year = pd.to_numeric(
        dtnasc.where(dtnasc.str.len() == 8, other=None).str[4:8],
        errors="coerce",
    )
    df["age"] = df["year"] - birth_year
else:
    df["age"] = np.nan

# Clip implausible ages to NaN before binning
age_valid = df["age"].where(df["age"].between(14, 80))

df["age_bin"] = pd.cut(
    age_valid,
    bins=[13, 24, 34, 44, 54, 120],
    labels=["14_24", "25_34", "35_44", "45_54", "55plus"],
    right=True,
)
df["age_bin"] = df["age_bin"].cat.add_categories("missing")
df["age_bin"] = df["age_bin"].fillna("missing")
print(f"\nage_bin value_counts:\n{df['age_bin'].value_counts(dropna=False).sort_index()}")
missing_rate = (df["age_bin"] == "missing").mean() * 100
print(f"age_bin 'missing' rate: {missing_rate:.2f}%")

# Check missing by year
miss_by_year = df.groupby("year")["age_bin"].apply(lambda s: (s == "missing").mean() * 100)
print(f"age_bin 'missing' rate by year:\n{miss_by_year.round(2)}")

# ---------------------------------------------------------------------------
# Tenure bin  (from tempempr in months)
#   lt1yr   : [0,   12)
#   1_2yr   : [12,  36)
#   3_5yr   : [36,  72)
#   5_10yr  : [72, 132)
#   10_20yr : [132, 252)
#   20plus  : [252, inf)
# ---------------------------------------------------------------------------
df["tenure_bin"] = pd.cut(
    df["tempempr"],
    bins=[-np.inf, 12, 36, 72, 132, 252, np.inf],
    labels=["lt1yr", "1_2yr", "3_5yr", "5_10yr", "10_20yr", "20plus"],
    right=False,
)
print(f"\ntenure_bin value_counts:\n{df['tenure_bin'].value_counts(dropna=False).sort_index()}")

# ---------------------------------------------------------------------------
# Contract type dummies  (reference = tpvinculo == 10)
# ---------------------------------------------------------------------------
contract_dummies = [
    ("d_rural",            [20, 70]),
    ("d_apprentice",       [55]),
    ("d_fixed_term",       [60, 90, 50, 95, 96, 97]),
    ("d_public",           [30, 31, 35]),
    ("d_other_contract",   [40, 80, 15, 25]),
]

print("\nContract type dummies:")
for col, codes in contract_dummies:
    df[col] = df["tpvinculo"].isin(codes).astype("int8")
    rate = df[col].mean() * 100
    print(f"  {col:20s}: {rate:.2f}% = 1")

# Sanity check: for reference code 10 workers, all dummies should be 0
ref_mask = df["tpvinculo"] == 10
dummy_sum = sum(df.loc[ref_mask, col] for col, _ in contract_dummies)
bad = (dummy_sum > 0).sum()
print(f"\nSanity check — tpvinculo==10 workers with any dummy==1: {bad} (should be 0)")

# ---------------------------------------------------------------------------
# 4-digit occupation  (ocup2002 // 100)
# ---------------------------------------------------------------------------
df["ocup4"] = (df["ocup2002"] // 100).astype("Int32")
print(f"\nocup4 unique values: {df['ocup4'].nunique()}  null rate: {df['ocup4'].isna().mean()*100:.2f}%")

# ---------------------------------------------------------------------------
# Save (overwrite in place)
# ---------------------------------------------------------------------------
print(f"\nSaving to {PARQUET} ...")
df.to_parquet(PARQUET, index=False, engine="pyarrow")
print(f"Done. File size: {os.path.getsize(PARQUET) / 1e9:.2f} GB")
print(f"Total columns: {df.shape[1]}")
