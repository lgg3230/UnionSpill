#!/home/lgg3230/.conda/envs/venv_python312/bin/python
"""
Improve CEP-to-coordinates matching using prefix fallback strategy.
Validates that correlation with geo_distance remains high.
"""

import duckdb
import pandas as pd
import numpy as np

# Paths
ESTAB_CEP = "/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/establishment_cep.csv"
CEP_COORDS = "/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/IBGE/cep_coordinates.csv"
MAIN_PARQUET = "/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/bilateral_regression_data.parquet"
OUTPUT_CSV = "/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/establishment_cep_improved.csv"
OUTPUT_BILATERAL = "/gpfs/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/bilateral_cep_improved.parquet"

con = duckdb.connect()
con.execute("PRAGMA threads=8")
con.execute("PRAGMA memory_limit='32GB'")

print("=" * 70)
print("IMPROVING CEP MATCHING WITH PREFIX FALLBACK")
print("=" * 70)

# ==============================================================================
# STEP 1: Create prefix-averaged coordinates
# ==============================================================================
print("\n--- Creating prefix-averaged coordinates ---")

con.execute("""
    CREATE OR REPLACE TABLE cep_coords AS
    SELECT cep, latitude, longitude
    FROM read_csv(?, types={'cep': 'VARCHAR'})
""", [CEP_COORDS])

con.execute("""
    CREATE OR REPLACE TABLE prefix5_coords AS
    SELECT
        SUBSTR(cep, 1, 5) as prefix5,
        AVG(latitude) as lat5,
        AVG(longitude) as lon5,
        COUNT(*) as n_ceps5
    FROM cep_coords
    GROUP BY SUBSTR(cep, 1, 5)
""")

con.execute("""
    CREATE OR REPLACE TABLE prefix3_coords AS
    SELECT
        SUBSTR(cep, 1, 3) as prefix3,
        AVG(latitude) as lat3,
        AVG(longitude) as lon3,
        COUNT(*) as n_ceps3
    FROM cep_coords
    GROUP BY SUBSTR(cep, 1, 3)
""")

print(f"5-digit prefixes: {con.execute('SELECT COUNT(*) FROM prefix5_coords').fetchone()[0]:,}")
print(f"3-digit prefixes: {con.execute('SELECT COUNT(*) FROM prefix3_coords').fetchone()[0]:,}")

# ==============================================================================
# STEP 2: Match establishments with tiered strategy
# ==============================================================================
print("\n--- Matching establishments (tiered strategy) ---")

con.execute("""
    CREATE OR REPLACE TABLE estab_cep AS
    SELECT identificad, cep
    FROM read_csv(?, types={'identificad': 'VARCHAR', 'cep': 'VARCHAR'})
""", [ESTAB_CEP])

# Tiered matching: exact -> 5-digit prefix -> 3-digit prefix
con.execute("""
    CREATE OR REPLACE TABLE estab_coords AS
    SELECT
        e.identificad,
        e.cep,
        CASE
            WHEN c.latitude IS NOT NULL THEN 'exact'
            WHEN p5.lat5 IS NOT NULL THEN 'prefix5'
            WHEN p3.lat3 IS NOT NULL THEN 'prefix3'
            ELSE 'unmatched'
        END as match_type,
        COALESCE(c.latitude, p5.lat5, p3.lat3) as latitude,
        COALESCE(c.longitude, p5.lon5, p3.lon3) as longitude
    FROM estab_cep e
    LEFT JOIN cep_coords c ON e.cep = c.cep
    LEFT JOIN prefix5_coords p5 ON SUBSTR(e.cep, 1, 5) = p5.prefix5
    LEFT JOIN prefix3_coords p3 ON SUBSTR(e.cep, 1, 3) = p3.prefix3
    WHERE e.cep != '99999999'  -- Exclude invalid CEPs
""")

# Report match rates
match_stats = con.execute("""
    SELECT match_type, COUNT(*) as n
    FROM estab_coords
    GROUP BY match_type
    ORDER BY n DESC
""").df()
print("\nMatch type breakdown:")
print(match_stats.to_string(index=False))

total_matched = con.execute("""
    SELECT COUNT(*) FROM estab_coords WHERE match_type != 'unmatched'
""").fetchone()[0]
total_estab = con.execute("SELECT COUNT(*) FROM estab_coords").fetchone()[0]
print(f"\nTotal matched: {total_matched:,} / {total_estab:,} ({total_matched/total_estab*100:.1f}%)")

