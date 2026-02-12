#!/home/lgg3230/.conda/envs/venv_python312/bin/python
"""
Enhance directed bilateral data with:
1. CEP proximity (replacing geo_proximity)
2. Turnover proximity
3. Early/late connectivity splits for 07d

Uses chunked processing for memory efficiency.

Input: /tmp/bilateral_pairs_gravity_ready.parquet (271M directed pairs)
Output: /tmp/bilateral_pairs_enhanced.parquet
"""

import duckdb
import pandas as pd
import numpy as np
import time
import sys

# Force unbuffered output
sys.stdout.reconfigure(line_buffering=True)

# Paths
DIRECTED_PARQUET = '/tmp/bilateral_pairs_gravity_ready.parquet'
CEP_PARQUET = '/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/bilateral_cep_improved.parquet'
TURNOVER_PARQUET = '/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/bilateral_cep_turnover.parquet'
FIRM_DTA = '/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/CBA_RAIS_firm_level/cba_rais_firm_2009_2016_flows_1.dta'
CONN_CSV = '/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/bilateral_connectivity_2007_2011.csv'
OUTPUT_PARQUET = '/tmp/bilateral_pairs_enhanced.parquet'

con = duckdb.connect()
con.execute("PRAGMA threads=4")
con.execute("PRAGMA memory_limit='48GB'")
con.execute("SET preserve_insertion_order=false")
con.execute("SET temp_directory='/tmp/duckdb_temp'")
con.execute("PRAGMA max_temp_directory_size='200GB'")

print("=" * 70)
print("ENHANCING DIRECTED BILATERAL DATA (EFFICIENT VERSION)")
print("=" * 70)

start_time = time.time()

# ==============================================================================
# STEP 1: Prepare lookup tables
# ==============================================================================
print("\n--- Step 1: Preparing lookup tables ---")

# CEP symmetric lookup (both i,j and j,i directions)
print("  Creating CEP lookup...")
con.execute(f"""
    CREATE TABLE cep_lookup AS
    SELECT identificad_i, identificad_j, cep_distance, cep_proximity
    FROM read_parquet('{CEP_PARQUET}')
    UNION ALL
    SELECT identificad_j as identificad_i, identificad_i as identificad_j, cep_distance, cep_proximity
    FROM read_parquet('{CEP_PARQUET}')
""")
print(f"    CEP lookup rows: {con.execute('SELECT COUNT(*) FROM cep_lookup').fetchone()[0]:,}")

# Turnover symmetric lookup (both i,j and j,i directions)
print("  Creating turnover lookup...")
con.execute(f"""
    CREATE TABLE turnover_lookup AS
    SELECT identificad_i, identificad_j, turnover_proximity
    FROM read_parquet('{TURNOVER_PARQUET}')
    WHERE turnover_proximity IS NOT NULL
    UNION ALL
    SELECT identificad_j as identificad_i, identificad_i as identificad_j, turnover_proximity
    FROM read_parquet('{TURNOVER_PARQUET}')
    WHERE turnover_proximity IS NOT NULL
""")
print(f"    Turnover lookup rows: {con.execute('SELECT COUNT(*) FROM turnover_lookup').fetchone()[0]:,}")

# Connectivity splits lookup
# NB: CSV ratio columns contain NaN (not NULL) for missing year-pairs.
#     COALESCE and IS NOT NULL do NOT catch NaN, so we use explicit isnan() checks.
print("  Creating connectivity splits...")
con.execute(f"""
    CREATE TABLE conn_lookup AS
    SELECT
        SUBSTR(identificad_i::VARCHAR, 2, 14) as identificad_i,
        SUBSTR(identificad_j::VARCHAR, 2, 14) as identificad_j,
        (CASE WHEN NOT isnan(ratio_0708) THEN ratio_0708 ELSE 0 END +
         CASE WHEN NOT isnan(ratio_0809) THEN ratio_0809 ELSE 0 END) /
            NULLIF(
                CASE WHEN NOT isnan(ratio_0708) THEN 1 ELSE 0 END +
                CASE WHEN NOT isnan(ratio_0809) THEN 1 ELSE 0 END, 0) as early_pre,
        (CASE WHEN NOT isnan(ratio_0910) THEN ratio_0910 ELSE 0 END +
         CASE WHEN NOT isnan(ratio_1011) THEN ratio_1011 ELSE 0 END) /
            NULLIF(
                CASE WHEN NOT isnan(ratio_0910) THEN 1 ELSE 0 END +
                CASE WHEN NOT isnan(ratio_1011) THEN 1 ELSE 0 END, 0) as late_pre
    FROM read_csv('{CONN_CSV}')
""")
print(f"    Connectivity lookup rows: {con.execute('SELECT COUNT(*) FROM conn_lookup').fetchone()[0]:,}")

