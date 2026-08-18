"""
011c_worker_panel.py
====================
Builds a worker × establishment × year panel (2009-2016) for firms in the
Lagos analysis sample.  One spell per (identificad, PIS) is selected using
the same ranking as 1010_rais_to_firm.do:
    1. horascontr DESC (highest contracted hours)
    2. remdezr_h  DESC (highest hourly December wage)
    3. deterministic hash tiebreaker (salt "12345")

Wage variables are deflated to December 2015 (IPCA).

Input
-----
- Raw RAIS:    /kellogg/proj/lgg3230/RAIS/output/data/full/RAIS_{year}.dta
- Sample IDs:  Data/CBA_RAIS_firm_level/cba_rais_firm_2009_2016_flows_1.dta
- Validation:  Data/CBA_RAIS_firm_level/lagos_sample_sep24.dta

Output
------
- Data/CBA_RAIS_firm_level/worker_panel_lagos.parquet
"""

import duckdb
import pandas as pd
import numpy as np
import time
import os

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
PROJECT   = "/kellogg/proj/lgg3230/UnionSpill"
RAIS_DIR  = "/kellogg/proj/lgg3230/RAIS/output/data/full"
SAMPLE_FILE  = os.path.join(PROJECT, "Data/CBA_RAIS_firm_level/cba_rais_firm_2009_2016_flows_1.dta")
REF_FILE     = os.path.join(PROJECT, "Data/CBA_RAIS_firm_level/lagos_sample_sep24.dta")
OUTPUT_FILE  = os.path.join(PROJECT, "Data/CBA_RAIS_firm_level/worker_panel_lagos.parquet")

YEARS = range(2009, 2017)

# ---------------------------------------------------------------------------
# IPCA deflators (to December 2015 prices)
# ---------------------------------------------------------------------------
IPCA = {
    2007: 0.607949398754109,
    2008: 0.643834976197206,
    2009: 0.671594887351247,
    2010: 0.711277338716318,
    2011: 0.757534213038901,
    2012: 0.80176356558955,
    2013: 0.849153270408197,
    2014: 0.903562518222102,
    2015: 1.0,
    2016: 1.06287988213221,
}

# ---------------------------------------------------------------------------
# Columns requested from RAIS (some may be absent in certain years)
# ---------------------------------------------------------------------------
COLS_ALWAYS = [
    # Selection algorithm
    "identificad", "PIS", "horascontr", "remdezr", "empem3112", "tempempr",
    # Demographics
    "genero", "raca_cor", "nacionalidad", "portdefic", "tpdefic",
    # Education
    "grinstrucao",
    # Contract & occupation
    "ocup2002", "clascnae20", "tpvinculo", "tipoadm", "tiposal", "dtadmissao",
    # Additional wages
    "remdezembro", "remmedia", "remmedr", "salcontr", "ultrem",
    # Location & firm type
    "municipio", "tamestab", "natjuridica",
    # Separation & leave
    "causadesli",
    "causafast1", "causafast2", "causafast3",
    "mesiniaf1", "mesiniaf2", "mesiniaf3",
    "mesfimaf1", "mesfimaf2", "mesfimaf3",
]

