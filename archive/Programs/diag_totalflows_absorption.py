"""
Diagnostic: show explicitly that Spec A and Spec B controls absorb all
within-firm variation in totalflows_pw — no regression required.

Method: iterative within-estimator (alternating projections / Gauss-Seidel),
identical to what reghdfe does internally.  We apply each FE in a loop and
repeat until the residuals converge.  We track residual variance at every
iteration and again after adding each new FE.

FE sequence matching the actual reghdfe spec:
  1. identificad             (firm FE)
  2. industry1 × year
  3. mode_base_month × year
  4. microregion × year
  5. l_firm_emp_pre4 × year
  6. [Spec A] totalflows_pw_pre_07_114 × year
     [Spec B] totalflows_pw_pre4 × year
"""

import numpy as np
import pandas as pd

MAIN_DTA  = "/kellogg/proj/lgg3230/UnionSpill/Data/CBA_RAIS_firm_level/lagos_sample_sep24_pct_unionexp_ext_df2.dta"
PANEL_CSV = "/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/totalflows_panel_2009_2016.csv"
WIDE_CSV  = "/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/totalflows_wide_2007_2011.csv"

# ── 1. Load ──────────────────────────────────────────────────────────────────
print("Loading data...")

main = pd.read_stata(MAIN_DTA, columns=[
    'identificad','year','microregion','industry1','mode_base_month',
    'in_balanced_panel','lagos_sample_avg','treat_ultra','totaltreat_pw_n',
    'firm_emp'
])
main['identificad'] = main['identificad'].astype(str).str.zfill(14)

panel = pd.read_csv(PANEL_CSV, dtype={'identificad': str})
panel['identificad'] = panel['identificad'].str.zfill(14)
panel = panel[['identificad','year','totalflows_pw','outflows_pw']]

wide = pd.read_csv(WIDE_CSV, dtype={'identificad': str})
wide['identificad'] = wide['identificad'].str.zfill(14)
wide = wide[['identificad','totalflows_pw_07_08','totalflows_pw_08_09',
             'totalflows_pw_09_10','totalflows_pw_10_11']]

df = (main.merge(panel, on=['identificad','year'], how='left')
          .merge(wide,  on='identificad',          how='left'))

# Panel A sample restriction
df = df[
    (df['lagos_sample_avg'] == 1) &
    (df['in_balanced_panel'] == 1) &
    ((df['treat_ultra'] == 1) | (df['totaltreat_pw_n'] == 0)) &
    (df['year'] >= 2009)
].copy()
print(f"Sample: {len(df):,} obs, {df['identificad'].nunique():,} firms")

# ── 2. Build FE group keys ────────────────────────────────────────────────────

# l_firm_emp_pre4
pre_emp = (df[df['year'].between(2009,2011)]
           .groupby('identificad')['firm_emp'].mean().apply(np.log))
base09  = df[df['year']==2009].set_index('identificad')['firm_emp'].apply(np.log)
emp_bins = pd.qcut(base09.dropna(), q=4, labels=[0,1,2,3]).cat.codes
emp_bins.name = 'l_firm_emp_pre4'
df = df.merge(emp_bins, on='identificad', how='left')
df['l_firm_emp_pre4'] = df['l_firm_emp_pre4'].fillna(0).astype(int)

# Spec A bins: 2007-2011 average
wide_cols = ['totalflows_pw_07_08','totalflows_pw_08_09','totalflows_pw_09_10','totalflows_pw_10_11']
df['pre_07_11'] = df[wide_cols].mean(axis=1)
base09A = df[df['year']==2009].set_index('identificad')['pre_07_11']
binsA = pd.qcut(base09A.dropna(), q=4, labels=[0,1,2,3]).cat.codes
binsA.name = 'binA'
df = df.merge(binsA, on='identificad', how='left')
df['binA'] = df['binA'].fillna(0).astype(int)

# Spec B bins: 2009-2011 panel average
pre_09_11 = (df[df['year'].between(2009,2011)]
             .groupby('identificad')['totalflows_pw'].mean())
base09B = df[df['year']==2009].set_index('identificad').join(pre_09_11.rename('pre_09_11'))['pre_09_11']
binsB = pd.qcut(base09B.dropna(), q=4, labels=[0,1,2,3]).cat.codes
binsB.name = 'binB'
df = df.merge(binsB, on='identificad', how='left')
df['binB'] = df['binB'].fillna(0).astype(int)

# Composite group keys
df['ind_yr']  = df['industry1'].astype(str) + '_' + df['year'].astype(str)
df['mode_yr'] = df['mode_base_month'].astype(str) + '_' + df['year'].astype(str)
df['mic_yr']  = df['microregion'].astype(str) + '_' + df['year'].astype(str)
df['siz_yr']  = df['l_firm_emp_pre4'].astype(str) + '_' + df['year'].astype(str)
df['binA_yr'] = df['binA'].astype(str) + '_' + df['year'].astype(str)
df['binB_yr'] = df['binB'].astype(str) + '_' + df['year'].astype(str)

# ── 3. Iterative within-estimator (alternating projections) ─────────────────

