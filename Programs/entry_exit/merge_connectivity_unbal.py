"""
Entry/Exit Pipeline — Merge Connectivity into Unbalanced Panel
==============================================================
Runs after:
  build_unbal_dataset.py   → cba_rais_firm_unbal_2009_2016.parquet
  connectivity_treat_unbal.m → connectivity_treat_unbal_2007_2011.csv

Aggregates the MATLAB connectivity output, merges into the unbalanced panel,
adds derived measures, and saves the final analysis dataset:
  Data/CBA_RAIS_firm_level/cba_rais_firm_unbal_flows.parquet
  Data/CBA_RAIS_firm_level/cba_rais_firm_unbal_flows.dta   (for Stata)
"""

import duckdb
import numpy as np
import pandas as pd
from pathlib import Path
import subprocess

ROOT     = Path("/kellogg/proj/lgg3230/UnionSpill")
RAIS_DIR = ROOT / "Data/CBA_RAIS_firm_level"
RAIS_AUX = ROOT / "Data/RAIS_aux"

PANEL_PARQ = RAIS_DIR / "cba_rais_firm_unbal_2009_2016.parquet"
CONN_CSV   = RAIS_AUX / "connectivity_treat_unbal_2007_2011.csv"
OUT_PARQ   = RAIS_DIR / "cba_rais_firm_unbal_flows.parquet"
OUT_DTA    = RAIS_DIR / "cba_rais_firm_unbal_flows.dta"

YEAR_PAIRS = [("2007", "2008"), ("2008", "2009"), ("2009", "2010"), ("2010", "2011")]

# ── 1. Load connectivity CSV ──────────────────────────────────────────────────
print("Reading connectivity CSV …")
conn = pd.read_csv(CONN_CSV)

# Recover 14-digit RAIS identificad from 15-digit MATLAB string
conn["identificad1_s"] = conn["identificad1"].astype(str).str.zfill(15)
conn["identificad"]    = conn["identificad1_s"].str[1:]   # strip leading "1"
conn = conn.drop(columns=["identificad1", "identificad1_s"])

print(f"  Connectivity rows: {len(conn):,}")

# ── 2. Aggregate connectivity measures ───────────────────────────────────────

# For each year-pair, compute proportion of flows to treated (NaN-aware)
for y, yn in YEAR_PAIRS:
    tf_col  = f"totalflows_{y}_{yn}"
    tt_col  = f"totaltreat_{y}_{yn}"
    pf_col  = f"flowtreat_pf_{y}_{yn}_n"
    if tf_col in conn.columns and tt_col in conn.columns:
        conn[pf_col] = np.where(
            conn[tf_col] > 0,
            conn[tt_col] / conn[tf_col],
            np.nan
        )

# Average proportion across year-pairs (NaN-aware)
pf_cols = [f"flowtreat_pf_{y}_{yn}_n" for y, yn in YEAR_PAIRS if f"flowtreat_pf_{y}_{yn}_n" in conn.columns]
conn["avg_ftreat_pf_n"] = conn[pf_cols].mean(axis=1, skipna=True)

# Sum total flows (NaN-aware)
def nan_aware_sum(df, prefix, pairs):
    level_cols = [f"{prefix}_{y}_{yn}" for y, yn in pairs if f"{prefix}_{y}_{yn}" in df.columns]
    df[f"{prefix}_n"] = df[level_cols].sum(axis=1, skipna=True)
    df.loc[df[level_cols].isna().all(axis=1), f"{prefix}_n"] = np.nan
    return df

for prefix in ["totalflows", "totaltreat"]:
    conn = nan_aware_sum(conn, prefix, YEAR_PAIRS)

conn["totaltreat_pf_n"] = np.where(
    conn["totalflows_n"] > 0,
    conn["totaltreat_n"] / conn["totalflows_n"],
    np.nan
)

# Per-worker (NaN-aware average)
pw_pairs_treat = [f"totaltreat_pw_{y}_{yn}" for y, yn in YEAR_PAIRS if f"totaltreat_pw_{y}_{yn}" in conn.columns]
if pw_pairs_treat:
    conn["totaltreat_pw_n"] = conn[pw_pairs_treat].mean(axis=1, skipna=True)
    conn.loc[conn[pw_pairs_treat].isna().all(axis=1), "totaltreat_pw_n"] = np.nan

# Keep only aggregated columns
keep_conn = ["identificad", "totaltreat_n", "totalflows_n",
             "totaltreat_pf_n", "totaltreat_pw_n", "avg_ftreat_pf_n"]
keep_conn = [c for c in keep_conn if c in conn.columns]
conn_agg = conn[keep_conn].copy()

print(f"  Connectivity agg rows: {len(conn_agg):,}")
conn_agg.to_parquet(RAIS_AUX / "connectivity_treat_unbal_agg.parquet", index=False)

# ── 3. Merge connectivity into panel ─────────────────────────────────────────
print("Merging connectivity into panel …")

con = duckdb.connect()
con.execute("PRAGMA threads=8")
con.execute("PRAGMA memory_limit='32GB'")

result = con.execute(f"""
    SELECT
        p.*,
        COALESCE(c.totaltreat_n,    0) AS totaltreat_n,
        COALESCE(c.totalflows_n,    0) AS totalflows_n,
        c.totaltreat_pf_n,
        c.totaltreat_pw_n,
        c.avg_ftreat_pf_n
    FROM read_parquet('{PANEL_PARQ}') p
    LEFT JOIN read_parquet('{RAIS_AUX}/connectivity_treat_unbal_agg.parquet') c
        USING (identificad)
""").fetch_arrow_table().to_pandas()

print(f"  Merged: {len(result):,} rows")

# ── 4. Baseline outcomes (year 2011, pre-treatment) ──────────────────────────
for outcome in ["l_firm_emp", "lr_remdezr", "lr_remmedr"]:
    base = result[result["year"] == 2011][["identificad", outcome]].rename(
        columns={outcome: f"{outcome}_2011"}
    )
    result = result.merge(base, on="identificad", how="left")

# ── 5. Save ───────────────────────────────────────────────────────────────────
result.to_parquet(OUT_PARQ, index=False)
print(f"Saved parquet: {OUT_PARQ}  ({OUT_PARQ.stat().st_size/1e6:.0f} MB)")

result.to_stata(str(OUT_DTA), write_index=False, version=118)
print(f"Saved dta:     {OUT_DTA}  ({OUT_DTA.stat().st_size/1e6:.0f} MB)")

subprocess.run(
    ["curl", "-s", "-o", "/dev/null",
     "-H", "Title: merge_connectivity done",
     "-d", f"{len(result):,} rows saved",
     "https://ntfy.sh/lgg3230-kellogg"]
)
print("Done.")
