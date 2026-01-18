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

## Running the Analysis

### Master File
The main entry point is `Programs/00_master.do`. It controls which programs run via local flags:
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
From the Kellogg cluster:
```bash
stata-mp -b do Programs/00_master.do
```

For optimized parallel processing of RAIS data:
```bash
stata-mp -b do Programs/011_rais_to_firm_parallel.do
```

### MATLAB Connectivity Scripts
Worker flow connectivity matrices are computed in MATLAB. Run from Stata via:
```stata
shell "/software/matlab/R2020b/bin/matlab" -nojvm < "/kellogg/proj/lgg3230/UnionSpill/Programs/connectivity_full_lagos.m"
```

Key MATLAB scripts:
- `connectivity_full_lagos.m`: Full sample connectivity
- `connectivity_treat_lagos.m`: Flows to treated firms
- `connectivity_control_lagos.m`: Flows to control firms

## Pipeline Architecture

1. **011_rais_to_firm.do**: Cleans RAIS data, selects one spell per worker-firm (ranking by hours, wages, random tiebreaker), generates firm-level outcomes (employment, wages, turnover, education composition), collapses to firm level

2. **02_clean_emp_assoc.do**: Cleans employer association data

3. **031_clean_cba.do**: Cleans CBA data, Python scripts (`explode_cba_coverage_*.py`) expand coverage to municipalities

4. **041_merge_cba_rais.do**: Merges CBA and RAIS at firm level, defines treatment status (`treat_ultra`)

5. **05_yearly_employers.do**: Constructs worker flow transition matrices between consecutive years (2007-2011), runs MATLAB connectivity scripts, computes connectivity measures (flows to treated/control/Lagos sample as proportion of total flows)

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

Defined in `00_master.do`:
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
