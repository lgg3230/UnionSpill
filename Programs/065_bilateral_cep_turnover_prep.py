#!/home/lgg3230/.conda/envs/venv_python312/bin/python
"""
PROJECT: UNION SPILLOVERS
AUTHOR: LUIS GOMES
PROGRAM: 065_bilateral_cep_turnover_prep.py
PURPOSE: Create supplementary bilateral proximity file with CEP-based distance and turnover proximity
INPUT:
  - establishment_cep.csv (from 063)
  - cep_coordinates.csv (from 064)
  - cba_rais_firm_2009_2016_flows_1.dta (for turnover)
  - bilateral_regression_data.parquet (for pair list)
OUTPUT: bilateral_cep_turnover.parquet
"""

import duckdb
import pandas as pd
import numpy as np
from pathlib import Path
import time

# ==============================================================================
# PATHS
# ==============================================================================

BASE_DIR = Path("/kellogg/proj/lgg3230/UnionSpill")
RAIS_AUX = BASE_DIR / "Data" / "RAIS_aux"
IBGE_DIR = BASE_DIR / "Data" / "IBGE"
RAIS_FIRM = BASE_DIR / "Data" / "CBA_RAIS_firm_level"

# Input files
ESTAB_CEP_FILE = RAIS_AUX / "establishment_cep.csv"
CEP_COORDS_FILE = IBGE_DIR / "cep_coordinates.csv"
FIRM_DATA_FILE = RAIS_FIRM / "cba_rais_firm_2009_2016_flows_1.dta"
BILATERAL_PARQUET = RAIS_AUX / "bilateral_regression_data.parquet"

# Output
OUTPUT_FILE = RAIS_AUX / "bilateral_cep_turnover.parquet"

# ==============================================================================
# MAIN
# ==============================================================================

