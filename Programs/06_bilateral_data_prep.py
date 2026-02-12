#!/home/lgg3230/.conda/envs/venv_python312/bin/python
"""
Build directed bilateral dataset from scratch with all variables.

Sources:
- bilateral_regression_data.parquet (135M undirected pairs with base proximity)
- bilateral_cep_turnover.parquet (CEP and turnover proximity)
- bilateral_connectivity_2007_2011.csv (year-pair flow ratios)

Output: /tmp/bilateral_pairs_enhanced.parquet (271M directed pairs)

Variables included:
- Connectivity: bilateral_conn_pw, early_pre, late_pre (standardized)
- Proximity: cep, turnover, size, wage, female, nonwhite, educ, hs, clauses
- Dummies: same_microregion, same_union, same_industry, same_industry_micro
"""

import duckdb
import pandas as pd
import numpy as np
import time
import sys

sys.stdout.reconfigure(line_buffering=True)

# Paths
BASE_PARQUET = '/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/bilateral_regression_data.parquet'
CEP_IMPROVED_PARQUET = '/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/bilateral_cep_improved.parquet'  # 93.8% coverage
TURNOVER_PARQUET = '/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/bilateral_cep_turnover.parquet'  # Has turnover
CONN_CSV = '/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/bilateral_connectivity_2007_2011.csv'
FIRM_DTA = '/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/CBA_RAIS_firm_level/cba_rais_firm_2009_2016_flows_1.dta'
OUTPUT_PARQUET = '/tmp/bilateral_pairs_enhanced.parquet'

con = duckdb.connect()
con.execute("PRAGMA threads=8")
con.execute("PRAGMA memory_limit='64GB'")
con.execute("SET preserve_insertion_order=false")

print("=" * 70)
print("BUILDING DIRECTED BILATERAL DATASET FROM SCRATCH")
print("=" * 70)

start_time = time.time()

# ==============================================================================
# STEP 1: Load and prepare connectivity splits
# ==============================================================================
print("\n--- Step 1: Preparing connectivity splits ---")

con.execute(f"""
    CREATE TABLE conn_raw AS
    SELECT
        SUBSTR(identificad_i::VARCHAR, 2, 14) as identificad_i,
        SUBSTR(identificad_j::VARCHAR, 2, 14) as identificad_j,
        (COALESCE(ratio_0708, 0) + COALESCE(ratio_0809, 0)) /
            NULLIF(CASE WHEN ratio_0708 IS NOT NULL THEN 1 ELSE 0 END +
                   CASE WHEN ratio_0809 IS NOT NULL THEN 1 ELSE 0 END, 0) as early_pre,
        (COALESCE(ratio_0910, 0) + COALESCE(ratio_1011, 0)) /
            NULLIF(CASE WHEN ratio_0910 IS NOT NULL THEN 1 ELSE 0 END +
                   CASE WHEN ratio_1011 IS NOT NULL THEN 1 ELSE 0 END, 0) as late_pre
    FROM read_csv('{CONN_CSV}')
""")
print(f"  Connectivity rows: {con.execute('SELECT COUNT(*) FROM conn_raw').fetchone()[0]:,}")

# Compute early/late stats for standardization
early_data = con.execute("SELECT COALESCE(early_pre, 0) FROM conn_raw").fetchall()
late_data = con.execute("SELECT COALESCE(late_pre, 0) FROM conn_raw").fetchall()

early_vals = np.array([x[0] if x[0] is not None else 0.0 for x in early_data], dtype=np.float64)
late_vals = np.array([x[0] if x[0] is not None else 0.0 for x in late_data], dtype=np.float64)

early_mean, early_sd = float(np.nanmean(early_vals)), max(float(np.nanstd(early_vals)), 0.0001)
late_mean, late_sd = float(np.nanmean(late_vals)), max(float(np.nanstd(late_vals)), 0.0001)

print(f"  early_pre: mean={early_mean:.6f}, sd={early_sd:.6f}")
print(f"  late_pre: mean={late_mean:.6f}, sd={late_sd:.6f}")

# ==============================================================================
# STEP 2: Get CEP/turnover stats (from separate files)
# ==============================================================================
print("\n--- Step 2: Getting CEP/turnover statistics ---")

