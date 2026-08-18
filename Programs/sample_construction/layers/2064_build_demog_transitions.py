#!/usr/bin/env python3
"""
Script 2064: Build per-worker transition records with demographic layer assignment.

Handles two demographic dimensions:
  - gender: female / male  (from `genero` int column)
  - race:   white / nonwhite  (from `race_group` str in parquet; `raca_cor` int in raw RAIS)

Race exclusions: indigenous (1), Asian (6), missing (9) are dropped (NaN).

Usage:
    python 2064_build_demog_transitions.py --layer gender
    python 2064_build_demog_transitions.py --layer race
"""

import argparse
import os
import sys
import duckdb
import pandas as pd
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from layer_config import (
    YEAR_PAIRS, PAIR_LABELS,
    PARQUET_ORIGIN_YEARS, PARQUET_DEST_YEARS, IPCA,
    RAIS_DIR, RAIS_AUX, WORKER_PANEL_PARQUET,
    OUT_BASE, YEARLY_EMP_TEMPLATE, YEARLY_EMP_PARQUET_TEMPLATE,
)

# ---------------------------------------------------------------------------
# Demographic layer definitions (standalone — no LAYER_DEFS dependency)
# ---------------------------------------------------------------------------
DEMOG_LAYERS = {
    "gender": {
        "description":  "Gender: female / male",
        # SQL expression applied to worker_panel_lagos.parquet
        "parquet_expr": "CASE WHEN genero=0 THEN 'female' WHEN genero=1 THEN 'male' END",
        # Raw RAIS column name (years 2007/2008)
        "raw_col":      "genero",
        # Integer → layer_id mapping for raw RAIS
        "raw_map":      {0: "female", 1: "male"},
    },
    "race": {
        "description":  "Race: white / nonwhite (excludes indigenous, Asian, missing)",
        "parquet_expr": (
            "CASE WHEN race_group='branca' THEN 'white' "
            "WHEN race_group IN ('parda','preta') THEN 'nonwhite' END"
        ),
        "raw_col":      "raca_cor",
        # 2=white, 4=parda, 8=preta → nonwhite; others (1,6,9,...) → NaN (excluded)
        "raw_map":      {2: "white", 4: "nonwhite", 8: "nonwhite"},
    },
}


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--layer", required=True, choices=list(DEMOG_LAYERS.keys()),
                   help="Demographic layer to build")
    return p.parse_args()


def get_sample_and_treatment_ids():
    """Load Lagos sample and treated firm IDs (14-digit strings)."""
    treat_path   = os.path.join(RAIS_AUX, "lagos_treat.csv")
    control_path = os.path.join(RAIS_AUX, "lagos_control.csv")

    df_treat   = pd.read_csv(treat_path,   dtype=str)
    df_control = pd.read_csv(control_path, dtype=str)

    df_treat["identificad"]   = df_treat["identificad"].str[1:]
    df_control["identificad"] = df_control["identificad"].str[1:]

    treated_ids = set(df_treat.loc[df_treat["lagos_treat"]     == "1", "identificad"])
    sample_ids  = treated_ids | \
                  set(df_control.loc[df_control["lagos_control"] == "1", "identificad"])

    return sample_ids, treated_ids


def load_yearly_employers(year: int) -> pd.DataFrame:
    """Load yearly_employers_{year} from parquet cache or DTA fallback."""
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
    df = df.sort_values(["PIS", "identificad"]).drop_duplicates("PIS")
    return df


def load_layer_from_parquet(year: int, layerdef: dict) -> pd.DataFrame:
    """
    Load demographic layer for a given year from worker_panel_lagos.parquet.
    Uses a SQL CASE WHEN expression to map raw values to layer IDs.
    Returns DataFrame with columns: PIS (str), identificad (14-digit str), layer_id.
    """
    con = duckdb.connect()
    con.execute("PRAGMA threads=8")
    con.execute("PRAGMA memory_limit='32GB'")

    parquet_expr = layerdef["parquet_expr"]

    query = f"""
        SELECT
            CAST(PIS AS VARCHAR)         AS PIS,
            CAST(identificad AS VARCHAR) AS identificad,
            ({parquet_expr})             AS layer_id
        FROM read_parquet('{WORKER_PANEL_PARQUET}')
        WHERE year = {year}
          AND ({parquet_expr}) IS NOT NULL
        QUALIFY ROW_NUMBER() OVER (PARTITION BY PIS, identificad ORDER BY 1) = 1
    """
    df = con.execute(query).fetch_arrow_table().to_pandas()
    df["layer_id"] = df["layer_id"].astype(str)
    return df


