#!/usr/bin/env python
"""
Randomization inference — Module 0: build the flow-weight engine.

Connectivity to treated is EXACTLY linear in the destination set:
    totaltreat_pw_n_i = (1/P_i) * sum_p  sum_{j in T} (f^p_{i->j}+f^p_{j->i}) / avgemp_{i,p}
where P_i = # pre-treatment year-pairs in which firm i is present (avgemp>0),
independent of the destination set. Define
    W_ij = (1/P_i) * sum_p (f^p_{i->j}+f^p_{j->i}) / avgemp_{i,p}
so that C_i(S) = sum_{j in S} W_ij for ANY destination set S (a matrix-vector product).

This script builds W over the Lagos x Lagos submatrix (treated set and placebo pool
are both subsets of the 17,836 Lagos firms) and VALIDATES that sum_{j in T} W_ij
reproduces the panel's totaltreat_pw_n to machine precision.

Source flows: Data/RAIS_aux/employers_YYYY_YYYY.csv (worker PIS-level; a mover
contributes f_{a->b} for estab a in year y and b in year y+1, a<>b).
IDs: CSV are 15-digit w/ leading prefix; panel is 14-digit -> substr(id,2,14).
"""
import duckdb
from pathlib import Path

ROOT = Path("/gpfs/kellogg/proj/lgg3230/UnionSpill")
AUX  = ROOT / "Data/RAIS_aux"
OUT  = ROOT / "Data/rand_inference"
KEYS = OUT / "firm_keys_2009.parquet"

PAIRS = [(2007, 2008), (2008, 2009), (2009, 2010), (2010, 2011)]

con = duckdb.connect()
con.execute("PRAGMA threads=8")
con.execute("PRAGMA memory_limit='32GB'")

# Lagos firm universe (14-digit ids) = rows i and columns j
con.execute(f"CREATE TEMP TABLE lg AS SELECT identificad AS id FROM read_parquet('{KEYS}')")
n_lagos = con.execute("SELECT count(*) FROM lg").fetchone()[0]
print(f"Lagos firms: {n_lagos}")

# Accumulators across pairs
con.execute("CREATE TEMP TABLE contrib_all (i VARCHAR, j VARCHAR, w DOUBLE)")   # per-pair (sym flow)/avgemp
con.execute("CREATE TEMP TABLE present_all (firm VARCHAR)")                     # one row per (firm,pair present)

for (y0, y1) in PAIRS:
    csv = AUX / f"employers_{y0}_{y1}.csv"
    print(f"  pair {y0}-{y1}: {csv.name}")
    types = {f'identificad_{y0}': 'VARCHAR', f'identificad_{y1}': 'VARCHAR',
             f'firm_emp_{y0}': 'DOUBLE', f'firm_emp_{y1}': 'DOUBLE'}
    con.execute(f"""
        CREATE OR REPLACE TEMP TABLE e AS
        SELECT substr(identificad_{y0},2,14) AS a, firm_emp_{y0} AS ea,
               substr(identificad_{y1},2,14) AS b, firm_emp_{y1} AS eb
        FROM read_csv('{csv}', types={types})
    """)

    # firm employment in each side (restricted to Lagos)
    con.execute("""
        CREATE OR REPLACE TEMP TABLE emp_y AS
        SELECT a AS firm, max(ea) AS emp FROM e JOIN lg ON e.a=lg.id GROUP BY a
    """)
    con.execute("""
        CREATE OR REPLACE TEMP TABLE emp_n AS
        SELECT b AS firm, max(eb) AS emp FROM e JOIN lg ON e.b=lg.id GROUP BY b
    """)
    # avgemp = (emp_y + emp_next)/2 ; present if > 0
    con.execute("""
        CREATE OR REPLACE TEMP TABLE avgemp AS
        SELECT COALESCE(y.firm,n.firm) AS firm,
               (COALESCE(y.emp,0)+COALESCE(n.emp,0))/2.0 AS avgemp
        FROM emp_y y FULL OUTER JOIN emp_n n ON y.firm=n.firm
    """)
    con.execute("DELETE FROM avgemp WHERE avgemp<=0 OR avgemp IS NULL")
    con.execute("INSERT INTO present_all SELECT firm FROM avgemp")

    # directed mover counts, both endpoints Lagos, a<>b
    con.execute("""
        CREATE OR REPLACE TEMP TABLE ed AS
        SELECT a AS i, b AS j, count(*)::DOUBLE AS f
        FROM e JOIN lg la ON e.a=la.id JOIN lg lb ON e.b=lb.id
        WHERE e.a <> e.b
        GROUP BY a,b
    """)
    # symmetric flow for source i: outflow i->j + inflow j->i
    con.execute("""
        CREATE OR REPLACE TEMP TABLE sym AS
        SELECT i, j, SUM(f) AS s FROM (
            SELECT i, j, f FROM ed
            UNION ALL
            SELECT j AS i, i AS j, f FROM ed
        ) GROUP BY i, j
    """)
    # contribution = sym / avgemp_i  (only firms i present that pair)
    con.execute("""
        INSERT INTO contrib_all
        SELECT s.i, s.j, s.s / a.avgemp AS w
        FROM sym s JOIN avgemp a ON s.i = a.firm
    """)

