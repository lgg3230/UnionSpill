"""
Build a wide-format dataset of NaN-aware yearly totalflow measures (all 4 pre-treatment
year-pairs) for the 16,472 sample firms (lagos_sample_avg==1 & in_balanced_panel==1).

NaN-aware: firms absent from a year-pair retain NaN (not replaced with 0).

Output columns: identificad,
  totalflows_07_08, totalflows_pw_07_08,
  totalflows_08_09, totalflows_pw_08_09,
  totalflows_09_10, totalflows_pw_09_10,
  totalflows_10_11, totalflows_pw_10_11
"""

import pandas as pd

rais_firm = "/kellogg/proj/lgg3230/UnionSpill/Data/CBA_RAIS_firm_level"
rais_aux  = "/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux"

# ── 1. Get the 16,472 sample firm IDs ─────────────────────────────────────────
print("Loading sample firms...")
sample_df = pd.read_stata(
    f"{rais_firm}/labor_analysis_sample.dta",
    columns=["identificad", "lagos_sample_avg", "in_balanced_panel"],
)
sample_firms = (
    sample_df
    .loc[(sample_df["lagos_sample_avg"] == 1) & (sample_df["in_balanced_panel"] == 1),
         "identificad"]
    .unique()
)
print(f"  Sample firms: {len(sample_firms):,}")

# ── 2. Load connectivity yearly (wide) and filter to sample ───────────────────
print("Loading connectivity_2007_2011_yearly.dta...")
conn = pd.read_stata(
    f"{rais_aux}/connectivity_2007_2011_yearly.dta",
    columns=[
        "identificad",
        "totalflows_2007_2008", "totalflows_pw_2007_2008",
        "totalflows_2008_2009", "totalflows_pw_2008_2009",
        "totalflows_2009_2010", "totalflows_pw_2009_2010",
        "totalflows_2010_2011", "totalflows_pw_2010_2011",
    ],
)
conn = conn[conn["identificad"].isin(sample_firms)].copy()
print(f"  Firms matched: {len(conn):,}")

# ── 3. Rename to short year-pair labels ───────────────────────────────────────
conn = conn.rename(columns={
    "totalflows_2007_2008":    "totalflows_07_08",
    "totalflows_pw_2007_2008": "totalflows_pw_07_08",
    "totalflows_2008_2009":    "totalflows_08_09",
    "totalflows_pw_2008_2009": "totalflows_pw_08_09",
    "totalflows_2009_2010":    "totalflows_09_10",
    "totalflows_pw_2009_2010": "totalflows_pw_09_10",
    "totalflows_2010_2011":    "totalflows_10_11",
    "totalflows_pw_2010_2011": "totalflows_pw_10_11",
})

conn = conn.sort_values("identificad").reset_index(drop=True)

# ── 4. Save ────────────────────────────────────────────────────────────────────
out_path = f"{rais_aux}/totalflows_wide_2007_2011.csv"
conn.to_csv(out_path, index=False)
print(f"\nSaved: {out_path}")
print(f"  Rows: {len(conn):,}")
print("\nColumn list:", list(conn.columns))
print("\nSample (first 5 rows):")
print(conn.head())
