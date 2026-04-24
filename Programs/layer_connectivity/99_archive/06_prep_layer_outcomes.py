#!/usr/bin/env python3
"""
Script 06: Build firm × layer × year outcomes from worker_panel_lagos.parquet.

The parquet already applies the spell-selection algorithm (one spell per
PIS × year), so COUNT(PIS) gives layer employment directly.

Outputs:
    Data/layer_connectivity/firm_layer_outcomes_edu.dta   (3-bin: 0_no_hs/1_hs/2_higher)
    Data/layer_connectivity/firm_layer_outcomes_edu2.dta  (2-bin: no_hs/has_hs)

Usage:
    python 06_prep_layer_outcomes.py
"""

import os
import sys
import subprocess

import duckdb
import numpy as np
import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from layer_config import OUT_BASE, WORKER_PANEL_PARQUET


def build_outcomes(layer: str) -> pd.DataFrame:
    con = duckdb.connect()
    con.execute("PRAGMA threads=8")
    con.execute("PRAGMA memory_limit='32GB'")

    if layer == "edu":
        layer_expr  = "CAST(educ_bin AS VARCHAR)"
        group_by    = "identificad, educ_bin, year"
    elif layer == "edu2":
        layer_expr  = ("CASE WHEN educ_bin = '0_no_hs' THEN 'no_hs' "
                       "ELSE 'has_hs' END")
        group_by    = "identificad, layer_id, year"
    else:
        raise ValueError(f"Unknown layer: {layer}")

    query = f"""
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
          AND remdezr > 0
          AND horascontr > 0
        GROUP BY {group_by}
    """

    df = con.execute(query).fetch_arrow_table().to_pandas()
    df["l_layer_emp"] = np.log(df["layer_emp"].replace(0, np.nan))
    return df


def main():
    os.makedirs(OUT_BASE, exist_ok=True)

    for layer in ["edu", "edu2"]:
        print(f"\nBuilding outcomes for layer: {layer}")
        df = build_outcomes(layer)
        print(f"  Rows:         {len(df):,}")
        print(f"  Year range:   {df['year'].min()} – {df['year'].max()}")
        print(f"  Unique firms: {df['identificad'].nunique():,}")
        print(f"  Layers:       {sorted(df['layer_id'].unique())}")

        out_parquet = os.path.join(OUT_BASE, f"firm_layer_outcomes_{layer}.parquet")
        out_dta     = os.path.join(OUT_BASE, f"firm_layer_outcomes_{layer}.dta")
        df.to_parquet(out_parquet, index=False)
        df.to_stata(out_dta, write_index=False, version=118)
        print(f"  Saved to {out_parquet} and {out_dta}")

    subprocess.run([
        "curl", "-s", "-o", "/dev/null",
        "-H", "Title: Done",
        "-d", "Layer outcomes prep complete (edu + edu2)",
        "https://ntfy.sh/lgg3230-kellogg",
    ])
    print("\nDone.")


if __name__ == "__main__":
    main()
