#!/usr/bin/env python3
"""
Script 2063: Compute layer-level totalflows_layer_pw for all 4 pre-treatment
year pairs (0708, 0809, 0910, 1011) and add totalflows_layer_pw_n to the
existing firm_layer_connectivity_{edu,edu2}.dta files.

The measure mirrors what scripts 01 → 02 → 03 would produce for is_mover,
but is faster because we do NOT need contact-layer tracking:
  - total outflow movers = workers at focal firm in t who are at a DIFFERENT
    firm in t+1 (from yearly_employers join — no raw-RAIS contact needed)
  - total inflow movers  = workers at focal firm in t+1 who came from a
    DIFFERENT firm in t
  - totalflows_layer_pw  = (M_out_any + M_in_any) / E_avg per (firm, layer)

Focal-year layer assignment:
  - Year 2009, 2010 → worker_panel_lagos.parquet  (fast)
  - Year 2007, 2008 → raw RAIS_{year}.dta with spell-selection algorithm
    (same logic as 2061_build_transitions.py, but only loading grinstrucao)

NaN-aware average over 4 pairs → totalflows_layer_pw_n, which is then
merged into the existing connectivity DTA files in place.

Usage:
    python 2063_totalflows_layer.py
"""

import os
import sys
import warnings

import duckdb
import numpy as np
import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from layer_config import (
    PAIR_LABELS, YEAR_PAIRS,
    PARQUET_ORIGIN_YEARS,      # {2009, 2010}
    RAIS_DIR, RAIS_AUX, OUT_BASE,
    WORKER_PANEL_PARQUET, YEARLY_EMP_TEMPLATE, YEARLY_EMP_PARQUET_TEMPLATE,
    IPCA,
)

EDU2_REMAP = {"0_no_hs": "no_hs", "1_hs": "has_hs", "2_higher": "has_hs"}


# ──────────────────────────────────────────────────────────────────────────────
# Data loaders
# ──────────────────────────────────────────────────────────────────────────────

def get_sample_ids() -> set:
    """Lagos sample firm IDs (14-digit strings, leading '1' stripped)."""
    treat_path   = os.path.join(RAIS_AUX, "lagos_treat.csv")
    control_path = os.path.join(RAIS_AUX, "lagos_control.csv")
    df_t = pd.read_csv(treat_path,   dtype=str)
    df_c = pd.read_csv(control_path, dtype=str)
    df_t["identificad"] = df_t["identificad"].str[1:]
    df_c["identificad"] = df_c["identificad"].str[1:]
    return (set(df_t.loc[df_t["lagos_treat"]   == "1", "identificad"]) |
            set(df_c.loc[df_c["lagos_control"] == "1", "identificad"]))


def load_yearly_employers(year: int) -> pd.DataFrame:
    """Return DataFrame(PIS:str, identificad:str) from parquet cache or DTA fallback."""
    parquet_path = YEARLY_EMP_PARQUET_TEMPLATE.format(year=year)
    if os.path.exists(parquet_path):
        df = pd.read_parquet(parquet_path)
        df["PIS"]         = df["PIS"].astype(str)
        df["identificad"] = df["identificad"].astype(str)
    else:
        col_id = f"identificad_{year}"
        df = pd.read_stata(YEARLY_EMP_TEMPLATE.format(year=year),
                           columns=["PIS", col_id])
        df = df.rename(columns={col_id: "identificad"})
        df["PIS"]         = df["PIS"].astype(str)
        df["identificad"] = df["identificad"].astype(str)
    df = df.sort_values(["PIS", "identificad"]).drop_duplicates("PIS")
    return df


def load_focal_layer_parquet(year: int) -> pd.DataFrame:
    """
    Load (PIS, identificad, educ_bin) from worker_panel_lagos.parquet.
    One row per PIS (the spell-selection has already been applied).
    """
    con = duckdb.connect()
    con.execute("PRAGMA threads=8")
    con.execute("PRAGMA memory_limit='32GB'")
    q = f"""
        SELECT
            CAST(PIS         AS VARCHAR) AS PIS,
            CAST(identificad AS VARCHAR) AS identificad,
            CAST(educ_bin    AS VARCHAR) AS educ_bin
        FROM read_parquet('{WORKER_PANEL_PARQUET}')
        WHERE year = {year}
          AND educ_bin IS NOT NULL
          AND educ_bin != 'nan'
        QUALIFY ROW_NUMBER() OVER (PARTITION BY PIS ORDER BY 1) = 1
    """
    return con.execute(q).fetch_arrow_table().to_pandas()