def load_layer_from_raw_rais(year: int, layerdef: dict,
                              pis_filter: set = None,
                              for_origin: bool = True) -> pd.DataFrame:
    """
    Load demographic layer from raw RAIS_{year} (parquet or dta fallback).
    Applies Stage 1 spell selection (one per identificad × PIS).
    for_origin=True (default): also applies Stage 2 (one per PIS).
    Returns DataFrame with columns: PIS (str), identificad (14-digit str), layer_id.
    """
    raw_col       = layerdef["raw_col"]
    raw_map       = layerdef["raw_map"]
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

    df["PIS"]         = df["PIS"].astype(str)
    df["identificad"] = df["identificad"].astype(str)
    df["r_remdezr_h"] = (df["remdezr"] / ipca_deflator) / df["horascontr"].replace(0, np.nan)

    # Stage 1: one per (identificad × PIS) — pick highest hours, then highest hourly wage
    df = df.sort_values(["identificad", "PIS", "horascontr", "r_remdezr_h"],
                        ascending=[True, True, False, False])
    df = df.drop_duplicates(subset=["identificad", "PIS"], keep="first")

    if for_origin:
        # Stage 2: one per PIS — pick highest tenure, then highest hourly wage
        df = df.sort_values(["PIS", "tempempr", "r_remdezr_h"],
                            ascending=[True, False, False])
        df = df.drop_duplicates(subset=["PIS"], keep="first")

    # Map raw integer codes → layer_id string; unmapped → NaN (excluded)
    df["layer_id"] = df[raw_col].map(raw_map)

    df = df[["PIS", "identificad", "layer_id"]].dropna(subset=["layer_id"])
    df = df[df["layer_id"] != "nan"]
    return df


