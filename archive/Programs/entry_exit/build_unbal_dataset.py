"""
Entry/Exit Pipeline — Build Unbalanced Dataset
===============================================
Replicates the CBA sample logic from 1040_merge_cba_rais.do but without the
pos_emp == 1 restriction, so firms that enter or exit within 2009–2014 qualify.

Steps:
  1. Read CBA file → compute firm-level CBA indicators (cba_pre2012_avg,
     cba_post2012_avg, treat_ultra) → export entry_exit_treat.csv for MATLAB.
  2. Read per-year rais_firm_YYYY.dta → register in DuckDB → stack + join
     with CBA indicators → add in_balanced_panel flag.
  3. Save:
       Data/RAIS_aux/entry_exit_treat.csv          (for MATLAB)
       Data/RAIS_aux/cba_indicators_unbal.parquet   (intermediate)
       Data/CBA_RAIS_firm_level/cba_rais_firm_unbal_2009_2016.parquet

Outputs ~500K firm-year rows (all firms with a CBA, 2009–2016).
"""

import duckdb
import numpy as np
import pandas as pd
from pathlib import Path
import subprocess

# ── Paths ────────────────────────────────────────────────────────────────────
ROOT      = Path("/kellogg/proj/lgg3230/UnionSpill")
CBA_FILE  = ROOT / "Data/CBA/collapsed_cba_firm_updated.dta"
RAIS_DIR  = ROOT / "Data/CBA_RAIS_firm_level"
RAIS_AUX  = ROOT / "Data/RAIS_aux"
OUT_PARQ  = RAIS_DIR / "cba_rais_firm_unbal_2009_2016.parquet"
OUT_TREAT = RAIS_AUX / "entry_exit_treat.csv"
IND_PARQ  = RAIS_AUX / "cba_indicators_unbal.parquet"

YEARS = list(range(2009, 2017))

# ── 1. Compute firm-level CBA indicators ─────────────────────────────────────
print("Reading CBA file …")
cba = pd.read_stata(
    CBA_FILE,
    columns=["identificad", "avg_file_date", "end_date_stata", "treat_ultra",
             "active_year"]
)

# Ensure date columns are datetime
cba["avg_file_date"]  = pd.to_datetime(cba["avg_file_date"],  errors="coerce")
cba["end_date_stata"] = pd.to_datetime(cba["end_date_stata"], errors="coerce")

D2009_START = pd.Timestamp("2009-01-01")
D2009_END   = pd.Timestamp("2009-12-31")
D2012_START = pd.Timestamp("2012-01-01")
D2012_END   = pd.Timestamp("2012-12-31")

# ── 1a. treat_ultra: max across all CBA rows per firm ────────────────────────
treat_ultra = (
    cba.groupby("identificad")["treat_ultra"]
    .max()
    .rename("treat_ultra")
    .reset_index()
)

# ── 1b. cba2009_avg: has any CBA filed in calendar year 2009 ─────────────────
cba["in_2009"] = (
    (cba["avg_file_date"] >= D2009_START) &
    (cba["avg_file_date"] <= D2009_END)
).astype(int)

cba2009 = (
    cba.groupby("identificad")["in_2009"]
    .max()
    .rename("cba2009_avg")
    .reset_index()
)

# ── 1c. cba_pre2012_avg: has 2009 CBA AND another CBA filed after the
#         earliest 2009 CBA but before 2012-01-01 ────────────────────────────

# Earliest 2009 filing date per firm
earliest_2009 = (
    cba[cba["in_2009"] == 1]
    .groupby("identificad")["avg_file_date"]
    .min()
    .rename("earliest_2009_date")
    .reset_index()
)

# Merge earliest_2009 back to full CBA frame
cba2 = cba.merge(earliest_2009, on="identificad", how="left")

# Tag rows filed strictly after earliest 2009 CBA and before 2012-01-01
cba2["tag_post2009_pre2012"] = (
    cba2["avg_file_date"].notna() &
    cba2["earliest_2009_date"].notna() &
    (cba2["avg_file_date"] > cba2["earliest_2009_date"]) &
    (cba2["avg_file_date"] < D2012_START)
).astype(int)

count_post2009_pre2012 = (
    cba2.groupby("identificad")["tag_post2009_pre2012"]
    .sum()
    .rename("count_2009_2012_avg")
    .reset_index()
)

# ── 1d. cba_post2012_avg: has CBA filed >= 2012-01-01 with end >= 2012-12-31 ─
cba["post2012"] = (
    (cba["avg_file_date"] >= D2012_START) &
    (cba["end_date_stata"] >= D2012_END)
).astype(int)

cba_post2012 = (
    cba.groupby("identificad")["post2012"]
    .max()
    .rename("cba_post2012_avg")
    .reset_index()
)

# ── 1e. Assemble firm-level indicators ───────────────────────────────────────
firm_indicators = (
    treat_ultra
    .merge(cba2009,           on="identificad", how="outer")
    .merge(count_post2009_pre2012, on="identificad", how="outer")
    .merge(cba_post2012,      on="identificad", how="outer")
)

firm_indicators = firm_indicators.fillna({
    "treat_ultra":          0,
    "cba2009_avg":          0,
    "count_2009_2012_avg":  0,
    "cba_post2012_avg":     0,
})

# cba_pre2012_avg: has 2009 CBA AND at least one more before 2012
firm_indicators["cba_pre2012_avg"] = (
    (firm_indicators["cba2009_avg"] == 1) &
    (firm_indicators["count_2009_2012_avg"] >= 1)
).astype(int)

