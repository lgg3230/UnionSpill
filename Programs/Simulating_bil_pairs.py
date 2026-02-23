import numpy as np
import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq

# =========================
# PARAMETERS
# =========================
N = 100_000                 # number of unordered pairs
NCELLS = 200                # number of industry×microregion cells
P_NZ = 0.01                 # ~1% non-zero connectivity
P_PERSIST = 0.60            # persistence from pre to post
SEED = 123456

OUTFILE = "sim_pairs_100k.parquet"

# =========================
# SET SEED
# =========================
rng = np.random.default_rng(SEED)

# =========================
# DRAW CELLS FOR i AND j
# =========================
cell_i = rng.integers(1, NCELLS + 1, size=N, dtype=np.int32)
cell_j = rng.integers(1, NCELLS + 1, size=N, dtype=np.int32)

# unordered paircell (min,max)
cell_min = np.minimum(cell_i, cell_j)
cell_max = np.maximum(cell_i, cell_j)

# stable integer paircell id
paircell = pd.factorize(pd.Series(list(zip(cell_min, cell_max))))[0].astype(np.int64)

# =========================
# PRE-TREATMENT CONNECTIVITY
# =========================
any_pre = rng.random(N) < P_NZ
conn_pre = np.zeros(N, dtype=np.int8)
conn_pre[any_pre] = rng.integers(1, 4, size=any_pre.sum(), dtype=np.int8)

# =========================
# POST-TREATMENT CONNECTIVITY
# =========================
any_post = np.zeros(N, dtype=bool)

# persistence
persist_mask = any_pre & (rng.random(N) < P_PERSIST)
any_post[persist_mask] = True

# new links
new_mask = (~any_pre) & (rng.random(N) < (P_NZ * (1 - P_PERSIST)))
any_post[new_mask] = True

conn_post = np.zeros(N, dtype=np.int8)
conn_post[any_post] = rng.integers(1, 4, size=any_post.sum(), dtype=np.int8)

# mild dependence on pre (optional, but realistic)
bump = (any_pre & any_post & (rng.random(N) < 0.20))
conn_post[bump] = np.minimum(3, conn_pre[bump] + 1)

# =========================
# BUILD DATAFRAME
# =========================
df = pd.DataFrame({
    "paircell": paircell,
    "cell_i": cell_i,
    "cell_j": cell_j,
    "conn_pre": conn_pre,
    "conn_post": conn_post
})

# =========================
# QUICK CHECKS
# =========================
print("Rows:", len(df))
print("Share conn_pre == 0 :", (df["conn_pre"] == 0).mean())
print("Share conn_post == 0:", (df["conn_post"] == 0).mean())
print("Unique paircells:", df["paircell"].nunique())

# =========================
# WRITE PARQUET
# =========================
table = pa.Table.from_pandas(df, preserve_index=False)
pq.write_table(table, OUTFILE, compression="zstd")

print(f"Saved to {OUTFILE}")