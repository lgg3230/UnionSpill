"""
011b_turnover_diagnostics.py
============================
Diagnostic script to verify the accounting identity:

    firm_emp_t = firm_emp_{t-1} + hired_t - separations_t

For firms where this doesn't hold, go back to raw RAIS to understand why.

Decomposes discrepancies into:
- "Stayers": in Dec t-1 AND Dec t, no separation, no new hire spell
- "Churners": hired AND separated within the same year
- "Ghost exits": in Dec t-1, NOT in Dec t, but no separation recorded
- "Ghost entries": in Dec t, NOT in Dec t-1, but no hire recorded in year t
- "Rehires": hired in year t, but were also in Dec t-1 (left and came back, or new spell)
- "Separated but stayed": separated in year t, but still in Dec t
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
OUTPUT_CSV = os.path.join(PROJECT, "Data/CBA_RAIS_firm_level/corrected_turnover_sample.csv")

# We'll do the deep investigation for a pair of consecutive years
# Use 2010 (with 2009 as t-1) — avoids the 2008 missing-firm issue
YEAR_PAIRS = [(2009, 2010), (2011, 2012), (2014, 2015)]

COLS = [
    "identificad", "PIS", "horascontr", "remdezr", "causadesli",
    "empem3112", "tempempr", "dtadmissao", "mesdesli",
]

# ---------------------------------------------------------------------------
# Step 1: Check accounting identity from the output CSV
# ---------------------------------------------------------------------------
print("=" * 70)
print("STEP 1: Accounting identity check from output CSV")
print("=" * 70)

panel = pd.read_csv(OUTPUT_CSV)
panel.sort_values(["identificad", "year"], inplace=True)
panel["firm_emp_lag"] = panel.groupby("identificad")["firm_emp"].shift(1)
panel["predicted_emp"] = panel["firm_emp_lag"] + panel["hired_u"] - panel["separations_u"]
panel["discrepancy"] = panel["firm_emp"] - panel["predicted_emp"]

# Only look at years where we have a lag
has_lag = panel["firm_emp_lag"].notna()
subset = panel[has_lag].copy()

print(f"\nObservations with lagged employment: {len(subset):,}")
exact_match = (subset["discrepancy"] == 0).sum()
print(f"Firms where emp_t = emp_{{t-1}} + hires - separations: {exact_match:,} ({exact_match/len(subset)*100:.1f}%)")
print(f"Firms with discrepancy: {(subset['discrepancy'] != 0).sum():,} ({(subset['discrepancy'] != 0).sum()/len(subset)*100:.1f}%)")

print(f"\nDiscrepancy statistics:")
print(f"  Mean:   {subset['discrepancy'].mean():.2f}")
print(f"  Median: {subset['discrepancy'].median():.1f}")
print(f"  Std:    {subset['discrepancy'].std():.2f}")
print(f"  Min:    {subset['discrepancy'].min():.0f}")
print(f"  Max:    {subset['discrepancy'].max():.0f}")
print(f"  P5:     {subset['discrepancy'].quantile(0.05):.0f}")
print(f"  P25:    {subset['discrepancy'].quantile(0.25):.0f}")
print(f"  P75:    {subset['discrepancy'].quantile(0.75):.0f}")
print(f"  P95:    {subset['discrepancy'].quantile(0.95):.0f}")

# Sign of discrepancy
pos = (subset["discrepancy"] > 0).sum()
neg = (subset["discrepancy"] < 0).sum()
print(f"\n  Positive (actual > predicted): {pos:,} — more workers appeared than hires suggest")
print(f"  Negative (actual < predicted): {neg:,} — more workers left than separations suggest")

# By year
print(f"\nBy year:")
for yr in sorted(subset["year"].unique()):
    yr_data = subset[subset["year"] == yr]
    n_disc = (yr_data["discrepancy"] != 0).sum()
    mean_disc = yr_data["discrepancy"].mean()
    median_disc = yr_data["discrepancy"].median()
    print(f"  {int(yr)}: {n_disc:,}/{len(yr_data):,} with discrepancy, "
          f"mean={mean_disc:.1f}, median={median_disc:.0f}")

# By firm size
print(f"\nBy firm size (Dec emp quartiles):")
subset["size_q"] = pd.qcut(subset["firm_emp"], 4, labels=["Q1 (small)", "Q2", "Q3", "Q4 (large)"])
for q in ["Q1 (small)", "Q2", "Q3", "Q4 (large)"]:
    q_data = subset[subset["size_q"] == q]
    n_disc = (q_data["discrepancy"] != 0).sum()
    mean_disc = q_data["discrepancy"].mean()
    abs_mean = q_data["discrepancy"].abs().mean()
    rel_mean = (q_data["discrepancy"] / q_data["firm_emp"]).mean()
    print(f"  {q}: {n_disc:,}/{len(q_data):,} with discrepancy, "
          f"mean={mean_disc:.1f}, |mean|={abs_mean:.1f}, mean/emp={rel_mean:.3f}")

del panel, subset

# ---------------------------------------------------------------------------
# Step 2: Deep investigation using raw RAIS
# ---------------------------------------------------------------------------
print(f"\n{'=' * 70}")
print("STEP 2: Deep investigation from raw RAIS")
print("=" * 70)

# Load sample IDs
sample_df = pd.read_stata(
    SAMPLE_FILE,
    columns=["identificad", "lagos_sample_avg", "in_balanced_panel"],
    convert_categoricals=False,
)
sample_df = sample_df.query("lagos_sample_avg == 1 & in_balanced_panel == 1")
sample_ids = set(sample_df["identificad"].unique())
del sample_df

con = duckdb.connect()
con.execute("PRAGMA threads=8")
con.execute("PRAGMA memory_limit='32GB'")


def load_rais_year(year):
    """Load RAIS for a year, filtered to sample, return pandas DF."""
    rais_file = os.path.join(RAIS_DIR, f"RAIS_{year}.dta")
    print(f"  Loading RAIS {year}...")
    t0 = time.time()
    chunks = []
    reader = pd.read_stata(rais_file, columns=COLS, chunksize=5_000_000, convert_categoricals=False)
    for chunk in reader:
        filtered = chunk[chunk["identificad"].isin(sample_ids)]
        if len(filtered) > 0:
            chunks.append(filtered)
    df = pd.concat(chunks, ignore_index=True)
    print(f"    {len(df):,} rows in {time.time()-t0:.0f}s")
    return df


def get_dec_workers(df, year):
    """Get set of (identificad, PIS) for December-employed workers, deduplicated."""
    con.register("rais_tmp", df)
    result = con.execute(f"""
    WITH base AS (
        SELECT
            identificad, PIS, horascontr,
            CASE WHEN empem3112 = 1 AND tempempr > 1 THEN 1 ELSE 0 END AS empdec_lagos,
            CASE
                WHEN remdezr IS NULL OR remdezr = 0 OR horascontr IS NULL OR horascontr = 0
                THEN 0.0
                ELSE remdezr / (horascontr * 4.348)
            END AS remdezr_h,
            hash(identificad || '|' || PIS || '|' || CAST(horascontr AS VARCHAR)
                 || '|' || CAST(remdezr AS VARCHAR) || '|12345') / 1e19 AS random_tb
        FROM rais_tmp
    ),
    ranked AS (
        SELECT *,
            ROW_NUMBER() OVER (
                PARTITION BY identificad, PIS
                ORDER BY
                    CASE WHEN empdec_lagos = 1 THEN horascontr ELSE -1 END DESC,
                    CASE WHEN empdec_lagos = 1 THEN remdezr_h  ELSE -1 END DESC,
                    random_tb DESC
            ) AS rn
        FROM base
        WHERE empdec_lagos = 1
    )
    SELECT identificad, PIS
    FROM ranked
    WHERE rn = 1
    """).fetchdf()
    con.unregister("rais_tmp")
    return set(zip(result["identificad"], result["PIS"]))


def get_separated_workers(df, year):
    """Get set of (identificad, PIS) for separated workers, deduplicated."""
    con.register("rais_tmp", df)
    result = con.execute("""
    WITH base AS (
        SELECT
            identificad, PIS, horascontr, causadesli,
            CASE
                WHEN remdezr IS NULL OR remdezr = 0 OR horascontr IS NULL OR horascontr = 0
                THEN 0.0
                ELSE remdezr / (horascontr * 4.348)
            END AS remdezr_h,
            hash(identificad || '|' || PIS || '|' || CAST(horascontr AS VARCHAR)
                 || '|' || CAST(remdezr AS VARCHAR) || '|12345') / 1e19 AS random_tb
        FROM rais_tmp
        WHERE causadesli != 0 AND causadesli IS NOT NULL
    ),
    ranked AS (
        SELECT *,
            ROW_NUMBER() OVER (
                PARTITION BY identificad, PIS
                ORDER BY horascontr DESC, remdezr_h DESC, random_tb DESC
            ) AS rn
        FROM base
    )
    SELECT identificad, PIS
    FROM ranked
    WHERE rn = 1
    """).fetchdf()
    con.unregister("rais_tmp")
    return set(zip(result["identificad"], result["PIS"]))


def get_hired_workers(df, year):
    """Get set of (identificad, PIS) for workers hired in `year`."""
    con.register("rais_tmp", df)
    result = con.execute(f"""
    SELECT DISTINCT identificad, PIS
    FROM rais_tmp
    WHERE YEAR(COALESCE(
        TRY_CAST(dtadmissao AS DATE),
        TRY_STRPTIME(CAST(dtadmissao AS VARCHAR), '%d%m%Y')
    )) = {year}
    """).fetchdf()
    con.unregister("rais_tmp")
    return set(zip(result["identificad"], result["PIS"]))


for t_minus_1, t in YEAR_PAIRS:
    print(f"\n{'='*60}")
    print(f"Investigating year pair: {t_minus_1} → {t}")
    print(f"{'='*60}")

    df_prev = load_rais_year(t_minus_1)
    df_curr = load_rais_year(t)

    # Get worker sets
    print(f"  Computing worker sets...")
    dec_prev = get_dec_workers(df_prev, t_minus_1)    # Dec t-1 stock
    dec_curr = get_dec_workers(df_curr, t)             # Dec t stock
    separated_t = get_separated_workers(df_curr, t)    # Separated in year t
    hired_t = get_hired_workers(df_curr, t)            # Hired in year t

    del df_prev, df_curr

    # Build firm-level dictionaries
    # For each firm, get its workers in each set
    from collections import defaultdict

    firms_dec_prev = defaultdict(set)
    for estab, pis in dec_prev:
        firms_dec_prev[estab].add(pis)

    firms_dec_curr = defaultdict(set)
    for estab, pis in dec_curr:
        firms_dec_curr[estab].add(pis)

    firms_sep = defaultdict(set)
    for estab, pis in separated_t:
        firms_sep[estab].add(pis)

    firms_hired = defaultdict(set)
    for estab, pis in hired_t:
        firms_hired[estab].add(pis)

    all_firms = set(firms_dec_prev.keys()) | set(firms_dec_curr.keys())

    # Classify each worker-firm observation
    total_ghost_exits = 0
    total_ghost_entries = 0
    total_churners = 0
    total_rehires = 0
    total_sep_but_stayed = 0
    total_stayers = 0
    total_true_exits = 0
    total_true_entries = 0
    n_firms_with_disc = 0
    n_firms_total = 0
    discrepancies = []

    for firm in all_firms:
        prev_workers = firms_dec_prev.get(firm, set())
        curr_workers = firms_dec_curr.get(firm, set())
        sep_workers = firms_sep.get(firm, set())
        hire_workers = firms_hired.get(firm, set())

        if not prev_workers:
            continue  # Can't check identity without t-1

        n_firms_total += 1
        emp_prev = len(prev_workers)
        emp_curr = len(curr_workers)
        n_sep = len(sep_workers)
        n_hired = len(hire_workers)

        predicted = emp_prev + n_hired - n_sep
        disc = emp_curr - predicted

        if disc != 0:
            n_firms_with_disc += 1

        # Detailed worker-level classification
        # 1. Ghost exits: in Dec t-1, NOT in Dec t, NO separation in t
        exiters = prev_workers - curr_workers  # left between Dec t-1 and Dec t
        ghost_exits = exiters - sep_workers     # ... but no separation recorded
        true_exits = exiters & sep_workers      # ... with separation recorded

        # 2. Ghost entries: in Dec t, NOT in Dec t-1, NO hire in t
        entrants = curr_workers - prev_workers  # new in Dec t
        ghost_entries = entrants - hire_workers  # ... but no hire recorded
        true_entries = entrants & hire_workers   # ... with hire recorded

        # 3. Churners: hired AND separated in year t (appear in both sets)
        #    These cancel out in the identity but inflate both counts
        churners = hire_workers & sep_workers

        # 4. Rehires: hired in year t, but were ALSO in Dec t-1
        rehires = hire_workers & prev_workers

        # 5. Separated but stayed: separated in year t, but still in Dec t
        sep_but_stayed = sep_workers & curr_workers

        total_ghost_exits += len(ghost_exits)
        total_ghost_entries += len(ghost_entries)
        total_churners += len(churners)
        total_rehires += len(rehires)
        total_sep_but_stayed += len(sep_but_stayed)
        total_stayers += len(prev_workers & curr_workers)
        total_true_exits += len(true_exits)
        total_true_entries += len(true_entries)

        discrepancies.append({
            "firm": firm,
            "emp_prev": emp_prev,
            "emp_curr": emp_curr,
            "n_sep": n_sep,
            "n_hired": n_hired,
            "predicted": predicted,
            "disc": disc,
            "ghost_exits": len(ghost_exits),
            "ghost_entries": len(ghost_entries),
            "churners": len(churners),
            "rehires": len(rehires),
            "sep_but_stayed": len(sep_but_stayed),
            "true_exits": len(true_exits),
            "true_entries": len(true_entries),
        })

    disc_df = pd.DataFrame(discrepancies)

    print(f"\n  --- AGGREGATE WORKER FLOW CLASSIFICATION ({t_minus_1}→{t}) ---")
    print(f"  Firms analyzed: {n_firms_total:,}")
    print(f"  Firms with discrepancy (emp_t ≠ emp_{{t-1}} + hires - seps): {n_firms_with_disc:,} ({n_firms_with_disc/n_firms_total*100:.1f}%)")
    print()
    print(f"  Stayers (in Dec t-1 AND Dec t):                  {total_stayers:,}")
    print(f"  True exits (left Dec, separation recorded):      {total_true_exits:,}")
    print(f"  True entries (new in Dec, hire recorded):         {total_true_entries:,}")
    print()
    print(f"  GHOST EXITS (in Dec t-1, not Dec t, NO sep):     {total_ghost_exits:,}")
    print(f"  GHOST ENTRIES (in Dec t, not Dec t-1, NO hire):   {total_ghost_entries:,}")
    print(f"  CHURNERS (hired AND separated in same year):     {total_churners:,}")
    print(f"  REHIRES (hired in t, but also in Dec t-1):       {total_rehires:,}")
    print(f"  SEP BUT STAYED (separated, still in Dec t):      {total_sep_but_stayed:,}")

    print(f"\n  --- ACCOUNTING IDENTITY DECOMPOSITION ---")
    print(f"  The identity emp_t = emp_{{t-1}} + hires - seps fails because:")
    print(f"  1. Hires overcount by {total_rehires:,} (rehires already in Dec t-1)")
    print(f"     → these are counted as hires but don't add to stock")
    print(f"  2. Seps overcount by {total_sep_but_stayed:,} (separated but still in Dec t)")
    print(f"     → these are counted as separations but don't reduce stock")
    print(f"  3. Ghost exits (uncounted loss):   {total_ghost_exits:,}")
    print(f"     → workers vanish from Dec without a separation code")
    print(f"  4. Ghost entries (uncounted gain):  {total_ghost_entries:,}")
    print(f"     → workers appear in Dec without a hire-year-t admission date")
    print(f"  Net expected discrepancy: +ghost_entries - ghost_exits + sep_but_stayed - rehires")
    net_expected = total_ghost_entries - total_ghost_exits + total_sep_but_stayed - total_rehires
    actual_disc = disc_df["disc"].sum()
    print(f"  = +{total_ghost_entries:,} - {total_ghost_exits:,} + {total_sep_but_stayed:,} - {total_rehires:,}")
    print(f"  = {net_expected:,}")
    print(f"  Actual sum of discrepancies: {actual_disc:,}")
    print(f"  Match: {'YES' if net_expected == actual_disc else 'NO (rounding or edge case)'}")

    # Distribution of discrepancies
    print(f"\n  --- DISCREPANCY DISTRIBUTION ---")
    print(f"  Mean disc:   {disc_df['disc'].mean():.2f}")
    print(f"  Median disc: {disc_df['disc'].median():.0f}")
    print(f"  Std disc:    {disc_df['disc'].std():.2f}")
    print(f"  % exact match: {(disc_df['disc'] == 0).mean()*100:.1f}%")

    # Relative magnitudes
    print(f"\n  --- RELATIVE MAGNITUDES (as % of Dec t-1 employment) ---")
    total_emp_prev = disc_df["emp_prev"].sum()
    print(f"  Ghost exits / emp_{{t-1}}:     {total_ghost_exits/total_emp_prev*100:.2f}%")
    print(f"  Ghost entries / emp_{{t-1}}:    {total_ghost_entries/total_emp_prev*100:.2f}%")
    print(f"  Churners / emp_{{t-1}}:         {total_churners/total_emp_prev*100:.2f}%")
    print(f"  Rehires / emp_{{t-1}}:          {total_rehires/total_emp_prev*100:.2f}%")
    print(f"  Sep but stayed / emp_{{t-1}}:   {total_sep_but_stayed/total_emp_prev*100:.2f}%")

    # Examples of largest discrepancies
    print(f"\n  --- TOP 5 FIRMS BY |DISCREPANCY| ---")
    top5 = disc_df.reindex(disc_df["disc"].abs().sort_values(ascending=False).index).head(5)
    for _, row in top5.iterrows():
        print(f"    Firm {row['firm']}: emp_prev={row['emp_prev']:.0f}, emp_curr={row['emp_curr']:.0f}, "
              f"hires={row['n_hired']:.0f}, seps={row['n_sep']:.0f}, "
              f"disc={row['disc']:.0f} "
              f"(ghost_exit={row['ghost_exits']:.0f}, ghost_entry={row['ghost_entries']:.0f}, "
              f"churners={row['churners']:.0f}, rehires={row['rehires']:.0f}, sep_stayed={row['sep_but_stayed']:.0f})")

con.close()
print(f"\n{'='*70}")
print("DIAGNOSTICS COMPLETE")
print("=" * 70)
