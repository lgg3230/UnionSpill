# Layer Connectivity Pipeline

Computes firm-level connectivity to treated firms, disaggregated by internal occupation or demographic layer, and runs spillover regressions. Extends the firm-level connectivity measure from `Programs/05_yearly_employers.do` by tracking not just _how much_ each firm trades workers with treated firms, but _which internal layer_ those workers belong to.

## Motivation

A firm may be highly connected to treated firms through its managers but not through its low-skill workers, or vice versa. This decomposition allows testing whether spillover effects (Súmula 277 reform, 2012) propagate through specific occupational or demographic channels.

---

## Layer Definitions

Defined in `layer_config.py` (`LAYER_DEFS`):

| Key | Description | Values |
|-----|-------------|--------|
| `edu` | 3-bin education (CBO `grinstrucao`) | `0_no_hs`, `1_hs`, `2_higher` |
| `edu2` | 2-bin education: remapped from `edu` | `no_hs`, `has_hs` |
| `occ3` | 3-digit occupation (`floor(ocup2002/10)`) | Integer CBO digit |
| `occ4` | 4-bin CBO 2002 first digit (`ocup2002/100000`) | `1_mgr`, `23_high`, `4_bur`, `5p_low` |
| Gender | Female / male (in demog pipeline) | `female`, `male` |
| Race | White / non-white (in demog pipeline) | `white`, `nonwhite` |

**Do not use occupation as a causal layer.** Employers can change worker occupation codes; it is a firm choice variable, not a fixed worker attribute. Use occupation layers only as a grouping to characterize _which workers_ carry the connectivity.

---

## Pipeline Overview

### Stage 1 — Transitions (Python)

Scripts 01–03 build the core connectivity measure:

```
01_build_transitions.py   → transitions_base/transitions_{layer}.parquet
02_aggregate.py           → connectivity_components/{long,wide}_{layer}.parquet
03_compute_n.py           → final_measures/firm_layer_connectivity_{layer}.dta/.parquet
```

**Script 01** reads `worker_panel_lagos.parquet` (for years 2009–2010) and RAIS raw files (for 2007–2008) to build worker-level transition records. For each pre-treatment year pair (0708, 0809, 0910, 1011) it identifies workers at Lagos-sample firms who moved to/from a treated firm, recording the layer at each end of the move.

**Script 02** aggregates to (firm, layer, year_pair) level, computing:
- `ratio_total`: (outflows to treated + inflows from treated) / average employment
- `ratio_same`: contacts with treated workers _in the same layer_
- `ratio_cross`: contacts with treated workers _in a different layer_

**Script 03** averages year-pair ratios across 2007–2011 (NaN-aware, matching the `_n` logic in `05_yearly_employers.do`) to produce the final `layer_treat_pw_n`, `sametreat_pw_n`, `crosstreat_pw_n` variables per firm × layer.

For **demographic layers** (gender, race), use the parallel `d`-suffix scripts:
```
01d_build_demog_transitions.py → 02d_aggregate_demog.py → 03d_compute_n_demog.py
```

For **occ4**, use `01_build_transitions.py --layer occ4` (the same script, generic via `sql_layer_expr`).

### Stage 2 — Outcomes (Python)

```
06_prep_layer_outcomes.py   → firm_layer_outcomes_{layer}.dta/.parquet
06_prep_demog_outcomes.py   → firm_layer_outcomes_{gender,race,occ4}.dta/.parquet
06b_prep_layer_outcomes.py  → *_full.dta  (zero-filled: all firm×layer×year cells)
06b_prep_demog_outcomes.py  → *_full.dta  (zero-filled)
```

Reads `worker_panel_lagos.parquet` and collapses to firm × layer × year, computing:
- `lr_remdezr_layer`: log average December wages
- `lr_remdezr_h_layer`: log average hourly wages
- `l_layer_emp` / `l1p_layer_emp`: log employment (NaN or log(1+N) at zero)

The `_full` variants fill in zero-employment cells so all (firm, layer, year) combinations appear.

### Stage 3 — Regressions (Stata)

```
07e_layer_spillover.do        → main spillover: edu2, gender, race
07f_layer_spillover_occ4.do   → spillover: occ4
11_disentangling_layers.do    → disentangling: edu2, gender, race
11c_disentangling_occ4.do     → disentangling: occ4
13*.do                        → horse-race regressions
10_cross_layer_spillover.do   → cross-layer (connectivity of layer A → outcomes of layer B)
```

The main spillover spec (`07e`) runs three specifications:
1. **Within-firm FE** (`firm×year`): tests whether high-connectivity layers see larger effects within the same firm
2. **Cross-firm FE** (`micro×year`, `industry×year`, `mode×year`): compares across firms
3. **Firm-level restricted**: firm-level outcome on the same restricted sample

Sample restriction: untreated firms in the balanced panel, **above median pre-treatment employment** (2009–2011). This avoids confounding with firm size.

### Stage 4 — Tables (Python)

