#!/usr/bin/env python3
"""
Script 06d: Build firm × layer × year outcomes from worker_panel_lagos.parquet
for demographic layers (gender, race).

Mirrors 06_prep_layer_outcomes.py but handles the two-level demographic splits:
  - gender:  female / male
  - race:    white / nonwhite  (excludes indigenous, Asian, missing)

Outputs:
    Data/layer_connectivity/firm_layer_outcomes_gender.dta
    Data/layer_connectivity/firm_layer_outcomes_race.dta

Usage:
    python 06_prep_demog_outcomes.py
    python 06_prep_demog_outcomes.py --layer gender
    python 06_prep_demog_outcomes.py --layer race
"""

import argparse
import os
import sys

import duckdb
import numpy as np
import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from layer_config import OUT_BASE, WORKER_PANEL_PARQUET

# ---------------------------------------------------------------------------
# Layer definitions: SQL expression over worker_panel_lagos.parquet
# ---------------------------------------------------------------------------
DEMOG_OUTCOME_DEFS = {
    "gender": {
        "layer_expr":  "CASE WHEN genero = 0 THEN 'female' WHEN genero = 1 THEN 'male' END",
        "null_filter": "genero IS NOT NULL",
    },
    "race": {
        "layer_expr": (
            "CASE WHEN race_group = 'branca' THEN 'white' "
            "     WHEN race_group IN ('parda', 'preta') THEN 'nonwhite' END"
        ),
        "null_filter": "race_group IN ('branca', 'parda', 'preta')",
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
    },
}


def build_outcomes(layer: str) -> pd.DataFrame:
    defn        = DEMOG_OUTCOME_DEFS[layer]
    layer_expr  = defn["layer_expr"]
    null_filter = defn["null_filter"]

    con = duckdb.connect()
    con.execute("PRAGMA threads=8")
    con.execute("PRAGMA memory_limit='32GB'")

    query = f"""
        SELECT
            CAST(identificad AS VARCHAR)                    AS identificad,
            ({layer_expr})                                  AS layer_id,
            year,
            COUNT(PIS)                                      AS layer_emp,
            AVG(lr_remdezr)                                 AS lr_remdezr_layer,
            AVG(LOG(remdezr / NULLIF(horascontr, 0)))       AS lr_remdezr_h_layer
        FROM read_parquet('{WORKER_PANEL_PARQUET}')
        WHERE {null_filter}
          AND ({layer_expr}) IS NOT NULL
          AND remdezr    > 0
          AND horascontr > 0
        GROUP BY identificad, ({layer_expr}), year
    """

    df = con.execute(query).fetch_arrow_table().to_pandas()
    df["l_layer_emp"] = np.log(df["layer_emp"].replace(0, np.nan))
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

    print("\nDone.")


if __name__ == "__main__":
    main()