# ==============================================================================
# STEP 2: Compute standardization statistics
# ==============================================================================
print("\n--- Step 2: Computing standardization statistics ---")

# Get stats from joined sample (faster than full data)
print("  Computing stats from sample...")

# Compute each stat separately to handle NULLs
cep_stats = con.execute("""
    SELECT AVG(cep_proximity) as mean, STDDEV_POP(cep_proximity) as sd
    FROM cep_lookup
    WHERE cep_proximity IS NOT NULL
""").fetchone()
cep_mean, cep_sd = cep_stats[0] or 0, cep_stats[1] or 1

turn_stats = con.execute("""
    SELECT AVG(turnover_proximity) as mean, STDDEV_POP(turnover_proximity) as sd
    FROM turnover_lookup
    WHERE turnover_proximity IS NOT NULL
""").fetchone()
turn_mean, turn_sd = turn_stats[0] or 0, turn_stats[1] or 1

# For connectivity, compute stats manually to avoid numerical issues
# The connectivity data is very sparse (most values are NULL/0)
print("  Computing connectivity stats manually...")

# Get early_pre stats — replace NULL and NaN with 0
early_data = con.execute("""
    SELECT CASE WHEN early_pre IS NOT NULL AND NOT isnan(early_pre)
                THEN early_pre ELSE 0 END as val
    FROM conn_lookup
""").fetchall()
early_vals = np.array([x[0] for x in early_data], dtype=np.float64)
early_mean = float(np.mean(early_vals))
early_sd = float(np.std(early_vals))
early_sd = max(early_sd, 0.0001)
n_early_pos = int(np.sum(early_vals > 0))
print(f"    early_pre from conn_lookup: mean={early_mean:.8f}, sd={early_sd:.8f}, n_pos={n_early_pos:,}")

# Get late_pre stats — replace NULL and NaN with 0
late_data = con.execute("""
    SELECT CASE WHEN late_pre IS NOT NULL AND NOT isnan(late_pre)
                THEN late_pre ELSE 0 END as val
    FROM conn_lookup
""").fetchall()
late_vals = np.array([x[0] for x in late_data], dtype=np.float64)
late_mean = float(np.mean(late_vals))
late_sd = float(np.std(late_vals))
late_sd = max(late_sd, 0.0001)
n_late_pos = int(np.sum(late_vals > 0))
print(f"    late_pre from conn_lookup: mean={late_mean:.8f}, sd={late_sd:.8f}, n_pos={n_late_pos:,}")

# Ensure no division by zero
cep_sd = max(cep_sd, 0.0001)
turn_sd = max(turn_sd, 0.0001)

print(f"    cep_proximity: mean={cep_mean:.6f}, sd={cep_sd:.6f}")
print(f"    turnover_proximity: mean={turn_mean:.6f}, sd={turn_sd:.6f}")
print(f"    early_pre: mean={early_mean:.8f}, sd={early_sd:.8f}")
print(f"    late_pre: mean={late_mean:.8f}, sd={late_sd:.8f}")

# ==============================================================================
# STEP 3: Create enhanced dataset
# ==============================================================================
print("\n--- Step 3: Creating enhanced dataset ---")
print("  Executing main query (this will take several minutes)...")

