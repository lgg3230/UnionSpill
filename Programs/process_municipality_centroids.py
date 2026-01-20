"""
Process municipality centroid data for bilateral connectivity analysis.
Extracts longitude and latitude from POINT format and saves as Stata-compatible file.

Input: municipio_centroid.csv with centroide column in format "POINT(longitude latitude)"
Output: municipality_coordinates.csv with municipio, latitude, longitude columns
"""

import pandas as pd
import re

# Define paths
input_file = '/kellogg/proj/lgg3230/UnionSpill/Data/IBGE/municipio_centroid.csv'
output_file = '/kellogg/proj/lgg3230/UnionSpill/Data/IBGE/municipality_coordinates.csv'

# Read the CSV file
print(f"Reading {input_file}...")
df = pd.read_csv(input_file)

print(f"Loaded {len(df)} municipalities")
print(f"Columns: {df.columns.tolist()}")

# Function to extract longitude and latitude from POINT format
def parse_point(point_str):
    """
    Parse POINT(-61.8800839234306 -11.4707893352808) format.
    First number is longitude, second is latitude.
    """
    if pd.isna(point_str):
        return None, None

    # Use regex to extract the two numbers
    # Pattern matches: POINT( followed by two numbers separated by space
    match = re.search(r'POINT\(([-\d.]+)\s+([-\d.]+)\)', str(point_str))

    if match:
        longitude = float(match.group(1))
        latitude = float(match.group(2))
        return longitude, latitude
    else:
        print(f"Warning: Could not parse: {point_str}")
        return None, None

# Apply parsing to centroide column
print("Parsing centroid coordinates...")
coords = df['centroide'].apply(parse_point)

# Extract longitude and latitude into separate columns
df['longitude'] = coords.apply(lambda x: x[0])
df['latitude'] = coords.apply(lambda x: x[1])

# Create output dataframe with required columns
# Using id_municipio (7-digit) as municipio
output_df = df[['id_municipio', 'latitude', 'longitude']].copy()
output_df.columns = ['municipio', 'latitude', 'longitude']

# Remove rows with missing coordinates
n_before = len(output_df)
output_df = output_df.dropna(subset=['latitude', 'longitude'])
n_after = len(output_df)
if n_before != n_after:
    print(f"Dropped {n_before - n_after} rows with missing coordinates")

# Ensure municipio is integer
output_df['municipio'] = output_df['municipio'].astype(int)

# Display sample
print("\nSample of processed data:")
print(output_df.head(10))

# Display summary statistics
print("\nSummary statistics:")
print(f"  Municipalities: {len(output_df)}")
print(f"  Latitude range: {output_df['latitude'].min():.4f} to {output_df['latitude'].max():.4f}")
print(f"  Longitude range: {output_df['longitude'].min():.4f} to {output_df['longitude'].max():.4f}")

# Save to CSV
print(f"\nSaving to {output_file}...")
output_df.to_csv(output_file, index=False)

print("Done!")
print(f"\nTo create the Stata file, run in Stata:")
print(f'  import delimited "{output_file}", clear')
print(f'  save "$ibge/municipality_coordinates.dta", replace')
