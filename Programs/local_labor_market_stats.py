"""
Compute local labor market size statistics based on worker flows.

For each sample firm, counts:
1. How many unique other firms (across all of RAIS) it is connected to via worker flows
2. What proportion of those connected firms are treated (treat_ultra==1)

Reports statistics for 5 groups:
- Whole analysis sample
- Directly treated (treat_ultra==1)
- Untreated (treat_ultra==0)
- Untreated with positive connectivity (treat_ultra==0 & totaltreat_pw_n>0)
- Untreated with zero connectivity (treat_ultra==0 & totaltreat_pw_n==0)
"""

import duckdb
import pandas as pd
import numpy as np

# --- Setup ---
con = duckdb.connect()
con.execute("PRAGMA threads=8")
con.execute("PRAGMA memory_limit='32GB'")

DATA = "/gpfs/kellogg/proj/lgg3230/UnionSpill/Data"
RAIS_AUX = f"{DATA}/RAIS_aux"
FIRM_DATA = f"{DATA}/CBA_RAIS_firm_level/cba_rais_firm_2009_2016_flows_1.dta"

# --- Step 1: Load firm-level data (one obs per firm, using year 2011) ---
print("Loading firm-level data...")
firm_cols = ['identificad', 'year', 'treat_ultra', 'lagos_sample_avg',
             'in_balanced_panel', 'totaltreat_pw_n']

df_firm = pd.read_stata(FIRM_DATA, columns=firm_cols)
# Keep one observation per firm (year 2011, pre-treatment)
df_firm = df_firm[df_firm['year'] == 2011].copy()
df_firm = df_firm.drop_duplicates(subset='identificad')
print(f"  Total firms in 2011: {len(df_firm):,}")

# Analysis sample: lagos_sample_avg==1 & in_balanced_panel==1
sample = df_firm[(df_firm['lagos_sample_avg'] == 1) & (df_firm['in_balanced_panel'] == 1)].copy()
print(f"  Analysis sample firms: {len(sample):,}")

# Register firm-level data in DuckDB
# IDs in firm data are 14-char zero-padded strings (e.g., "01425787000287")
# IDs in employer CSVs are 15-digit BIGINTs with leading "1" (e.g., 101425787000287)
# To match: add leading "1" to firm IDs and cast to BIGINT
con.execute("""
    CREATE TABLE sample_firms AS
    SELECT
        identificad,
        CAST('1' || identificad AS BIGINT) AS identificad_csv,
        treat_ultra,
        totaltreat_pw_n
    FROM sample
""")
# Register ALL firms with treatment status
# Store both 14-char string ID and the 15-digit CSV-format ID
con.execute("""
    CREATE TABLE all_firms_treat AS
    SELECT
        identificad,
        CAST('1' || identificad AS BIGINT) AS identificad_csv,
        treat_ultra
    FROM df_firm
    WHERE treat_ultra IS NOT NULL
""")
print(f"  Firms with known treat_ultra: {con.execute('SELECT COUNT(*) FROM all_firms_treat').fetchone()[0]:,}")

# Also register only SAMPLE firms with treatment (for consistent "treated" definition)
# totaltreat_pw_n measures flows to treated firms IN the analysis sample,
# so we should use the same restriction when counting connected treated firms
con.execute("""
    CREATE TABLE sample_firms_treat AS
    SELECT
        identificad,
        CAST('1' || identificad AS BIGINT) AS identificad_csv,
        treat_ultra
    FROM sample
""")
n_sample_treated = con.execute("SELECT COUNT(*) FROM sample_firms_treat WHERE treat_ultra = 1").fetchone()[0]
print(f"  Treated firms in analysis sample: {n_sample_treated:,}")

# Verify ID conversion
r = con.execute("SELECT identificad, identificad_csv FROM sample_firms LIMIT 3").fetchall()
print(f"  ID conversion check: {r}")

# --- Step 2: Process employer transition files to count unique connections ---
year_pairs = [
    ('2007', '2008'),
    ('2008', '2009'),
    ('2009', '2010'),
    ('2010', '2011'),
]