query = f"""
    COPY (
        SELECT
            d.identificad_i,
            d.identificad_j,
            d.swapped,
            -- Connectivity measures
            d.bilateral_conn_pw,
            d.z_bilateral_conn_pw,
            COALESCE(conn.early_pre, 0) as bilateral_conn_early_pre,
            COALESCE(conn.late_pre, 0) as bilateral_conn_late_pre,
            (COALESCE(conn.early_pre, 0) - {early_mean}) / {early_sd} as z_bilateral_conn_early_pre,
            (COALESCE(conn.late_pre, 0) - {late_mean}) / {late_sd} as z_bilateral_conn_late_pre,
            -- CEP proximity
            c.cep_distance,
            c.cep_proximity,
            (c.cep_proximity - {cep_mean}) / {cep_sd} as z_cep_proximity,
            -- Turnover proximity
            turn.turnover_proximity,
            (turn.turnover_proximity - {turn_mean}) / {turn_sd} as z_turnover_proximity,
            -- Other proximities (already in data)
            d.size_proximity, d.z_size_proximity,
            d.wage_proximity, d.z_wage_proximity,
            d.female_proximity, d.z_female_proximity,
            d.nonwhite_proximity, d.z_nonwhite_proximity,
            d.educ_proximity, d.z_educ_proximity,
            d.hs_proximity, d.z_hs_proximity,
            d.clauses_proximity, d.z_clauses_proximity,
            -- Dummies
            d.same_microregion,
            d.same_union,
            d.same_industry,
            d.same_industry_micro,
            -- Keep geo for reference
            d.geo_distance,
            d.geo_proximity,
            d.z_geo_proximity,
            d.has_positive_flow
        FROM read_parquet('{DIRECTED_PARQUET}') d
        LEFT JOIN cep_lookup c ON d.identificad_i = c.identificad_i AND d.identificad_j = c.identificad_j
        LEFT JOIN conn_lookup conn ON d.identificad_i = conn.identificad_i AND d.identificad_j = conn.identificad_j
        LEFT JOIN turnover_lookup turn ON d.identificad_i = turn.identificad_i AND d.identificad_j = turn.identificad_j
    ) TO '{OUTPUT_PARQUET}' (FORMAT PARQUET)
"""

con.execute(query)

# ==============================================================================
# STEP 4: Verify output
# ==============================================================================
print("\n--- Step 4: Verifying output ---")

out_stats = con.execute(f"""
    SELECT
        COUNT(*) as n_rows,
        SUM(CASE WHEN cep_proximity IS NOT NULL THEN 1 ELSE 0 END) as n_cep,
        SUM(CASE WHEN turnover_proximity IS NOT NULL THEN 1 ELSE 0 END) as n_turnover,
        SUM(CASE WHEN bilateral_conn_early_pre > 0 AND NOT isnan(bilateral_conn_early_pre) THEN 1 ELSE 0 END) as n_early_nonzero,
        SUM(CASE WHEN bilateral_conn_late_pre > 0 AND NOT isnan(bilateral_conn_late_pre) THEN 1 ELSE 0 END) as n_late_nonzero,
        SUM(CASE WHEN isnan(bilateral_conn_early_pre) THEN 1 ELSE 0 END) as n_early_nan,
        SUM(CASE WHEN isnan(bilateral_conn_late_pre) THEN 1 ELSE 0 END) as n_late_nan
    FROM read_parquet('{OUTPUT_PARQUET}')
""").fetchone()

print(f"Total rows: {out_stats[0]:,}")
print(f"CEP proximity coverage: {out_stats[1]:,} ({out_stats[1]/out_stats[0]*100:.1f}%)")
print(f"Turnover proximity coverage: {out_stats[2]:,} ({out_stats[2]/out_stats[0]*100:.1f}%)")
print(f"Early-pre connectivity > 0: {out_stats[3]:,} (NaN: {out_stats[5]:,})")
print(f"Late-pre connectivity > 0: {out_stats[4]:,} (NaN: {out_stats[6]:,})")

elapsed = time.time() - start_time
print(f"\n{'=' * 70}")
print(f"DONE in {elapsed/60:.1f} minutes")
print(f"Output: {OUTPUT_PARQUET}")
print(f"{'=' * 70}")
