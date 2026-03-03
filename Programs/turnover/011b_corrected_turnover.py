"""
011b_corrected_turnover.py
==========================
Builds a corrected establishment × year panel (2009-2016) with additive
turnover measures based on **unique workers**, not spells.

Additivity: separations_u = layoffs_u + quits_u + other_sep_u

Rates are computed as count / avg(firm_emp_t, firm_emp_{t-1}).
For 2009, firm_emp_{t-1} comes from RAIS_2008. If a firm isn't in 2008,
we fall back to using 2009 employment alone.

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
- Data/CBA_RAIS_firm_level/corrected_turnover_sample.csv
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
OUTPUT_FILE = os.path.join(PROJECT, "Data/CBA_RAIS_firm_level/corrected_turnover_sample.csv")

YEARS = range(2008, 2017)

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
prev_dec_workers = {}  # {identificad -> set of PIS} for previous year's Dec workers

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

    # ------------------------------------------------------------------
    # Pre-query: extract Dec worker set for this year (for YoY retention)
    # ------------------------------------------------------------------
    dec_workers_df = con.execute("""
        WITH base AS (
            SELECT
                identificad,
                PIS,
                horascontr,
                CASE WHEN empem3112 = 1 AND (tempempr > 1 OR tempempr IS NULL) THEN 1 ELSE 0 END AS empdec_lagos,
                CASE
                    WHEN remdezr IS NULL OR remdezr = 0 OR horascontr IS NULL OR horascontr = 0
                    THEN 0.0
                    ELSE remdezr / (horascontr * 4.348)
                END AS remdezr_h,
                hash(identificad || '|' || PIS || '|' || CAST(horascontr AS VARCHAR)
                     || '|' || CAST(remdezr AS VARCHAR) || '|12345') / 1e19 AS random_tb
            FROM rais
        ),
        dec_ranked AS (
            SELECT
                identificad,
                PIS,
                ROW_NUMBER() OVER (
                    PARTITION BY identificad, PIS
                    ORDER BY horascontr DESC, remdezr_h DESC, random_tb DESC
                ) AS rn_dec
            FROM base
            WHERE empdec_lagos = 1
        )
        SELECT identificad, PIS
        FROM dec_ranked
        WHERE rn_dec = 1
    """).fetch_arrow_table().to_pandas()

    cur_dec_workers = (
        dec_workers_df
        .groupby("identificad")["PIS"]
        .apply(set)
        .to_dict()
    )

    # Compute YoY retention numerator: workers in Dec(t-1) AND Dec(t)
    if year >= 2009 and prev_dec_workers:
        cur_dec_set = set(zip(dec_workers_df["identificad"], dec_workers_df["PIS"]))
        yoy_counts = {}
        for estab, prev_pis_set in prev_dec_workers.items():
            count = sum(1 for pis in prev_pis_set if (estab, pis) in cur_dec_set)
            if count > 0:
                yoy_counts[estab] = count
    else:
        yoy_counts = {}

    if year == 2008:
        # For 2008, we only need Dec employment (used as lag for 2009)
        result = con.execute(f"""
        WITH base AS (
            SELECT
                identificad,
                PIS,
                horascontr,
                empem3112,
                tempempr,
                CASE WHEN empem3112 = 1 AND (tempempr > 1 OR tempempr IS NULL) THEN 1 ELSE 0 END AS empdec_lagos,
                CASE
                    WHEN remdezr IS NULL OR remdezr = 0 OR horascontr IS NULL OR horascontr = 0
                    THEN 0.0
                    ELSE remdezr / (horascontr * 4.348)
                END AS remdezr_h,
                hash(identificad || '|' || PIS || '|' || CAST(horascontr AS VARCHAR)
                     || '|' || CAST(remdezr AS VARCHAR) || '|12345') / 1e19 AS random_tb
            FROM rais
        ),
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
            SELECT identificad, COUNT(*) AS firm_emp, SUM(horascontr) AS total_hours
            FROM dec_ranked
            WHERE rn_dec = 1
            GROUP BY identificad
        )
        SELECT
            identificad,
            {year} AS year,
            firm_emp,
            total_hours,
            0 AS separations_u,
            0 AS layoffs_u,
            0 AS quits_u,
            0 AS other_sep_u,
            0 AS hired_u,
            0 AS firm_emp_jan,
            0 AS jan_dec_count
        FROM dec_emp
        ORDER BY identificad
        """).fetch_arrow_table().to_pandas()

        print(f"  Establishments (2008, emp only): {len(result):,}")
    else:
        # Full query for 2009-2016: counts + employment
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
                COALESCE(
                    TRY_CAST(dtadmissao AS DATE),
                    TRY_STRPTIME(CAST(dtadmissao AS VARCHAR), '%d%m%Y')
                ) AS admit_date,
                CASE WHEN empem3112 = 1 AND (tempempr > 1 OR tempempr IS NULL) THEN 1 ELSE 0 END AS empdec_lagos,
                CASE
                    WHEN remdezr IS NULL OR remdezr = 0 OR horascontr IS NULL OR horascontr = 0
                    THEN 0.0
                    ELSE remdezr / (horascontr * 4.348)
                END AS remdezr_h,
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
            SELECT identificad, COUNT(*) AS firm_emp, SUM(horascontr) AS total_hours
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
            WHERE YEAR(admit_date) = {year}
        ),
        hire_counts AS (
            SELECT identificad, COUNT(*) AS hired_u
            FROM hired
            GROUP BY identificad
        ),

        -- =================================================================
        -- January employment: unique workers via jan_rank
        -- =================================================================
        jan_filter AS (
            SELECT *
            FROM base
            WHERE admit_date < MAKE_DATE({year}, 1, 1)
              AND (mesdesli IS NULL OR mesdesli != 1)
              AND DATEDIFF('month', admit_date, MAKE_DATE({year}, 1, 31)) > 1
        ),
        jan_ranked AS (
            SELECT *,
                ROW_NUMBER() OVER (
                    PARTITION BY identificad, PIS
                    ORDER BY horascontr DESC, remdezr_h DESC, random_tb DESC
                ) AS rn_jan
            FROM jan_filter
        ),
        jan_emp AS (
            SELECT identificad, COUNT(*) AS firm_emp_jan
            FROM jan_ranked
            WHERE rn_jan = 1
            GROUP BY identificad
        ),
        -- Workers present in BOTH January and December (numerator of retention)
        jan_dec_overlap AS (
            SELECT j.identificad, COUNT(*) AS jan_dec_count
            FROM jan_ranked j
            INNER JOIN dec_ranked d
                ON j.identificad = d.identificad AND j.PIS = d.PIS
            WHERE j.rn_jan = 1 AND d.rn_dec = 1
            GROUP BY j.identificad
        )

        -- =================================================================
        -- Combine (raw counts only, no rates)
        -- =================================================================
        SELECT
            d.identificad,
            {year} AS year,
            d.firm_emp,
            d.total_hours,
            COALESCE(s.separations_u, 0) AS separations_u,
            COALESCE(s.layoffs_u, 0)     AS layoffs_u,
            COALESCE(s.quits_u, 0)       AS quits_u,
            COALESCE(s.other_sep_u, 0)   AS other_sep_u,
            COALESCE(h.hired_u, 0)       AS hired_u,
            COALESCE(j.firm_emp_jan, 0)  AS firm_emp_jan,
            COALESCE(o.jan_dec_count, 0) AS jan_dec_count
        FROM dec_emp d
        LEFT JOIN sep_counts s      ON d.identificad = s.identificad
        LEFT JOIN hire_counts h     ON d.identificad = h.identificad
        LEFT JOIN jan_emp j         ON d.identificad = j.identificad
        LEFT JOIN jan_dec_overlap o ON d.identificad = o.identificad
        ORDER BY d.identificad
        """).fetch_arrow_table().to_pandas()

        # Verification: additivity check
        addit_check = (result["separations_u"] == result["layoffs_u"] + result["quits_u"] + result["other_sep_u"]).all()
        print(f"  Additivity check (separations = layoffs + quits + other): {'PASS' if addit_check else 'FAIL'}")
        print(f"  Establishments: {len(result):,}")

    # Add YoY retention count and carry Dec workers forward
    result["dec_yoy_count"] = result["identificad"].map(yoy_counts).fillna(0).astype(int)
    prev_dec_workers = cur_dec_workers

    all_years.append(result)
    con.unregister("rais")
    del df
    elapsed = time.time() - t0
    print(f"  Done in {elapsed:.1f}s")

