#!/home/lgg3230/.conda/envs/venv_python312/bin/python
"""
PROJECT: UNION SPILLOVERS
AUTHOR: LUIS GOMES
PROGRAM: PRETREATMENT BILATERAL CONNECTIVITY - DATA PREPARATION
PURPOSE: Efficiently prepare regression-ready data using DuckDB
INPUT: bilateral_connectivity_2007_2011.csv, bilateral_regression_data.parquet
OUTPUT: bilateral_pretreatment_regression_data.dta (for Stata)

This script computes early-pre and late-pre connectivity splits from the
pretreatment bilateral connectivity data and joins with the existing parquet
that contains all proximity measures.
"""

import duckdb
import pandas as pd
from pathlib import Path
import time

# ==============================================================================
# PATHS
# ==============================================================================

PROJECT_ROOT = Path("/gpfs/kellogg/proj/lgg3230/UnionSpill")
RAIS_AUX = PROJECT_ROOT / "Data" / "RAIS_aux"

CSV_FILE = RAIS_AUX / "bilateral_connectivity_2007_2011.csv"
PARQUET_FILE = RAIS_AUX / "bilateral_regression_data.parquet"
OUTPUT_FILE = RAIS_AUX / "bilateral_pretreatment_regression_data.dta"

# ==============================================================================
# MAIN
# ==============================================================================

