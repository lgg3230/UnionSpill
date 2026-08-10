# -*- coding: utf-8 -*-
# Merge worker x year with firm x year, streaming the big .dta in chunks
# Output: one row per worker-year, with firm vars repeated; columns suffixed: _w (worker), _f (firm)

import pandas as pd, duckdb
import numpy as np
import pyarrow as pa
import pyarrow.parquet as pq
import os
import polars as pl


# ---------- Paths ----------
df_ls_sep24 = pd.read_stata('/kellogg/proj/lgg3230/UnionSpill/Data/CBA_RAIS_firm_level/lagos_sample_sep24.dta', convert_categoricals=False ) # Load lagos sample data
df_workers_all = pd.read_stata('/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/worker_estab_all_years.dta', convert_categoricals=False)
# df_workers_all= next(df)         # worker x year (very large)
OUT_PARQ   = "/kellogg/proj/lgg3230/UnionSpill/Data/CBA_RAIS_firm_level/worker_estab_lagos_sample_sep24.parquet"

# CHUNK_ROWS = 1_000_000  # stream size
N_THREADS  = 5          # DuckDB threads (adjust as you like)

# ---------- Prep output ----------
# Start fresh
if os.path.exists(OUT_PARQ):
    os.remove(OUT_PARQ)

# ---------- Load firm-level sample ----------
df_ls_sep24["cnpj_str"] = df_ls_sep24["identificad"].astype(str)
df_ls_sep24["year_str"] = df_ls_sep24["year"].astype(str)
df_ls_sep24["cnpj_year"] = df_ls_sep24["cnpj_str"] + df_ls_sep24["year_str"]

# ---------- Open DuckDB ----------
con = duckdb.connect()
con.execute(f"PRAGMA threads={N_THREADS};")
con.register("df_ls_sep24", df_ls_sep24)
con.register("df_lagos", df_workers_all)

# List of worker columns (with suffixes)
worker_cols = [f'w."{c}" AS "{c}_worker"' for c in df_workers_all.columns if c != "cnpj_year"]
# Keep all firm columns (no suffix)
firm_cols = [f'f."{c}"' for c in df_ls_sep24.columns]

select_cols = ", ".join(worker_cols + firm_cols)

query = f"""
COPY (
    SELECT {select_cols}
    FROM df_lagos AS w
    INNER JOIN df_ls_sep24 AS f
    USING (cnpj_year)
) TO '/kellogg/proj/lgg3230/UnionSpill/Data/CBA_RAIS_firm_level/worker_estab_lagos_sample_sep24.parquet'
  (FORMAT PARQUET, COMPRESSION ZSTD);
"""

con.execute(query)