def main():
    print("=" * 70)
    print("CREATING SUPPLEMENTARY CEP AND TURNOVER PROXIMITY FILE")
    print("=" * 70)

    start_time = time.time()

    # Initialize DuckDB
    con = duckdb.connect()
    con.execute("PRAGMA threads=8")
    con.execute("PRAGMA memory_limit='32GB'")

    # =========================================================================
    # STEP 1: Load establishment CEP data
    # =========================================================================
    print("\n[1/6] Loading establishment CEP data...")

    if not ESTAB_CEP_FILE.exists():
        raise FileNotFoundError(f"CEP file not found: {ESTAB_CEP_FILE}\nRun 063_extract_cep_from_rais.do first.")

    con.execute(f"""
        CREATE TABLE estab_cep AS
        SELECT
            CAST(identificad AS VARCHAR) AS identificad,
            CAST(cep AS VARCHAR) AS cep
        FROM read_csv('{ESTAB_CEP_FILE}', auto_detect=true, all_varchar=true)
        WHERE cep IS NOT NULL AND TRIM(cep) != ''
    """)

    n_estab_cep = con.execute("SELECT COUNT(*) FROM estab_cep").fetchone()[0]
    print(f"  Establishments with CEP: {n_estab_cep:,}")

    # =========================================================================
    # STEP 2: Load CEP coordinates
    # =========================================================================
    print("\n[2/6] Loading CEP coordinates...")

    if not CEP_COORDS_FILE.exists():
        raise FileNotFoundError(f"CEP coordinates file not found: {CEP_COORDS_FILE}\nRun 064_process_cep_centroids.py first.")

    con.execute(f"""
        CREATE TABLE cep_coords AS
        SELECT
            CAST(cep AS VARCHAR) AS cep,
            latitude,
            longitude
        FROM read_csv('{CEP_COORDS_FILE}')
    """)

    n_cep_coords = con.execute("SELECT COUNT(*) FROM cep_coords").fetchone()[0]
    print(f"  CEPs with coordinates: {n_cep_coords:,}")

    # =========================================================================
    # STEP 3: Load turnover from firm-level data
    # =========================================================================
    print("\n[3/6] Loading turnover data...")

    # Read firm-level data - just need identificad and turnover
    # Average turnover across years for each establishment
    firm_df = pd.read_stata(
        FIRM_DATA_FILE,
        columns=['identificad', 'year', 'turnover', 'lagos_sample_avg', 'in_balanced_panel']
    )

    # Filter to sample and compute average turnover
    firm_df = firm_df[
        (firm_df['lagos_sample_avg'] == 1) &
        (firm_df['in_balanced_panel'] == 1)
    ]
    turnover_df = firm_df.groupby('identificad')['turnover'].mean().reset_index()
    turnover_df.columns = ['identificad', 'avg_turnover']
    turnover_df['identificad'] = turnover_df['identificad'].astype(str)

    con.execute("CREATE TABLE turnover AS SELECT * FROM turnover_df")
    n_turnover = con.execute("SELECT COUNT(*) FROM turnover").fetchone()[0]
    print(f"  Establishments with turnover: {n_turnover:,}")

    # =========================================================================
    # STEP 4: Load bilateral pairs from parquet
    # =========================================================================
    print("\n[4/6] Loading bilateral pairs...")

    con.execute(f"""
        CREATE TABLE pairs AS
        SELECT DISTINCT identificad_i, identificad_j
        FROM read_parquet('{BILATERAL_PARQUET}')
    """)

    n_pairs = con.execute("SELECT COUNT(*) FROM pairs").fetchone()[0]
    print(f"  Bilateral pairs: {n_pairs:,}")

    # =========================================================================
    # STEP 5: Compute CEP-based distance (Haversine) and turnover proximity
    # =========================================================================
    print("\n[5/6] Computing CEP distance and turnover proximity...")

    # Join CEP coordinates to pairs and compute Haversine distance
    con.execute("""
        CREATE TABLE pairs_with_vars AS
        SELECT
            p.identificad_i,
            p.identificad_j,

            -- CEP coordinates for establishment i
            ci.latitude AS lat_i,
            ci.longitude AS lon_i,

            -- CEP coordinates for establishment j
            cj.latitude AS lat_j,
            cj.longitude AS lon_j,

            -- Turnover values
            ti.avg_turnover AS turnover_i,
            tj.avg_turnover AS turnover_j,

            -- CEP distance (Haversine formula, km)
            CASE
                WHEN ci.latitude IS NOT NULL AND cj.latitude IS NOT NULL THEN
                    6371 * 2 * ASIN(SQRT(
                        POWER(SIN(RADIANS(cj.latitude - ci.latitude) / 2), 2) +
                        COS(RADIANS(ci.latitude)) * COS(RADIANS(cj.latitude)) *
                        POWER(SIN(RADIANS(cj.longitude - ci.longitude) / 2), 2)
                    ))
                ELSE NULL
            END AS cep_distance,

            -- Turnover proximity (negative absolute difference)
            CASE
                WHEN ti.avg_turnover IS NOT NULL AND tj.avg_turnover IS NOT NULL THEN
                    -ABS(ti.avg_turnover - tj.avg_turnover)
                ELSE NULL
            END AS turnover_proximity

        FROM pairs p

        -- Join CEP for establishment i
        LEFT JOIN estab_cep ei ON p.identificad_i = ei.identificad
        LEFT JOIN cep_coords ci ON ei.cep = ci.cep

        -- Join CEP for establishment j
        LEFT JOIN estab_cep ej ON p.identificad_j = ej.identificad
        LEFT JOIN cep_coords cj ON ej.cep = cj.cep

        -- Join turnover for both establishments
        LEFT JOIN turnover ti ON p.identificad_i = ti.identificad
        LEFT JOIN turnover tj ON p.identificad_j = tj.identificad
    """)

    # Check coverage
    cep_coverage = con.execute("""
        SELECT
            COUNT(*) AS total,
            SUM(CASE WHEN cep_distance IS NOT NULL THEN 1 ELSE 0 END) AS with_cep_dist,
            SUM(CASE WHEN turnover_proximity IS NOT NULL THEN 1 ELSE 0 END) AS with_turnover
        FROM pairs_with_vars
    """).fetchone()

    print(f"  Total pairs: {cep_coverage[0]:,}")
    print(f"  Pairs with CEP distance: {cep_coverage[1]:,} ({100*cep_coverage[1]/cep_coverage[0]:.1f}%)")
    print(f"  Pairs with turnover: {cep_coverage[2]:,} ({100*cep_coverage[2]/cep_coverage[0]:.1f}%)")

    # Compute CEP proximity (negative distance, NOT log-transformed)
    con.execute("""
        ALTER TABLE pairs_with_vars ADD COLUMN cep_proximity DOUBLE;
        UPDATE pairs_with_vars SET cep_proximity = -cep_distance WHERE cep_distance IS NOT NULL;
    """)

    # =========================================================================
    # STEP 6: Standardize variables
    # =========================================================================
    print("\n[6/6] Standardizing variables...")

    # Get means and standard deviations
    stats = con.execute("""
        SELECT
            AVG(cep_proximity) AS cep_mean,
            STDDEV(cep_proximity) AS cep_std,
            AVG(turnover_proximity) AS turnover_mean,
            STDDEV(turnover_proximity) AS turnover_std
        FROM pairs_with_vars
        WHERE cep_proximity IS NOT NULL AND turnover_proximity IS NOT NULL
    """).fetchone()

    cep_mean, cep_std, turnover_mean, turnover_std = stats
    print(f"  CEP proximity: mean={cep_mean:.4f}, std={cep_std:.4f}")
    print(f"  Turnover proximity: mean={turnover_mean:.6f}, std={turnover_std:.6f}")

    # Create standardized variables
    con.execute(f"""
        CREATE TABLE output AS
        SELECT
            identificad_i,
            identificad_j,
            cep_distance,
            cep_proximity,
            CASE
                WHEN cep_proximity IS NOT NULL THEN
                    (cep_proximity - {cep_mean}) / {cep_std}
                ELSE NULL
            END AS z_cep_proximity,
            turnover_proximity,
            CASE
                WHEN turnover_proximity IS NOT NULL THEN
                    (turnover_proximity - {turnover_mean}) / {turnover_std}
                ELSE NULL
            END AS z_turnover_proximity
        FROM pairs_with_vars
    """)

    # =========================================================================
    # SAVE OUTPUT
    # =========================================================================
    print(f"\nSaving: {OUTPUT_FILE}")
    con.execute(f"COPY output TO '{OUTPUT_FILE}' (FORMAT PARQUET)")

    # Summary
    elapsed = time.time() - start_time
    print("\n" + "=" * 70)
    print("COMPLETE")
    print("=" * 70)
    print(f"Output: {OUTPUT_FILE}")
    print(f"Elapsed time: {elapsed/60:.1f} minutes")

    # Clean up
    con.close()


if __name__ == "__main__":
    main()
