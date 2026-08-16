# Plan: Cross-Layer Spillover Exercise

## Context

The goal is to test whether connectivity of one layer of a firm (e.g. higher-ed workers) spills over to *other* layers within the same firm (e.g. lower-ed workers). The key new regressor is **cross-layer connectivity**: the sum over all other layers A of `layer_treat_pw_n_{i,A} × (avg_emp_pre_{i,A} / avg_emp_pre_{i,B})`, which emerges from the algebra of decomposing firm-level per-worker connectivity into layer contributions (firm-share-weighted sum). The weight `avg_emp_pre_{i,A} / avg_emp_pre_{i,B}` is not ad-hoc — it follows from `s_{i,A} / s_{i,B} = (n_{i,A}/n_i) / (n_{i,B}/n_i)`.

The exercise requires a **balanced firm-level panel**: every firm in the spillover sample gets rows for ALL layers. Missing layers get `layer_emp=0`, `l_layer_emp=ln(1+0)=0`, wages=missing, connectivity=0.

---

## Formula

For focal layer B of firm i:

$$\text{cross\_conn}_{i,B} = \sum_{A \neq B} \text{layer\_treat\_pw\_n}_{i,A} \times \frac{\overline{n}_{i,A}}{\overline{n}_{i,B}}$$

where $\overline{n}_{i,A}$ = avg pre-treatment (2009–2011) layer employment (using 0 for absent combos).

- If $\overline{n}_{i,B} = 0$ (firm never had workers in focal layer): set `cross_conn = .` (undefined ratio, obs drop from regressions)
- `l_layer_emp = ln(1 + layer_emp)` throughout (consistent for all obs, including zeros)

---

## Files to create

| File | Purpose |
|------|---------|
| `Programs/layer_connectivity/10_cross_layer_prep.py` | Build balanced panel + compute cross_conn; save DTA |
| `Programs/layer_connectivity/10_cross_layer_spillover.do` | Stata regressions (within-firm spec) |
| `Programs/layer_connectivity/10_make_table_cross_layer.py` | LaTeX table |

Output CSVs: `Tables/layer_connectivity/results_cross_layer_{layer}_layer_spill.csv`
Output table: `Tables/layer_connectivity/table_cross_layer_specs.tex/.csv`

---

## Step 1 — Python: `10_cross_layer_prep.py`

### Inputs
- `Data/layer_connectivity/firm_layer_outcomes_{layer}.dta` — outcomes (firm × layer × year, 2009–2016); variables: `identificad`, `layer_id`, `year`, `layer_emp`, `lr_remdezr_layer`, `lr_remdezr_h_layer`
- `Data/layer_connectivity/final_measures/firm_layer_connectivity_{layer}.dta` — connectivity (firm × layer, time-invariant); key variable: `layer_treat_pw_n`
- `Data/CBA_RAIS_firm_level/lagos_sample_sep24_pct_unionexp_ext_df2.dta` — firm-level panel; keepusing `treat_ultra`, `in_balanced_panel`, `lagos_sample_avg`, `firm_emp`, `industry1`, `mode_base_month`, `microregion`

### Logic