def load_focal_layer_rais(year: int) -> pd.DataFrame:
    """
    Load (PIS, identificad, educ_bin) from raw RAIS_{year}.dta.
    Applies the same spell-selection algorithm as 2061_build_transitions.py:
      Stage 1: one per (identificad × PIS) by hours then hourly wage
      Stage 2: one per PIS by tenure then hourly wage
    Only loads columns needed for layer assignment + spell selection.
    """
    ipca = IPCA[year]
    rais_path = os.path.join(RAIS_DIR, f"RAIS_{year}.dta")
    cols = ["PIS", "identificad", "horascontr", "remdezr",
            "tempempr", "empem3112", "grinstrucao"]

    print(f"    Reading raw RAIS {year}...")
    chunks = []
    reader = pd.read_stata(rais_path, columns=cols, chunksize=500_000,
                           convert_categoricals=False)
    for chunk in reader:
        chunk = chunk[chunk["empem3112"] == 1]
        chunk = chunk[chunk["tempempr"]  > 1]
        chunks.append(chunk)
    df = pd.concat(chunks, ignore_index=True)

    df["PIS"]         = df["PIS"].astype(str)
    df["identificad"] = df["identificad"].astype(str)
    df["remdezr_h"]   = (df["remdezr"] / ipca) / df["horascontr"].replace(0, np.nan)

    # Stage 1: one per (identificad × PIS)
    df = df.sort_values(["identificad", "PIS", "horascontr", "remdezr_h"],
                        ascending=[True, True, False, False])
    df = df.drop_duplicates(subset=["identificad", "PIS"], keep="first")

    # Stage 2: one per PIS
    df = df.sort_values(["PIS", "tempempr", "remdezr_h"],
                        ascending=[True, False, False])
    df = df.drop_duplicates(subset=["PIS"], keep="first")

    # Assign educ_bin exactly as layer_config.edu "compute" does
    df["educ_bin"] = pd.cut(
        df["grinstrucao"].astype(float),
        bins=[0, 6, 8, 11],
        labels=["0_no_hs", "1_hs", "2_higher"],
    ).astype(str)
    df = df[df["educ_bin"] != "nan"]

    print(f"    RAIS {year}: {len(df):,} workers with valid edu layer")
    return df[["PIS", "identificad", "educ_bin"]].copy()


def load_focal_layer(year: int) -> pd.DataFrame:
    """Dispatch to parquet or raw RAIS based on availability."""
    if year in PARQUET_ORIGIN_YEARS:
        print(f"    Getting focal layer from parquet (year {year})...")
        return load_focal_layer_parquet(year)
    else:
        return load_focal_layer_rais(year)


# ──────────────────────────────────────────────────────────────────────────────
# Core computation
# ──────────────────────────────────────────────────────────────────────────────

