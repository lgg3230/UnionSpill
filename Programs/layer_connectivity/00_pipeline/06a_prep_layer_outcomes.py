#!/usr/bin/env python3
"""
Script 06b: Build firm × layer × year outcomes (edu / edu2) with zero-employment cells.

Mirrors 06_prep_layer_outcomes.py but fills in zero-employment cells so that all
(firm × layer × year) combinations are present in the output, not just those where
the firm has workers with positive wages in that layer.

Key differences from 06_prep_layer_outcomes.py:
  - layer_emp = 0 for firm-layer-year cells with no workers (not dropped)
  - l1p_layer_emp = ln(1 + layer_emp)  — valid at zero, used as employment outcome
  - l_layer_emp   = ln(layer_emp)       — NaN at zero, kept for wage regression controls
  - lr_remdezr_layer / lr_remdezr_h_layer stay NaN at zero (wages unobservable)

Universe of zero cells: all (firm, year) pairs where the firm employs anyone in any
layer in that year × all layers. A firm with zero total employment in a year is
absent from the worker panel and so receives no zero cells.

Outputs:
    Data/layer_connectivity/firm_layer_outcomes_edu_full.dta
    Data/layer_connectivity/firm_layer_outcomes_edu2_full.dta

Usage:
    python 06b_prep_layer_outcomes.py
"""

import os
import sys
import subprocess

import duckdb
import numpy as np
import pandas as pd

sys.path.insert(0, os.path.dirname(__file__))
from layer_config import OUT_BASE, WORKER_PANEL_PARQUET


def build_outcomes(layer: str) -> pd.DataFrame:
    con = duckdb.connect()
    con.execute("PRAGMA threads=8")
    con.execute("PRAGMA memory_limit='32GB'")

    if layer == "edu":
        layer_expr = "CAST(educ_bin AS VARCHAR)"
        group_by   = "identificad, educ_bin, year"
        all_layers = ["0_no_hs", "1_hs", "2_higher"]
    elif layer == "edu2":
        layer_expr = ("CASE WHEN educ_bin = '0_no_hs' THEN 'no_hs' "
                      "ELSE 'has_hs' END")
        group_by   = "identificad, layer_id, year"
        all_layers = ["no_hs", "has_hs"]
    else:
        raise ValueError(f"Unknown layer: {layer}")

    # --- Step 1: wage/employment aggregates for cells with positive wages ---
    agg_query = f"""
        SELECT
            CAST(identificad AS VARCHAR)   AS identificad,
            {layer_expr}                   AS layer_id,
            year,
            COUNT(PIS)                     AS layer_emp,
            AVG(lr_remdezr)                AS lr_remdezr_layer,
            AVG(LOG(remdezr / NULLIF(horascontr, 0))) AS lr_remdezr_h_layer
        FROM read_parquet('{WORKER_PANEL_PARQUET}')
        WHERE educ_bin IS NOT NULL
          AND educ_bin != 'nan'
          AND remdezr    > 0
          AND horascontr > 0
        GROUP BY {group_by}
    """
    df_agg = con.execute(agg_query).fetch_arrow_table().to_pandas()

    # --- Step 2: complete grid of (firm × layer × year) with zero fill ---
    # Use (firm, year) pairs from the aggregated data: any firm that employs
    # at least one worker with positive wages in any layer in that year.
    firm_years = df_agg[["identificad", "year"]].drop_duplicates().reset_index(drop=True)
    grid = firm_years.merge(pd.DataFrame({"layer_id": all_layers}), how="cross")
    df = grid.merge(df_agg, on=["identificad", "layer_id", "year"], how="left")

    df["layer_emp"]     = df["layer_emp"].fillna(0).astype(int)
    df["l1p_layer_emp"] = np.log1p(df["layer_emp"])
    # l_layer_emp: NaN for zero-employment cells (wages require positive employment)
    df["l_layer_emp"]   = np.log(df["layer_emp"].replace(0, np.nan))

    return df


def main():
    os.makedirs(OUT_BASE, exist_ok=True)

    for layer in ["edu", "edu2"]:
        print(f"\nBuilding zero-filled outcomes for layer: {layer}")
        df = build_outcomes(layer)
        print(f"  Rows:              {len(df):,}")
        print(f"  Year range:        {df['year'].min()} – {df['year'].max()}")
        print(f"  Unique firms:      {df['identificad'].nunique():,}")
        print(f"  Layers:            {sorted(df['layer_id'].unique())}")
        n_zero = (df["layer_emp"] == 0).sum()
        print(f"  Zero-emp cells:    {n_zero:,}  ({100 * n_zero / len(df):.1f}%)")

        out_parquet = os.path.join(OUT_BASE, f"firm_layer_outcomes_{layer}_full.parquet")
        out_dta     = os.path.join(OUT_BASE, f"firm_layer_outcomes_{layer}_full.dta")
        df.to_parquet(out_parquet, index=False)
        df.to_stata(out_dta, write_index=False, version=118)
        print(f"  Saved to {out_parquet} and {out_dta}")

    subprocess.run([
        "curl", "-s", "-o", "/dev/null",
        "-H", "Title: Done",
        "-d", "Zero-filled layer outcomes prep complete (edu + edu2)",
        "https://ntfy.sh/lgg3230-kellogg",
    ])
    print("\nDone.")


if __name__ == "__main__":
    main()