```python
# 1. Get spillover-sample firms (untreated, balanced, lagos)
firm_df = pd.read_stata(firm_dta, columns=[...])
spillover_firms = firm_df[
    (firm_df.treat_ultra == 0) &
    (firm_df.in_balanced_panel == 1) &
    (firm_df.lagos_sample_avg == 1)
]["identificad"].unique()

# 2. Get layer IDs for this layer
layer_ids = outcomes_df["layer_id"].unique()
years = range(2009, 2017)

# 3. Build full balanced index: spillover_firms × layer_ids × years
idx = pd.MultiIndex.from_product([spillover_firms, layer_ids, years],
                                  names=["identificad", "layer_id", "year"])
balanced = pd.DataFrame(index=idx).reset_index()

# 4. Merge outcomes (left join → missing = NaN)
balanced = balanced.merge(outcomes_df, on=["identificad","layer_id","year"], how="left")

# 5. Fill employment zeros; leave wages as NaN
balanced["layer_emp"] = balanced["layer_emp"].fillna(0).astype(int)
# lr_remdezr_layer, lr_remdezr_h_layer: leave NaN

# 6. l_layer_emp = ln(1 + layer_emp) for all rows
balanced["l_layer_emp"] = np.log1p(balanced["layer_emp"])

# 7. Merge connectivity (left join → missing = 0)
conn_df = pd.read_stata(conn_dta, columns=["identificad","layer_id","layer_treat_pw_n"])
balanced = balanced.merge(conn_df, on=["identificad","layer_id"], how="left")
balanced["layer_treat_pw_n"] = balanced["layer_treat_pw_n"].fillna(0)

# 8. Compute avg pre-treatment layer employment (2009–2011, including 0s)
pre = balanced[balanced["year"].between(2009, 2011)]
avg_emp = pre.groupby(["identificad","layer_id"])["layer_emp"].mean().rename("avg_emp_pre")
balanced = balanced.merge(avg_emp.reset_index(), on=["identificad","layer_id"], how="left")

# 9. Compute cross_conn for each focal layer B
# For each firm-layer, sum over other layers: layer_treat_pw_n_A * (avg_emp_A / avg_emp_B)
# First get firm-level sum of (layer_treat_pw_n_A * avg_emp_A) per year group (time-invariant)
firm_weighted = (
    balanced.drop_duplicates(["identificad","layer_id"])  # connectivity is time-invariant
    .assign(weighted_conn=lambda x: x["layer_treat_pw_n"] * x["avg_emp_pre"])
    .groupby("identificad")[["weighted_conn","avg_emp_pre"]]
    .sum()
    .rename(columns={"weighted_conn": "firm_total_weighted_conn",
                     "avg_emp_pre":   "firm_total_emp_pre"})
)
# For focal layer B: cross_conn = (firm_total_weighted_conn - own_weighted) / avg_emp_pre_B
balanced = balanced.merge(firm_weighted.reset_index(), on="identificad", how="left")
balanced["own_weighted"] = balanced["layer_treat_pw_n"] * balanced["avg_emp_pre"]
balanced["cross_total_weighted"] = balanced["firm_total_weighted_conn"] - balanced["own_weighted"]
balanced["cross_conn"] = balanced["cross_total_weighted"] / balanced["avg_emp_pre"]
# Set to missing where focal layer has no pre-treatment workers
balanced.loc[balanced["avg_emp_pre"] == 0, "cross_conn"] = np.nan

# 10. Merge firm-level controls back (year-varying)
balanced = balanced.merge(firm_df[["identificad","year","firm_emp","industry1",
                                    "mode_base_month","microregion","treat_ultra",
                                    "in_balanced_panel","lagos_sample_avg"]],
                           on=["identificad","year"], how="left")

# 11. Save per layer
balanced.to_stata(f"Data/layer_connectivity/cross_layer_balanced_{layer}.dta",
                  write_index=False, version=118)
```

### Output
`Data/layer_connectivity/cross_layer_balanced_{layer}.dta` — one per layer (edu, edu2, gender, race)

Variables added: `avg_emp_pre`, `cross_conn` (time-invariant within firm-layer), `l_layer_emp` (recomputed as ln(1+emp))

---

## Step 2 — Stata: `10_cross_layer_spillover.do`

Mirrors `07_layer_spillover.do` but uses the balanced DTA with `cross_conn`.

### Key differences from `07_layer_spillover.do`
1. Load `cross_layer_balanced_{layer}.dta` instead of `firm_layer_outcomes_{layer}.dta`
2. No need to merge connectivity (already in the file) — only merge for FE encoding variables
3. P90-scale both `own_conn` (`layer_treat_pw_n`) and `cross_conn` from full spillover sample
4. Regression adds `c.cross_conn_norm##i.treat_year` alongside `c.own_conn_norm##i.treat_year`
5. Report BOTH post-treatment interactions: `1.treat_year#c.own_conn_norm` AND `1.treat_year#c.cross_conn_norm`