def compute_pair_flows(t: int, t1: int,
                       sample_ids: set,
                       df_layer_t:  pd.DataFrame,
                       df_layer_t1: pd.DataFrame) -> pd.DataFrame:
    """
    Compute (firm, educ_bin, pair_label, totalflows_layer_pw) for one year pair.

    df_layer_t  = (PIS, identificad, educ_bin) for focal year t
    df_layer_t1 = (PIS, identificad, educ_bin) for contact year t+1
                  Only PIS and identificad columns are used from df_layer_t1.
    """
    label = PAIR_LABELS[(t, t1)]
    print(f"  Computing pair {label}...")

    # yearly_employers (firm assignment, includes all workers)
    print(f"    Loading yearly_employers {t} and {t1}...")
    emp_t  = load_yearly_employers(t)
    emp_t1 = load_yearly_employers(t1)

    # Restrict focal firms to Lagos sample
    emp_t_sample  = emp_t [emp_t ["identificad"].isin(sample_ids)]
    emp_t1_sample = emp_t1[emp_t1["identificad"].isin(sample_ids)]

    # ── OUTFLOWS ──────────────────────────────────────────────────────────────
    # Workers at focal firm in t: are they at a DIFFERENT firm in t+1?
    df_out = emp_t_sample.rename(columns={"identificad": "id_focal"}).copy()
    # Join to year-t1 employers (all firms, not just sample) for mover detection
    df_out = df_out.merge(
        emp_t1[["PIS", "identificad"]].rename(columns={"identificad": "id_t1"}),
        on="PIS", how="left"
    )
    df_out["id_t1"]       = df_out["id_t1"].fillna("")
    df_out["is_mover_out"] = (
        (df_out["id_t1"] != "") & (df_out["id_t1"] != df_out["id_focal"])
    ).astype(int)

    # Attach focal layer (only for workers whose firm matches df_layer_t)
    df_out = df_out.merge(
        df_layer_t[["PIS", "identificad", "educ_bin"]]
                  .rename(columns={"identificad": "id_layer"}),
        on="PIS", how="left"
    )
    # Keep only rows where yearly_employers matches layer-source firm
    df_out = df_out[
        df_out["id_layer"].isna() | (df_out["id_focal"] == df_out["id_layer"])
    ].copy()
    df_out = df_out[df_out["educ_bin"].notna() & (df_out["educ_bin"] != "nan")]

    agg_out = (df_out.groupby(["id_focal", "educ_bin"])
               .agg(E_t=("PIS", "count"), M_out=("is_mover_out", "sum"))
               .reset_index()
               .rename(columns={"id_focal": "identificad"}))

    # ── INFLOWS ───────────────────────────────────────────────────────────────
    # Workers at focal firm in t+1: did they come from a DIFFERENT firm in t?
    df_in = emp_t1_sample.rename(columns={"identificad": "id_focal"}).copy()
    df_in = df_in.merge(
        emp_t[["PIS", "identificad"]].rename(columns={"identificad": "id_t"}),
        on="PIS", how="left"
    )
    df_in["id_t"]        = df_in["id_t"].fillna("")
    df_in["is_mover_in"] = (
        (df_in["id_t"] != "") & (df_in["id_t"] != df_in["id_focal"])
    ).astype(int)

    # Attach focal layer for t+1 workers
    df_in = df_in.merge(
        df_layer_t1[["PIS", "identificad", "educ_bin"]]
                   .rename(columns={"identificad": "id_layer"}),
        on="PIS", how="left"
    )
    df_in = df_in[
        df_in["id_layer"].isna() | (df_in["id_focal"] == df_in["id_layer"])
    ].copy()
    df_in = df_in[df_in["educ_bin"].notna() & (df_in["educ_bin"] != "nan")]

    agg_in = (df_in.groupby(["id_focal", "educ_bin"])
              .agg(E_t1=("PIS", "count"), M_in=("is_mover_in", "sum"))
              .reset_index()
              .rename(columns={"id_focal": "identificad"}))

    # ── COMBINE ───────────────────────────────────────────────────────────────
    df = agg_out.merge(agg_in, on=["identificad", "educ_bin"], how="outer")
    for col in ["E_t", "M_out", "E_t1", "M_in"]:
        df[col] = df[col].fillna(0).astype(float)

    df["E_avg"]              = (df["E_t"] + df["E_t1"]) / 2.0
    df["totalflows_layer_pw"] = ((df["M_out"] + df["M_in"])
                                  / df["E_avg"].replace(0, np.nan))
    df["pair_label"] = label

    print(f"    Rows: {len(df):,}  |  "
          f"Mean M_out: {df['M_out'].mean():.1f}  "
          f"M_in: {df['M_in'].mean():.1f}  "
          f"ratio: {df['totalflows_layer_pw'].mean():.4f}")
    return df[["identificad", "educ_bin", "pair_label",
               "totalflows_layer_pw"]].copy()


# ──────────────────────────────────────────────────────────────────────────────
# NaN-aware average + DTA update
# ──────────────────────────────────────────────────────────────────────────────

def nan_aware_avg(df: pd.DataFrame, cols: list) -> pd.Series:
    existing = [c for c in cols if c in df.columns]
    if not existing:
        return pd.Series(np.nan, index=df.index)
    vals  = df[existing]
    n     = vals.notna().sum(axis=1)
    total = vals.sum(axis=1, min_count=1)
    return np.where(n > 0, total / n, np.nan)


