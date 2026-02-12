#!/home/lgg3230/.conda/envs/venv_python312/bin/python
"""
PROJECT: UNION SPILLOVERS
AUTHOR: LUIS GOMES
PROGRAM: 064_process_cep_centroids.py
PURPOSE: Process CEP centroid coordinates from IBGE data
INPUT: Data/IBGE/cep_centroids.csv
OUTPUT: Data/IBGE/cep_coordinates.csv, Data/IBGE/cep_coordinates.dta
"""

import pandas as pd
import re
from pathlib import Path

# ==============================================================================
# PATHS
# ==============================================================================

BASE_DIR = Path("/kellogg/proj/lgg3230/UnionSpill")
IBGE_DIR = BASE_DIR / "Data" / "IBGE"

INPUT_FILE = IBGE_DIR / "cep_centroids.csv"
OUTPUT_CSV = IBGE_DIR / "cep_coordinates.csv"
OUTPUT_DTA = IBGE_DIR / "cep_coordinates.dta"

# ==============================================================================
# MAIN
# ==============================================================================

def parse_point(point_str):
    """Parse POINT(-55.5 -30.8) format to longitude, latitude."""
    if pd.isna(point_str):
        return None, None
    match = re.match(r'POINT\(([-\d.]+)\s+([-\d.]+)\)', str(point_str))
    if match:
        lon = float(match.group(1))
        lat = float(match.group(2))
        return lon, lat
    return None, None


def main():
    print("=" * 70)
    print("PROCESSING CEP CENTROIDS")
    print("=" * 70)

    # Load CEP centroids
    print(f"\nLoading: {INPUT_FILE}")
    df = pd.read_csv(INPUT_FILE)
    print(f"  Rows: {len(df):,}")
    print(f"  Columns: {list(df.columns)}")

    # Parse POINT format to get lat/lon
    print("\nParsing coordinates...")
    coords = df['centroide'].apply(parse_point)
    df['longitude'] = coords.apply(lambda x: x[0])
    df['latitude'] = coords.apply(lambda x: x[1])

    # Check for missing coordinates
    missing = df['latitude'].isna().sum()
    print(f"  Missing coordinates: {missing:,}")

    # Standardize CEP format (8 digits, zero-padded string)
    print("\nStandardizing CEP format...")
    df['cep'] = df['cep'].astype(str).str.zfill(8)

    # Keep relevant columns
    df_out = df[['cep', 'latitude', 'longitude']].copy()

    # Drop rows with missing coordinates
    df_out = df_out.dropna(subset=['latitude', 'longitude'])
    print(f"  CEPs with valid coordinates: {len(df_out):,}")

    # Check for duplicates
    dups = df_out['cep'].duplicated().sum()
    if dups > 0:
        print(f"  WARNING: {dups} duplicate CEPs found, keeping first occurrence")
        df_out = df_out.drop_duplicates(subset=['cep'], keep='first')

    # Save outputs
    print(f"\nSaving: {OUTPUT_CSV}")
    df_out.to_csv(OUTPUT_CSV, index=False)

    print(f"Saving: {OUTPUT_DTA}")
    df_out.to_stata(OUTPUT_DTA, write_index=False, version=118)

    # Summary stats
    print("\n" + "=" * 70)
    print("SUMMARY")
    print("=" * 70)
    print(f"Total CEPs: {len(df_out):,}")
    print(f"Latitude range: [{df_out['latitude'].min():.4f}, {df_out['latitude'].max():.4f}]")
    print(f"Longitude range: [{df_out['longitude'].min():.4f}, {df_out['longitude'].max():.4f}]")

    print("\nDone!")


if __name__ == "__main__":
    main()