# P_i = # pairs present
con.execute("""
    CREATE OR REPLACE TEMP TABLE P AS
    SELECT firm, count(*) AS Pi FROM present_all GROUP BY firm
""")

# W_ij = (sum over pairs of contribution) / P_i
con.execute(f"""
    COPY (
        SELECT c.i, c.j, SUM(c.w)/p.Pi AS W
        FROM contrib_all c JOIN P p ON c.i = p.firm
        GROUP BY c.i, c.j, p.Pi
    ) TO '{OUT}/flow_weights.parquet' (FORMAT PARQUET)
""")
nedges = con.execute(f"SELECT count(*) FROM read_parquet('{OUT}/flow_weights.parquet')").fetchone()[0]
print(f"flow_weights.parquet edges: {nedges:,}")

# ---- VALIDATION: sum_{j in T} W_ij  vs  panel totaltreat_pw_n ----
con.execute(f"""
    CREATE TEMP TABLE treated AS
    SELECT identificad AS id FROM read_parquet('{KEYS}') WHERE treat_ultra=1
""")
con.execute(f"""
    CREATE TEMP TABLE Cbase AS
    SELECT w.i AS id, SUM(w.W) AS C_recon
    FROM read_parquet('{OUT}/flow_weights.parquet') w
    JOIN treated t ON w.j = t.id
    GROUP BY w.i
""")
val = con.execute(f"""
    SELECT k.identificad AS id, k.totaltreat_pw_n AS C_panel,
           COALESCE(c.C_recon,0) AS C_recon
    FROM read_parquet('{KEYS}') k
    LEFT JOIN Cbase c ON k.identificad=c.id
    WHERE k.lagos_sample_avg=1 AND k.treat_ultra=0 AND k.in_balanced_panel=1
""").fetchdf()

import numpy as np
d = val.dropna(subset=['C_panel'])
diff = (d.C_recon - d.C_panel).abs()
print("\n===== VALIDATION (s_spill firms) =====")
print(f"  N compared            : {len(d)}")
print(f"  corr(recon, panel)    : {np.corrcoef(d.C_recon, d.C_panel)[0,1]:.10f}")
print(f"  max abs diff          : {diff.max():.3e}")
print(f"  mean abs diff         : {diff.mean():.3e}")
print(f"  # |diff|>1e-6         : {(diff>1e-6).sum()}")
print(f"  panel C mean/sd       : {d.C_panel.mean():.5f} / {d.C_panel.std():.5f}")
d.to_parquet(OUT / "baseline_connectivity_check.parquet", index=False)
print("saved baseline_connectivity_check.parquet")