### Spec

```stata
local s_spill "lagos_sample_avg==1 & treat_ultra==0 & in_balanced_panel==1"

* P90 scaling from full spillover sample (year==2009, one row per firm-layer)
sum layer_treat_pw_n if `s_spill' & year==2009, detail
gen double own_conn_norm  = layer_treat_pw_n / r(p90)

sum cross_conn if `s_spill' & year==2009, detail
gen double cross_conn_norm = cross_conn / r(p90)

* Pre-treatment bins (use ln(1+emp) already in l_layer_emp)
* ... same bin construction as 07 ...

local absorb "`base_fe' ib0.`outcome'_pre4#i.year ib0.l_layer_emp_pre4#i.year `extra_year'"

reghdfe `outcome' c.own_conn_norm##i.treat_year c.cross_conn_norm##i.treat_year ///
    if `s_spill', absorb(`absorb') vce(cluster identificad)
```

### CSV format
Same as existing CSVs but with two coefficient rows:
```
spec, section, outcome, row_type, value
"cross_{layer}","cross_layer","lr_remdezr_layer","own_main","0.0082***"
"cross_{layer}","cross_layer","lr_remdezr_layer","own_main_se","(0.0021)"
"cross_{layer}","cross_layer","lr_remdezr_layer","cross_main","0.0031*"
"cross_{layer}","cross_layer","lr_remdezr_layer","cross_main_se","(0.0017)"
...n_obs, n_firms, n_cells, pre_pval (from event study on cross_conn)
```

---

## Step 3 — Python: `10_make_table_cross_layer.py`

### Table structure
- 4 panels (edu, edu2, gender, race)
- 3 outcome columns (log Dec wage, log hourly wage, log employment)
- Each column: 1 sub-column (no size split here)
- Rows per panel:
  - Own connectivity × Post  +  SE
  - Cross connectivity × Post  +  SE
  - Pre-trend (own), SE
  - Pre-trend (cross), SE
  - N obs, N firms, N cells, pre-pval (F-test on cross_conn pre-trend)

### Notes
- Mirrors `08_make_table_layer_specs.py` structure
- Output: `Tables/layer_connectivity/table_cross_layer_specs.tex/.csv`
- Landscape format (`\begin{landscape}`) — table will be wide with two coefficient rows

---

## Verification

```bash
# Step 1: Build balanced panels (one per layer)
~/.conda/envs/venv_python312/bin/python Programs/layer_connectivity/10_cross_layer_prep.py

# Check output
~/.conda/envs/venv_python312/bin/python -c "
import pandas as pd
df = pd.read_stata('Data/layer_connectivity/cross_layer_balanced_edu.dta')
print(df[['identificad','layer_id','year','layer_emp','l_layer_emp','cross_conn']].head(12))
print('cross_conn missing:', df['cross_conn'].isna().mean())
print('layer_emp==0:', (df['layer_emp']==0).mean())
"

# Step 2: Run Stata
module load stata/17
nohup stata-mp -b do Programs/layer_connectivity/10_cross_layer_spillover.do &

# Step 3: Generate table
~/.conda/envs/venv_python312/bin/python Programs/layer_connectivity/10_make_table_cross_layer.py

# Verify
ls Tables/layer_connectivity/results_cross_layer_*_layer_spill.csv
ls Tables/layer_connectivity/table_cross_layer_specs.tex
```

---

## Open question

When `avg_emp_pre_{i,B} = 0` (firm never had workers in focal layer in 2009–2011), `cross_conn` is set to **missing** — these observations drop from all regressions. For the employment outcome (`l_layer_emp = 0`), keeping them in with `cross_conn = 0` would be an alternative. Current plan: missing, to avoid an arbitrary assumption about spillover intensity when the focal layer doesn't exist.