# CEP from improved file (93.8% coverage)
cep_stats = con.execute(f"""
    SELECT AVG(cep_proximity), STDDEV_POP(cep_proximity)
    FROM read_parquet('{CEP_IMPROVED_PARQUET}')
    WHERE cep_proximity IS NOT NULL
""").fetchone()
cep_mean, cep_sd = cep_stats[0] or 0, max(cep_stats[1] or 1, 0.0001)
print(f"  cep_proximity: mean={cep_mean:.6f}, sd={cep_sd:.6f}")

# Turnover from turnover file
turn_stats = con.execute(f"""
    SELECT AVG(turnover_proximity), STDDEV_POP(turnover_proximity)
    FROM read_parquet('{TURNOVER_PARQUET}')
    WHERE turnover_proximity IS NOT NULL
""").fetchone()
turn_mean, turn_sd = turn_stats[0] or 0, max(turn_stats[1] or 1, 0.0001)
print(f"  turnover_proximity: mean={turn_mean:.6f}, sd={turn_sd:.6f}")

# Clauses from firm-level data (year=2009 baseline)
print("  Loading clauses data...")
clauses_df = pd.read_stata(FIRM_DTA, columns=['identificad', 'year', 'numb_clauses'])
clauses_df = clauses_df[clauses_df['year'] == 2009][['identificad', 'numb_clauses']].copy()
clauses_df['identificad'] = clauses_df['identificad'].astype(str).str.strip()
clauses_df = clauses_df.dropna(subset=['numb_clauses'])
con.register('clauses_lookup', clauses_df)
print(f"  Clauses lookup: {len(clauses_df):,} firms (year=2009)")

# Compute clauses standardization stats over undirected pairs
clauses_stats = con.execute(f"""
    SELECT
        AVG(-ABS(ci.numb_clauses - cj.numb_clauses)),
        STDDEV_POP(-ABS(ci.numb_clauses - cj.numb_clauses))
    FROM read_parquet('{BASE_PARQUET}') b
    INNER JOIN clauses_lookup ci ON b.identificad_i = ci.identificad
    INNER JOIN clauses_lookup cj ON b.identificad_j = cj.identificad
""").fetchone()
clauses_mean = clauses_stats[0] or 0
clauses_sd = max(clauses_stats[1] or 1, 0.0001)
print(f"  clauses_proximity: mean={clauses_mean:.6f}, sd={clauses_sd:.6f}")

# ==============================================================================
# STEP 3: Build directed dataset with all variables
# ==============================================================================
print("\n--- Step 3: Building directed dataset ---")
print("  This will take several minutes...")