# ---------------------------------------------------------------------------
# Combine all years and compute rates using avg employment
# ---------------------------------------------------------------------------
print(f"\n{'='*60}")
print("Combining all years and computing rates...")

panel = pd.concat(all_years, ignore_index=True)

# DuckDB may return Decimal types; convert numeric columns to float
numeric_cols = ["firm_emp", "total_hours", "separations_u", "layoffs_u", "quits_u", "other_sep_u",
                "hired_u", "firm_emp_jan", "jan_dec_count", "dec_yoy_count"]
for c in numeric_cols:
    panel[c] = pd.to_numeric(panel[c], errors="coerce").astype(float)

panel.sort_values(["identificad", "year"], inplace=True)
panel.reset_index(drop=True, inplace=True)

# Create lagged employment
panel["firm_emp_lag"] = panel.groupby("identificad")["firm_emp"].shift(1)

# Average employment = (current + lagged) / 2; fall back to current if no lag
panel["avg_emp"] = (panel["firm_emp"] + panel["firm_emp_lag"]) / 2
panel.loc[panel["firm_emp_lag"].isna(), "avg_emp"] = panel.loc[panel["firm_emp_lag"].isna(), "firm_emp"]

# Report 2009 firms missing 2008 employment
firms_2009 = panel[panel["year"] == 2009]
n_2009_no_lag = firms_2009["firm_emp_lag"].isna().sum()
n_2009_total = len(firms_2009)
print(f"  2009 firms with no 2008 employment match: {n_2009_no_lag:,} / {n_2009_total:,} ({n_2009_no_lag/n_2009_total*100:.1f}%)")

