#!/usr/bin/env python3
"""
PROJECT: UNION SPILLOVERS
AUTHOR: LUIS GOMES
PROGRAM: BILATERAL CONNECTIVITY DATA PREPARATION (GRAVITY SPECIFICATION)

Prepares bilateral connectivity data for gravity-style regressions using DuckDB.
Uses /tmp for temporary storage to avoid disk quota issues.
"""

import duckdb
import pandas as pd
from pathlib import Path
import time
import os

# Paths
BASE_DIR = Path("/kellogg/proj/lgg3230/UnionSpill")
RAIS_AUX = BASE_DIR / "Data" / "RAIS_aux"
RAIS_FIRM = BASE_DIR / "Data" / "CBA_RAIS_firm_level"
IBGE_DIR = BASE_DIR / "Data" / "IBGE"

INPUT_CSV = RAIS_AUX / "bilateral_pairs_descriptives.csv"
FIRM_DATA = RAIS_FIRM / "cba_rais_firm_2009_2016_flows_1.dta"
COORDS_FILE = IBGE_DIR / "municipality_coordinates.dta"
# Output directly to /tmp due to disk quota constraints
# Stata will read from /tmp
OUTPUT_PARQUET = Path("/tmp") / "bilateral_pairs_gravity_ready.parquet"

# Use /tmp for temp database to avoid disk quota issues
DB_FILE = Path("/tmp") / f"bilateral_prep_{os.getpid()}.duckdb"


