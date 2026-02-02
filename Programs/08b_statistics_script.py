import duckdb

PATH = "/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/bilateral_regression_data.parquet"

con = duckdb.connect()
con.execute("PRAGMA threads=8")

# 1) Complement share among positive pre flows (exclude NULLs)
q1 = f"""
SELECT
  AVG(CASE WHEN same_industry_micro = 0 THEN 1.0 ELSE 0.0 END) AS share_not_same,
  COUNT(*) AS n_pos
FROM read_parquet('{PATH}')
WHERE has_flow_pre = 1
  AND same_industry_micro IS NOT NULL
"""
share_not_same, n_pos = con.execute(q1).fetchone()
print(f"Positive pre flows: share not-same_industry_micro = {share_not_same:.3f} (N={n_pos})")

# 2) Complement shares among top 5/10/20/25% connectivity (within positive-flow sample)
q2 = f"""
WITH pos AS (
  SELECT bilateral_conn_pre, same_industry_micro
  FROM read_parquet('{PATH}')
  WHERE has_flow_pre = 1
    AND bilateral_conn_pre IS NOT NULL
    AND same_industry_micro IS NOT NULL
),
cuts AS (
  SELECT
    quantile_cont(bilateral_conn_pre, 0.95) AS c95,
    quantile_cont(bilateral_conn_pre, 0.90) AS c90,
    quantile_cont(bilateral_conn_pre, 0.80) AS c80,
    quantile_cont(bilateral_conn_pre, 0.75) AS c75
  FROM pos
)
SELECT 'Top 5%'  AS grp,
       AVG(CASE WHEN same_industry_micro=0 THEN 1.0 ELSE 0.0 END) AS share_not_same,
       COUNT(*) AS n
FROM pos, cuts
WHERE bilateral_conn_pre >= c95
UNION ALL
SELECT 'Top 10%' AS grp,
       AVG(CASE WHEN same_industry_micro=0 THEN 1.0 ELSE 0.0 END) AS share_not_same,
       COUNT(*) AS n
FROM pos, cuts
WHERE bilateral_conn_pre >= c90
UNION ALL
SELECT 'Top 20%' AS grp,
       AVG(CASE WHEN same_industry_micro=0 THEN 1.0 ELSE 0.0 END) AS share_not_same,
       COUNT(*) AS n
FROM pos, cuts
WHERE bilateral_conn_pre >= c80
UNION ALL
SELECT 'Top 25%' AS grp,
       AVG(CASE WHEN same_industry_micro=0 THEN 1.0 ELSE 0.0 END) AS share_not_same,
       COUNT(*) AS n
FROM pos, cuts
WHERE bilateral_conn_pre >= c75
;
"""
rows = con.execute(q2).fetchall()
for grp, share, n in rows:
    print(f"{grp}: share not-same_industry_micro = {share:.3f} (N={n})")