print("\nProcessing employer transition files...")

# For each sample firm, collect all unique connected firms across all year pairs
# A connection exists when a worker moves from firm A to firm B (A != B)
# Store connected_firm as the CSV-format BIGINT for later matching
con.execute("CREATE TABLE all_connections (sample_firm VARCHAR, connected_firm BIGINT)")

for yr1, yr2 in year_pairs:
    fname = f"{RAIS_AUX}/employers_{yr1}_{yr2}.csv"
    print(f"  Processing {yr1}-{yr2}...")

    # Extract connections where a worker changes firms
    # Connection is bidirectional: if worker goes A->B, both A and B are connected
    # Match using CSV-format BIGINT IDs (with leading "1")
    con.execute(f"""
        INSERT INTO all_connections
        -- Sample firm is the origin, connected firm is destination
        SELECT s.identificad AS sample_firm,
               e.identificad_{yr2} AS connected_firm
        FROM read_csv('{fname}', auto_detect=true) e
        JOIN sample_firms s ON e.identificad_{yr1} = s.identificad_csv
        WHERE e.identificad_{yr1} != e.identificad_{yr2}

        UNION ALL

        -- Sample firm is the destination, connected firm is origin
        SELECT s.identificad AS sample_firm,
               e.identificad_{yr1} AS connected_firm
        FROM read_csv('{fname}', auto_detect=true) e
        JOIN sample_firms s ON e.identificad_{yr2} = s.identificad_csv
        WHERE e.identificad_{yr1} != e.identificad_{yr2}
    """)

print("\nAggregating unique connections per sample firm...")

# Count unique connected firms per sample firm, and how many are treated
# Use sample_firms_treat (not all_firms_treat) so "treated" is consistent
# with the totaltreat_pw_n definition (flows to treated firms in analysis sample)
con.execute("""
    CREATE TABLE firm_connections AS
    SELECT
        c.sample_firm AS identificad,
        COUNT(DISTINCT c.connected_firm) AS n_connected_firms,
        COUNT(DISTINCT CASE WHEN st.treat_ultra = 1 THEN c.connected_firm END) AS n_connected_treated,
        COUNT(DISTINCT CASE WHEN st.treat_ultra = 0 THEN c.connected_firm END) AS n_connected_untreated,
        COUNT(DISTINCT CASE WHEN st.treat_ultra IS NOT NULL THEN c.connected_firm END) AS n_connected_in_sample
    FROM all_connections c
    LEFT JOIN sample_firms_treat st ON c.connected_firm = st.identificad_csv
    GROUP BY c.sample_firm
""")

# Merge with sample firm characteristics
result = con.execute("""
    SELECT
        s.identificad,
        s.treat_ultra,
        s.totaltreat_pw_n,
        COALESCE(fc.n_connected_firms, 0) AS n_connected_firms,
        COALESCE(fc.n_connected_treated, 0) AS n_connected_treated,
        COALESCE(fc.n_connected_untreated, 0) AS n_connected_untreated,
        COALESCE(fc.n_connected_in_sample, 0) AS n_connected_in_sample,
        CASE WHEN COALESCE(fc.n_connected_firms, 0) > 0
             THEN COALESCE(fc.n_connected_treated, 0)::FLOAT / fc.n_connected_firms
             ELSE 0 END AS prop_connected_treated,
        CASE WHEN COALESCE(fc.n_connected_in_sample, 0) > 0
             THEN COALESCE(fc.n_connected_treated, 0)::FLOAT / fc.n_connected_in_sample
             ELSE NULL END AS prop_treated_among_known
    FROM sample_firms s
    LEFT JOIN firm_connections fc ON s.identificad = fc.identificad
""").fetch_arrow_table().to_pandas()

print(f"\nFinal dataset: {len(result):,} firms")
print(f"  Firms with at least one connection: {(result['n_connected_firms'] > 0).sum():,}")

