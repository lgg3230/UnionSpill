#!/usr/bin/env python3
"""
Script 06b (demog): Build firm × layer × year outcomes for demographic layers
(gender, race) with zero-employment cells.

Mirrors 06_prep_demog_outcomes.py but fills in zero-employment cells so that all
(firm × layer × year) combinations are present in the output, not just those where
the firm has workers with positive wages in that layer.

Key differences from 06_prep_demog_outcomes.py:
  - layer_emp = 0 for firm-layer-year cells with no workers (not dropped)
  - l1p_layer_emp = ln(1 + layer_emp)  — valid at zero, used as employment outcome
  - l_layer_emp   = ln(layer_emp)       — NaN at zero, kept for wage regression controls
  - lr_remdezr_layer / lr_remdezr_h_layer stay NaN at zero (wages unobservable)

Universe of zero cells: all (firm, year) pairs where the firm employs anyone in any
layer in that year × all layers. A firm with zero total employment in a year is
absent from the worker panel and so receives no zero cells.

Outputs:
    Data/layer_connectivity/firm_layer_outcomes_gender_full.dta
    Data/layer_connectivity/firm_layer_outcomes_race_full.dta

Usage:
    python 06b_prep_demog_outcomes.py
    python 06b_prep_demog_outcomes.py --layer gender
    python 06b_prep_demog_outcomes.py --layer race
"""

import argparse
import os
import sys

import duckdb
import numpy as np
import pandas as pd
import subprocess

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from layer_config import IPCA, OUT_BASE, WORKER_PANEL_PARQUET


def ipca_case_sql() -> str:
    clauses = " ".join(f"WHEN year = {year} THEN {value}" for year, value in sorted(IPCA.items()))
    return f"CASE {clauses} ELSE NULL END"

DEMOG_OUTCOME_DEFS = {
    "gender": {
        "layer_expr":  "CASE WHEN genero = 0 THEN 'female' WHEN genero = 1 THEN 'male' END",
        "null_filter": "genero IS NOT NULL",
        "all_layers":  ["female", "male"],
    },
    "race": {
        "layer_expr": (
            "CASE WHEN race_group = 'branca' THEN 'white' "
            "     WHEN race_group IN ('parda', 'preta') THEN 'nonwhite' END"
        ),
        "null_filter": "race_group IN ('branca', 'parda', 'preta')",
        "all_layers":  ["white", "nonwhite"],
    },
    "occ4": {
        "layer_expr": (
            "CASE "
            "  WHEN FLOOR(ocup2002 / 100000) = 1       THEN '1_mgr' "
            "  WHEN FLOOR(ocup2002 / 100000) IN (2, 3) THEN '23_high' "
            "  WHEN FLOOR(ocup2002 / 100000) = 4       THEN '4_bur' "
            "  WHEN FLOOR(ocup2002 / 100000) >= 5      THEN '5p_low' "
            "  ELSE NULL "
            "END"
        ),
        "null_filter": "ocup2002 IS NOT NULL AND ocup2002 >= 1000",
        "all_layers":  ["1_mgr", "23_high", "4_bur", "5p_low"],
    },
}


def build_outcomes(layer: str) -> pd.DataFrame:
    defn        = DEMOG_OUTCOME_DEFS[layer]
    layer_expr  = defn["layer_expr"]
    null_filter = defn["null_filter"]
    all_layers  = defn["all_layers"]

    ipca_case = ipca_case_sql()

    con = duckdb.connect()
    con.execute("PRAGMA threads=8")
    con.execute("PRAGMA memory_limit='32GB'")

    # --- Step 1: wage/employment aggregates for cells with positive wages ---
    agg_query = f"""
        SELECT
            CAST(identificad AS VARCHAR)                    AS identificad,
            ({layer_expr})                                  AS layer_id,
            year,
            COUNT(PIS)                                      AS layer_emp,
            AVG(lr_remdezr)                                 AS lr_remdezr_layer,
            AVG(LN((remdezr / NULLIF(horascontr * 4.348, 0)) / ({ipca_case}))) AS lr_remdezr_h_layer
        FROM read_parquet('{WORKER_PANEL_PARQUET}')
        WHERE {null_filter}
          AND ({layer_expr}) IS NOT NULL
          AND remdezr    > 0
          AND horascontr > 0
        GROUP BY identificad, ({layer_expr}), year
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
    parser = argparse.ArgumentParser()
    parser.add_argument("--layer", choices=list(DEMOG_OUTCOME_DEFS.keys()),
                        default=None,
                        help="Layer to build (default: both)")
    args = parser.parse_args()

    layers = [args.layer] if args.layer else list(DEMOG_OUTCOME_DEFS.keys())

    os.makedirs(OUT_BASE, exist_ok=True)

    for layer in layers:
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
        "-d", f"Zero-filled demog outcomes complete: {', '.join(layers)}",
        "https://ntfy.sh/lgg3230-kellogg",
    ])
    print("\nDone.")


if __name__ == "__main__":
    main()
