"""
011b_corrected_turnover.py
==========================
Builds a corrected establishment × year panel (2009-2016) with additive
turnover measures based on **unique workers**, not spells.

Additivity: separations_u = layoffs_u + quits_u + other_sep_u

Algorithm
---------
For each separated worker-establishment pair, one spell is selected using
the same ranking as final_rank (hours ↓, Dec hourly wage ↓, random tiebreaker),
and that spell's causadesli determines the separation category.

Input
-----
- Raw RAIS: /kellogg/proj/lgg3230/RAIS/output/data/full/RAIS_{year}.dta
- Sample IDs: Data/CBA_RAIS_firm_level/cba_rais_firm_2009_2016_flows_1.dta

Output
------
- Data/CBA_RAIS_firm_level/corrected_turnover_sample.dta
"""

import duckdb
import pandas as pd
import numpy as np
import time
import os

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
PROJECT = "/kellogg/proj/lgg3230/UnionSpill"
RAIS_DIR = "/kellogg/proj/lgg3230/RAIS/output/data/full"
SAMPLE_FILE = os.path.join(PROJECT, "Data/CBA_RAIS_firm_level/cba_rais_firm_2009_2016_flows_1.dta")
OUTPUT_FILE = os.path.join(PROJECT, "Data/CBA_RAIS_firm_level/corrected_turnover_sample.dta")

YEARS = range(2009, 2017)

# Columns needed from RAIS
COLS = [
    "identificad", "PIS", "horascontr", "remdezr", "causadesli",
    "empem3112", "tempempr", "dtadmissao", "mesdesli",
]

# ---------------------------------------------------------------------------
# Load sample establishment IDs
# ---------------------------------------------------------------------------
print("Loading sample establishment IDs...")
sample_df = pd.read_stata(
    SAMPLE_FILE,
    columns=["identificad", "lagos_sample_avg", "in_balanced_panel"],
    convert_categoricals=False,
)
# Keep only sample establishments (take unique across years)
sample_df = sample_df.query("lagos_sample_avg == 1 & in_balanced_panel == 1")
sample_ids = set(sample_df["identificad"].unique())
print(f"  {len(sample_ids):,} unique sample establishments")
del sample_df

# ---------------------------------------------------------------------------
# DuckDB connection
# ---------------------------------------------------------------------------
con = duckdb.connect()
con.execute("PRAGMA threads=8")
con.execute("PRAGMA memory_limit='32GB'")

all_years = []

