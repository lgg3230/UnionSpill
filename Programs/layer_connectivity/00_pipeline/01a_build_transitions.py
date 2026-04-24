#!/usr/bin/env python3
"""
Script 01: Build per-worker transition records with layer assignment.

For each of the 4 pre-treatment year pairs (0708, 0809, 0910, 1011):
  - Outflows: workers at Lagos-sample firm i in year t who move to treated firm in t+1
  - Inflows:  workers at Lagos-sample firm i in year t+1 who came from treated firm in t
  - Records layer at focal firm (layer_id_focal) and at contacted treated firm (layer_id_contact)

Output schema per record:
    identificad_focal  - firm being studied
    layer_id_focal     - layer at focal firm
    layer_id_contact   - layer at the contacted treated firm (NaN if not a mover)
    pair_label         - year pair (0708, 0809, 0910, 1011)
    record_type        - "out" (outflow) or "in" (inflow)
    is_treated_contact - 1 if contact with a treated firm

Usage:
    python 01a_build_transitions.py --layer occ3
    python 01a_build_transitions.py --layer edu
"""

import argparse
import os
import sys
import duckdb
import pandas as pd
import numpy as np

# Allow running from project root
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from layer_config import (
    LAYER_DEFS, YEAR_PAIRS, PAIR_LABELS,
    PARQUET_ORIGIN_YEARS, PARQUET_DEST_YEARS, IPCA,
    RAIS_DIR, RAIS_AUX, WORKER_PANEL_PARQUET,
    OUT_BASE, YEARLY_EMP_TEMPLATE, YEARLY_EMP_PARQUET_TEMPLATE,
)


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--layer", required=True, choices=list(LAYER_DEFS.keys()),
                   help="Layer definition to use")
    return p.parse_args()


def get_sample_and_treatment_ids():
    """Load Lagos sample and treated firm IDs (14-digit strings).

    Reads from the canonical CSV sources used by the Stata/MATLAB pipeline:
      - lagos_treat.csv:   firms with lagos_treat == 1 (treated)
      - lagos_control.csv: firms with lagos_control == 1 (control)
    Both files store 15-digit IDs with a leading "1"; we strip the first
    character to obtain 14-digit IDs that match yearly_employers / worker_panel.
    """
    treat_path   = os.path.join(RAIS_AUX, "lagos_treat.csv")
    control_path = os.path.join(RAIS_AUX, "lagos_control.csv")

    df_treat   = pd.read_csv(treat_path,   dtype=str)
    df_control = pd.read_csv(control_path, dtype=str)

    # Strip leading "1" from 15-digit IDs → 14-digit
    df_treat["identificad"]   = df_treat["identificad"].str[1:]
    df_control["identificad"] = df_control["identificad"].str[1:]

    treated_ids = set(df_treat.loc[df_treat["lagos_treat"]     == "1", "identificad"])
    sample_ids  = treated_ids | \
                  set(df_control.loc[df_control["lagos_control"] == "1", "identificad"])

    return sample_ids, treated_ids


