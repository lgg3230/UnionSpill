import duckdb
import pandas as pd
from pathlib import Path

main = Path("/kellogg/proj/lgg3230")
panel = main / "UnionSpill/Data/RAIS_aux/totalflows_panel_2009_2016.csv"
base  = main / "UnionSpill/Data/CBA_RAIS_firm_level/lagos_sample_sep24_pct_unionexp_ext_df2.dta"

con = duckdb.connect()

# Load panel CSV
con.execute(f"""
    CREATE TABLE flows AS
    SELECT
        printf('%014d', CAST(identificad AS BIGINT)) AS identificad,
        year,
        totalflows,
        LN(NULLIF(totalflows, 0)) AS ll_totalflows
    FROM read_csv('{panel}')
    WHERE totalflows IS NOT NULL
""")

# Load lagos sample to get balanced panel restriction
import subprocess, tempfile, os
# Use pandas to read the dta
import pandas as pd
df_base = pd.read_stata(str(base), columns=["identificad", "year", "lagos_sample_avg", "in_balanced_panel"])
df_base["identificad"] = df_base["identificad"].astype(str).str.zfill(14)
df_base = df_base[(df_base["lagos_sample_avg"] == 1) & (df_base["in_balanced_panel"] == 1)]
con.register("base_tbl", df_base)

con.execute("""
    CREATE TABLE analysis AS
    SELECT f.identificad, f.year, f.totalflows, f.ll_totalflows
    FROM flows f
    INNER JOIN base_tbl b ON f.identificad = b.identificad AND f.year = b.year
    WHERE f.year >= 2009
""")

# 1. Total obs and share with non-missing ll_totalflows
res = con.execute("""
    SELECT
        COUNT(*) AS n_total,
        SUM(CASE WHEN ll_totalflows IS NOT NULL THEN 1 ELSE 0 END) AS n_nonmiss,
        ROUND(100.0 * SUM(CASE WHEN ll_totalflows IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_nonmiss
    FROM analysis
""").fetchdf()
print("=== Coverage ===")
print(res.to_string(index=False))

# 2. Within-firm variation: for each firm, does ll_totalflows change across years?
res2 = con.execute("""
    WITH firm_stats AS (
        SELECT
            identificad,
            COUNT(ll_totalflows) AS n_years,
            STDDEV(ll_totalflows) AS within_sd,
            MAX(ll_totalflows) - MIN(ll_totalflows) AS within_range
        FROM analysis
        GROUP BY identificad
        HAVING COUNT(ll_totalflows) > 1
    )
    SELECT
        COUNT(*) AS n_firms,
        ROUND(AVG(n_years), 2) AS avg_years_nonmiss,
        ROUND(AVG(within_sd), 4) AS mean_within_sd,
        ROUND(AVG(within_range), 4) AS mean_within_range,
        ROUND(100.0 * SUM(CASE WHEN within_sd = 0 OR within_sd IS NULL THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_zero_within_sd
    FROM firm_stats
""").fetchdf()
print("\n=== Within-firm variation across years ===")
print(res2.to_string(index=False))

# 3. Overall variance decomposition
res3 = con.execute("""
    WITH grand AS (
        SELECT AVG(ll_totalflows) AS grand_mean FROM analysis WHERE ll_totalflows IS NOT NULL
    ),
    firm_means AS (
        SELECT identificad, AVG(ll_totalflows) AS firm_mean
        FROM analysis WHERE ll_totalflows IS NOT NULL
        GROUP BY identificad
    ),
    decomp AS (
        SELECT
            a.ll_totalflows,
            fm.firm_mean,
            g.grand_mean,
            (a.ll_totalflows - fm.firm_mean) AS within_dev,
            (fm.firm_mean - g.grand_mean) AS between_dev
        FROM analysis a
        JOIN firm_means fm ON a.identificad = fm.identificad
        CROSS JOIN grand g
        WHERE a.ll_totalflows IS NOT NULL
    )
    SELECT
        ROUND(VARIANCE(ll_totalflows), 4) AS total_var,
        ROUND(AVG(within_dev * within_dev), 4) AS within_var,
        ROUND(VARIANCE(firm_mean), 4) AS between_var,
        ROUND(100.0 * AVG(within_dev * within_dev) / VARIANCE(ll_totalflows), 1) AS pct_within
    FROM decomp
""").fetchdf()
print("\n=== Variance decomposition ===")
print(res3.to_string(index=False))

# 4. Year-by-year means to see time trend
res4 = con.execute("""
    SELECT year,
           COUNT(ll_totalflows) AS n,
           ROUND(AVG(ll_totalflows), 4) AS mean_ll_totalflows,
           ROUND(STDDEV(ll_totalflows), 4) AS sd_ll_totalflows
    FROM analysis
    WHERE ll_totalflows IS NOT NULL
    GROUP BY year ORDER BY year
""").fetchdf()
print("\n=== Year-by-year means ===")
print(res4.to_string(index=False))