def main():
    start_time = time.time()
    con = None

    try:
        # Clean up any existing temp database
        if DB_FILE.exists():
            os.remove(DB_FILE)

        print("=" * 70)
        print("BILATERAL CONNECTIVITY DATA PREPARATION (GRAVITY SPECIFICATION)")
        print("=" * 70)
        print(f"Temp database: {DB_FILE}")

        # Initialize DuckDB
        con = duckdb.connect(str(DB_FILE))
        con.execute("PRAGMA threads=8")
        con.execute("PRAGMA memory_limit='48GB'")
        con.execute("PRAGMA temp_directory='/tmp'")
        con.execute("PRAGMA max_temp_directory_size='100GB'")
        con.execute("SET preserve_insertion_order=false")

        # =====================================================================
        # STEP 1: Load bilateral pairs CSV
        # =====================================================================
        print("\n[Step 1] Loading bilateral pairs CSV...")

        con.execute(f"""
            CREATE TABLE pairs AS
            SELECT * FROM read_csv('{INPUT_CSV}',
                types={{'identificad_i': 'VARCHAR', 'identificad_j': 'VARCHAR'}})
        """)

        n_original = con.execute("SELECT COUNT(*) FROM pairs").fetchone()[0]
        print(f"  Loaded {n_original:,} unique pairs")

        cols = [r[0] for r in con.execute("DESCRIBE pairs").fetchall()]

        # =====================================================================
        # STEP 2: Create symmetric directed pairs
        # =====================================================================
        print("\n[Step 2] Creating symmetric directed pairs...")

        # Build swap expressions
        swap_exprs = []
        for c in cols:
            if c == 'identificad_i':
                swap_exprs.append('identificad_j AS identificad_i')
            elif c == 'identificad_j':
                swap_exprs.append('identificad_i AS identificad_j')
            elif c.endswith('_i') and c[:-2] + '_j' in cols:
                swap_exprs.append(f"{c[:-2]}_j AS {c}")
            elif c.endswith('_j') and c[:-2] + '_i' in cols:
                swap_exprs.append(f"{c[:-2]}_i AS {c}")
            else:
                swap_exprs.append(c)

        swap_select = ', '.join(swap_exprs)

        print("  Creating original pairs...")
        con.execute("CREATE TABLE directed_pairs AS SELECT *, 0::TINYINT AS swapped FROM pairs")

        print("  Inserting swapped pairs...")
        con.execute(f"INSERT INTO directed_pairs SELECT {swap_select}, 1::TINYINT AS swapped FROM pairs")

        n_directed = con.execute("SELECT COUNT(*) FROM directed_pairs").fetchone()[0]
        print(f"  Total directed pairs: {n_directed:,}")

        con.execute("DROP TABLE pairs")

        # =====================================================================
        # STEP 3: Merge numb_clauses from firm-level data
        # =====================================================================
        print("\n[Step 3] Merging firm data...")

        parquet_path = RAIS_FIRM / "cba_rais_firm_2009_2016_flows_1.parquet"

        if parquet_path.exists():
            print(f"  Loading from parquet...")
            con.execute(f"""
                CREATE TABLE firm_2009 AS
                SELECT DISTINCT identificad, numb_clauses, municipio
                FROM read_parquet('{parquet_path}')
                WHERE year = 2009
            """)
        else:
            print(f"  Loading from Stata file...")
            firm_df = pd.read_stata(FIRM_DATA)
            firm_df = firm_df[firm_df['year'] == 2009][['identificad', 'numb_clauses', 'municipio']].drop_duplicates()
            con.register('firm_2009_pd', firm_df)
            con.execute("CREATE TABLE firm_2009 AS SELECT * FROM firm_2009_pd")

        n_firms = con.execute("SELECT COUNT(DISTINCT identificad) FROM firm_2009").fetchone()[0]
        print(f"  Loaded {n_firms:,} firms")

        con.execute("CREATE INDEX idx_firm_id ON firm_2009(identificad)")

        # Add columns and merge
        con.execute("ALTER TABLE directed_pairs ADD COLUMN numb_clauses_2009_i DOUBLE")
        con.execute("ALTER TABLE directed_pairs ADD COLUMN numb_clauses_2009_j DOUBLE")
        con.execute("ALTER TABLE directed_pairs ADD COLUMN municipio_i INTEGER")
        con.execute("ALTER TABLE directed_pairs ADD COLUMN municipio_j INTEGER")

        print("  Updating firm i data...")
        con.execute("""
            UPDATE directed_pairs p SET
                numb_clauses_2009_i = f.numb_clauses, municipio_i = f.municipio
            FROM firm_2009 f WHERE p.identificad_i = f.identificad
        """)

        print("  Updating firm j data...")
        con.execute("""
            UPDATE directed_pairs p SET
                numb_clauses_2009_j = f.numb_clauses, municipio_j = f.municipio
            FROM firm_2009 f WHERE p.identificad_j = f.identificad
        """)

        con.execute("DROP TABLE firm_2009")

        # =====================================================================
        # STEP 4: Compute geographic proximity
        # =====================================================================
        print("\n[Step 4] Computing geographic proximity...")

        con.execute("ALTER TABLE directed_pairs ADD COLUMN geo_distance DOUBLE")
        con.execute("ALTER TABLE directed_pairs ADD COLUMN geo_proximity DOUBLE")

        if COORDS_FILE.exists():
            coords_df = pd.read_stata(COORDS_FILE)
            con.register('coords', coords_df)

            print("  Computing Haversine distances...")
            con.execute("""
                UPDATE directed_pairs p SET geo_distance =
                    6371 * 2 * ASIN(SQRT(
                        POWER(SIN(RADIANS(c_j.latitude - c_i.latitude) / 2), 2) +
                        COS(RADIANS(c_i.latitude)) * COS(RADIANS(c_j.latitude)) *
                        POWER(SIN(RADIANS(c_j.longitude - c_i.longitude) / 2), 2)
                    ))
                FROM coords c_i, coords c_j
                WHERE p.municipio_i = c_i.municipio AND p.municipio_j = c_j.municipio
            """)

            con.execute("UPDATE directed_pairs SET geo_proximity = -geo_distance WHERE geo_distance IS NOT NULL")

            n_geo = con.execute("SELECT COUNT(*) FROM directed_pairs WHERE geo_proximity IS NOT NULL").fetchone()[0]
            print(f"  Pairs with geo_proximity: {n_geo:,}")
        else:
            print(f"  WARNING: Coordinates file not found")

        # =====================================================================
        # STEP 5: Create clauses_proximity
        # =====================================================================
        print("\n[Step 5] Creating clauses_proximity...")

        con.execute("ALTER TABLE directed_pairs ADD COLUMN clauses_proximity DOUBLE")
        con.execute("""
            UPDATE directed_pairs
            SET clauses_proximity = -ABS(numb_clauses_2009_i - numb_clauses_2009_j)
            WHERE numb_clauses_2009_i IS NOT NULL AND numb_clauses_2009_j IS NOT NULL
        """)

        # =====================================================================
        # STEP 6: Standardize variables
        # =====================================================================
        print("\n[Step 6] Standardizing variables...")

        vars_to_std = ['bilateral_conn_pw', 'geo_proximity', 'size_proximity', 'wage_proximity',
                       'female_proximity', 'nonwhite_proximity', 'educ_proximity', 'hs_proximity',
                       'clauses_proximity']

        existing_cols = [r[0] for r in con.execute("DESCRIBE directed_pairs").fetchall()]

        for var in vars_to_std:
            if var not in existing_cols:
                continue
            stats = con.execute(f"SELECT AVG({var}), STDDEV({var}) FROM directed_pairs WHERE {var} IS NOT NULL").fetchone()
            mean_val, std_val = stats[0], stats[1]

            if std_val and std_val > 0:
                z_col = f"z_{var}"
                con.execute(f"ALTER TABLE directed_pairs ADD COLUMN {z_col} DOUBLE")
                con.execute(f"UPDATE directed_pairs SET {z_col} = ({var} - {mean_val}) / {std_val}")
                print(f"  {var}: mean={mean_val:.4f}, std={std_val:.4f}")

        # =====================================================================
        # STEP 7: Export to Stata
        # =====================================================================
        print("\n[Step 7] Exporting to Stata...")

        final_cols = [
            'identificad_i', 'identificad_j', 'swapped',
            'bilateral_conn_pw', 'z_bilateral_conn_pw',
            'geo_proximity', 'z_geo_proximity',
            'size_proximity', 'z_size_proximity',
            'wage_proximity', 'z_wage_proximity',
            'female_proximity', 'z_female_proximity',
            'nonwhite_proximity', 'z_nonwhite_proximity',
            'educ_proximity', 'z_educ_proximity',
            'hs_proximity', 'z_hs_proximity',
            'clauses_proximity', 'z_clauses_proximity',
            'same_microregion', 'same_union', 'same_industry', 'same_industry_micro',
            'has_positive_flow', 'geo_distance'
        ]

        existing = [r[0] for r in con.execute("DESCRIBE directed_pairs").fetchall()]
        final_cols = [c for c in final_cols if c in existing]
        if 'same_muni' in existing:
            final_cols.append('same_muni')

        total_rows = con.execute("SELECT COUNT(*) FROM directed_pairs").fetchone()[0]
        print(f"  Rows: {total_rows:,}")

        # Write directly to parquet using DuckDB (much faster and smaller than Stata format)
        cols_str = ', '.join(final_cols)

        print(f"  Writing to {OUTPUT_PARQUET}...")
        con.execute(f"COPY (SELECT {cols_str} FROM directed_pairs) TO '{OUTPUT_PARQUET}' (FORMAT PARQUET, COMPRESSION ZSTD)")

        # Get file size
        file_size_gb = OUTPUT_PARQUET.stat().st_size / 1e9
        print(f"  Parquet file size: {file_size_gb:.2f} GB")

        elapsed = time.time() - start_time
        print("\n" + "=" * 70)
        print("COMPLETE")
        print("=" * 70)
        print(f"Output: {OUTPUT_PARQUET}")
        print(f"Rows: {total_rows:,}")
        print(f"Time: {elapsed/60:.1f} min")
        print("\nIMPORTANT: File is in /tmp - run Stata regression immediately!")
        print("           /tmp is cleared periodically by the system.")

    finally:
        if con is not None:
            con.close()
        if DB_FILE.exists():
            os.remove(DB_FILE)
            print("Cleaned up temp database")


if __name__ == "__main__":
    main()