| Script | Reads | Outputs |
|--------|-------|---------|
| `08d_make_table_layer_specs_abvmed_firm.py` | `07e` CSVs | `table_layer_specs_abvmed_firm_{edu,demog}.tex` |
| `08e_make_table_layer_specs_abvmed_firm_occ4.py` | `07f` CSVs | `table_layer_specs_abvmed_firm_occ4.tex` |
| `12_make_table_disentangle.py` | `11` CSVs | `table_disentangle_demog.tex` |
| `12b_make_table_disentangle_edu.py` | `11b` CSVs | `table_disentangle_edu.tex` |
| `12d_make_table_disentangle_occ4.py` | `11c` CSVs | `table_disentangle_occ4.tex` |
| `14*.py` | `13*` CSVs | horse-race tables |

---

## Running the Pipeline

### Full run (edu + edu2)

```bash
bash Programs/layer_connectivity/_run_layer_connectivity.sh
```

Runs 00 → 01 → 01b → 02 → 03 for both `edu` and `edu2`. Script 01 takes ~70 min (reads RAIS 2007–2008 raw files).

### Demographic layers (gender, race)

```bash
bash Programs/layer_connectivity/_run_demog_layers.sh
```

### occ4 layer (Python steps only)

```bash
PYTHON=~/.conda/envs/venv_python312/bin/python
$PYTHON Programs/layer_connectivity/01_build_transitions.py --layer occ4
$PYTHON Programs/layer_connectivity/02_aggregate.py --layer occ4
$PYTHON Programs/layer_connectivity/03_compute_n.py --layer occ4
$PYTHON Programs/layer_connectivity/06_prep_demog_outcomes.py --layer occ4
```

### Stata regressions

```bash
/software/Stata/stata17/stata-mp -b do Programs/layer_connectivity/07e_layer_spillover.do
/software/Stata/stata17/stata-mp -b do Programs/layer_connectivity/07f_layer_spillover_occ4.do
/software/Stata/stata17/stata-mp -b do Programs/layer_connectivity/11_disentangling_layers.do
/software/Stata/stata17/stata-mp -b do Programs/layer_connectivity/11c_disentangling_occ4.do
```

### Table generation

```bash
PYTHON=~/.conda/envs/venv_python312/bin/python
$PYTHON Programs/layer_connectivity/08d_make_table_layer_specs_abvmed_firm.py
$PYTHON Programs/layer_connectivity/08e_make_table_layer_specs_abvmed_firm_occ4.py
$PYTHON Programs/layer_connectivity/12_make_table_disentangle.py
$PYTHON Programs/layer_connectivity/12d_make_table_disentangle_occ4.py
```

---

## Data Flow

```
worker_panel_lagos.parquet      RAIS raw 2007–2008
         │                              │
         └──────────┬───────────────────┘
                    │
            01_build_transitions
                    │
             transitions_{layer}.parquet
                    │
             02_aggregate
                    │
         {long,wide}_{layer}.parquet
                    │
             03_compute_n
                    │
    firm_layer_connectivity_{layer}.dta    ←── merges with cba_rais_firm_2009_2016_flows_1.dta
                    │                                    (treatment, balanced panel, size)
            06_prep_outcomes
                    │
    firm_layer_outcomes_{layer}.dta
                    │
         07e / 07f (Stata)
                    │
       results_spill_layer_*.csv
                    │
         08d / 08e (Python)
                    │
    table_layer_specs_abvmed_firm_*.tex
```

---

## Key Output Files

| File | Description |
|------|-------------|
| `Data/layer_connectivity/final_measures/firm_layer_connectivity_{layer}.dta` | Firm × layer connectivity measure (main output of 01–03) |
| `Data/layer_connectivity/firm_layer_outcomes_{layer}.dta` | Firm × layer × year wage and employment outcomes |
| `Tables/layer_connectivity/results_spill_layer_{layer}_abvmed_firm_layer_spill.csv` | Spillover regression results (within-firm FE) |
| `Tables/layer_connectivity/results_disentangle_{layer}_layer_spill.csv` | Disentangling 4×4 matrix |
| `Tables/layer_connectivity/table_layer_specs_abvmed_firm_occ4.tex` | LaTeX spillover table (occ4) |
| `Tables/layer_connectivity/table_disentangle_occ4.tex` | LaTeX disentangling table (occ4) |

---

## Adding a New Layer

1. Add an entry to `LAYER_DEFS` in `layer_config.py` with `sql_layer_expr` and `pandas_compute`.
2. Run `01_build_transitions.py --layer <new>` → `02_aggregate.py` → `03_compute_n.py`.
3. If the layer is demographic (not derivable from `worker_panel_lagos.parquet` occupation codes), use the `01d` / `02d` / `03d` scripts instead and add to `DEMOG_OUTCOME_DEFS` in `06_prep_demog_outcomes.py`.
4. Write a Stata do-file (copy `07f_layer_spillover_occ4.do`, update `foreach layer` and `local layer_vals`).
5. Write a Python table script (copy `08e` / `12d`, update layer key and labels).

---

## Environment

```bash
# Python (required for all .py scripts)
~/.conda/envs/venv_python312/bin/python

# Stata
/software/Stata/stata17/stata-mp
module load stata/17   # on Kellogg cluster
```

Key Python packages: `duckdb` (1.4.1), `pandas`, `pyarrow`, `numpy`.