# --- Step 3: Compute statistics by group ---
def compute_stats(df, group_name):
    """Compute summary statistics for a group."""
    n = len(df)
    if n == 0:
        return None

    stats = {
        'Group': group_name,
        'N firms': n,
        'Mean connected firms': df['n_connected_firms'].mean(),
        'Median connected firms': df['n_connected_firms'].median(),
        'SD connected firms': df['n_connected_firms'].std(),
        'P25 connected firms': df['n_connected_firms'].quantile(0.25),
        'P75 connected firms': df['n_connected_firms'].quantile(0.75),
        'Min connected firms': df['n_connected_firms'].min(),
        'Max connected firms': df['n_connected_firms'].max(),
        'Mean connected treated': df['n_connected_treated'].mean(),
        'Median connected treated': df['n_connected_treated'].median(),
        'Mean prop treated (all connected)': df['prop_connected_treated'].mean(),
        'Median prop treated (all connected)': df['prop_connected_treated'].median(),
        'Mean prop treated (known status)': df['prop_treated_among_known'].mean(),
        'Median prop treated (known status)': df['prop_treated_among_known'].median(),
        'Mean connected in sample': df['n_connected_in_sample'].mean(),
        'Median connected in sample': df['n_connected_in_sample'].median(),
    }
    return stats

# Define groups
groups = {
    'Whole sample': result,
    'Treated (treat_ultra=1)': result[result['treat_ultra'] == 1],
    'Untreated (treat_ultra=0)': result[result['treat_ultra'] == 0],
    'Untreated, positive connectivity': result[(result['treat_ultra'] == 0) & (result['totaltreat_pw_n'] > 0)],
    'Untreated, zero connectivity': result[(result['treat_ultra'] == 0) & (result['totaltreat_pw_n'] == 0)],
}

print("\n" + "=" * 100)
print("LOCAL LABOR MARKET SIZE STATISTICS (Pre-treatment worker flows, 2007-2011)")
print("=" * 100)

all_stats = []
for group_name, group_df in groups.items():
    stats = compute_stats(group_df, group_name)
    if stats:
        all_stats.append(stats)

stats_df = pd.DataFrame(all_stats)

# Print formatted table
for _, row in stats_df.iterrows():
    print(f"\n--- {row['Group']} (N = {int(row['N firms']):,}) ---")
    print(f"  Connected firms (across all RAIS):")
    print(f"    Mean:   {row['Mean connected firms']:.1f}")
    print(f"    Median: {row['Median connected firms']:.0f}")
    print(f"    SD:     {row['SD connected firms']:.1f}")
    print(f"    P25:    {row['P25 connected firms']:.0f}")
    print(f"    P75:    {row['P75 connected firms']:.0f}")
    print(f"    Min:    {int(row['Min connected firms'])}")
    print(f"    Max:    {int(row['Max connected firms'])}")
    print(f"  Connected treated firms:")
    print(f"    Mean:   {row['Mean connected treated']:.1f}")
    print(f"    Median: {row['Median connected treated']:.0f}")
    print(f"  Proportion treated (among all connected firms):")
    print(f"    Mean:   {row['Mean prop treated (all connected)']:.4f}")
    print(f"    Median: {row['Median prop treated (all connected)']:.4f}")
    print(f"  Proportion treated (among connected firms with known status):")
    print(f"    Mean:   {row['Mean prop treated (known status)']:.4f}")
    print(f"    Median: {row['Median prop treated (known status)']:.4f}")
    print(f"  Connected firms in analysis sample:")
    print(f"    Mean:   {row['Mean connected in sample']:.1f}")
    print(f"    Median: {row['Median connected in sample']:.0f}")

# Save to CSV
output_path = f"{DATA}/../Tables/local_labor_market_stats.csv"
stats_df.to_csv(output_path, index=False)
print(f"\nStatistics saved to {output_path}")

# Also save firm-level results
firm_output = f"{RAIS_AUX}/firm_local_labor_market_size.csv"
result.to_csv(firm_output, index=False)
print(f"Firm-level results saved to {firm_output}")

con.close()
