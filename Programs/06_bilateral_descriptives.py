"""
================================================================================
PROJECT: UNION SPILLOVERS
AUTHOR: LUIS GOMES
PROGRAM: BILATERAL CONNECTIVITY DESCRIPTIVES - DATA PREPARATION
INPUT: BILATERAL CONNECTIVITY FROM MATLAB, FIRM-LEVEL RAIS DATA
OUTPUT: BILATERAL PAIRS DATASET FOR STATA REGRESSION
================================================================================

This script creates all possible establishment pairs and computes proximity
measures efficiently in Python, streaming to CSV to avoid memory issues.
"""

import pandas as pd
import numpy as np
from pathlib import Path
import time
from itertools import combinations
import csv
import gc

# ============================================================================
# CONFIGURATION
# ============================================================================

# Paths - adjust these to match your environment
BASE_PATH = Path("/kellogg/proj/lgg3230/UnionSpill")
RAIS_FIRM = BASE_PATH / "Data" / "CBA_RAIS_firm_level"
RAIS_AUX = BASE_PATH / "Data" / "RAIS_aux"

# Processing parameters
BATCH_SIZE = 100_000  # Process this many pairs at a time before writing

# Sampling options (set to None for full sample)
# With 16,472 establishments, full sample = ~135 million pairs
SAMPLE_FRACTION = None  # Set to 0.10 for 10% sample, None for full sample
RANDOM_SEED = 12345