# ==============================================================================
# STEP 3: Compute bilateral CEP distances
# ==============================================================================
print("\n--- Computing bilateral CEP distances ---")

# Haversine formula for distance in km
con.execute("""
    CREATE OR REPLACE TABLE bilateral_cep AS
    SELECT
        ei.identificad as identificad_i,
        ej.identificad as identificad_j,
        ei.match_type as match_type_i,
        ej.match_type as match_type_j,
        -- Haversine distance formula
        2 * 6371 * ASIN(SQRT(
            POWER(SIN(RADIANS(ej.latitude - ei.latitude) / 2), 2) +
            COS(RADIANS(ei.latitude)) * COS(RADIANS(ej.latitude)) *
            POWER(SIN(RADIANS(ej.longitude - ei.longitude) / 2), 2)
        )) as cep_distance_improved
    FROM estab_coords ei
    JOIN estab_coords ej ON ei.identificad < ej.identificad
    WHERE ei.match_type != 'unmatched' AND ej.match_type != 'unmatched'
""")

n_pairs = con.execute("SELECT COUNT(*) FROM bilateral_cep").fetchone()[0]
print(f"Bilateral pairs with improved CEP distance: {n_pairs:,}")

# ==============================================================================
# STEP 4: Validate correlation with geo_distance
# ==============================================================================
print("\n--- Validating correlation with geo_distance ---")

# Sample for correlation check
df_check = con.execute(f"""
    SELECT
        bc.cep_distance_improved,
        bc.match_type_i,
        bc.match_type_j,
        main.geo_distance
    FROM bilateral_cep bc
    JOIN read_parquet('{MAIN_PARQUET}') main
        ON bc.identificad_i = main.identificad_i
        AND bc.identificad_j = main.identificad_j
    USING SAMPLE 200000
""").df()

print(f"\nSampled {len(df_check):,} pairs for validation")

# Overall correlation
corr_all = df_check['cep_distance_improved'].corr(df_check['geo_distance'])
print(f"\nOverall correlation: {corr_all:.4f}")

# Correlation by match type combination
print("\nCorrelation by match type:")
df_check['match_combo'] = df_check['match_type_i'] + '-' + df_check['match_type_j']
for combo in df_check['match_combo'].unique():
    subset = df_check[df_check['match_combo'] == combo]
    if len(subset) > 100:
        corr = subset['cep_distance_improved'].corr(subset['geo_distance'])
        print(f"  {combo}: {corr:.4f} (n={len(subset):,})")

# ==============================================================================
# STEP 5: Save improved data
# ==============================================================================
print("\n--- Saving improved CEP data ---")

# Save establishment coordinates
con.execute(f"""
    COPY (
        SELECT identificad, cep, match_type, latitude, longitude
        FROM estab_coords
    ) TO '{OUTPUT_CSV}' (HEADER, DELIMITER ',')
""")
print(f"Saved: {OUTPUT_CSV}")

# Save bilateral CEP distances
con.execute(f"""
    COPY (
        SELECT
            identificad_i,
            identificad_j,
            cep_distance_improved,
            -LN(cep_distance_improved + 0.1) as cep_proximity_improved,
            match_type_i,
            match_type_j
        FROM bilateral_cep
    ) TO '{OUTPUT_BILATERAL}' (FORMAT PARQUET)
""")
print(f"Saved: {OUTPUT_BILATERAL}")

# ==============================================================================
# SUMMARY
# ==============================================================================
print("\n" + "=" * 70)
print("SUMMARY")
print("=" * 70)

total_possible = 16472 * 16471 // 2
old_pairs = 67936996
print(f"\nPairs coverage:")
print(f"  Original: {old_pairs:,} ({old_pairs/total_possible*100:.1f}%)")
print(f"  Improved: {n_pairs:,} ({n_pairs/total_possible*100:.1f}%)")
print(f"  Gain: +{n_pairs - old_pairs:,} pairs (+{(n_pairs-old_pairs)/old_pairs*100:.1f}%)")

print(f"\nCorrelation with geo_distance: {corr_all:.4f}")
print("\nRecommendation: ", end="")
if corr_all >= 0.99:
    print("Excellent - use improved CEP distance")
elif corr_all >= 0.95:
    print("Good - use improved CEP distance with caution")
else:
    print("Consider using only exact matches")