def update_dta(layer: str, df_all: pd.DataFrame):
    """Compute wide + NaN-avg and write back to connectivity parquet (and DTA)."""
    parquet_path = os.path.join(OUT_BASE, "final_measures",
                                f"firm_layer_connectivity_{layer}.parquet")
    dta_path     = os.path.join(OUT_BASE, "final_measures",
                                f"firm_layer_connectivity_{layer}.dta")
    print(f"\nUpdating {dta_path}...")

    df = df_all.copy()

    # Apply edu/edu2 layer mapping
    if layer == "edu":
        df["layer_id"] = df["educ_bin"]
    elif layer == "edu2":
        df["layer_id"] = df["educ_bin"].map(EDU2_REMAP)
        df = df.dropna(subset=["layer_id"])
    else:
        raise ValueError(f"Unknown layer: {layer}")

    # Pivot to wide: one row per (identificad, layer_id)
    df_wide = df.pivot_table(
        index=["identificad", "layer_id"],
        columns="pair_label",
        values="totalflows_layer_pw",
        aggfunc="first",
    ).reset_index()
    df_wide.columns.name = None

    pairs = list(PAIR_LABELS.values())  # ["0708","0809","0910","1011"]
    rename_map = {p: f"totalflows_layer_pw_{p}" for p in pairs if p in df_wide.columns}
    df_wide = df_wide.rename(columns=rename_map)

    pair_cols = [f"totalflows_layer_pw_{p}" for p in pairs]
    df_wide["totalflows_layer_pw_n"] = nan_aware_avg(df_wide, pair_cols)
    df_wide["totalflows_layer_pw_count_n"] = (
        df_wide[[c for c in pair_cols if c in df_wide.columns]]
        .notna().sum(axis=1).astype(float)
    )

    print(f"  Wide rows: {len(df_wide):,}")
    print(f"  totalflows_layer_pw_n: "
          f"non-null={df_wide['totalflows_layer_pw_n'].notna().sum():,}  "
          f"mean={df_wide['totalflows_layer_pw_n'].mean():.4f}")

    # Load existing connectivity file (parquet preferred, DTA fallback)
    src_path = parquet_path if os.path.exists(parquet_path) else dta_path
    df_dta = pd.read_parquet(src_path) if src_path.endswith(".parquet") else pd.read_stata(src_path)
    df_dta["identificad"] = df_dta["identificad"].astype(str)
    df_dta["layer_id"]    = df_dta["layer_id"].astype(str)

    # Drop any pre-existing totalflows_layer_pw columns
    drop_cols = [c for c in df_dta.columns if c.startswith("totalflows_layer_pw")]
    if drop_cols:
        print(f"  Dropping existing columns: {drop_cols}")
        df_dta = df_dta.drop(columns=drop_cols)

    new_cols = (pair_cols
                + ["totalflows_layer_pw_n", "totalflows_layer_pw_count_n"])
    df_wide["identificad"] = df_wide["identificad"].astype(str)
    df_wide["layer_id"]    = df_wide["layer_id"].astype(str)

    df_out = df_dta.merge(
        df_wide[["identificad", "layer_id"] + [c for c in new_cols if c in df_wide.columns]],
        on=["identificad", "layer_id"], how="left"
    )

    n_matched = df_out["totalflows_layer_pw_n"].notna().sum()
    print(f"  Matched {n_matched:,} / {len(df_out):,} rows")

    df_out.to_parquet(parquet_path, index=False)
    df_out.to_stata(dta_path, write_index=False, version=118)
    print(f"  Saved parquet + DTA.")


# ──────────────────────────────────────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────────────────────────────────────

def main():
    import subprocess

    print("Computing layer-level totalflows for all 4 pre-treatment year pairs.")
    print("Focal-year layers: parquet (2009-10), raw RAIS (2007-08).\n")

    sample_ids = get_sample_ids()
    print(f"Lagos sample firms: {len(sample_ids):,}\n")

    # Pre-load focal-year layers (shared across pairs that use the same year)
    # Years needed as FOCAL: 2007 (0708), 2008 (0809), 2009 (0809-inflow, 0910),
    #                         2010 (0910-inflow, 1011), 2011 (1011-inflow)
    # The function caches nothing; we load each year once and reuse.
    print("Loading focal-year layers...")
    layers = {}
    for year in [2007, 2008, 2009, 2010, 2011]:
        print(f"  Year {year}:")
        layers[year] = load_focal_layer(year)
        print(f"    → {len(layers[year]):,} workers")

    # Compute flows for all 4 pairs
    all_pairs = []
    for (t, t1) in YEAR_PAIRS:
        df_pair = compute_pair_flows(
            t, t1,
            sample_ids,
            df_layer_t=layers[t],
            df_layer_t1=layers[t1],
        )
        all_pairs.append(df_pair)

    df_all = pd.concat(all_pairs, ignore_index=True)
    print(f"\nTotal rows across 4 pairs: {len(df_all):,}")

    # Update both connectivity DTAs
    for layer in ["edu", "edu2"]:
        update_dta(layer, df_all)

    subprocess.run([
        "curl", "-s", "-o", "/dev/null",
        "-H", "Title: Done",
        "-d", "totalflows_layer_pw_n added to connectivity DTAs (all 4 pairs)",
        "https://ntfy.sh/lgg3230-kellogg",
    ])
    print("\nDone.")


if __name__ == "__main__":
    main()
