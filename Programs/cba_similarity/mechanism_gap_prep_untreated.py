"""
mechanism_gap_prep_untreated.py

Mirror of mechanism_gap_prep.py.

For each *untreated* firm j and each clause type c, compute:

    gap_jc     = max(0, weighted_avg_cl_c_i - own_cl_c_j)   [treated partner has more]
    surplus_jc = max(0, own_cl_c_j - weighted_avg_cl_c_i)   [own has more]

where i ranges over *treated* firms connected to j in the pre-treatment
bilateral connectivity data (2007-2011), weighted by conn_weight.

Output:
    Data/CBA_RAIS_firm_level/mechanism_gaps_untreated.dta
"""

import pandas as pd
import numpy as np
from pathlib import Path
import subprocess

ROOT = Path('/gpfs/kellogg/proj/lgg3230/UnionSpill')
DATA = ROOT / 'Data'
OUT  = DATA / 'CBA_RAIS_firm_level'

# 1. Bilateral connectivity
print("Loading bilateral connectivity...")
conn = pd.read_csv(DATA / 'RAIS_aux/bilateral_connectivity_2007_2011.csv')

conn['id_i'] = conn['identificad_i'].astype(str).str.zfill(15).str[1:]
conn['id_j'] = conn['identificad_j'].astype(str).str.zfill(15).str[1:]

ratio_cols = ['ratio_0708', 'ratio_0809', 'ratio_0910', 'ratio_1011']
conn['conn_weight'] = conn[ratio_cols].mean(axis=1)
conn = conn.loc[conn['conn_weight'].notna() & (conn['conn_weight'] > 0),
                ['id_i', 'id_j', 'conn_weight']].copy()
print(f"  {len(conn):,} pairs with positive connectivity")

# 2. Pre-treatment clause counts per firm
print("Loading main dataset (pre-treatment periods)...")
df = pd.read_stata(
    OUT / 'lagos_sample_sep24_pct_unionexp_ext_df2.dta',
    convert_categoricals=False
)

cl_cols = [c for c in df.columns if c.startswith('cl_')]
print(f"  {len(cl_cols)} clause-type variables")

pre = (
    df.loc[df['cba_period'].isin([1, 2]),
           ['identificad', 'treat_ultra'] + cl_cols]
    .groupby('identificad')[['treat_ultra'] + cl_cols]
    .mean()
    .reset_index()
)
pre['treat_ultra'] = (pre['treat_ultra'] >= 0.5).astype(int)

pre_treat   = pre.loc[pre['treat_ultra'] == 1, ['identificad'] + cl_cols].copy()
pre_untreat = pre.loc[pre['treat_ultra'] == 0, ['identificad'] + cl_cols].copy()
print(f"  {len(pre_treat):,} treated firms, {len(pre_untreat):,} untreated firms")

# 3. Directed pairs: untreated focal firm j, treated partner firm i
treat_ids   = set(pre_treat['identificad'])
untreat_ids = set(pre_untreat['identificad'])

# Undirected bilateral → check both orientations. focal=untreated, partner=treated.
conn_ab = conn.rename(columns={'id_i': 'focal', 'id_j': 'partner'})
conn_ba = conn.rename(columns={'id_j': 'focal', 'id_i': 'partner'})
conn_dir = pd.concat([conn_ab, conn_ba], ignore_index=True)

conn_dir = conn_dir.loc[
    conn_dir['focal'].isin(untreat_ids) &
    conn_dir['partner'].isin(treat_ids)
].copy()
print(f"  {conn_dir['focal'].nunique():,} untreated firms have ≥1 connected treated firm")

# 4. Connectivity-weighted average clause counts of treated partners
conn_dir = conn_dir.merge(
    pre_treat.rename(columns={'identificad': 'partner'}),
    on='partner', how='left'
)

for c in cl_cols:
    conn_dir[f'w_{c}'] = conn_dir['conn_weight'] * conn_dir[c].fillna(0)

agg_dict = {'conn_weight': 'sum'}
agg_dict.update({f'w_{c}': 'sum' for c in cl_cols})
agg = conn_dir.groupby('focal').agg(agg_dict).reset_index()

for c in cl_cols:
    agg[f'avg_{c}'] = agg[f'w_{c}'] / agg['conn_weight']
agg = agg[['focal'] + [f'avg_{c}' for c in cl_cols]]

# 5. Merge with untreated firm's own pre-treatment counts
agg = agg.merge(
    pre_untreat.rename(columns={'identificad': 'focal'}),
    on='focal', how='inner'
)
print(f"  {len(agg):,} untreated firms after inner join")

# 6. Build long dataset: identificad × clause_num
records = []
for idx, c in enumerate(cl_cols, start=1):
    tmp = agg[['focal', f'avg_{c}', c]].copy()
    tmp.columns = ['identificad', 'avg_connected', 'own']
    diff = tmp['avg_connected'] - tmp['own']
    tmp['clause_num'] = idx
    tmp['gap']        = diff.clip(lower=0)
    tmp['surplus']    = (-diff).clip(lower=0)
    records.append(tmp[['identificad', 'clause_num', 'gap', 'surplus']])

gap_long = pd.concat(records, ignore_index=True)
print(f"  Gap dataset: {len(gap_long):,} rows ({agg.shape[0]} firms × {len(cl_cols)} clause types)")
print(f"  gap>0: {(gap_long['gap']>0).sum():,} | surplus>0: {(gap_long['surplus']>0).sum():,}")

# 7. Save
out_dta = OUT / 'mechanism_gaps_untreated.dta'
gap_long.to_stata(str(out_dta), write_index=False, version=118)
print(f"Saved: {out_dta}")

subprocess.run([
    'curl', '-s', '-o', '/dev/null',
    '-H', 'Title: Done',
    '-d', 'mechanism_gap_prep_untreated.py finished',
    'https://ntfy.sh/lgg3230-kellogg'
])