def main():
    print("=" * 70)
    print("PRETREATMENT BILATERAL CONNECTIVITY - DATA PREPARATION")
    print("=" * 70)

    start_time = time.time()

    # Initialize DuckDB connection with parallel processing
    con = duckdb.connect()
    con.execute("PRAGMA threads=8")
    con.execute("PRAGMA memory_limit='32GB'")

    # -------------------------------------------------------------------------
    # STEP 1: Read CSV and compute early/late pre connectivity splits
    # -------------------------------------------------------------------------
    print("\n--- Step 1: Computing early-pre and late-pre connectivity from CSV ---")

    # The CSV has ratio columns: ratio_0708, ratio_0809, ratio_0910, ratio_1011
    # Early-pre = average of ratio_0708, ratio_0809 (year pairs 2007-08, 2008-09)
    # Late-pre = average of ratio_0910, ratio_1011 (year pairs 2009-10, 2010-11)
    # IDs in CSV have 15 digits with leading "1", need to strip to 14 digits

    # IMPORTANT: CSV has directed pairs (i→j in any order), but parquet has
    # undirected pairs (always i < j). We must normalize CSV pairs to match.
    # Step 1a: Read and normalize pairs (smaller ID first)
    con.execute(f"""
        CREATE TABLE csv_normalized AS
        SELECT
            -- Normalize pair order: smaller ID first (to match parquet convention)
            CASE
                WHEN SUBSTR(CAST(identificad_i AS VARCHAR), 2, 14) < SUBSTR(CAST(identificad_j AS VARCHAR), 2, 14)
                THEN SUBSTR(CAST(identificad_i AS VARCHAR), 2, 14)
                ELSE SUBSTR(CAST(identificad_j AS VARCHAR), 2, 14)
            END AS identificad_i,
            CASE
                WHEN SUBSTR(CAST(identificad_i AS VARCHAR), 2, 14) < SUBSTR(CAST(identificad_j AS VARCHAR), 2, 14)
                THEN SUBSTR(CAST(identificad_j AS VARCHAR), 2, 14)
                ELSE SUBSTR(CAST(identificad_i AS VARCHAR), 2, 14)
            END AS identificad_j,
            -- Keep raw ratio and flow columns
            ratio_0708, ratio_0809, ratio_0910, ratio_1011,
            flows_0708, flows_0809, flows_0910, flows_1011
        FROM read_csv('{CSV_FILE}')
    """)

    # Step 1b: Aggregate duplicates (pairs that appear in both directions)
    # Sum flows and average ratios for each normalized pair
    con.execute("""
        CREATE TABLE connectivity_splits AS
        SELECT
            identificad_i,
            identificad_j,
            -- Early-pre: average of ratio_0708, ratio_0809 across both directions
            CASE
                WHEN MAX(ratio_0708) IS NOT NULL AND MAX(ratio_0809) IS NOT NULL
                    THEN (SUM(ratio_0708) + SUM(ratio_0809)) / 2.0
                WHEN MAX(ratio_0708) IS NOT NULL THEN SUM(ratio_0708)
                WHEN MAX(ratio_0809) IS NOT NULL THEN SUM(ratio_0809)
                ELSE NULL
            END AS bilateral_conn_early_pre,
            -- Late-pre: average of ratio_0910, ratio_1011 across both directions
            CASE
                WHEN MAX(ratio_0910) IS NOT NULL AND MAX(ratio_1011) IS NOT NULL
                    THEN (SUM(ratio_0910) + SUM(ratio_1011)) / 2.0
                WHEN MAX(ratio_0910) IS NOT NULL THEN SUM(ratio_0910)
                WHEN MAX(ratio_1011) IS NOT NULL THEN SUM(ratio_1011)
                ELSE NULL
            END AS bilateral_conn_late_pre,
            -- Also keep total flows for reference (sum across both directions)
            COALESCE(SUM(flows_0708), 0) + COALESCE(SUM(flows_0809), 0) AS flows_early_pre,
            COALESCE(SUM(flows_0910), 0) + COALESCE(SUM(flows_1011), 0) AS flows_late_pre
        FROM csv_normalized
        GROUP BY identificad_i, identificad_j
    """)

    csv_raw = con.execute("SELECT COUNT(*) FROM csv_normalized").fetchone()[0]
    csv_rows = con.execute("SELECT COUNT(*) FROM connectivity_splits").fetchone()[0]
    duplicates = csv_raw - csv_rows
    print(f"  Raw CSV rows: {csv_raw:,}")
    print(f"  After normalization (unique pairs): {csv_rows:,}")
    print(f"  Duplicate pairs (both directions): {duplicates:,}")

    # Count non-zero connectivity in CSV
    early_nonzero_csv = con.execute(
        "SELECT COUNT(*) FROM connectivity_splits WHERE bilateral_conn_early_pre > 0"
    ).fetchone()[0]
    late_nonzero_csv = con.execute(
        "SELECT COUNT(*) FROM connectivity_splits WHERE bilateral_conn_late_pre > 0"
    ).fetchone()[0]
    print(f"  CSV pairs with early-pre > 0: {early_nonzero_csv:,}")
    print(f"  CSV pairs with late-pre > 0: {late_nonzero_csv:,}")

    # -------------------------------------------------------------------------
    # STEP 2: Read parquet and join with connectivity splits
    # -------------------------------------------------------------------------
    print("\n--- Step 2: Joining with parquet for proximity measures ---")
    print(f"  Reading parquet: {PARQUET_FILE}")
    print("  This may take a few minutes for 135M+ rows...")

    # Join parquet (all pairs) with CSV (pairs with flows)
    # For pairs without flows, early/late connectivity will be NULL -> set to 0
    con.execute(f"""
        CREATE TABLE regression_data AS
        SELECT
            p.identificad_i,
            p.identificad_j,
            -- Connectivity measures (0 if no flows)
            COALESCE(c.bilateral_conn_early_pre, 0) AS bilateral_conn_early_pre,
            COALESCE(c.bilateral_conn_late_pre, 0) AS bilateral_conn_late_pre,
            COALESCE(c.flows_early_pre, 0) AS flows_early_pre,
            COALESCE(c.flows_late_pre, 0) AS flows_late_pre,
            -- Proximity measures (already computed in parquet)
            -- Note: clauses_proximity is NOT in parquet, will be computed in Stata
            p.size_proximity,
            p.wage_proximity,
            p.female_proximity,
            p.nonwhite_proximity,
            p.educ_proximity,
            p.hs_proximity,
            p.nhs_proximity,
            p.geo_proximity,
            -- Dummy variables
            p.same_muni,
            p.same_microregion,
            p.same_union,
            p.same_industry,
            p.same_industry_micro
        FROM read_parquet('{PARQUET_FILE}') p
        LEFT JOIN connectivity_splits c
            ON p.identificad_i = c.identificad_i
            AND p.identificad_j = c.identificad_j
    """)

    total_rows = con.execute("SELECT COUNT(*) FROM regression_data").fetchone()[0]
    print(f"  Total pairs in regression data: {total_rows:,}")

    # Count pairs with flows
    pairs_with_early = con.execute(
        "SELECT COUNT(*) FROM regression_data WHERE bilateral_conn_early_pre > 0"
    ).fetchone()[0]
    pairs_with_late = con.execute(
        "SELECT COUNT(*) FROM regression_data WHERE bilateral_conn_late_pre > 0"
    ).fetchone()[0]
    print(f"  Pairs with early-pre flows: {pairs_with_early:,}")
    print(f"  Pairs with late-pre flows: {pairs_with_late:,}")

    # -------------------------------------------------------------------------
    # STEP 3: Export to Stata format
    # -------------------------------------------------------------------------
    print("\n--- Step 3: Exporting to Stata format ---")
    print(f"  Output: {OUTPUT_FILE}")
    print("  This will take a while for 135M+ rows...")

    # Use Arrow for efficient transfer to pandas
    df = con.execute("SELECT * FROM regression_data").fetch_arrow_table().to_pandas()

    print(f"  DataFrame shape: {df.shape}")
    print(f"  Memory usage: {df.memory_usage(deep=True).sum() / 1e9:.2f} GB")

    # Convert identificad columns to string to preserve full ID
    df['identificad_i'] = df['identificad_i'].astype(str)
    df['identificad_j'] = df['identificad_j'].astype(str)

    # Ensure numeric columns are proper numeric types (fill NaN with 0 for flows)
    numeric_cols = ['bilateral_conn_early_pre', 'bilateral_conn_late_pre',
                    'flows_early_pre', 'flows_late_pre',
                    'size_proximity', 'wage_proximity', 'female_proximity',
                    'nonwhite_proximity', 'educ_proximity', 'hs_proximity',
                    'nhs_proximity', 'geo_proximity', 'same_muni', 'same_microregion',
                    'same_union', 'same_industry', 'same_industry_micro']
    for col in numeric_cols:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors='coerce').fillna(0).astype('float64')

    print(f"  Converted numeric columns to float64")

    # Also save as parquet for backup/verification
    parquet_output = RAIS_AUX / "bilateral_pretreatment_regression_data.parquet"
    df.to_parquet(parquet_output, index=False, compression='snappy')
    print(f"  Also saved parquet: {parquet_output}")

    # -------------------------------------------------------------------------
    # STEP 4: Summary statistics
    # -------------------------------------------------------------------------
    print("\n--- Step 4: Summary statistics ---")

    print("\nEarly-pre connectivity:")
    print(df['bilateral_conn_early_pre'].describe())

    print("\nLate-pre connectivity:")
    print(df['bilateral_conn_late_pre'].describe())

    # -------------------------------------------------------------------------
    # DONE
    # -------------------------------------------------------------------------
    elapsed = time.time() - start_time
    print("\n" + "=" * 70)
    print(f"COMPLETE - Elapsed time: {elapsed/60:.1f} minutes")
    print("=" * 70)
    print(f"\nOutput files:")
    print(f"  - {OUTPUT_FILE}")
    print(f"  - {parquet_output}")
    print(f"\nNext step: Run 07d_bilateral_pretreatment.do in Stata")

    # Clean up
    con.close()


if __name__ == "__main__":
    main()
