#!/usr/bin/env python3
"""
Script 01: Build per-worker transition records with layer assignment.

For each of the 4 pre-treatment year pairs (0708, 0809, 0910, 1011):
  - Identifies each Lagos-sample origin worker and their layer (occ3 or edu)
  - Identifies destination firm for each worker in t+1
  - Flags whether destination is a treated firm (≠ origin)
  - Records destination layer when available (for within/cross-layer analysis)

Usage:
    python 01_build_transitions.py --layer occ3
    python 01_build_transitions.py --layer edu
"""

import argparse
import os
import sys
import duckdb
import pandas as pd
import numpy as np

# Allow running from project root
sys.path.insert(0, os.path.dirname(__file__))
from layer_config import (
    LAYER_DEFS, YEAR_PAIRS, PAIR_LABELS,
    PARQUET_ORIGIN_YEARS, PARQUET_DEST_YEARS, IPCA,
    RAIS_DIR, RAIS_AUX, WORKER_PANEL_PARQUET,
    CBA_FIRM, CBA_RAIS_FIRM, OUT_BASE, YEARLY_EMP_TEMPLATE,
)


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--layer", required=True, choices=list(LAYER_DEFS.keys()),
                   help="Layer definition to use")
    return p.parse_args()


def get_sample_and_treatment_ids():
    """Load Lagos sample and treated firm IDs (14-digit strings).

    Uses labor_analysis_sample.dta (5.6 GB) instead of cba_rais_firm (56 GB);
    chunked read avoids loading the full file into memory.
    """
    labor_sample_path = os.path.join(CBA_FIRM, "labor_analysis_sample.dta")
    reader = pd.read_stata(
        labor_sample_path,
        columns=["identificad", "lagos_sample_avg", "treat_ultra"],
        chunksize=100_000,
        convert_categoricals=False,
    )
    sample_ids, treated_ids = set(), set()
    for chunk in reader:
        sample_ids.update(
            chunk.loc[chunk["lagos_sample_avg"] == 1, "identificad"].astype(str)
        )
        treated_ids.update(
            chunk.loc[chunk["treat_ultra"] == 1, "identificad"].astype(str)
        )
    return sample_ids, treated_ids


def load_yearly_employers(year: int) -> pd.DataFrame:
    """
    Load yearly_employers_{year}.dta.
    Returns DataFrame with columns: PIS (str), identificad (14-digit str).
    yearly_employers stores 15-digit IDs with leading '1'; we strip it here.
    """
    col_id = f"identificad_{year}"
    df = pd.read_stata(
        YEARLY_EMP_TEMPLATE.format(year=year),
        columns=["PIS", col_id],
    )
    df = df.rename(columns={col_id: "identificad"})
    df["PIS"] = df["PIS"].astype(str)
    df["identificad"] = df["identificad"].astype(str)
    # IDs in .dta files are already 14-digit — no stripping needed
    # Issue 7: sort before drop_duplicates so the surviving row is deterministic
    df = df.sort_values(["PIS", "identificad"]).drop_duplicates("PIS")
    return df


def load_layer_from_parquet(year: int, layerdef: dict) -> pd.DataFrame:
    """
    Load layer variables for a given year from worker_panel_lagos.parquet.
    Returns DataFrame with columns: PIS (str), identificad (14-digit str), layer_id.
    """
    con = duckdb.connect()
    con.execute("PRAGMA threads=8")
    con.execute("PRAGMA memory_limit='32GB'")

    parquet_col = layerdef["parquet_col"]

    if parquet_col is not None:
        # Pre-computed column (e.g., educ_bin)
        query = f"""
            SELECT
                CAST(PIS AS VARCHAR)          AS PIS,
                CAST(identificad AS VARCHAR)  AS identificad,
                CAST({parquet_col} AS VARCHAR) AS layer_id
            FROM read_parquet('{WORKER_PANEL_PARQUET}')
            WHERE year = {year}
              AND {parquet_col} IS NOT NULL
            QUALIFY ROW_NUMBER() OVER (PARTITION BY PIS, identificad ORDER BY 1) = 1
        """
    else:
        # Must compute from raw column (e.g., occ3 from ocup2002)
        raw_col = layerdef["raw_cols"][0]
        if raw_col == "ocup2002":
            query = f"""
                SELECT
                    CAST(PIS AS VARCHAR)         AS PIS,
                    CAST(identificad AS VARCHAR) AS identificad,
                    CAST(FLOOR({raw_col} / 10) AS INTEGER) AS layer_id
                FROM read_parquet('{WORKER_PANEL_PARQUET}')
                WHERE year = {year}
                  AND {raw_col} IS NOT NULL
                QUALIFY ROW_NUMBER() OVER (PARTITION BY PIS, identificad ORDER BY 1) = 1
            """
        else:
            raise ValueError(f"Unknown raw_col: {raw_col}")

    df = con.execute(query).fetch_arrow_table().to_pandas()
    df["layer_id"] = df["layer_id"].astype(str)
    return df


