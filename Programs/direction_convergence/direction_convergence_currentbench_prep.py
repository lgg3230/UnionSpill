"""
direction_convergence_currentbench_prep.py        [CLUSTER ONLY — needs bilateral file]

Extends the fixed-(period-2)-benchmark pipeline with the two pieces that the local
geometry script cannot build because they require the partner-level bilateral weights:

  #2  CURRENT-period benchmark: each untreated focal i is compared, in cba_period t, to the
      connectivity-weighted clause vector of its connected TREATED partners *in that same
      cba_period t* (a moving target), in addition to the fixed period-2 benchmark.
        - convergence to the CURRENT but not the FIXED-2011 benchmark = "following the
          partner as it relocates" (the joint-movement signature).

  #3  UNION control: share of i's connectivity weight to treated partners that share i's
      union (same_union_wshare). Lets the .do test whether convergence survives conditioning
      on shared-union exposure, mirroring the wage-spillover robustness in the Draft.
      (FEDERATION/CUT control still needs a federation variable that is NOT in the panel —
      add `federation_id` to the firm panel to enable it.)

Output: Data/direction_convergence/direction_convergence_currentbench.dta
Mirrors direction_convergence_prep.py exactly except for the benchmark timing + union share.
"""
import pandas as pd
import numpy as np
from pathlib import Path

ROOT = Path('/gpfs/kellogg/proj/lgg3230/UnionSpill')
DATA = ROOT / 'Data'
OUT  = DATA / 'direction_convergence'

# 1. bilateral connectivity (same construction as direction_convergence_prep.py)
conn = pd.read_csv(DATA / 'RAIS_aux/bilateral_connectivity_2007_2011.csv')
conn['id_i'] = conn['identificad_i'].astype('int64').astype(str).str.zfill(15).str[1:]
conn['id_j'] = conn['identificad_j'].astype('int64').astype(str).str.zfill(15).str[1:]
conn['conn_weight'] = pd.to_numeric(conn['bilateral_conn_pw'], errors='coerce').fillna(0)
conn = conn.loc[conn['conn_weight'] > 0, ['id_i', 'id_j', 'conn_weight']].copy()

# 2. main panel
df = pd.read_stata(ROOT / 'Data/CBA_RAIS_firm_level/lagos_sample_sep24_pct_unionexp_ext_df2.dta',
                   convert_categoricals=False)
cl_cols = [c for c in df.columns if c.startswith('cl_')]
df = df[(df['in_balanced_panel'] == 1) & (df['year'] >= 2009)
        & df['cba_period'].notna() & df['mode_union'].notna()
        & df['treat_ultra'].notna()].copy()

# union per firm (modal)
def _modal(s):
    s = s.dropna()
    return s.mode().iloc[0] if len(s) else np.nan
firm_union = (df.groupby('identificad')['mode_union'].agg(_modal)
              .rename('focal_union').reset_index())

# 3. treated partner clause vectors BY cba_period (moving target) + period-2 (fixed)
treat = df[df['treat_ultra'] == 1]
treat_pt = (treat.groupby(['identificad', 'cba_period'], as_index=False)[cl_cols].mean())
treat_p2 = (treat[treat['cba_period'] == 2].groupby('identificad', as_index=False)[cl_cols].mean())
treat_union = firm_union.rename(columns={'identificad': 'partner', 'focal_union': 'partner_union'})

treat_ids = set(treat['identificad'].unique())
untreat_ids = set(df.loc[df['treat_ultra'] == 0, 'identificad'].unique())

# directed (untreated focal, treated partner) pairs
ab = conn.rename(columns={'id_i': 'focal', 'id_j': 'partner'})
ba = conn.rename(columns={'id_j': 'focal', 'id_i': 'partner'})
cd = pd.concat([ab, ba], ignore_index=True)
cd = cd[cd['focal'].isin(untreat_ids) & cd['partner'].isin(treat_ids)].copy()

# connectivity_treat and same-union weight share
cd = cd.merge(firm_union, left_on='focal', right_on='identificad', how='left').drop(columns='identificad')
cd = cd.merge(treat_union, on='partner', how='left')
cd['same_union'] = (cd['focal_union'] == cd['partner_union']).astype(float)
conn_tot = cd.groupby('focal', as_index=False).agg(
    connectivity_treat=('conn_weight', 'sum'),
    same_union_wshare=('same_union', lambda s: np.average(s, weights=cd.loc[s.index, 'conn_weight'])),
)