# Columns absent in some years — handled with try/except
COLS_OPTIONAL = [
    "dtnascimento",  # absent in 2011-2013
    "idade",         # absent in 2009-2010
    "mesdesli",      # absent in 2011-2013
    "diadesli",      # absent in 2011-2013
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
sample_df = sample_df.query("lagos_sample_avg == 1 & in_balanced_panel == 1")
sample_ids = set(sample_df["identificad"].unique())
print(f"  {len(sample_ids):,} unique sample establishments")
del sample_df

# ---------------------------------------------------------------------------
# Load validation reference
# ---------------------------------------------------------------------------
print("Loading validation reference (lagos_sample_sep24.dta)...")
ref_df = pd.read_stata(
    REF_FILE,
    columns=["identificad", "year", "lr_remdezr"],
    convert_categoricals=False,
)
ref_df["year"] = ref_df["year"].astype(int)
# Keep only 2009-2016
ref_df = ref_df[ref_df["year"].between(2009, 2016)].copy()
print(f"  {len(ref_df):,} firm-year rows in reference (2009-2016)")

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
    # Determine which optional columns are available this year
    # ------------------------------------------------------------------
    reader_probe = pd.read_stata(rais_file, chunksize=1, convert_categoricals=False)
    probe_chunk = next(iter(reader_probe))
    available_cols = set(probe_chunk.columns.tolist())
    del probe_chunk

    cols_optional_present = [c for c in COLS_OPTIONAL if c in available_cols]
    cols_optional_absent  = [c for c in COLS_OPTIONAL if c not in available_cols]
    cols_to_read = COLS_ALWAYS + cols_optional_present

    if cols_optional_absent:
        print(f"  Optional columns absent this year: {cols_optional_absent}")

    # ------------------------------------------------------------------
    # Read RAIS in chunks, filtering to sample establishments
    # ------------------------------------------------------------------
    print("  Reading RAIS (chunked, filtering to sample)...")
    chunks = []
    n_total = 0
    n_kept  = 0
    reader = pd.read_stata(
        rais_file,
        columns=cols_to_read,
        chunksize=5_000_000,
        convert_categoricals=False,
    )
    for chunk in reader:
        n_total += len(chunk)
        filtered = chunk[chunk["identificad"].isin(sample_ids)]
        n_kept   += len(filtered)
        if len(filtered) > 0:
            chunks.append(filtered)

    if not chunks:
        print(f"  WARNING: No sample observations found for {year}. Skipping.")
        continue

    df = pd.concat(chunks, ignore_index=True)
    del chunks
    print(f"  Read {n_total:,} rows, kept {n_kept:,} sample rows ({n_kept/n_total*100:.1f}%)")

    # Add NULL columns for absent optional cols
    for col in cols_optional_absent:
        df[col] = np.nan

    # ------------------------------------------------------------------
    # Register in DuckDB and select one spell per (identificad, PIS)
    # ------------------------------------------------------------------
    con.register("rais", df)

    result = con.execute(f"""
    WITH base AS (
        SELECT *,
            CASE WHEN remdezr IS NULL OR remdezr = 0
                      OR horascontr IS NULL OR horascontr = 0
                 THEN 0.0
                 ELSE remdezr / (horascontr * 4.348)
            END AS remdezr_h,
            hash(identificad || '|' || PIS
                 || '|' || CAST(horascontr AS VARCHAR)
                 || '|' || CAST(remdezr    AS VARCHAR)
                 || '|12345') / 1e19 AS random_tb
        FROM rais
        WHERE empem3112 = 1
          AND (tempempr > 1 OR tempempr IS NULL)
    ),
    ranked AS (
        SELECT *,
            ROW_NUMBER() OVER (
                PARTITION BY identificad, PIS
                ORDER BY horascontr DESC, remdezr_h DESC, random_tb DESC
            ) AS rn_dec
        FROM base
    )
    SELECT * EXCLUDE (rn_dec, remdezr_h, random_tb)
    FROM ranked
    WHERE rn_dec = 1
    """).fetch_arrow_table().to_pandas()

    con.unregister("rais")
    del df

    print(f"  Selected spells: {len(result):,}")

    # ------------------------------------------------------------------
    # Post-selection wage computation
    # ------------------------------------------------------------------
    deflator = IPCA[year]

    # 2016 contracted wage fix (Lagos footnote 76)
    if year == 2016:
        result.loc[result["salcontr"] < 880, "salcontr"] = (
            result.loc[result["salcontr"] < 880, "salcontr"] * 100
        )

    # Monthly contracted salary from raw salcontr + tiposal
    result["salcontr_m"] = np.where(
        result["tiposal"].isin([1, 6, 7]), result["salcontr"],
        np.where(result["tiposal"] == 2, 2   * result["salcontr"],
        np.where(result["tiposal"] == 3, 4.348 * result["salcontr"],
        np.where(result["tiposal"] == 4, 30.436875 * result["salcontr"],
        np.where(result["tiposal"] == 5,
                 4.348 * result["horascontr"] * result["salcontr"],
                 np.nan)))))

    # Log real wages (deflated to December 2015)
    # Replace zero/negative with NaN before log (matches Stata: log(0) = missing)
    result["lr_remdezr"]    = np.log(result["remdezr"].where(result["remdezr"]       > 0) / deflator)
    result["lr_remmedr"]    = np.log(result["remmedr"].where(result["remmedr"]        > 0) / deflator)
    result["lr_salcontr_m"] = np.log(result["salcontr_m"].where(result["salcontr_m"] > 0) / deflator)

    result["year"] = year

    all_years.append(result)
    elapsed = time.time() - t0
    print(f"  Done in {elapsed:.1f}s")

# ---------------------------------------------------------------------------
# Concatenate all years
# ---------------------------------------------------------------------------
print(f"\n{'='*60}")
print("Concatenating all years...")
panel_df = pd.concat(all_years, ignore_index=True)
del all_years

# Ensure identificad is a 14-character zero-padded string
panel_df["identificad"] = panel_df["identificad"].astype(str).str.zfill(14)

print(f"Total worker-spells: {len(panel_df):,}")
print(f"Unique establishments: {panel_df['identificad'].nunique():,}")
print(f"Unique workers (PIS): {panel_df['PIS'].nunique():,}")
print(f"Years: {sorted(panel_df['year'].unique())}")

# ---------------------------------------------------------------------------
# Save to parquet
# ---------------------------------------------------------------------------
print(f"\nSaving to {OUTPUT_FILE} ...")
panel_df.to_parquet(OUTPUT_FILE, index=False, engine="pyarrow")
print(f"Saved. File size: {os.path.getsize(OUTPUT_FILE) / 1e9:.2f} GB")

# ---------------------------------------------------------------------------
# Validation: mean lr_remdezr by firm-year must match lagos_sample_sep24
# ---------------------------------------------------------------------------
print(f"\n{'='*60}")
print("Validation: comparing mean lr_remdezr per firm-year with reference...")

computed = (
    panel_df.groupby(["identificad", "year"])["lr_remdezr"]
    .mean()
    .reset_index()
    .rename(columns={"lr_remdezr": "lr_remdezr_computed"})
)

check = computed.merge(
    ref_df.rename(columns={"lr_remdezr": "lr_remdezr_ref"}),
    on=["identificad", "year"],
    how="inner",
)
diff = (check["lr_remdezr_computed"] - check["lr_remdezr_ref"]).abs()

print(f"  N firm-years matched:     {len(check):,}")
print(f"  Max  |diff|:              {diff.max():.6f}")
print(f"  Mean |diff|:              {diff.mean():.8f}")
print(f"  Pct within 1e-3:          {(diff < 1e-3).mean()*100:.1f}%")
print(f"  Pct within 1e-2:          {(diff < 1e-2).mean()*100:.1f}%")

if diff.max() < 0.01:
    print("\n  VALIDATION PASSED (max |diff| < 0.01)")
else:
    print(f"\n  WARNING: max |diff| = {diff.max():.4f} exceeds 0.01 threshold.")
    # Show worst offenders
    worst = check.assign(absdiff=diff).nlargest(10, "absdiff")
    print("  Worst 10 firm-years:")
    print(worst[["identificad", "year", "lr_remdezr_computed", "lr_remdezr_ref", "absdiff"]].to_string(index=False))

# ---------------------------------------------------------------------------
# Summary statistics for key worker characteristics
# ---------------------------------------------------------------------------
print(f"\n{'='*60}")
print("Non-null rates for key worker characteristic columns:")
for col in ["genero", "grinstrucao", "ocup2002", "raca_cor", "idade", "dtnascimento"]:
    if col in panel_df.columns:
        rate = panel_df[col].notna().mean() * 100
        print(f"  {col:20s}: {rate:.1f}% non-null")

print(f"\n{'='*60}")
print("Wage summary statistics (2009-2016):")
for col in ["lr_remdezr", "lr_remmedr", "lr_salcontr_m"]:
    s = panel_df[col].describe()
    print(f"  {col:20s}: mean={s['mean']:.3f}  median={s['50%']:.3f}  "
          f"min={s['min']:.3f}  max={s['max']:.3f}")

con.close()
print("\nDone.")