def load_layer_from_raw_rais(year: int, layerdef: dict,
                              pis_filter: set = None,
                              for_origin: bool = True) -> pd.DataFrame:
    """
    Load layer variables from raw RAIS_{year}.dta.
    Applies Stage 1 spell selection (one per identificad × PIS).
    Optionally filter to a specific set of PIS values (for destination semi-join).

    for_origin=True  (default): also applies Stage 2 — one per PIS by tenure/wage.
                                Use for origin-year calls.
    for_origin=False:           stops after Stage 1 — returns all matched spells
                                (one per identificad × PIS).
                                Use for destination-year calls so the firm
                                assigned by yearly_employers is not replaced.

    Returns DataFrame with columns: PIS (str), identificad (14-digit str), layer_id.
    """
    raw_col = layerdef["raw_cols"][0]
    ipca_deflator = IPCA[year]

    rais_path = os.path.join(RAIS_DIR, f"RAIS_{year}.dta")

    # Load the raw RAIS data in chunks via DuckDB (or pandas for .dta)
    # For .dta files, we use pandas with chunked reading
    cols_needed = ["PIS", "identificad", "horascontr", "remdezr", "tempempr",
                   "empem3112", raw_col]

    print(f"  Loading raw RAIS {year} for layer variable '{raw_col}'...")
    chunks = []
    import warnings
    reader = pd.read_stata(rais_path, columns=cols_needed, chunksize=500_000,
                           convert_categoricals=False)
    for chunk in reader:
        # Filter: December-employed, tenure > 1
        chunk = chunk[chunk["empem3112"] == 1]
        chunk = chunk[chunk["tempempr"] > 1]
        if pis_filter is not None:
            chunk = chunk[chunk["PIS"].astype(str).isin(pis_filter)]
        chunks.append(chunk)
    df = pd.concat(chunks, ignore_index=True)

    if df.empty:
        return pd.DataFrame(columns=["PIS", "identificad", "layer_id"])

    df["PIS"] = df["PIS"].astype(str)
    df["identificad"] = df["identificad"].astype(str)  # already 14-digit in .dta files
    df["remdezr_h"] = (df["remdezr"] / ipca_deflator) / df["horascontr"].replace(0, np.nan)

    # Stage 1: one per (identificad × PIS) — pick highest hours, then highest hourly wage
    df = df.sort_values(["identificad", "PIS", "horascontr", "remdezr_h"],
                        ascending=[True, True, False, False])
    df = df.drop_duplicates(subset=["identificad", "PIS"], keep="first")

    # Issue 3: Stage 2 (one per PIS) only for origin calls.
    # For destination calls we need one row per (PIS, identificad) so that the
    # firm-matching filter in process_pair can find the correct destination spell.
    if for_origin:
        # Stage 2: one per PIS — pick highest tenure, then highest hourly wage
        df = df.sort_values(["PIS", "tempempr", "remdezr_h"],
                            ascending=[True, False, False])
        df = df.drop_duplicates(subset=["PIS"], keep="first")

    # Compute layer_id
    if raw_col == "ocup2002":
        df["layer_id"] = (df[raw_col] // 10).astype("Int64").astype(str)
    else:
        # edu: apply pd.cut
        df["layer_id"] = pd.cut(
            df[raw_col].astype(float), bins=[0, 6, 8, 11],
            labels=["0_no_hs", "1_hs", "2_higher"]
        ).astype(str)

    df = df[["PIS", "identificad", "layer_id"]].dropna(subset=["layer_id"])
    df = df[df["layer_id"] != "nan"]
    return df


def process_pair(t: int, t1: int, layerdef: dict,
                 sample_ids: set, treated_ids: set) -> pd.DataFrame:
    """
    Build transition records for a single year pair (t, t+1).
    Returns DataFrame with columns:
        identificad_t, layer_id_t, layer_id_t1, pair_label,
        is_treated_dest, identificad_t1
    """
    pair_label = PAIR_LABELS[(t, t1)]
    print(f"\n--- Processing pair {pair_label} ---")

    # ── STEP 1: Origin PIS→firm from yearly_employers (Stage 1+2 done) ──
    print(f"  Loading yearly_employers_{t}...")
    df_orig = load_yearly_employers(t)
    # Filter to Lagos sample firms
    n_before = len(df_orig)
    df_orig = df_orig[df_orig["identificad"].isin(sample_ids)].copy()
    print(f"  Origin workers: {n_before:,} total → {len(df_orig):,} in Lagos sample")

    # ── STEP 2: Origin layer vars ──
    if t in PARQUET_ORIGIN_YEARS:
        print(f"  Getting origin layer from parquet (year {t})...")
        df_layer_orig = load_layer_from_parquet(t, layerdef)
    else:
        print(f"  Getting origin layer from raw RAIS {t}...")
        # for_origin=True: apply Stage 2 (one per PIS)
        df_layer_orig = load_layer_from_raw_rais(t, layerdef, for_origin=True)

    # Issue 4: deduplicate origin layer on (PIS, identificad) before merging
    # to prevent row inflation from any multi-row returns.
    df_layer_orig = df_layer_orig.drop_duplicates(subset=["PIS", "identificad"])

    # Join: yearly_employers origin → layer. Use (PIS, identificad) as key.
    df_orig = df_orig.merge(
        df_layer_orig.rename(columns={"identificad": "identificad_layer"}),
        on="PIS", how="left",
    )
    # Keep only workers where the firm in parquet/rais matches yearly_employers
    # (handles case where parquet has a different job selected)
    df_orig = df_orig[
        df_orig["identificad_layer"].isna() |
        (df_orig["identificad"] == df_orig["identificad_layer"])
    ].copy()
    df_orig = df_orig[df_orig["layer_id"].notna()].copy()
    df_orig = df_orig[df_orig["layer_id"] != "nan"].copy()
    df_orig = df_orig[["PIS", "identificad", "layer_id"]].copy()
    df_orig = df_orig.rename(columns={"identificad": "identificad_t",
                                       "layer_id": "layer_id_t"})
    print(f"  After layer join: {len(df_orig):,} origin workers with valid layer")

    # ── STEP 3: Destination PIS→firm from yearly_employers ──
    print(f"  Loading yearly_employers_{t1}...")
    df_dest = load_yearly_employers(t1)
    df_dest = df_dest.rename(columns={"identificad": "identificad_t1"})

    # ── STEP 4: Left join origin → destination on PIS ──
    df = df_orig.merge(df_dest, on="PIS", how="left")
    df["identificad_t1"] = df["identificad_t1"].fillna("")

    # Flag treated destination (must be different from origin)
    df["is_treated_dest"] = (
        df["identificad_t1"].isin(treated_ids) &
        (df["identificad_t1"] != df["identificad_t"]) &
        (df["identificad_t1"] != "")
    ).astype(int)

    print(f"  Movers to treated: {df['is_treated_dest'].sum():,} / {len(df):,}")

    # ── STEP 5: Destination layer (for cross/within decomposition) ──
    # Only for movers (identificad_t1 is non-empty and != origin)
    mover_mask = (df["identificad_t1"] != "") & (df["identificad_t1"] != df["identificad_t"])
    mover_pis = set(df.loc[mover_mask, "PIS"])
    print(f"  Movers (any destination): {len(mover_pis):,}")

    if t1 in PARQUET_DEST_YEARS and mover_pis:
        print(f"  Getting destination layer from parquet (year {t1})...")
        df_layer_dest = load_layer_from_parquet(t1, layerdef)
        df_layer_dest = df_layer_dest[df_layer_dest["PIS"].isin(mover_pis)]
        df_layer_dest = df_layer_dest.rename(columns={
            "identificad": "identificad_dest_layer",
            "layer_id": "layer_id_t1",
        })
    elif mover_pis:
        print(f"  Getting destination layer from raw RAIS {t1} (semi-join)...")
        # Issue 3: for_origin=False — stop after Stage 1 (one per identificad × PIS)
        # so the mismatch filter can match the destination firm from yearly_employers.
        df_layer_dest_raw = load_layer_from_raw_rais(
            t1, layerdef, pis_filter=mover_pis, for_origin=False
        )
        df_layer_dest = df_layer_dest_raw.rename(columns={
            "identificad": "identificad_dest_layer",
            "layer_id": "layer_id_t1",
        })
    else:
        df_layer_dest = pd.DataFrame(columns=["PIS", "identificad_dest_layer", "layer_id_t1"])

    # Issue 5: merge on (PIS, identificad_t1) to eliminate fan-out entirely.
    # Renaming identificad_dest_layer → identificad_t1 lets us join on the
    # compound key, so each origin row matches at most one destination-layer row.
    df_layer_dest = df_layer_dest.rename(
        columns={"identificad_dest_layer": "identificad_t1"}
    )

    # Join destination layer: compound key eliminates fan-out; no mismatch filter needed.
    df = df.merge(
        df_layer_dest[["PIS", "identificad_t1", "layer_id_t1"]],
        on=["PIS", "identificad_t1"], how="left"
    )

    # Clear destination layer for stayers (no firm change).
    # (mismatch filter removed — compound-key join makes it unnecessary.)
    non_mover_mask = (df["identificad_t1"] == "") | (df["identificad_t1"] == df["identificad_t"])
    df.loc[non_mover_mask, "layer_id_t1"] = np.nan

    df["pair_label"] = pair_label

    # Select and clean output columns
    out = df[["identificad_t", "layer_id_t", "layer_id_t1",
              "pair_label", "is_treated_dest", "identificad_t1"]].copy()
    out["layer_id_t1"] = out["layer_id_t1"].where(
        out["layer_id_t1"].notna() & (out["layer_id_t1"] != "nan"), other=np.nan
    )

    dest_layer_coverage = out["layer_id_t1"].notna().sum()
    print(f"  Destination layer coverage: {dest_layer_coverage:,} / {len(mover_pis):,} movers")

    return out


def main():
    args = parse_args()
    layerdef = LAYER_DEFS[args.layer]
    print(f"Layer: {args.layer} — {layerdef['description']}")

    # Output directory
    out_dir = os.path.join(OUT_BASE, "transitions_base")
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, f"transitions_{args.layer}.parquet")

    # Load sample/treatment IDs
    print("Loading sample and treatment IDs...")
    sample_ids, treated_ids = get_sample_and_treatment_ids()
    print(f"  Lagos sample firms: {len(sample_ids):,}")
    print(f"  Treated firms:      {len(treated_ids):,}")

    # Process all year pairs
    all_records = []
    for (t, t1) in YEAR_PAIRS:
        df_pair = process_pair(t, t1, layerdef, sample_ids, treated_ids)
        all_records.append(df_pair)

    df_all = pd.concat(all_records, ignore_index=True)
    print(f"\nTotal transition records: {len(df_all):,}")
    print(f"Saving to {out_path}")
    df_all.to_parquet(out_path, index=False)
    print("Done.")


if __name__ == "__main__":
    main()
