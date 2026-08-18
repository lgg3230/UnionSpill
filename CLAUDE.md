# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

UnionSpill is an economics research project studying union spillover effects in Brazil. The project analyzes how improvements in union bargaining power (following Brazil's Súmula 277 reform in 2012) spread through labor markets to affect firms that are not directly unionized but are connected via worker flows.

**Authors**: Luis de Azevedo-Gomes and Guilherme Neri

## Data Sources

- **RAIS**: Brazilian employer-employee matched administrative data (cleaned using Dahis procedure)
- **CBAs**: Collective Bargaining Agreements from Sistema Mediador (Lagos, 2025)
- **IBGE**: Geographic/microregion data

## Directory Structure

- `Programs/`: Analysis code (Stata `.do`, MATLAB `.m`, Python `.py`)
- `Data/`: Input and intermediate datasets (excluded from git)
- `Tables/`: Regression output tables (CSV)
- `Graphs/`: Event study and distribution plots (PNG)
- `UnionSpill-paper/`: LaTeX manuscript — **separate Overleaf repo**, gitignored here. `Draft.tex` is the paper, `bib.bib` the bibliography. Sync via `/pull-paper` and `/push-paper`.
- `quality_reports/`: Plans, session logs, agent reviews, research journal
- `.claude/`: Research pipeline — agents, skills, rules, references, hooks

## Research Pipeline (ported from clo-author, 2026-07-16)

Adapted from [clo-author](https://github.com/hugosantanna/clo-author): 21 worker/critic
agents, 14 skills, and a quality-gate system. Every creator agent has a paired critic;
critics score but never edit. Full rules in `.claude/rules/`, agent registry in
`.claude/rules/permissions.md`.

| Skill | What it does |
|-------|-------------|
| `/discover [mode] [topic]` | Literature search, data discovery, research interview |
| `/strategize [mode] [q]` | Identification strategy, pre-analysis plan, formal theory |
| `/analyze [dataset]` | End-to-end analysis (coder + data-engineer + coder-critic) |
| `/write [section]` | Draft paper sections + AI-pattern cleanup pass |
| `/paper-review [file]` | Quality reviews — paper, code, or simulated peer review |
| `/revise [report]` | R&R cycle: classify and route referee comments |
| `/talk [mode] [format]` | Beamer / Quarto presentations |
| `/submit [mode]` | Journal targeting, replication package, final gate |
| `/checkpoint` | Session handoff to memory + SESSION_REPORT + journal |
| `/careful`, `/freeze [dirs]` | Session guards: block destructive commands / edits |
| `/tools [subcommand]` | commit, compile, validate-bib, lint, journal |
| `/dashboard` | Regenerate `project_dashboard.html` |

**Local deviations from upstream clo-author** — the port is not vanilla:

- `/review` → **`/paper-review`** (upstream's name collides with Claude Code's built-in `/review`).
- Paths remapped to this repo: `paper/tables/` → `Tables/`, `paper/figures/` → `Graphs/`,
  `scripts/` → `Programs/`, `paper/main.tex` → `UnionSpill-paper/Draft.tex`.
- **Stata is not supported by `/analyze`** (upstream covers R/Python/Julia only). Stata work
  stays on the existing `/new-pipeline` convention; `/analyze` suits the Python/DuckDB side.
- `.claude/references/domain-profile.md` calibrates every agent to this project (field,
  journals, conventions, referee concerns). **Edit it first** when agent output feels generic.
- Hooks run via `.claude/hooks/run-hook.sh`, which probes for Python >= 3.10 — the cluster's
  `/usr/bin/python3` is 3.6 and cannot parse the compact hooks' `dict | None` syntax.
- `post-edit-lint.sh` is intentionally **not wired** (it enforces upstream's no-`print()` R/Python
  standards against this repo's existing style). Run `/tools lint` on demand instead.

## Running the Analysis

### Master File
The main entry point is `Programs/0000_master.do`. It controls which programs run via local flags:
```stata
local 011_rais_to_firm   = 0
local 02_clean_emp_assoc = 0
local 031_clean_cba      = 0
local 041_merge_cba_rais = 0
local 05_flows           = 0
...
```
Set a flag to 1 to run that stage.

### Stata Version
Requires Stata 17.0 (set in master file with `version 17.0`).

### Running Individual Programs
From the Kellogg cluster, first load the Stata module:
```bash
module load stata/17
stata-mp -b do Programs/0000_master.do
```

Or use the full path directly:
```bash
/software/Stata/stata17/stata-mp -b do Programs/0000_master.do
```

For optimized parallel processing of RAIS data:
```bash
module load stata/17
stata-mp -b do Programs/011_rais_to_firm_parallel.do
```

### MATLAB Connectivity Scripts
Worker flow connectivity matrices are computed in MATLAB. Run from Stata via:
```stata
shell "/software/matlab/R2020b/bin/matlab" -nojvm < "/kellogg/proj/lgg3230/UnionSpill/Programs/1041_connectivity_full_lagos.m"
```

Key MATLAB scripts:
- `1041_connectivity_full_lagos.m`: Full sample connectivity
- `1042_connectivity_treat_lagos.m`: Flows to treated firms
- `1043_connectivity_control_lagos.m`: Flows to control firms

## Pipeline Architecture

1. **1010_rais_to_firm.do**: Cleans RAIS data, selects one spell per worker-firm (ranking by hours, wages, random tiebreaker), generates firm-level outcomes (employment, wages, turnover, education composition), collapses to firm level

2. **1020_clean_emp_assoc.do**: Cleans employer association data

3. **1020_clean_cba.do**: Cleans CBA data, Python scripts (`explode_cba_coverage_*.py`) expand coverage to municipalities

4. **1030_merge_cba_rais.do**: Merges CBA and RAIS at firm level, defines treatment status (`treat_ultra`)

5. **1050_yearly_employers.do**: Constructs worker flow transition matrices between consecutive years (2007-2011), runs MATLAB connectivity scripts, computes connectivity measures (flows to treated/control/Lagos sample as proportion of total flows)

6. **results.do**: Runs balance tests, generates event study graphs, TWFE regressions

## Key Variables

### Treatment
- `treat_ultra`: Treatment indicator (firms with CBAs affected by Súmula 277 reform)
- `lagos_sample`: Sample restriction following Lagos (2021)
- `in_balanced_panel`: Balanced panel indicator

### Connectivity Measures
- `totaltreat_pf_n`: Proportion of flows going to treated firms
- `totaltreat_pw_n`: Flows to treated per worker
- `avg_ftreat_pf_n`: Average flow share to treated across year pairs

### Outcomes
- `l_firm_emp`: Log December employment
- `lr_remdezr`: Log December earnings (deflated to 2015)
- `lr_remmedr`: Log average earnings
- `turnover`, `retention`, `hiring`, `layoffs`, `quits`: Flow rates

## Global Paths

Defined in `0000_master.do`:
```stata
global klc "/kellogg/proj/lgg3230"
global rais_raw_dir "$main/RAIS/output/data/full"
global rais_firm "$main/UnionSpill/Data/CBA_RAIS_firm_level"
global rais_aux "$main/UnionSpill/Data/RAIS_aux"
```

## Wage Deflation

All wage variables are deflated to December 2015 prices using Brazil's IPCA index. The deflators are stored as a local in processing scripts.

## Worker Selection Algorithm

For selecting one spell per worker-firm pair:
1. Rank by contracted hours (highest)
2. Among tied, rank by hourly December wage (highest)
3. Random tiebreaker with seed 12345

## Python Environment

The system Python (3.6) is too old for modern packages like DuckDB. Use the conda Python 3.12 environment:

```bash
# Python interpreter path
~/.conda/envs/venv_python312/bin/python

# Install packages
~/.conda/envs/venv_python312/bin/pip install duckdb

# Run Python scripts
~/.conda/envs/venv_python312/bin/python Programs/script.py
```

Note: `pip` does not work, use `pip3` or the full conda path above.

## Installed Python Packages (in conda env)

Key packages available in `~/.conda/envs/venv_python312/`:
- `duckdb` (1.4.1) - Fast SQL analytics for large datasets
- `pyfixest` (0.40.1) - Fixed effects regression (produces identical results to Stata reghdfe)
- `pandas`, `numpy`, `matplotlib` - Standard data science stack
- `pyarrow` - Parquet file support

## Data File Locations & Structures

### Bilateral Connectivity Files

| File | Size | Contents |
|------|------|----------|
| `Data/RAIS_aux/bilateral_connectivity_2007_2011.csv` | 5 MB | 62K pairs with year-pair ratios (ratio_0708, ratio_0809, ratio_0910, ratio_1011) |
| `Data/RAIS_aux/bilateral_connectivity_2011_2016.csv` | 5.6 MB | Post-treatment bilateral pairs with year-pair ratios |
| `Data/RAIS_aux/bilateral_regression_data.parquet` | 12 GB | 135M pairs with proximity measures (all unique i<j pairs) |
| `Data/CBA_RAIS_firm_level/cba_rais_firm_2009_2016_flows_1.dta` | - | Firm-level data with `numb_clauses`, `lagos_sample_avg`, `in_balanced_panel` |

### What's IN vs NOT IN the Parquet

**IN the parquet:**
- `identificad_i`, `identificad_j` (14-digit strings, no leading "1")
- `bilateral_conn_pre`, `bilateral_conn_post` (aggregated connectivity)
- Proximity measures: `size_proximity`, `wage_proximity`, `female_proximity`, `nonwhite_proximity`, `educ_proximity`, `hs_proximity`, `nhs_proximity`, `geo_proximity`
- Dummies: `same_muni`, `same_microregion`, `same_union`, `same_industry`, `same_industry_micro`
- Standardized versions: `z_bilateral_conn_pre`, `z_bilateral_conn_post`, `z_*_proximity`

**NOT in the parquet (must be computed separately):**
- `clauses_proximity` - Must be computed from `numb_clauses` in firm-level data
- Year-pair specific ratios - Only available in original CSVs

### CSV ID Format
```python
# CSV has 15-digit IDs with leading "1"
# Must strip to 14 digits for matching with parquet
SUBSTR(identificad_i, 2, 14) AS identificad_i
```

## DuckDB for Efficient Data Manipulation

DuckDB is much faster than Stata for data manipulation on large datasets (135M rows processed in 8.4 min vs hours in Stata).

```python
import duckdb

con = duckdb.connect()
con.execute("PRAGMA threads=8")
con.execute("PRAGMA memory_limit='32GB'")

# Read CSV and parquet directly in SQL
con.execute("""
    SELECT * FROM read_csv('file.csv')
    JOIN read_parquet('file.parquet') USING (id)
""")

# Handle NULL values with COALESCE
con.execute("""
    SELECT
        COALESCE(ratio_0708, 0) AS ratio_0708,
        (COALESCE(ratio_0708, 0) + COALESCE(ratio_0809, 0)) / 2 AS avg_ratio
    FROM read_csv('file.csv')
""")

# Export to pandas via Arrow (fastest method)
df = con.execute("SELECT * FROM table").fetch_arrow_table().to_pandas()

# Save to Stata format
df.to_stata('output.dta', write_index=False, version=118)
```

## pyfixest for Fixed Effects Regressions

pyfixest produces **identical results to Stata reghdfe** (validated: differences at machine precision ~10⁻⁸).

```python
import pyfixest as pf

# Univariate regression with FE and robust SE
model = pf.feols("y ~ x | fe_var", data=df, vcov='hetero')

# Multivariate regression
model = pf.feols("y ~ x1 + x2 + x3 | fe_var", data=df, vcov='hetero')

# Get results
coef = model.coef()['x']
se = model.se()['x']
ci_lower = coef - 1.96 * se
ci_upper = coef + 1.96 * se
```

## Stata Regression Specifications

```stata
* Univariate with establishment FE
reghdfe z_outcome z_predictor, absorb(identificad_i) vce(robust)

* Multivariate with establishment FE
reghdfe z_outcome z_predictor z_controls same_dummies, absorb(identificad_i) vce(robust)

* Export coefficients to CSV using postfile
tempname coef_hold
tempfile coef_data
postfile `coef_hold' str50 variable str20 var_type coef se ci_lower ci_upper str30 spec str20 reg_type r2 using `coef_data'

local coef = _b[z_predictor]
local se = _se[z_predictor]
local ci_lower = `coef' - 1.96 * `se'
local ci_upper = `coef' + 1.96 * `se'
local r2 = e(r2)

post `coef_hold' ("z_predictor") ("proximity") (`coef') (`se') (`ci_lower') (`ci_upper') ("spec_name") ("univariate") (`r2')
postclose `coef_hold'
```

## Variable Standardization

```stata
* Stata
qui sum var
gen z_var = (var - r(mean)) / r(sd)
```

```python
# Python
df['z_var'] = (df['var'] - df['var'].mean()) / df['var'].std()
```

## Proximity Measures Definition

All proximity measures are defined as **negative absolute difference** (higher = more similar):

```stata
* Continuous proximity
gen size_proximity = -abs(l_avg_firm_emp_i - l_avg_firm_emp_j)
gen wage_proximity = -abs(l_avg_wage_i - l_avg_wage_j)
gen female_proximity = -abs(avg_prop_female_i - avg_prop_female_j)
gen clauses_proximity = -abs(numb_clauses_i - numb_clauses_j)

* Geographic proximity (log transform for distance)
gen geo_proximity = -ln(geo_distance + 0.1)

* Binary dummies
gen same_industry = (industry1_i == industry1_j)
gen same_microregion = (microregion_i == microregion_j)
gen same_industry_micro = (industry1_i == industry1_j & microregion_i == microregion_j)
```

## Coefficient Export Format

Standard CSV format for Python coefplot scripts:
```
variable, var_type, coef, se, ci_lower, ci_upper, spec, reg_type, r2
```

- `var_type`: "proximity", "dummy", "early_connectivity", "pre_connectivity"
- `reg_type`: "univariate", "multivariate"
- `spec`: "pretreat", "post", "post_multivariate", "post_with_pre"

## Performance Benchmarks (135M rows, ~16K FE levels)

| Operation | Tool | Time |
|-----------|------|------|
| Data prep (joins, transforms) | DuckDB/Python | 8.4 min |
| 16 FE regressions | Stata reghdfe | ~45 min |
| 16 FE regressions | pyfixest | ~61 min |
| Load 12GB parquet to pandas | pyarrow | ~3 min |
| Export 135M rows to .dta | pandas.to_stata | ~5 min |

## Recommended Workflow

For large-scale bilateral connectivity analysis:

1. **Data manipulation**: Use Python/DuckDB (much faster than Stata)
2. **FE regressions**: Either Stata reghdfe or pyfixest (identical results; Stata ~25% faster)
3. **Plots**: Python/matplotlib (more flexible)

Example pipeline:
```bash
# 1. Data prep with DuckDB
~/.conda/envs/venv_python312/bin/python Programs/07d_bilateral_pretreatment_prep.py

# 2. Regressions with Stata
module load stata/17
stata-mp -b do Programs/07d_bilateral_pretreatment.do

# 3. Plots with Python
~/.conda/envs/venv_python312/bin/python Programs/07d_bilateral_pretreatment_coefplot.py
```

## ⚠️ Stata Coding Rules — MUST FOLLOW

### cap drop: ONE variable per line — NO EXCEPTIONS

`cap drop x y z` **silently fails** in Stata — only the first variable is dropped.
This is a hard rule. Every `cap drop` must be on its own line, always.

```stata
* WRONG — NEVER DO THIS
cap drop x y z
cap drop treat_year placebo_year
cap drop l_firm_emp_pre4_o l_firm_emp_pre4

* CORRECT — ALWAYS DO THIS
cap drop x
cap drop y
cap drop z
cap drop treat_year
cap drop placebo_year
cap drop l_firm_emp_pre4_o
cap drop l_firm_emp_pre4
```

This has caused real bugs: `cap drop totalflows_pw outflows_pw inflows_pw` silently kept
`totalflows_pw`, causing R²=1.0000 instead of R²≈0.44 in panel regressions.

## Notes on Singleton Fixed Effects

Both Stata reghdfe and pyfixest automatically detect and drop singleton fixed effects (observations where an FE level appears only once). In the bilateral connectivity data, there are typically 2 singleton observations that get dropped.

## Coefficient Plot Formatting Standards

Reference implementation: `Programs/06_bilateral_coefplot_gravity.py`

### Layout
- **No title** on figures (titles added in LaTeX)
- **Legend below graph** with `bbox_to_anchor=(0.5, -0.18)`, `ncol=2`, `frameon=False`
- **Horizontal faded guide lines** at each y-position (`alpha=0.2`)
- **Variables ordered** by univariate coefficient size (smallest at top, largest at bottom)

### Markers & Colors
- **Univariate**: hollow circle (white fill), blue edge (`#2166AC`), `markeredgewidth=2`
- **Multivariate**: filled circle, red (`#B2182B`), `markeredgewidth=1.5`
- Both markers on **same horizontal line** (no vertical offset)

### Coefficient Labels
- Display coefficient value (3 decimal places) next to each marker
- Univariate labels **above** marker (`y + 0.25`)
- Multivariate labels **below** marker (`y - 0.25`)
- Color matches marker color

### Axis Labels
- X-axis: **"Coefficient"** (bold, no "Standardized")
- Y-axis labels: **bold**, no "proximity" suffix, no "Same" prefix

### Variable Label Standards
| Variable | Label |
|----------|-------|
| `z_geo_proximity` | Spatial |
| `z_size_proximity` | Size |
| `z_wage_proximity` | Wage |
| `z_female_proximity` | % Female |
| `z_nonwhite_proximity` | % Non-white |
| `z_educ_proximity` | % Higher ed. |
| `z_hs_proximity` | % High school |
| `z_clauses_proximity` | # CBA clauses |
| `same_microregion` | Microregion |
| `same_union` | Union |
| `same_industry` | Industry |
| `same_industry_micro` | Industry × microregion |

### Figure Size
- `figsize=(8, len(vars) * 0.6 + 1.0)`

### Example Code
```python
# Marker with coefficient label
ax.plot(coef, y, marker='o', markersize=9,
        markerfacecolor='white',  # hollow for univariate
        markeredgecolor='#2166AC', markeredgewidth=2)
ax.text(coef, y + 0.25, f'{coef:.3f}',
        ha='center', va='bottom', fontsize=8, color='#2166AC')

# Horizontal guide lines
for i in range(len(vars)):
    ax.axhline(y=i, color='gray', linestyle='-', linewidth=0.5, alpha=0.2)

# Legend below plot
ax.legend(handles=legend_elements, loc='upper center',
          bbox_to_anchor=(0.5, -0.18), ncol=2, frameon=False)
```

## Going-Forward Workflow (Single Canonical Repo)

Single canonical remote: `https://github.com/lgg3230/UnionSpill.git`

Both the cluster and Mac should point to this remote:

```bash
# Verify remote (run on either machine)
git remote -v

# If Mac still points to Replication-Mar-2, update it:
git remote set-url origin https://github.com/lgg3230/UnionSpill.git
```

### Daily workflow

```bash
# Before starting work
git pull origin main

# After writing code
git add Programs/<files>
git commit -m "Description of change"
git push origin main

# After running analysis (Tables, Graphs are now tracked)
git add Tables/ Graphs/
git commit -m "Update outputs: <brief description>"
git push origin main
```

### What is tracked vs ignored

| Path | Tracked? |
|------|----------|
| `Programs/` | Yes — all code |
| `Tables/*.csv`, `Tables/*.tex` | Yes — regression output |
| `Tables/*.zip` | No — archives excluded |
| `Graphs/*.png`, `Graphs/*.pdf` | Yes — figures |
| `Graphs/plots jul 31/*.gph` | No — Stata format excluded |
| `Data/` | No — too large, synced separately via rsync |

### Data sync (one-time, Mac → cluster)

```bash
# From Mac — use --dry-run first to verify
rsync -avz --progress --dry-run \
  ".../Replication-Mar-2/UnionSpill/Data/" \
  lgg3230@kellogg.northwestern.edu:/kellogg/proj/lgg3230/UnionSpill/Data/

# Remove --dry-run when satisfied
```