# Compute rates: count / avg_emp
for count_col, rate_col in [
    ("separations_u", "turnover_u"),
    ("layoffs_u", "layoff_rate_u"),
    ("quits_u", "quit_rate_u"),
    ("other_sep_u", "other_sep_rate_u"),
    ("hired_u", "hiring_rate_u"),
]:
    panel[rate_col] = np.where(panel["avg_emp"] > 0, panel[count_col] / panel["avg_emp"], np.nan)

# Retention rate: workers in Jan AND Dec / workers in Jan
panel["retention_u"] = np.where(
    panel["firm_emp_jan"] > 0,
    panel["jan_dec_count"] / panel["firm_emp_jan"],
    np.nan
)

# YoY retention: workers in Dec(t-1) AND Dec(t) / Dec(t-1) employment
panel["retention_yoy_u"] = np.where(
    panel["firm_emp_lag"] > 0,
    panel["dec_yoy_count"] / panel["firm_emp_lag"],
    np.nan
)

# Drop 2008 rows (only needed as lag)
panel = panel[panel["year"] >= 2009].copy()

# Log employment
panel["l_firm_emp"] = np.log(panel["firm_emp"].replace(0, np.nan))

# Log total contracted hours
panel["l_total_hours"] = np.log(panel["total_hours"].replace(0, np.nan))

# Drop helper column
panel.drop(columns=["firm_emp_lag"], inplace=True)

print(f"Total observations: {len(panel):,}")
print(f"Unique establishments: {panel['identificad'].nunique():,}")
print(f"Years: {sorted(panel['year'].unique())}")

# Ensure identificad is a 14-character zero-padded string (matches Stata format)
panel["identificad"] = panel["identificad"].astype(str).str.zfill(14)

# Save as CSV
panel.to_csv(OUTPUT_FILE, index=False)
print(f"Saved to {OUTPUT_FILE}")

# ---------------------------------------------------------------------------
# Summary statistics
# ---------------------------------------------------------------------------
print(f"\n{'='*60}")
print("Summary statistics:")
for col in ["firm_emp", "total_hours", "avg_emp", "separations_u", "layoffs_u", "quits_u", "other_sep_u",
            "hired_u", "firm_emp_jan", "jan_dec_count", "dec_yoy_count",
            "turnover_u", "layoff_rate_u", "quit_rate_u",
            "other_sep_rate_u", "hiring_rate_u", "retention_u", "retention_yoy_u",
            "l_total_hours"]:
    s = panel[col].describe()
    print(f"  {col:20s}: mean={s['mean']:.3f}  median={s['50%']:.3f}  "
          f"min={s['min']:.3f}  max={s['max']:.1f}")

con.close()
print("\nDone.")