query = f"""
COPY (
    WITH base_undirected AS (
        SELECT
            b.identificad_i,
            b.identificad_j,
            b.bilateral_conn_pre as bilateral_conn_pw,
            b.z_bilateral_conn_pre as z_bilateral_conn_pw,
            -- Existing proximity measures
            b.size_proximity, b.z_size_proximity,
            b.wage_proximity, b.z_wage_proximity,
            b.female_proximity, b.z_female_proximity,
            b.nonwhite_proximity, b.z_nonwhite_proximity,
            b.educ_proximity, b.z_educ_proximity,
            b.hs_proximity, b.z_hs_proximity,
            -- Clauses proximity from firm-level CBA data
            -ABS(cli.numb_clauses - clj.numb_clauses) as clauses_proximity,
            (-ABS(cli.numb_clauses - clj.numb_clauses) - {clauses_mean}) / {clauses_sd} as z_clauses_proximity,
            b.geo_distance, b.geo_proximity, b.z_geo_proximity,
            -- Dummies
            b.same_microregion,
            b.same_union,
            b.same_industry,
            b.same_industry_micro,
            b.has_flow_pre as has_positive_flow,
            -- CEP from improved file (93.8% coverage)
            cep.cep_distance,
            cep.cep_proximity,
            (cep.cep_proximity - {cep_mean}) / {cep_sd} as z_cep_proximity,
            -- Turnover from turnover file
            turn.turnover_proximity,
            (turn.turnover_proximity - {turn_mean}) / {turn_sd} as z_turnover_proximity,
            -- Connectivity splits
            COALESCE(c.early_pre, 0) as bilateral_conn_early_pre,
            COALESCE(c.late_pre, 0) as bilateral_conn_late_pre,
            (COALESCE(c.early_pre, 0) - {early_mean}) / {early_sd} as z_bilateral_conn_early_pre,
            (COALESCE(c.late_pre, 0) - {late_mean}) / {late_sd} as z_bilateral_conn_late_pre
        FROM read_parquet('{BASE_PARQUET}') b
        LEFT JOIN read_parquet('{CEP_IMPROVED_PARQUET}') cep
            ON b.identificad_i = cep.identificad_i AND b.identificad_j = cep.identificad_j
        LEFT JOIN read_parquet('{TURNOVER_PARQUET}') turn
            ON b.identificad_i = turn.identificad_i AND b.identificad_j = turn.identificad_j
        LEFT JOIN conn_raw c
            ON b.identificad_i = c.identificad_i AND b.identificad_j = c.identificad_j
        LEFT JOIN clauses_lookup cli ON b.identificad_i = cli.identificad
        LEFT JOIN clauses_lookup clj ON b.identificad_j = clj.identificad
    )
    -- Create directed pairs: original (i,j) and swapped (j,i)
    SELECT *, 0 as swapped FROM base_undirected
    UNION ALL
    SELECT
        identificad_j as identificad_i,
        identificad_i as identificad_j,
        bilateral_conn_pw, z_bilateral_conn_pw,
        size_proximity, z_size_proximity,
        wage_proximity, z_wage_proximity,
        female_proximity, z_female_proximity,
        nonwhite_proximity, z_nonwhite_proximity,
        educ_proximity, z_educ_proximity,
        hs_proximity, z_hs_proximity,
        clauses_proximity, z_clauses_proximity,
        geo_distance, geo_proximity, z_geo_proximity,
        same_microregion, same_union, same_industry, same_industry_micro,
        has_positive_flow,
        cep_distance, cep_proximity, z_cep_proximity,
        turnover_proximity, z_turnover_proximity,
        bilateral_conn_early_pre, bilateral_conn_late_pre,
        z_bilateral_conn_early_pre, z_bilateral_conn_late_pre,
        1 as swapped
    FROM base_undirected
) TO '{OUTPUT_PARQUET}' (FORMAT PARQUET, COMPRESSION ZSTD)
"""

con.execute(query)

# ==============================================================================
# STEP 4: Verify output
# ==============================================================================
print("\n--- Step 4: Verifying output ---")

stats = con.execute(f"""
    SELECT
        COUNT(*) as n_rows,
        SUM(CASE WHEN cep_proximity IS NOT NULL THEN 1 ELSE 0 END) as n_cep,
        SUM(CASE WHEN turnover_proximity IS NOT NULL THEN 1 ELSE 0 END) as n_turnover,
        SUM(CASE WHEN clauses_proximity IS NOT NULL THEN 1 ELSE 0 END) as n_clauses,
        SUM(CASE WHEN bilateral_conn_early_pre > 0 THEN 1 ELSE 0 END) as n_early,
        SUM(CASE WHEN bilateral_conn_late_pre > 0 THEN 1 ELSE 0 END) as n_late
    FROM read_parquet('{OUTPUT_PARQUET}')
""").fetchone()

print(f"  Total rows: {stats[0]:,}")
print(f"  CEP coverage: {stats[1]:,} ({stats[1]/stats[0]*100:.1f}%)")
print(f"  Turnover coverage: {stats[2]:,} ({stats[2]/stats[0]*100:.1f}%)")
print(f"  Clauses coverage: {stats[3]:,} ({stats[3]/stats[0]*100:.1f}%)")
print(f"  Early connectivity > 0: {stats[4]:,}")
print(f"  Late connectivity > 0: {stats[5]:,}")

elapsed = time.time() - start_time
print(f"\n{'=' * 70}")
print(f"DONE in {elapsed/60:.1f} minutes")
print(f"Output: {OUTPUT_PARQUET}")
print(f"{'=' * 70}")