def _merge_focal_layer(df_workers: pd.DataFrame, df_layer: pd.DataFrame,
                        focal_col: str = "identificad_focal") -> pd.DataFrame:
    """
    Merge focal workers with layer data on PIS, keeping only matching firm rows.
    """
    df_layer = df_layer.drop_duplicates(subset=["PIS", "identificad"])
    df_merged = df_workers.merge(
        df_layer.rename(columns={"identificad": "identificad_layer"}),
        on="PIS", how="left",
    )
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
    """Outflow records: workers leaving focal firm i (year t) for treated firms in t+1."""
    pair_label = PAIR_LABELS[(t, t1)]
    print(f"  [outflows] pair {pair_label}")

    print(f"    Loading yearly_employers_{t} (focal)...")
    df_focal = load_yearly_employers(t)
    n_before = len(df_focal)
    df_focal = df_focal[df_focal["identificad"].isin(sample_ids)].copy()
    df_focal = df_focal.rename(columns={"identificad": "identificad_focal"})
    print(f"    Focal workers: {n_before:,} total → {len(df_focal):,} in Lagos sample")

    if t in PARQUET_ORIGIN_YEARS:
        print(f"    Getting focal layer from parquet (year {t})...")
        df_layer_focal = load_layer_from_parquet(t, layerdef)
    else:
        print(f"    Getting focal layer from raw RAIS {t}...")
        df_layer_focal = load_layer_from_raw_rais(t, layerdef, for_origin=True)

    df_focal = _merge_focal_layer(df_focal, df_layer_focal, focal_col="identificad_focal")
    df_focal = df_focal[["PIS", "identificad_focal", "layer_id_focal"]].copy()
    print(f"    After layer join: {len(df_focal):,} workers with valid layer")

    print(f"    Loading yearly_employers_{t1} (contact)...")
    df_contact = load_yearly_employers(t1)
    df_contact = df_contact.rename(columns={"identificad": "identificad_contact"})

    df = df_focal.merge(df_contact, on="PIS", how="left")
    df["identificad_contact"] = df["identificad_contact"].fillna("")

    df["is_treated_contact"] = (
        df["identificad_contact"].isin(treated_ids) &
        (df["identificad_contact"] != df["identificad_focal"]) &
        (df["identificad_contact"] != "")
    ).astype(int)

    df["is_mover"] = (
        (df["identificad_contact"] != "") &
        (df["identificad_contact"] != df["identificad_focal"])
    ).astype(int)

    print(f"    Outflows to treated: {df['is_treated_contact'].sum():,} / {len(df):,}")

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

    df = df.merge(
        df_layer_contact[["PIS", "identificad_contact", "layer_id_contact"]],
        on=["PIS", "identificad_contact"], how="left"
    )

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
    """Inflow records: workers arriving at focal firm i (year t+1) from treated firms in t."""
    pair_label = PAIR_LABELS[(t, t1)]
    print(f"  [inflows] pair {pair_label}")

    print(f"    Loading yearly_employers_{t1} (focal)...")
    df_focal = load_yearly_employers(t1)
    n_before = len(df_focal)
    df_focal = df_focal[df_focal["identificad"].isin(sample_ids)].copy()
    df_focal = df_focal.rename(columns={"identificad": "identificad_focal"})
    print(f"    Focal workers: {n_before:,} total → {len(df_focal):,} in Lagos sample")

    if t1 in PARQUET_DEST_YEARS:
        print(f"    Getting focal layer from parquet (year {t1})...")
        df_layer_focal = load_layer_from_parquet(t1, layerdef)
    else:
        print(f"    Getting focal layer from raw RAIS {t1}...")
        df_layer_focal = load_layer_from_raw_rais(t1, layerdef, for_origin=True)

    df_focal = _merge_focal_layer(df_focal, df_layer_focal, focal_col="identificad_focal")
    df_focal = df_focal[["PIS", "identificad_focal", "layer_id_focal"]].copy()
    print(f"    After layer join: {len(df_focal):,} workers with valid layer")

    print(f"    Loading yearly_employers_{t} (contact)...")
    df_contact_emp = load_yearly_employers(t)
    df_contact_emp = df_contact_emp.rename(columns={"identificad": "identificad_contact"})

    df = df_focal.merge(df_contact_emp, on="PIS", how="left")
    df["identificad_contact"] = df["identificad_contact"].fillna("")

    df["is_treated_contact"] = (
        df["identificad_contact"].isin(treated_ids) &
        (df["identificad_contact"] != df["identificad_focal"]) &
        (df["identificad_contact"] != "")
    ).astype(int)

    df["is_mover"] = (
        (df["identificad_contact"] != "") &
        (df["identificad_contact"] != df["identificad_focal"])
    ).astype(int)

    print(f"    Inflows from treated: {df['is_treated_contact'].sum():,} / {len(df):,}")

    mover_mask = (
        (df["identificad_contact"] != "") &
        (df["identificad_contact"] != df["identificad_focal"])
    )
    mover_pis = set(df.loc[mover_mask, "PIS"])
    print(f"    Movers (any origin): {len(mover_pis):,}")

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

    df = df.merge(
        df_layer_contact[["PIS", "identificad_contact", "layer_id_contact"]],
        on=["PIS", "identificad_contact"], how="left"
    )

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
    """Build outflow + inflow transition records for a single year pair."""
    pair_label = PAIR_LABELS[(t, t1)]
    print(f"\n--- Processing pair {pair_label} ---")

    df_out = compute_outflows(t, t1, layerdef, sample_ids, treated_ids)
    df_in  = compute_inflows(t, t1, layerdef, sample_ids, treated_ids)

    df_pair = pd.concat([df_out, df_in], ignore_index=True)
    print(f"  Pair {pair_label}: {len(df_out):,} outflow + {len(df_in):,} inflow = {len(df_pair):,} total")

    return df_pair


def main():
    args = parse_args()
    layerdef = DEMOG_LAYERS[args.layer]
    print(f"Layer: {args.layer} — {layerdef['description']}")

    out_dir = os.path.join(OUT_BASE, "transitions_base")
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, f"transitions_{args.layer}.parquet")

    print("Loading sample and treatment IDs...")
    sample_ids, treated_ids = get_sample_and_treatment_ids()
    print(f"  Lagos sample firms: {len(sample_ids):,}")
    print(f"  Treated firms:      {len(treated_ids):,}")

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
