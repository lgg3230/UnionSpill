Ok"""
011b_totalflows_panel.py
Build a long-format panel (identificad × year) of total and treat-directed
worker flows covering 2009–2016.

Year t corresponds to the worker-transition period December (t-1) → December t.

Sources
-------
- Data/RAIS_aux/connectivity_treat_2007_2011.csv  → pairs 0809, 0910, 1011
- Data/RAIS_aux/connectivity_treat_2011_2016.csv  → pairs 1112, 1213, 1314, 1415, 1516
- Data/CBA_RAIS_firm_level/labor_analysis_sample.dta  → sample firm IDs

Output
------
Data/RAIS_aux/totalflows_panel_2009_2016.csv
"""

import os
import duckdb
import pandas as pd
import pyarrow  # noqa: F401 – ensures pyarrow is available for read_stata

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
BASE = "/gpfs/kellogg/proj/lgg3230/UnionSpill"
PRE_CSV  = os.path.join(BASE, "Data/RAIS_aux/connectivity_treat_2007_2011.csv")
POST_CSV = os.path.join(BASE, "Data/RAIS_aux/connectivity_treat_2011_2016.csv")
SAMPLE_DTA = os.path.join(BASE, "Data/CBA_RAIS_firm_level/labor_analysis_sample.dta")
OUT_CSV  = os.path.join(BASE, "Data/RAIS_aux/totalflows_panel_2009_2016.csv")

# ---------------------------------------------------------------------------
# Year-pair definitions: (year_label, y, ny, source_csv)
# ---------------------------------------------------------------------------
YEAR_PAIRS = [
    (2009, "2008", "2009", PRE_CSV),
    (2010, "2009", "2010", PRE_CSV),
    (2011, "2010", "2011", PRE_CSV),
    (2012, "2011", "2012", POST_CSV),
    (2013, "2012", "2013", POST_CSV),
    (2014, "2013", "2014", POST_CSV),
    (2015, "2014", "2015", POST_CSV),
    (2016, "2015", "2016", POST_CSV),
]

# ---------------------------------------------------------------------------
# Step 1: Load sample firm IDs
# ---------------------------------------------------------------------------
print("Loading sample firm IDs...")
sample_df = pd.read_stata(SAMPLE_DTA, columns=["identificad", "lagos_sample_avg", "in_balanced_panel"])
sample_ids = set(
    sample_df.loc[
        (sample_df["lagos_sample_avg"] == 1) & (sample_df["in_balanced_panel"] == 1),
        "identificad"
    ].astype(str)
)
print(f"  Sample firms: {len(sample_ids):,}")

# ---------------------------------------------------------------------------
# Step 2: Extract each year-pair via DuckDB and filter to sample
# ---------------------------------------------------------------------------
con = duckdb.connect()
con.execute("PRAGMA threads=8")
con.execute("PRAGMA memory_limit='32GB'")

frames = []

for year, y, ny, csv_path in YEAR_PAIRS:
    pair = f"{y}_{ny}"
    print(f"Processing year {year} (pair {y}-{ny})...")

    q = f"""
    SELECT
        SUBSTR(CAST(identificad1 AS VARCHAR), 2)  AS identificad,
        {year}                     AS year,
        totalflows_{pair}          AS totalflows,
        totalflows_pw_{pair}       AS totalflows_pw,
        totalout_{pair}            AS outflows,
        totalout_pw_{pair}         AS outflows_pw,
        totalin_{pair}             AS inflows,
        totalin_pw_{pair}          AS inflows_pw,
        totaltreat_{pair}          AS totaltreat,
        totaltreat_pw_{pair}       AS totaltreat_pw,
        outtreat_{pair}            AS outflows_to_treat,
        outtreat_pw_{pair}         AS outflows_to_treat_pw,
        intreat_{pair}             AS inflows_from_treat,
        intreat_pw_{pair}          AS inflows_from_treat_pw
    FROM read_csv('{csv_path}', header=true, auto_detect=true)
    WHERE totalflows_{pair} IS NOT NULL
    """

    df = con.execute(q).fetch_arrow_table().to_pandas()

    # Drop rows where totalflows is still NaN (empty strings in CSV bypass WHERE)
    df = df[df["totalflows"].notna()].copy()

    # Filter to sample firms
    df = df[df["identificad"].isin(sample_ids)].copy()
    print(f"  Rows after sample filter: {len(df):,}")

    frames.append(df)

# ---------------------------------------------------------------------------
# Step 3: Concatenate and sort
# ---------------------------------------------------------------------------
print("Concatenating all year-pairs...")
panel = pd.concat(frames, ignore_index=True)
panel.sort_values(["identificad", "year"], inplace=True)
panel.reset_index(drop=True, inplace=True)

# ---------------------------------------------------------------------------
# Step 4: Verification checks
# ---------------------------------------------------------------------------
print("\n--- Verification ---")
print(f"Total rows:          {len(panel):,}  (max expected: {len(sample_ids) * 8:,})")
print(f"Unique firms:        {panel['identificad'].nunique():,}  (max expected: {len(sample_ids):,})")
print(f"Years present:       {sorted(panel['year'].unique())}")
print(f"Missing totalflows:  {panel['totalflows'].isna().sum():,}")

# Logical check: totaltreat should never exceed totalflows
bad = (panel["totaltreat"] > panel["totalflows"]).sum()
print(f"Rows totaltreat > totalflows: {bad:,}  (should be 0)")

# ---------------------------------------------------------------------------
# Step 5: Save
# ---------------------------------------------------------------------------
print(f"\nSaving to {OUT_CSV}...")
panel.to_csv(OUT_CSV, index=False)
print("Done.")