def load_yearly_employers(year: int) -> pd.DataFrame:
    """
    Load yearly_employers_{year} from parquet cache (fast) or DTA fallback.
    Returns DataFrame with columns: PIS (str), identificad (14-digit str).
    """
    parquet_path = YEARLY_EMP_PARQUET_TEMPLATE.format(year=year)
    if os.path.exists(parquet_path):
        df = pd.read_parquet(parquet_path)
        df["PIS"]         = df["PIS"].astype(str)
        df["identificad"] = df["identificad"].astype(str)
    else:
        col_id = f"identificad_{year}"
        df = pd.read_stata(
            YEARLY_EMP_TEMPLATE.format(year=year),
            columns=["PIS", col_id],
        )
        df = df.rename(columns={col_id: "identificad"})
        df["PIS"]         = df["PIS"].astype(str)
        df["identificad"] = df["identificad"].astype(str)
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
        # Must compute from raw column (e.g., occ3/occ4 from ocup2002)
        raw_col = layerdef["raw_cols"][0]
        sql_expr = layerdef.get("sql_layer_expr")
        if sql_expr is not None:
            expr = sql_expr.strip()
            query = f"""
                SELECT
                    CAST(PIS AS VARCHAR)         AS PIS,
                    CAST(identificad AS VARCHAR) AS identificad,
                    CAST(({expr}) AS VARCHAR)    AS layer_id
                FROM read_parquet('{WORKER_PANEL_PARQUET}')
                WHERE year = {year}
                  AND {raw_col} IS NOT NULL
                  AND ({expr}) IS NOT NULL
                QUALIFY ROW_NUMBER() OVER (PARTITION BY PIS, identificad ORDER BY 1) = 1
            """
        elif raw_col == "ocup2002":
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
    Load layer variables from raw RAIS_{year}.dta (or .parquet if cached).
    Applies Stage 1 spell selection (one per identificad × PIS).
    Optionally filter to a specific set of PIS values (for destination semi-join).

    for_origin=True  (default): also applies Stage 2 — one per PIS by tenure/wage.
                                Use for focal-year calls.
    for_origin=False:           stops after Stage 1 — returns all matched spells
                                (one per identificad × PIS).
                                Use for contact-year calls so the firm
                                assigned by yearly_employers is not replaced.

    Returns DataFrame with columns: PIS (str), identificad (14-digit str), layer_id.
    """
    raw_col = layerdef["raw_cols"][0]
    ipca_deflator = IPCA[year]

    parquet_path = os.path.join(RAIS_DIR, f"RAIS_{year}.parquet")
    rais_path    = os.path.join(RAIS_DIR, f"RAIS_{year}.dta")

    cols_needed = ["PIS", "identificad", "horascontr", "remdezr", "tempempr",
                   "empem3112", raw_col]

    if os.path.exists(parquet_path):
        print(f"  Loading raw RAIS {year} from parquet for layer variable '{raw_col}'...")
        con = duckdb.connect()
        con.execute("PRAGMA threads=8")
        con.execute("PRAGMA memory_limit='32GB'")
        cols_sql = ", ".join(cols_needed)
        query = f"""
            SELECT {cols_sql}
            FROM read_parquet('{parquet_path}')
            WHERE empem3112 = 1
              AND tempempr  > 1
        """
        df = con.execute(query).fetch_arrow_table().to_pandas()
        if pis_filter is not None:
            df = df[df["PIS"].astype(str).isin(pis_filter)]
    else:
        # Fall back to chunked .dta read
        print(f"  Loading raw RAIS {year} for layer variable '{raw_col}'...")
        chunks = []
        reader = pd.read_stata(rais_path, columns=cols_needed, chunksize=500_000,
                               convert_categoricals=False)
        for chunk in reader:
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
    df["r_remdezr_h"] = (df["remdezr"] / ipca_deflator) / df["horascontr"].replace(0, np.nan)

    # Stage 1: one per (identificad × PIS) — pick highest hours, then highest hourly wage
    df = df.sort_values(["identificad", "PIS", "horascontr", "r_remdezr_h"],
                        ascending=[True, True, False, False])
    df = df.drop_duplicates(subset=["identificad", "PIS"], keep="first")

    # Issue 3: Stage 2 (one per PIS) only for focal calls.
    # For contact calls we need one row per (PIS, identificad) so that the
    # compound-key join can find the correct spell.
    if for_origin:
        # Stage 2: one per PIS — pick highest tenure, then highest hourly wage
        df = df.sort_values(["PIS", "tempempr", "r_remdezr_h"],
                            ascending=[True, False, False])
        df = df.drop_duplicates(subset=["PIS"], keep="first")

    # Compute layer_id
    pandas_compute = layerdef.get("pandas_compute")
    if pandas_compute is not None:
        df["layer_id"] = pandas_compute(df[raw_col]).astype(str)
    elif raw_col == "ocup2002":
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


def _merge_focal_layer(df_workers: pd.DataFrame, df_layer: pd.DataFrame,
                        focal_col: str = "identificad_focal") -> pd.DataFrame:
    """
    Merge focal workers with layer data on PIS, keeping only matching firm rows.
    df_workers must have columns: PIS, {focal_col}, ...
    df_layer must have columns: PIS, identificad, layer_id
    Returns df_workers with layer_id_focal column, filtered to valid layers.
    """
    df_layer = df_layer.drop_duplicates(subset=["PIS", "identificad"])
    df_merged = df_workers.merge(
        df_layer.rename(columns={"identificad": "identificad_layer"}),
        on="PIS", how="left",
    )

    # Keep only workers where the firm in parquet/rais matches yearly_employers
    df_merged = df_merged[
        df_merged["identificad_layer"].isna() |
        (df_merged[focal_col] == df_merged["identificad_layer"])
    ].copy()
    df_merged = df_merged[df_merged["layer_id"].notna()].copy()
    df_merged = df_merged[df_merged["layer_id"] != "nan"].copy()
    df_merged = df_merged.rename(columns={"layer_id": "layer_id_focal"})
    return df_merged[[c for c in df_merged.columns if c != "identificad_layer"]]


def compute_outflows(t: int, t1: int, layerdef: dict,
                     sample_ids: set, treated_ids: set) -> pd.DataFrame:
    """
    Outflow records: workers leaving focal firm i (year t) for treated firms in t+1.

    Returns columns:
        identificad_focal, layer_id_focal, layer_id_contact,
        pair_label, record_type="out", is_treated_contact
    """
    pair_label = PAIR_LABELS[(t, t1)]
    print(f"  [outflows] pair {pair_label}")

    # STEP 1: Focal workers (year t) — filter to Lagos sample
    print(f"    Loading yearly_employers_{t} (focal)...")
    df_focal = load_yearly_employers(t)
    n_before = len(df_focal)
    df_focal = df_focal[df_focal["identificad"].isin(sample_ids)].copy()
    df_focal = df_focal.rename(columns={"identificad": "identificad_focal"})
    print(f"    Focal workers: {n_before:,} total → {len(df_focal):,} in Lagos sample")

    # STEP 2: Focal layer at year t
    if t in PARQUET_ORIGIN_YEARS:
        print(f"    Getting focal layer from parquet (year {t})...")
        df_layer_focal = load_layer_from_parquet(t, layerdef)
    else:
        print(f"    Getting focal layer from raw RAIS {t}...")
        df_layer_focal = load_layer_from_raw_rais(t, layerdef, for_origin=True)

    df_focal = _merge_focal_layer(df_focal, df_layer_focal, focal_col="identificad_focal")
    df_focal = df_focal[["PIS", "identificad_focal", "layer_id_focal"]].copy()
    print(f"    After layer join: {len(df_focal):,} workers with valid layer")

    # STEP 3: Contact firm (year t+1) from yearly_employers
    print(f"    Loading yearly_employers_{t1} (contact)...")
    df_contact = load_yearly_employers(t1)
    df_contact = df_contact.rename(columns={"identificad": "identificad_contact"})

    # STEP 4: Left join focal → contact on PIS
    df = df_focal.merge(df_contact, on="PIS", how="left")
    df["identificad_contact"] = df["identificad_contact"].fillna("")

    # Flag treated contact (must differ from focal firm)
    df["is_treated_contact"] = (
        df["identificad_contact"].isin(treated_ids) &
        (df["identificad_contact"] != df["identificad_focal"]) &
        (df["identificad_contact"] != "")
    ).astype(int)

    # is_mover: worker changed firms (regardless of destination)
    df["is_mover"] = (
        (df["identificad_contact"] != "") &
        (df["identificad_contact"] != df["identificad_focal"])
    ).astype(int)

    print(f"    Outflows to treated: {df['is_treated_contact'].sum():,} / {len(df):,}")

    # STEP 5: Contact layer at year t+1 (all movers, for cross/within decomp)
    mover_mask = (
        (df["identificad_contact"] != "") &
        (df["identificad_contact"] != df["identificad_focal"])
    )
    mover_pis = set(df.loc[mover_mask, "PIS"])
    print(f"    Movers (any contact): {len(mover_pis):,}")

    if t1 in PARQUET_DEST_YEARS and mover_pis:
        print(f"    Getting contact layer from parquet (year {t1})...")
        df_layer_contact = load_layer_from_parquet(t1, layerdef)
        df_layer_contact = df_layer_contact[df_layer_contact["PIS"].isin(mover_pis)]
        df_layer_contact = df_layer_contact.rename(columns={
            "identificad": "identificad_contact",
            "layer_id": "layer_id_contact",
        })
    elif mover_pis:
        print(f"    Getting contact layer from raw RAIS {t1} (semi-join)...")
        df_layer_contact = load_layer_from_raw_rais(
            t1, layerdef, pis_filter=mover_pis, for_origin=False
        )
        df_layer_contact = df_layer_contact.rename(columns={
            "identificad": "identificad_contact",
            "layer_id": "layer_id_contact",
        })
    else:
        df_layer_contact = pd.DataFrame(
            columns=["PIS", "identificad_contact", "layer_id_contact"]
        )

    # Compound-key join eliminates fan-out
    df = df.merge(
        df_layer_contact[["PIS", "identificad_contact", "layer_id_contact"]],
        on=["PIS", "identificad_contact"], how="left"
    )

    # Clear contact layer for stayers
    non_mover_mask = (
        (df["identificad_contact"] == "") |
        (df["identificad_contact"] == df["identificad_focal"])
    )
    df.loc[non_mover_mask, "layer_id_contact"] = np.nan

    df["pair_label"] = pair_label
    df["record_type"] = "out"

    out = df[["identificad_focal", "layer_id_focal", "layer_id_contact",
              "pair_label", "record_type", "is_treated_contact", "is_mover"]].copy()
    out["layer_id_contact"] = out["layer_id_contact"].where(
        out["layer_id_contact"].notna() & (out["layer_id_contact"] != "nan"),
        other=np.nan
    )

    coverage = out["layer_id_contact"].notna().sum()
    print(f"    Contact layer coverage: {coverage:,} / {len(mover_pis):,} movers")

    return out


def compute_inflows(t: int, t1: int, layerdef: dict,
                    sample_ids: set, treated_ids: set) -> pd.DataFrame:
    """
    Inflow records: workers arriving at focal firm i (year t+1) from treated firms in t.

    Returns columns:
        identificad_focal, layer_id_focal, layer_id_contact,
        pair_label, record_type="in", is_treated_contact
    """
    pair_label = PAIR_LABELS[(t, t1)]
    print(f"  [inflows] pair {pair_label}")

    # STEP 1: Focal workers (year t+1) — filter to Lagos sample
    print(f"    Loading yearly_employers_{t1} (focal)...")
    df_focal = load_yearly_employers(t1)
    n_before = len(df_focal)
    df_focal = df_focal[df_focal["identificad"].isin(sample_ids)].copy()
    df_focal = df_focal.rename(columns={"identificad": "identificad_focal"})
    print(f"    Focal workers: {n_before:,} total → {len(df_focal):,} in Lagos sample")

    # STEP 2: Focal layer at year t+1
    # PARQUET_DEST_YEARS covers {2009, 2010, 2011}; year 2008 uses raw RAIS
    if t1 in PARQUET_DEST_YEARS:
        print(f"    Getting focal layer from parquet (year {t1})...")
        df_layer_focal = load_layer_from_parquet(t1, layerdef)
    else:
        print(f"    Getting focal layer from raw RAIS {t1}...")
        df_layer_focal = load_layer_from_raw_rais(t1, layerdef, for_origin=True)

    df_focal = _merge_focal_layer(df_focal, df_layer_focal, focal_col="identificad_focal")
    df_focal = df_focal[["PIS", "identificad_focal", "layer_id_focal"]].copy()
    print(f"    After layer join: {len(df_focal):,} workers with valid layer")

    # STEP 3: Contact firm (year t) from yearly_employers
    print(f"    Loading yearly_employers_{t} (contact)...")
    df_contact_emp = load_yearly_employers(t)
    df_contact_emp = df_contact_emp.rename(columns={"identificad": "identificad_contact"})

    # STEP 4: Left join focal → contact on PIS
    df = df_focal.merge(df_contact_emp, on="PIS", how="left")
    df["identificad_contact"] = df["identificad_contact"].fillna("")

    # Flag treated contact (origin must differ from focal firm)
    df["is_treated_contact"] = (
        df["identificad_contact"].isin(treated_ids) &
        (df["identificad_contact"] != df["identificad_focal"]) &
        (df["identificad_contact"] != "")
    ).astype(int)

    # is_mover: worker changed firms (regardless of origin)
    df["is_mover"] = (
        (df["identificad_contact"] != "") &
        (df["identificad_contact"] != df["identificad_focal"])
    ).astype(int)

    print(f"    Inflows from treated: {df['is_treated_contact'].sum():,} / {len(df):,}")

    # STEP 5: Contact layer at year t (all movers, for cross/within decomp)
    mover_mask = (
        (df["identificad_contact"] != "") &
        (df["identificad_contact"] != df["identificad_focal"])
    )
    mover_pis = set(df.loc[mover_mask, "PIS"])
    print(f"    Movers (any origin): {len(mover_pis):,}")

    # Contact year is t; use PARQUET_ORIGIN_YEARS = {2009, 2010}
    if t in PARQUET_ORIGIN_YEARS and mover_pis:
        print(f"    Getting contact layer from parquet (year {t})...")
        df_layer_contact = load_layer_from_parquet(t, layerdef)
        df_layer_contact = df_layer_contact[df_layer_contact["PIS"].isin(mover_pis)]
        df_layer_contact = df_layer_contact.rename(columns={
            "identificad": "identificad_contact",
            "layer_id": "layer_id_contact",
        })
    elif mover_pis:
        print(f"    Getting contact layer from raw RAIS {t} (semi-join)...")
        df_layer_contact = load_layer_from_raw_rais(
            t, layerdef, pis_filter=mover_pis, for_origin=False
        )
        df_layer_contact = df_layer_contact.rename(columns={
            "identificad": "identificad_contact",
            "layer_id": "layer_id_contact",
        })
    else:
        df_layer_contact = pd.DataFrame(
            columns=["PIS", "identificad_contact", "layer_id_contact"]
        )

    # Compound-key join eliminates fan-out
    df = df.merge(
        df_layer_contact[["PIS", "identificad_contact", "layer_id_contact"]],
        on=["PIS", "identificad_contact"], how="left"
    )

    # Clear contact layer for stayers
    non_mover_mask = (
        (df["identificad_contact"] == "") |
        (df["identificad_contact"] == df["identificad_focal"])
    )
    df.loc[non_mover_mask, "layer_id_contact"] = np.nan

    df["pair_label"] = pair_label
    df["record_type"] = "in"

    out = df[["identificad_focal", "layer_id_focal", "layer_id_contact",
              "pair_label", "record_type", "is_treated_contact", "is_mover"]].copy()
    out["layer_id_contact"] = out["layer_id_contact"].where(
        out["layer_id_contact"].notna() & (out["layer_id_contact"] != "nan"),
        other=np.nan
    )

    coverage = out["layer_id_contact"].notna().sum()
    print(f"    Contact layer coverage: {coverage:,} / {len(mover_pis):,} movers")

    return out


def process_pair(t: int, t1: int, layerdef: dict,
                 sample_ids: set, treated_ids: set) -> pd.DataFrame:
    """
    Build outflow + inflow transition records for a single year pair (t, t+1).
    Returns DataFrame with columns:
        identificad_focal, layer_id_focal, layer_id_contact,
        pair_label, record_type, is_treated_contact
    """
    pair_label = PAIR_LABELS[(t, t1)]
    print(f"\n--- Processing pair {pair_label} ---")

    df_out = compute_outflows(t, t1, layerdef, sample_ids, treated_ids)
    df_in  = compute_inflows(t, t1, layerdef, sample_ids, treated_ids)

    df_pair = pd.concat([df_out, df_in], ignore_index=True)
    print(f"  Pair {pair_label}: {len(df_out):,} outflow + {len(df_in):,} inflow = {len(df_pair):,} total")

    return df_pair


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
    n_out = (df_all["record_type"] == "out").sum()
    n_in  = (df_all["record_type"] == "in").sum()
    print(f"  Outflow records: {n_out:,}")
    print(f"  Inflow records:  {n_in:,}")
    print(f"Saving to {out_path}")
    df_all.to_parquet(out_path, index=False)
    print("Done.")


if __name__ == "__main__":
    main()