# Unbalanced lagos sample: CBA requirement only, no pos_emp
firm_indicators["lagos_sample_unbal_avg"] = (
    (firm_indicators["cba_pre2012_avg"] == 1) &
    (firm_indicators["cba_post2012_avg"] == 1)
).astype(int)

# Treatment indicator for MATLAB
firm_indicators["lagos_treat_unbal"] = (
    (firm_indicators["lagos_sample_unbal_avg"] == 1) &
    (firm_indicators["treat_ultra"] == 1)
).astype(int)

print(f"  Total firms in CBA file:          {len(firm_indicators):>10,}")
print(f"  Firms with lagos_sample_unbal_avg:{firm_indicators['lagos_sample_unbal_avg'].sum():>10,}")
print(f"  Firms with lagos_treat_unbal:     {firm_indicators['lagos_treat_unbal'].sum():>10,}")

# Save intermediate parquet
firm_indicators.to_parquet(IND_PARQ, index=False)
print(f"  Saved: {IND_PARQ}")

# ── 1f. Export entry_exit_treat.csv for MATLAB ───────────────────────────────
# MATLAB expects 15-digit ID with leading "1".
# Export from firm_indicators (167K CBA firms only), not the full RAIS panel.
assert len(firm_indicators) < 300_000, \
    f"firm_indicators has {len(firm_indicators):,} rows — expected ~167K"
treat_csv = firm_indicators[["identificad", "lagos_treat_unbal"]].copy()
treat_csv["identificad"] = "1" + treat_csv["identificad"].astype(str)
treat_csv.to_csv(OUT_TREAT, index=False)
print(f"  Saved: {OUT_TREAT}  ({len(treat_csv):,} rows)")

# ── 2. Read per-year rais_firm files, register in DuckDB ─────────────────────
print("\nReading per-year RAIS firm files …")

# Columns we want from the RAIS firm files
RAIS_COLS = [
    "identificad",
    "firm_emp", "l_firm_emp",
    "lr_remdezr", "lr_remmedr",
    "retention", "hiring", "quits", "layoffs",
    "municipio", "pub_firm",
]

con = duckdb.connect()
con.execute("PRAGMA threads=8")
con.execute("PRAGMA memory_limit='32GB'")

year_dfs = []
for y in YEARS:
    fpath = RAIS_DIR / f"rais_firm_{y}.dta"
    print(f"  {y} …", end=" ", flush=True)
    df = pd.read_stata(fpath, columns=RAIS_COLS)
    df["year"] = y
    year_dfs.append(df)
    print(f"{len(df):,} rows")

rais_panel = pd.concat(year_dfs, ignore_index=True)
print(f"  Total stacked: {len(rais_panel):,} rows")

# ── 3. Join RAIS panel with CBA indicators in DuckDB ─────────────────────────
print("\nJoining RAIS panel with CBA indicators …")

con.register("rais_panel", rais_panel)
con.register("firm_ind",   firm_indicators)

# Compute in_balanced_panel in DuckDB: present in every year 2009–2016
year_checks = " AND ".join(
    [f"MAX(CASE WHEN year = {y} THEN 1 ELSE 0 END) = 1" for y in YEARS]
)

result = con.execute(f"""
    WITH
    -- join outcomes with CBA indicators (keep all RAIS firms)
    joined AS (
        SELECT
            r.identificad,
            r.year,
            r.firm_emp,
            r.l_firm_emp,
            r.lr_remdezr,
            r.lr_remmedr,
            r.retention,
            r.hiring,
            r.quits,
            r.layoffs,
            r.municipio,
            r.pub_firm,
            COALESCE(f.treat_ultra,              0) AS treat_ultra,
            COALESCE(f.lagos_sample_unbal_avg,   0) AS lagos_sample_unbal_avg,
            COALESCE(f.lagos_treat_unbal,        0) AS lagos_treat_unbal,
            COALESCE(f.cba_pre2012_avg,          0) AS cba_pre2012_avg,
            COALESCE(f.cba_post2012_avg,         0) AS cba_post2012_avg
        FROM rais_panel r
        LEFT JOIN firm_ind f USING (identificad)
    ),
    -- compute balanced panel flag per firm
    balance AS (
        SELECT
            identificad,
            CASE WHEN {year_checks} THEN 1 ELSE 0 END AS in_balanced_panel
        FROM joined
        GROUP BY identificad
    )
    SELECT j.*, b.in_balanced_panel
    FROM joined j
    JOIN balance b USING (identificad)
""").fetch_arrow_table().to_pandas()

print(f"  Joined dataset: {len(result):,} rows, {result['identificad'].nunique():,} unique firms")
print(f"  Firms with lagos_sample_unbal_avg == 1: {result[result['lagos_sample_unbal_avg']==1]['identificad'].nunique():,}")

# ── 4. Compute turnover ───────────────────────────────────────────────────────
result["turnover"] = result["layoffs"] / result["firm_emp"].replace(0, np.nan)

# ── 5. Save ───────────────────────────────────────────────────────────────────
result.to_parquet(OUT_PARQ, index=False)
print(f"\nSaved: {OUT_PARQ}  ({OUT_PARQ.stat().st_size / 1e9:.2f} GB)")

# Notify
subprocess.run(
    ["curl", "-s", "-o", "/dev/null",
     "-H", "Title: build_unbal_dataset done",
     "-d", f"Saved {len(result):,} rows to {OUT_PARQ.name}",
     "https://ntfy.sh/lgg3230-kellogg"]
)
print("Done.")