def main():
    start_time = time.time()
    print("=" * 70)
    print("BILATERAL DESCRIPTIVES - PYTHON DATA PREPARATION")
    print("=" * 70)

    # ========================================================================
    # STEP 1: Load bilateral connectivity from MATLAB output
    # ========================================================================
    print("\n[STEP 1] Loading bilateral connectivity data...")

    conn_path = RAIS_AUX / "bilateral_connectivity_2007_2011.csv"
    conn_df = pd.read_csv(conn_path, dtype={'identificad_i': str, 'identificad_j': str})

    # Remove the "1" prefix added during Stata export
    conn_df['identificad_i'] = conn_df['identificad_i'].str[1:]
    conn_df['identificad_j'] = conn_df['identificad_j'].str[1:]

    print(f"  Loaded {len(conn_df):,} directed pairs with positive flows")

    # Create undirected connectivity lookup (sum both directions)
    conn_df['id_min'] = np.minimum(conn_df['identificad_i'], conn_df['identificad_j'])
    conn_df['id_max'] = np.maximum(conn_df['identificad_i'], conn_df['identificad_j'])

    agg_dict = {'bilateral_conn_pw': 'sum', 'flows_total': 'sum'}
    conn_undir = conn_df.groupby(['id_min', 'id_max']).agg(agg_dict).reset_index()

    # Create lookup dictionary
    conn_lookup = {}
    for _, row in conn_undir.iterrows():
        key = (row['id_min'], row['id_max'])
        conn_lookup[key] = {
            'bilateral_conn_pw': row['bilateral_conn_pw'],
            'flows_total': row['flows_total']
        }

    print(f"  Created lookup with {len(conn_lookup):,} undirected pairs with flows")
    del conn_df, conn_undir
    gc.collect()

    # ========================================================================
    # STEP 2: Load sample establishments and their characteristics
    # ========================================================================
    print("\n[STEP 2] Loading sample establishments...")

    # Load main firm-level dataset
    firm_path = RAIS_FIRM / "cba_rais_firm_2009_2016_flows_1.dta"
    firm_df = pd.read_stata(firm_path)

    # Filter to 2009 and sample criteria
    firm_df = firm_df[firm_df['year'] == 2009].copy()
    firm_df = firm_df[
        (firm_df['lagos_sample_avg'] == 1) &
        (firm_df['in_balanced_panel'] == 1)
    ]

    # Keep relevant columns
    keep_cols = ['identificad', 'municipio', 'microregion', 'big_industry',
                 'industry1', 'mode_union']
    keep_cols = [c for c in keep_cols if c in firm_df.columns]
    firm_df = firm_df[keep_cols].drop_duplicates('identificad')
    firm_df['identificad'] = firm_df['identificad'].astype(str)

    n_estabs = len(firm_df)
    print(f"  Found {n_estabs:,} sample establishments")

    # ========================================================================
    # STEP 3: Load firm characteristics for 2009-2011 averages
    # ========================================================================
    print("\n[STEP 3] Computing 2009-2011 firm characteristic averages...")

    chars_dfs = []
    for year in [2009, 2010, 2011]:
        # Try multiple possible paths
        possible_paths = [
            BASE_PATH / "Data" / "RAIS_firm_level" / f"rais_firm_{year}.dta",
            RAIS_FIRM.parent / "RAIS_firm_level" / f"rais_firm_{year}.dta",
            RAIS_FIRM / f"rais_firm_{year}.dta",
        ]

        df = None
        for rais_path in possible_paths:
            if rais_path.exists():
                try:
                    df = pd.read_stata(rais_path)
                    print(f"    Loaded {year} from {rais_path}")
                    break
                except Exception as e:
                    continue

        if df is not None:
            df['identificad'] = df['identificad'].astype(str)
            char_cols = ['identificad', 'firm_emp', 'r_remdezr', 'male_prop',
                        'white_prop', 'prop_sup', 'prop_hs', 'prop_nhs']
            char_cols = [c for c in char_cols if c in df.columns]
            df = df[char_cols].copy()

            if 'male_prop' in df.columns:
                df['prop_female'] = 1 - df['male_prop']
            if 'white_prop' in df.columns:
                df['prop_nonwhite'] = 1 - df['white_prop']

            chars_dfs.append(df.set_index('identificad'))

    # Average across years
    if chars_dfs:
        chars_df = pd.concat(chars_dfs).groupby('identificad').mean().reset_index()
        chars_df['l_avg_firm_emp'] = np.log(chars_df['firm_emp'].clip(lower=1))
        chars_df['l_avg_r_remdezr'] = np.log(chars_df['r_remdezr'].clip(lower=1))
        chars_df = chars_df.rename(columns={'firm_emp': 'avg_firm_emp', 'r_remdezr': 'avg_r_remdezr'})
        print(f"  Computed averages for {len(chars_df):,} establishments")
    else:
        print("  WARNING: Could not load firm characteristics!")
        chars_df = pd.DataFrame({'identificad': firm_df['identificad']})

    # Merge characteristics with sample establishments
    estab_df = firm_df.merge(chars_df, on='identificad', how='left')

    # Create lookup dictionary
    estab_lookup = estab_df.set_index('identificad').to_dict('index')
    estab_ids = sorted(estab_df['identificad'].unique())

    del firm_df, chars_df, chars_dfs
    gc.collect()

    # ========================================================================
    # STEP 4: Generate all pairs and stream to CSV
    # ========================================================================
    print("\n[STEP 4] Generating pairs and streaming to CSV...")

    n_pairs_total = len(estab_ids) * (len(estab_ids) - 1) // 2
    print(f"  Total unique pairs: {n_pairs_total:,}")

    if SAMPLE_FRACTION is not None:
        n_pairs_sample = int(n_pairs_total * SAMPLE_FRACTION)
        print(f"  Sampling {SAMPLE_FRACTION*100:.0f}% = ~{n_pairs_sample:,} pairs")
        np.random.seed(RANDOM_SEED)

    # Define output columns
    output_cols = [
        'identificad_i', 'identificad_j', 'bilateral_conn_pw', 'flows_total', 'has_positive_flow',
        'same_muni', 'same_microregion', 'same_union', 'same_big_industry', 'same_industry', 'same_industry_micro',
        'size_proximity', 'wage_proximity', 'female_proximity', 'nonwhite_proximity',
        'educ_proximity', 'hs_proximity', 'nhs_proximity',
        'microregion_i', 'industry1_i'  # Keep for FE
    ]

    output_path = RAIS_AUX / "bilateral_pairs_descriptives.csv"

    # Open CSV file for streaming writes
    with open(output_path, 'w', newline='') as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=output_cols)
        writer.writeheader()

        batch = []
        pairs_written = 0
        pairs_processed = 0

        # Generate pairs using combinations
        for id_i, id_j in combinations(estab_ids, 2):
            pairs_processed += 1

            # Apply sampling if enabled
            if SAMPLE_FRACTION is not None:
                if np.random.random() > SAMPLE_FRACTION:
                    continue

            char_i = estab_lookup.get(id_i, {})
            char_j = estab_lookup.get(id_j, {})

            # Get connectivity
            conn_key = (id_i, id_j) if id_i < id_j else (id_j, id_i)
            conn_data = conn_lookup.get(conn_key, {'bilateral_conn_pw': 0, 'flows_total': 0})

            row = {
                'identificad_i': id_i,
                'identificad_j': id_j,
                'bilateral_conn_pw': conn_data['bilateral_conn_pw'],
                'flows_total': conn_data['flows_total'],
                'has_positive_flow': 1 if conn_data['flows_total'] > 0 else 0,
                'same_muni': 1 if char_i.get('municipio') == char_j.get('municipio') else 0,
                'same_microregion': 1 if char_i.get('microregion') == char_j.get('microregion') else 0,
                'same_union': 1 if char_i.get('mode_union') == char_j.get('mode_union') else 0,
                'same_big_industry': 1 if char_i.get('big_industry') == char_j.get('big_industry') else 0,
                'same_industry': 1 if char_i.get('industry1') == char_j.get('industry1') else 0,
                'same_industry_micro': 1 if (
                    char_i.get('industry1') == char_j.get('industry1') and
                    char_i.get('microregion') == char_j.get('microregion')
                ) else 0,
                'microregion_i': char_i.get('microregion'),
                'industry1_i': char_i.get('industry1'),
            }

            # Compute proximity measures
            for var, col in [
                ('size_proximity', 'l_avg_firm_emp'),
                ('wage_proximity', 'l_avg_r_remdezr'),
                ('female_proximity', 'prop_female'),
                ('nonwhite_proximity', 'prop_nonwhite'),
                ('educ_proximity', 'prop_sup'),
                ('hs_proximity', 'prop_hs'),
                ('nhs_proximity', 'prop_nhs'),
            ]:
                val_i = char_i.get(col)
                val_j = char_j.get(col)
                if val_i is not None and val_j is not None:
                    try:
                        row[var] = -abs(float(val_i) - float(val_j))
                    except (ValueError, TypeError):
                        row[var] = ''
                else:
                    row[var] = ''

            batch.append(row)

            # Write batch to file
            if len(batch) >= BATCH_SIZE:
                writer.writerows(batch)
                pairs_written += len(batch)
                batch = []

                if pairs_written % 1_000_000 == 0:
                    print(f"    Written {pairs_written:,} pairs ({100*pairs_processed/n_pairs_total:.1f}% processed)...")

        # Write remaining batch
        if batch:
            writer.writerows(batch)
            pairs_written += len(batch)

    print(f"  Total pairs written: {pairs_written:,}")
    print(f"  Output saved to: {output_path}")

    # ========================================================================
    # STEP 5: Summary statistics (quick sample)
    # ========================================================================
    print("\n[STEP 5] Quick summary (first 100k rows)...")

    sample_df = pd.read_csv(output_path, nrows=100_000)
    print(f"\n  Sample stats (n={len(sample_df):,}):")
    print(f"  Pairs with positive flows: {sample_df['has_positive_flow'].mean()*100:.2f}%")
    for col in ['same_muni', 'same_microregion', 'same_union', 'same_industry']:
        print(f"  Mean {col}: {sample_df[col].mean():.4f}")

    # ========================================================================
    # DONE
    # ========================================================================
    elapsed = time.time() - start_time
    print(f"\n{'=' * 70}")
    print(f"COMPLETED in {elapsed/60:.1f} minutes")
    print(f"Output: {output_path}")
    print(f"Total pairs: {pairs_written:,}")
    print(f"\nNext step: Run 06_bilateral_regression.do in Stata")
    print(f"{'=' * 70}")


if __name__ == "__main__":
    main()
