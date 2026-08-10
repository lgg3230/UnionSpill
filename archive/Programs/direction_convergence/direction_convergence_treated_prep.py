"""
direction_convergence_treated_prep.py

Mirror of direction_convergence_prep.py. Builds the TREATED-firm panel for the
direction-of-convergence test.

For each treated balanced-panel firm j:

  1. Connectivity:
       connectivity_untreat_j = Σ_i w_{ji,pre}
     over untreated partners i in the pre-treatment bilateral data
     (both pair orientations); w = bilateral_conn_pw.

  2. Fixed benchmark (cba_period == 2 of untreated partners):
       benchmark^{U,cba2}_{j,k} = Σ_i w_{ji,pre} · x^U_{i,2,k} / Σ_i w_{ji,pre}

  3. Per-period clause vector (mean of cl_* within firm × cba_period):
       x^T_{j,t,k}

  4. Similarity outcomes (same four measures as untreated side):
       sim_cosine_shares  / sim_tv_shares  / sim_ruzicka_counts  / sim_bc_counts
     (rows with degenerate similarity dropped)

Output:
  Data/direction_convergence/direction_convergence_treated.dta
"""

import pandas as pd
import numpy as np
from pathlib import Path
import subprocess

ROOT = Path('/gpfs/kellogg/proj/lgg3230/UnionSpill')
DATA = ROOT / 'Data'
OUT  = DATA / 'direction_convergence'

# 1. Bilateral connectivity (same construction as cba_similarity_prep.py)
print("Loading bilateral connectivity...")
conn = pd.read_csv(DATA / 'RAIS_aux/bilateral_connectivity_2007_2011.csv')
conn['id_i'] = conn['identificad_i'].astype('int64').astype(str).str.zfill(15).str[1:]
conn['id_j'] = conn['identificad_j'].astype('int64').astype(str).str.zfill(15).str[1:]
conn['conn_weight'] = pd.to_numeric(conn['bilateral_conn_pw'], errors='coerce').fillna(0)
conn = conn.loc[conn['conn_weight'] > 0, ['id_i', 'id_j', 'conn_weight']].copy()
print(f"  {len(conn):,} bilateral pairs with positive connectivity")

# 2. Main firm-year panel
print("Loading main firm-year panel...")
df = pd.read_stata(
    ROOT / 'Data/CBA_RAIS_firm_level/lagos_sample_sep24_pct_unionexp_ext_df2.dta',
    convert_categoricals=False
)
cl_cols = [c for c in df.columns if c.startswith('cl_')]
print(f"  {len(cl_cols)} clause-type variables")

df = df[
    (df['in_balanced_panel'] == 1)
    & (df['year'] >= 2009)
    & df['cba_period'].notna()
    & df['mode_union'].notna()
    & df['treat_ultra'].notna()
].copy()
print(f"  Balanced-panel rows post-filter: {len(df):,}")

# 3. Untreated firm cba_period==2 vectors → benchmark source
print("Computing per-untreated-firm cba_period==2 clause vector...")
untreat_p2 = (
    df.loc[(df['treat_ultra'] == 0) & (df['cba_period'] == 2),
           ['identificad'] + cl_cols]
    .groupby('identificad', as_index=False)
    .mean()
)
print(f"  {len(untreat_p2):,} untreated firms with cba_period==2 obs")

# 4. Directed pairs: treated focal j, untreated partner i
treat_ids   = set(df.loc[df['treat_ultra'] == 1, 'identificad'].unique())
untreat_ids = set(untreat_p2['identificad'])

conn_ab = conn.rename(columns={'id_i': 'focal', 'id_j': 'partner'})
conn_ba = conn.rename(columns={'id_j': 'focal', 'id_i': 'partner'})
conn_dir = pd.concat([conn_ab, conn_ba], ignore_index=True)
conn_dir = conn_dir[
    conn_dir['focal'].isin(treat_ids)
    & conn_dir['partner'].isin(untreat_ids)
].copy()
print(f"  {conn_dir['focal'].nunique():,} treated firms with ≥1 connected untreated firm")
print(f"  {len(conn_dir):,} directed (treated, untreated) pairs")

# 5. connectivity_untreat = Σ_i w_{ji,pre} (raw sum of bilateral weights)
conn_total = (
    conn_dir.groupby('focal', as_index=False)['conn_weight'].sum()
    .rename(columns={'focal': 'identificad', 'conn_weight': 'connectivity_untreat'})
)

# 6. benchmark_j = weighted mean of untreated partners' x^U_{i,2}
print("Computing connected-untreated cba_period==2 benchmarks...")
bench_in = conn_dir.merge(
    untreat_p2.rename(columns={'identificad': 'partner'}),
    on='partner', how='inner'
)
weighted_cl = {f'wcl_{c}': bench_in['conn_weight'] * bench_in[c] for c in cl_cols}
bench_in = bench_in.assign(**weighted_cl)

agg_dict = {'conn_weight': 'sum'}
agg_dict.update({f'wcl_{c}': 'sum' for c in cl_cols})
bench_agg = bench_in.groupby('focal', as_index=False).agg(agg_dict)