# 4. CURRENT-period benchmark: weighted mean of partners' vectors in the focal's period t.
#    Build per focal x cba_period.
foc_periods = (df[df['treat_ultra'] == 0][['identificad', 'cba_period']]
               .drop_duplicates().rename(columns={'identificad': 'focal'}))
cur = (foc_periods.merge(cd[['focal', 'partner', 'conn_weight']], on='focal', how='inner')
       .merge(treat_pt.rename(columns={'identificad': 'partner'}), on=['partner', 'cba_period'], how='inner'))
for c in cl_cols:
    cur[f'w_{c}'] = cur['conn_weight'] * cur[c]
cagg = cur.groupby(['focal', 'cba_period'], as_index=False).agg(
    {'conn_weight': 'sum', **{f'w_{c}': 'sum' for c in cl_cols}})
cur_bench = cagg[['focal', 'cba_period']].copy()
for c in cl_cols:
    cur_bench[f'cb_{c}'] = cagg[f'w_{c}'] / cagg['conn_weight']

# 5. fixed period-2 benchmark (as in the original prep)
fix = cd.merge(treat_p2.rename(columns={'identificad': 'partner'}), on='partner', how='inner')
for c in cl_cols:
    fix[f'w_{c}'] = fix['conn_weight'] * fix[c]
fagg = fix.groupby('focal', as_index=False).agg(
    {'conn_weight': 'sum', **{f'w_{c}': 'sum' for c in cl_cols}})
fix_bench = fagg[['focal']].copy()
for c in cl_cols:
    fix_bench[f'fb_{c}'] = fagg[f'w_{c}'] / fagg['conn_weight']

# 6. focal clause vectors by period
foc = (df[df['treat_ultra'] == 0].groupby(['identificad', 'cba_period'], as_index=False)[cl_cols].mean()
       .rename(columns={'identificad': 'focal'}))
panel = (foc.merge(cur_bench, on=['focal', 'cba_period'], how='inner')
            .merge(fix_bench, on='focal', how='inner')
            .merge(conn_tot, on='focal', how='inner')
            .merge(firm_union.rename(columns={'identificad': 'focal'}), on='focal', how='left'))

# 7. similarity helper (4 measures) for an arbitrary benchmark-prefix
def sims(P, pref):
    X = P[cl_cols].to_numpy(float)
    B = P[[f'{pref}{c}' for c in cl_cols]].to_numpy(float)
    xs, bs = X.sum(1), B.sum(1)
    S = np.divide(X, xs[:, None], out=np.zeros_like(X), where=xs[:, None] > 0)
    Q = np.divide(B, bs[:, None], out=np.zeros_like(B), where=bs[:, None] > 0)
    nS, nQ = np.linalg.norm(S, axis=1), np.linalg.norm(Q, axis=1)
    cos = np.where((nS > 0) & (nQ > 0), (S * Q).sum(1) / (nS * nQ), np.nan)
    tv = np.where((nS > 0) & (nQ > 0), 1 - 0.5 * np.abs(S - Q).sum(1), np.nan)
    mx = np.maximum(X, B).sum(1)
    ruz = np.where(mx > 0, np.minimum(X, B).sum(1) / mx, np.nan)
    den = (X + B).sum(1)
    bc = np.where(den > 0, 1 - np.abs(X - B).sum(1) / den, np.nan)
    return cos, tv, ruz, bc

for pref, tag in [('cb_', 'cur'), ('fb_', 'fix')]:
    cos, tv, ruz, bc = sims(panel, pref)
    panel[f'sim_{tag}_cosine_shares'] = cos
    panel[f'sim_{tag}_tv_shares'] = tv
    panel[f'sim_{tag}_ruzicka_counts'] = ruz
    panel[f'sim_{tag}_bc_counts'] = bc

panel['post'] = (panel['cba_period'] >= 3).astype(int)
panel['pre_treat_cba'] = (panel['cba_period'] == 1).astype(int)

keep = (['focal', 'cba_period', 'post', 'pre_treat_cba', 'connectivity_treat',
         'same_union_wshare', 'mode_union'] +
        [f'sim_{t}_{m}' for t in ['cur', 'fix']
         for m in ['cosine_shares', 'tv_shares', 'ruzicka_counts', 'bc_counts']])
out = panel[keep].rename(columns={'focal': 'identificad'})
out.to_stata(str(OUT / 'direction_convergence_currentbench.dta'), write_index=False, version=118)
print('Saved direction_convergence_currentbench.dta:', len(out), 'rows',
      out['identificad'].nunique(), 'firms')