for year in YEARS:
    t0 = time.time()
    rais_file = os.path.join(RAIS_DIR, f"RAIS_{year}.dta")
    print(f"\n{'='*60}")
    print(f"Processing {year} — {rais_file}")

    # ------------------------------------------------------------------
    # Read RAIS in chunks, filtering to sample establishments
    # ------------------------------------------------------------------
    print("  Reading RAIS (chunked, filtering to sample)...")
    chunks = []
    n_total = 0
    n_kept = 0
    reader = pd.read_stata(
        rais_file,
        columns=COLS,
        chunksize=5_000_000,
        convert_categoricals=False,
    )
    for chunk in reader:
        n_total += len(chunk)
        filtered = chunk[chunk["identificad"].isin(sample_ids)]
        n_kept += len(filtered)
        if len(filtered) > 0:
            chunks.append(filtered)

    if not chunks:
        print(f"  WARNING: No sample observations found for {year}. Skipping.")
        continue

    df = pd.concat(chunks, ignore_index=True)
    del chunks
    print(f"  Read {n_total:,} rows, kept {n_kept:,} sample rows ({n_kept/n_total*100:.1f}%)")

    # ------------------------------------------------------------------
    # Register in DuckDB and compute measures
    # ------------------------------------------------------------------
    con.register("rais", df)

    # Compute hourly December wage for ranking (0 if missing/zero)
    # empdec_lagos = empem3112 * (tempempr > 1)
    # final_rank logic: among empdec_lagos==1, rank by hours desc, dec wage desc, random
    result = con.execute(f"""
    WITH base AS (
        SELECT
            identificad,
            PIS,
            horascontr,
            causadesli,
            empem3112,
            tempempr,
            dtadmissao,
            mesdesli,
            -- empdec_lagos: employed in Dec per Lagos (2021)
            CASE WHEN empem3112 = 1 AND tempempr > 1 THEN 1 ELSE 0 END AS empdec_lagos,
            -- Hourly Dec wage (for ranking); treat NULL/0 remdezr as 0
            CASE
                WHEN remdezr IS NULL OR remdezr = 0 OR horascontr IS NULL OR horascontr = 0
                THEN 0.0
                ELSE remdezr / (horascontr * 4.348)
            END AS remdezr_h,
            -- Random tiebreaker (seeded via hash for reproducibility)
            hash(identificad || '|' || PIS || '|' || CAST(horascontr AS VARCHAR)
                 || '|' || CAST(remdezr AS VARCHAR) || '|12345') / 1e19 AS random_tb
        FROM rais
    ),

    -- =================================================================
    -- December employment: unique workers via final_rank
    -- =================================================================
    dec_ranked AS (
        SELECT *,
            ROW_NUMBER() OVER (
                PARTITION BY identificad, PIS
                ORDER BY
                    CASE WHEN empdec_lagos = 1 THEN horascontr ELSE -1 END DESC,
                    CASE WHEN empdec_lagos = 1 THEN remdezr_h  ELSE -1 END DESC,
                    random_tb DESC
            ) AS rn_dec
        FROM base
        WHERE empdec_lagos = 1
    ),
    dec_emp AS (
        SELECT identificad, COUNT(*) AS firm_emp
        FROM dec_ranked
        WHERE rn_dec = 1
        GROUP BY identificad
    ),

    -- =================================================================
    -- Separations: unique workers, one spell per worker-estab
    -- =================================================================
    separated AS (
        SELECT *
        FROM base
        WHERE causadesli != 0 AND causadesli IS NOT NULL
    ),
    sep_ranked AS (
        SELECT *,
            ROW_NUMBER() OVER (
                PARTITION BY identificad, PIS
                ORDER BY horascontr DESC, remdezr_h DESC, random_tb DESC
            ) AS rn_sep
        FROM separated
    ),
    sep_selected AS (
        SELECT
            identificad,
            PIS,
            causadesli,
            CASE WHEN causadesli IN (10, 11) THEN 1 ELSE 0 END AS is_layoff,
            CASE WHEN causadesli IN (20, 21) THEN 1 ELSE 0 END AS is_quit,
            CASE WHEN causadesli NOT IN (10, 11, 20, 21) THEN 1 ELSE 0 END AS is_other_sep
        FROM sep_ranked
        WHERE rn_sep = 1
    ),
    sep_counts AS (
        SELECT
            identificad,
            COUNT(*)        AS separations_u,
            SUM(is_layoff)  AS layoffs_u,
            SUM(is_quit)    AS quits_u,
            SUM(is_other_sep) AS other_sep_u
        FROM sep_selected
        GROUP BY identificad
    ),

    -- =================================================================
    -- Hiring: unique workers hired in year
    -- =================================================================
    hired AS (
        SELECT DISTINCT identificad, PIS
        FROM base
        WHERE YEAR(CAST(dtadmissao AS DATE)) = {year}
    ),
    hire_counts AS (
        SELECT identificad, COUNT(*) AS hired_u
        FROM hired
        GROUP BY identificad
    )

    -- =================================================================
    -- Combine
    -- =================================================================
    SELECT
        d.identificad,
        {year} AS year,
        d.firm_emp,
        COALESCE(s.separations_u, 0) AS separations_u,
        COALESCE(s.layoffs_u, 0)     AS layoffs_u,
        COALESCE(s.quits_u, 0)       AS quits_u,
        COALESCE(s.other_sep_u, 0)   AS other_sep_u,
        COALESCE(h.hired_u, 0)       AS hired_u,
        -- Rates
        CASE WHEN d.firm_emp > 0 THEN COALESCE(s.separations_u, 0) * 1.0 / d.firm_emp ELSE NULL END AS turnover_u,
        CASE WHEN d.firm_emp > 0 THEN COALESCE(s.layoffs_u, 0)     * 1.0 / d.firm_emp ELSE NULL END AS layoff_rate_u,
        CASE WHEN d.firm_emp > 0 THEN COALESCE(s.quits_u, 0)       * 1.0 / d.firm_emp ELSE NULL END AS quit_rate_u,
        CASE WHEN d.firm_emp > 0 THEN COALESCE(s.other_sep_u, 0)   * 1.0 / d.firm_emp ELSE NULL END AS other_sep_rate_u,
        CASE WHEN d.firm_emp > 0 THEN COALESCE(h.hired_u, 0)       * 1.0 / d.firm_emp ELSE NULL END AS hiring_rate_u
    FROM dec_emp d
    LEFT JOIN sep_counts s ON d.identificad = s.identificad
    LEFT JOIN hire_counts h ON d.identificad = h.identificad
    ORDER BY d.identificad
    """).fetch_arrow_table().to_pandas()

    con.unregister("rais")
    del df

    # Verification: additivity check
    addit_check = (result["separations_u"] == result["layoffs_u"] + result["quits_u"] + result["other_sep_u"]).all()
    print(f"  Additivity check (separations = layoffs + quits + other): {'PASS' if addit_check else 'FAIL'}")
    print(f"  Establishments: {len(result):,}")
    print(f"  Median turnover_u: {result['turnover_u'].median():.3f}")
    print(f"  Median hiring_rate_u: {result['hiring_rate_u'].median():.3f}")

    all_years.append(result)
    elapsed = time.time() - t0
    print(f"  Done in {elapsed:.1f}s")

# ---------------------------------------------------------------------------
# Combine all years and save
# ---------------------------------------------------------------------------
print(f"\n{'='*60}")
print("Combining all years and saving...")

panel = pd.concat(all_years, ignore_index=True)
print(f"Total observations: {len(panel):,}")
print(f"Unique establishments: {panel['identificad'].nunique():,}")
print(f"Years: {sorted(panel['year'].unique())}")

# Log employment
panel["l_firm_emp"] = np.log(panel["firm_emp"].replace(0, np.nan))

# Save as Stata .dta
panel.to_stata(OUTPUT_FILE, write_index=False, version=118)
print(f"Saved to {OUTPUT_FILE}")

# ---------------------------------------------------------------------------
# Summary statistics
# ---------------------------------------------------------------------------
print(f"\n{'='*60}")
print("Summary statistics:")
for col in ["firm_emp", "separations_u", "layoffs_u", "quits_u", "other_sep_u",
            "hired_u", "turnover_u", "layoff_rate_u", "quit_rate_u",
            "other_sep_rate_u", "hiring_rate_u"]:
    s = panel[col].describe()
    print(f"  {col:20s}: mean={s['mean']:.3f}  median={s['50%']:.3f}  "
          f"min={s['min']:.3f}  max={s['max']:.1f}")

con.close()
print("\nDone.")