bench_cols = []
for c in cl_cols:
    new = f'b_{c}'
    bench_agg[new] = bench_agg[f'wcl_{c}'] / bench_agg['conn_weight']
    bench_cols.append(new)

benchmark = bench_agg[['focal'] + bench_cols].rename(columns={'focal': 'identificad'})
print(f"  Benchmarks built for {len(benchmark):,} treated firms")

# 7. Treated firm × cba_period clause vectors (mean of cl_*)
print("Collapsing treated panel to firm × cba_period...")
treat = df[df['treat_ultra'] == 1].copy()

def _modal(s):
    s = s.dropna()
    return s.mode().iloc[0] if len(s) > 0 else np.nan

control_cols = ['mode_union']
if 'mode_base_month' in treat.columns:
    control_cols.append('mode_base_month')
else:
    print("  WARNING: mode_base_month not in panel; FE will be dropped from regs")

agg = {c: 'mean' for c in cl_cols}
for c in control_cols:
    agg[c] = _modal

panel = (
    treat
    .groupby(['identificad', 'cba_period'], as_index=False)
    .agg(agg)
)
print(f"  Treated firm × cba_period rows: {len(panel):,}")
print(f"  Unique treated firms: {panel['identificad'].nunique():,}")

# 8. Inner-join benchmark + connectivity
panel = panel.merge(benchmark, on='identificad', how='inner')
panel = panel.merge(conn_total, on='identificad', how='inner')
print(f"  After inner-joining benchmark + connectivity: {len(panel):,} rows "
      f"({panel['identificad'].nunique():,} firms)")

# 9. Similarity measures
print("Computing similarity measures...")
X = panel[cl_cols].to_numpy(dtype=float)
B = panel[bench_cols].to_numpy(dtype=float)

x_sum = X.sum(axis=1)
b_sum = B.sum(axis=1)
valid = (x_sum > 0) & (b_sum > 0)

S = np.where(x_sum[:, None] > 0, X / np.where(x_sum[:, None] > 0, x_sum[:, None], 1), 0.0)
Q = np.where(b_sum[:, None] > 0, B / np.where(b_sum[:, None] > 0, b_sum[:, None], 1), 0.0)

dot   = (S * Q).sum(axis=1)
nS    = np.linalg.norm(S, axis=1)
nQ    = np.linalg.norm(Q, axis=1)
cos_sh = np.where((nS > 0) & (nQ > 0), dot / (nS * nQ), np.nan)

tv_sh  = np.where((nS > 0) & (nQ > 0), 1 - 0.5 * np.abs(S - Q).sum(axis=1), np.nan)

denom_ruz = np.maximum(X, B).sum(axis=1)
num_ruz   = np.minimum(X, B).sum(axis=1)
ruz       = np.where(denom_ruz > 0, num_ruz / denom_ruz, np.nan)

denom_bc = (X + B).sum(axis=1)
bc       = np.where(denom_bc > 0, 1 - np.abs(X - B).sum(axis=1) / denom_bc, np.nan)

panel['sim_cosine_shares']  = cos_sh
panel['sim_tv_shares']      = tv_sh
panel['sim_ruzicka_counts'] = ruz
panel['sim_bc_counts']      = bc

n_pre = len(panel)
panel = panel[valid].copy()
print(f"  Dropped {n_pre - len(panel):,} rows with degenerate similarity (one side all-zero)")

# 10. post and placebo indicators
panel['post']          = (panel['cba_period'] >= 3).astype(int)
panel['pre_treat_cba'] = (panel['cba_period'] == 1).astype(int)

# 11. Save (same column names as untreated side except for connectivity_untreat).
keep_cols = (
    ['identificad', 'cba_period', 'post', 'pre_treat_cba',
     'connectivity_untreat'] + control_cols +
    ['sim_cosine_shares', 'sim_tv_shares', 'sim_ruzicka_counts', 'sim_bc_counts']
)
out = panel[keep_cols].copy()
out_dta = OUT / 'direction_convergence_treated.dta'
out.to_stata(str(out_dta), write_index=False, version=118)
print(f"Saved: {out_dta}")
print(f"  Rows: {len(out):,} | firms: {out['identificad'].nunique():,}")
print(f"  Similarity summaries:")
for c in ['sim_cosine_shares', 'sim_tv_shares', 'sim_ruzicka_counts', 'sim_bc_counts']:
    s = out[c]
    print(f"    {c:25s}  mean={s.mean():.4f}  std={s.std():.4f}  "
          f"p10={s.quantile(.1):.4f}  p90={s.quantile(.9):.4f}")
print(f"  connectivity_untreat: mean={out['connectivity_untreat'].mean():.4f}  "
      f"std={out['connectivity_untreat'].std():.4f}")

subprocess.run([
    'curl', '-s', '-o', '/dev/null',
    '-H', 'Title: Done',
    '-d', 'direction_convergence_treated_prep.py finished',
    'https://ntfy.sh/lgg3230-kellogg'
])