def within_estimator(y, fe_cols, df, tol=1e-10, max_iter=500):
    """
    Returns residuals after projecting out all FEs via iterative demeaning
    (alternating projections / Gauss-Seidel), identical to what reghdfe does.
    Also returns the variance after each FE is added to the active set.
    """
    idx   = df.index
    r     = y.values.astype(float) - y.mean()
    active_keys = []   # list of df[fe].values arrays
    active      = []   # fe names
    step_vars   = {}

    for fe in fe_cols:
        active.append(fe)
        active_keys.append(df[fe].values)

        # Iterate until convergence with the current active set
        for it in range(max_iter):
            r_old = r.copy()
            for key_arr in active_keys:
                # compute group means of r using the grouping key
                s = pd.Series(r, index=idx)
                grp_mean = s.groupby(key_arr).transform('mean').values
                r = r - grp_mean
            if np.abs(r - r_old).max() < tol:
                break

        step_vars[fe] = np.var(r)

    return pd.Series(r, index=idx), step_vars

df_clean = df.dropna(subset=['totalflows_pw','outflows_pw']).copy()

# ── SPEC A ──────────────────────────────────────────────────────────────────
fe_seq_A = ['identificad','ind_yr','mode_yr','mic_yr','siz_yr','binA_yr']
fe_labels = [
    '1. Firm FE',
    '2. + industry1 × year',
    '3. + mode × year',
    '4. + microregion × year',
    '5. + size_bin × year',
    '6. + FLOW_BIN_A × year  [Spec A]',
]

print("\n" + "="*74)
print("SPEC A  (Spec A flow bins = 2007-2011 average bins)")
print("="*74)
y_A = df_clean['totalflows_pw'].copy()
y_A.name = 'totalflows_pw'
total_var = y_A.var()
print(f"  Total variance: {total_var:.6f}")
_, step_A = within_estimator(y_A, fe_seq_A, df_clean)
for label, fe in zip(fe_labels, fe_seq_A):
    pct = step_A[fe] / total_var * 100
    print(f"  After {label:<40}  var = {step_A[fe]:.2e}  ({pct:5.2f}% remaining)")

# ── SPEC B ──────────────────────────────────────────────────────────────────
fe_seq_B = ['identificad','ind_yr','mode_yr','mic_yr','siz_yr','binB_yr']
fe_labels_B = fe_labels[:5] + ['6. + FLOW_BIN_B × year  [Spec B]']

print("\n" + "="*74)
print("SPEC B  (Spec B flow bins = 2009-2011 pre4 bins)")
print("="*74)
y_B = df_clean['totalflows_pw'].copy()
y_B.name = 'totalflows_pw'
print(f"  Total variance: {total_var:.6f}")
_, step_B = within_estimator(y_B, fe_seq_B, df_clean)
for label, fe in zip(fe_labels_B, fe_seq_B):
    pct = step_B[fe] / total_var * 100
    print(f"  After {label:<40}  var = {step_B[fe]:.2e}  ({pct:5.2f}% remaining)")

# ── COMPARISON: outflows_pw under Spec A ─────────────────────────────────────
print("\n" + "="*74)
print("COMPARISON: outflows_pw under Spec A (should retain variation)")
print("="*74)
y_out = df_clean['outflows_pw'].copy()
y_out.name = 'outflows_pw'
total_var_out = y_out.var()
print(f"  Total variance: {total_var_out:.6f}")
_, step_out = within_estimator(y_out, fe_seq_A, df_clean)
for label, fe in zip(fe_labels, fe_seq_A):
    pct = step_out[fe] / total_var_out * 100
    print(f"  After {label:<40}  var = {step_out[fe]:.2e}  ({pct:5.2f}% remaining)")

# ── WHY: auto-correlation ─────────────────────────────────────────────────────
print("\n" + "="*74)
print("WHY: auto-correlation of the two outcomes")
print("="*74)
d = df_clean[['identificad','year','totalflows_pw','outflows_pw']].sort_values(['identificad','year'])
d['tf_lag']  = d.groupby('identificad')['totalflows_pw'].shift(1)
d['out_lag'] = d.groupby('identificad')['outflows_pw'].shift(1)
ar1_tf  = d['totalflows_pw'].corr(d['tf_lag'])
ar1_out = d['outflows_pw'].corr(d['out_lag'])
print(f"  AR(1) of totalflows_pw : {ar1_tf:.4f}")
print(f"  AR(1) of outflows_pw   : {ar1_out:.4f}")

# ── SUMMARY TABLE ─────────────────────────────────────────────────────────────
print("\n" + "="*74)
print("SUMMARY: % of total variance remaining after full spec")
print("="*74)
rows = [
    ('totalflows_pw', 'Spec A', step_A['binA_yr'] / total_var * 100),
    ('totalflows_pw', 'Spec B', step_B['binB_yr'] / total_var * 100),
    ('outflows_pw',   'Spec A', step_out['binA_yr'] / total_var_out * 100),
]
print(f"  {'Outcome':<20}  {'Spec':<8}  {'% var remaining':>16}  {'Identified?':>12}")
print("  " + "-"*60)
for outcome, spec, pct in rows:
    flag = "YES" if pct > 1 else "NO — perfectly absorbed"
    print(f"  {outcome:<20}  {spec:<8}  {pct:>15.4f}%  {flag:>12}")

print("\nDone.")
