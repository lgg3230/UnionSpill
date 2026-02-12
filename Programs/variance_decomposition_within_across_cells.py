"""
Hierarchical Variance Decomposition: Bilateral Pre-treatment Connectivity

Decomposes Var(bilateral_conn_pre) across ALL pairs into four components:

  Total SS = Between-group SS (0 vs 1)
           + Within-group-0 SS
           + Within-group-1, between-cell SS
           + Within-group-1, within-cell SS

where "group" = same_industry_micro and "cell" = (microregion, industry).
"""

import duckdb

con = duckdb.connect()
con.execute("PRAGMA threads=8")
con.execute("PRAGMA memory_limit='32GB'")

PARQUET = 'Data/RAIS_aux/bilateral_regression_data.parquet'

# ── 1. Grand totals across ALL pairs ─────────────────────────────────────────
grand = con.execute(f"""
    SELECT
        COUNT(*)                     AS N,
        AVG(bilateral_conn_pre)      AS grand_mean,
        VAR_SAMP(bilateral_conn_pre) AS total_var
    FROM read_parquet('{PARQUET}')
""").fetchone()

N, grand_mean, total_var = grand
total_ss = total_var * (N - 1)

print(f"Total pairs:  {N:,.0f}")
print(f"Grand mean:   {grand_mean:.6e}")
print(f"Total var:    {total_var:.6e}")
print()

# ── 2. Group-level stats (same_industry_micro = 0 vs 1) ─────────────────────
groups = con.execute(f"""
    SELECT
        same_industry_micro           AS grp,
        COUNT(*)                      AS n_grp,
        AVG(bilateral_conn_pre)       AS grp_mean,
        VAR_SAMP(bilateral_conn_pre)  AS grp_var
    FROM read_parquet('{PARQUET}')
    GROUP BY same_industry_micro
    ORDER BY same_industry_micro
""").fetchall()

# groups[0] = (0, n0, mean0, var0), groups[1] = (1, n1, mean1, var1)
_, n0, mean0, var0 = groups[0]
_, n1, mean1, var1 = groups[1]

between_group_ss = (n0 * (mean0 - grand_mean)**2
                  + n1 * (mean1 - grand_mean)**2)
within_group0_ss = var0 * (n0 - 1)
within_group1_ss = var1 * (n1 - 1)

print(f"same_industry_micro = 0:  n = {n0:>14,.0f}   mean = {mean0:.6e}")
print(f"same_industry_micro = 1:  n = {n1:>14,.0f}   mean = {mean1:.6e}")
print()

# ── 3. Cell-level decomposition WITHIN group 1 ──────────────────────────────
cells = con.execute(f"""
    WITH cell_stats AS (
        SELECT
            microregion_i AS microregion,
            industry1_i   AS industry,
            COUNT(*)                     AS n_cell,
            AVG(bilateral_conn_pre)      AS cell_mean,
            VAR_SAMP(bilateral_conn_pre) AS cell_var
        FROM read_parquet('{PARQUET}')
        WHERE same_industry_micro = 1
        GROUP BY microregion_i, industry1_i
    )
    SELECT
        COUNT(*)  AS n_cells,
        SUM(n_cell * (cell_mean - {mean1}) * (cell_mean - {mean1}))
            AS between_cell_ss,
        SUM(CASE WHEN cell_var IS NOT NULL
                 THEN cell_var * (n_cell - 1) ELSE 0 END)
            AS within_cell_ss
    FROM cell_stats
""").fetchone()

n_cells, between_cell_ss, within_cell_ss = cells

# ── 4. Verification ─────────────────────────────────────────────────────────
reconstructed = between_group_ss + within_group0_ss + between_cell_ss + within_cell_ss
discrepancy = abs(total_ss - reconstructed)

# ── 5. Report ────────────────────────────────────────────────────────────────
print(f"Number of (microregion, industry) cells: {n_cells:,.0f}")
print()
print("═══ Hierarchical Variance Decomposition ═══")
print(f"{'Component':<55s} {'SS':>14s}  {'Share':>7s}")
print("─" * 80)

components = [
    ("Between same_industry_micro groups (0 vs 1)",  between_group_ss),
    ("Within same_industry_micro = 0",               within_group0_ss),
    ("Within same_industry_micro = 1, between cells", between_cell_ss),
    ("Within same_industry_micro = 1, within cells",  within_cell_ss),
]

for label, ss in components:
    print(f"  {label:<53s} {ss:>14.4e}  {100*ss/total_ss:6.2f}%")

print("─" * 80)
print(f"  {'Sum (check)':<53s} {reconstructed:>14.4e}  {100*reconstructed/total_ss:6.2f}%")
print(f"  {'Total SS':<53s} {total_ss:>14.4e}  100.00%")
print(f"  Discrepancy: {discrepancy:.2e}")
print()
print("═══ Interpretation ═══")
pct_within_cell = 100 * within_cell_ss / total_ss
print(f"  {pct_within_cell:.2f}% of total variance in bilateral_conn_pre")
print(f"  is within (microregion × industry) cells among same-cell pairs.")
print(f"  This variation is NOT explained by administrative proximity")
print(f"  and reflects meaningful heterogeneity in worker flows.")

con.close()
