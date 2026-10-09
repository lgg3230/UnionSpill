# `Programs/analysis/` — working guide

For an AI agent (or a person) using this folder to compute statistics from the
analysis data, run the paper's estimators, or add new exercises. 

**Scope.** Everything here reads finished datasets in `Data/` and writes to
`Tables/`, `Graphs/` and `Logs/`.  `Data/` is not under git; it is
shared through OneDrive.

---

## 1. Quick start

1. **Check the environment** (Stata packages, Python, inputs). From a terminal
   inside the project folder:
   ```bash
   stata-mp -b do Programs/analysis/check_setup.do    # writes check_setup.log here
   ```
   or in the Stata GUI: `cd` into the project folder, then
   `do Programs/analysis/check_setup.do`. It prints `FAIL` lines with the exact
   install command for anything missing.
2. **Run one estimator**: run its wrapper (the `xxx1_*.do` file; table in §5).
   - GUI: `do "<project>/Programs/analysis/main_results/3011_pct_tfpw.do"`.
   - Terminal: `cd Logs && stata-mp -b do ../Programs/analysis/main_results/3011_pct_tfpw.do`.
3. **Read results** from the CSV it writes (§5). Every number in the paper's
   tables comes from those CSVs.

No paths need editing. Nothing needs configuring unless a check fails.

---

## 2. Software

| Need                 | Detail |
|---                   |---|
| Stata 17+ (MP/SE)    | every `.do` file. Each wrapper is one fresh Stata process (see §4). |
| Stata packages (SSC) | `reghdfe` + `ftools` (all estimators), `binsreg` (provides `binstest`; linearity only), `coefplot` (event-study graphs), `distinct` (one diagnostic). `ssc install <name>`. |
| Python 3.9+          | `pandas`, `numpy`, `matplotlib` (all table/figure generators). Optional: `pyfixest` (only `rand_inference/4130`), `pymupdf` imported as `fitz` (only `--preview` PDFs). |
| LaTeX (optional)     | `pdflatex`, only for the `--preview` PDFs of the linearity and pure-control-cutoff tables. |

Stata calls Python itself (`shell $python_exe ...`) to turn CSVs into `.tex`.

---

## 3. How paths and executables are found

**Project root (`$root`).** Every wrapper starts with a block that sets `$root`
to the first of: an already-set `$root`; env `UNIONSPILL_ROOT`; the nearest
folder at or above Stata's working directory that contains
`Programs/0000_master.do`; the root remembered in `~/.unionspill_root` by the
last successful run. So: start Stata anywhere inside the project, or anywhere at
all once any wrapper/`check_setup.do` has run once. If none works it stops with
`Project root not found` (fix: `cd` into the project once).

**Shared setup.** After setting its globals, every wrapper (and the master) runs
`Programs/analysis/_setup.do`, which
1. writes `$root` to `~/.unionspill_root`;
2. sets `$python_exe`: env `UNIONSPILL_PYTHON` if set, else the first interpreter
   that can import pandas, numpy and matplotlib among conda/miniconda/anaconda/
   miniforge installs and envs, Homebrew, the python.org framework, `python3` on
   the PATH, `/usr/bin/python3` (Windows: Anaconda/Miniconda, python.org
   installs, `where python`). Interpreters inside OneDrive/CloudStorage are
   skipped on purpose: a OneDrive-synced virtualenv can hang on import;
3. creates `$tables`, `$graphs`, `$logs` and missing parents.

**Python scripts** (`4xxx_*.py`) locate the project from their own file path
(`Path(__file__).resolve().parents[3]`), so they run from any working directory.

**Environment overrides** (all optional): `UNIONSPILL_ROOT`, `UNIONSPILL_PYTHON`;
master only: `UNIONSPILL_STATA`, `UNIONSPILL_MATLAB`, `UNIONSPILL_RAIS`.

**Batch-mode caveat.** `stata-mp -b do "<path>"` splits the path at spaces even
when quoted. Run batch jobs from inside the project with a relative path (as the
master does: `cd Logs && stata-mp -b do ../Programs/...`). The batch log
`<wrapper>.log` lands in the working directory; the worker also writes its own
timestamped log under `$logs/<topic>/`. The Stata GUI's `do "<full path>"` has
no such problem.

---

## 4. Conventions

- **Wrapper/worker pairs.** `NNN1_name.do` (wrapper) sets globals, then
  `do`es `NNN2_name.do` (worker), which holds the specification. Run wrappers,
  not workers. Globals a worker relies on: `$rais_firm` (`Data/CBA_RAIS_firm_level`),
  `$rais_aux` (`Data/RAIS_aux`), `$tables`, `$graphs`, `$logs`, `$programs`
  (`Programs`), `$python_exe`, and for some workers `$OUTVAR`/`$OUTSUF` (outcome
  and CSV suffix; `lr_remdezr_h_w` / `_hw` for hourly wages).
- **Numbering** is dependency order: `30xx–31xx` estimators (Stata), `40xx–42xx`
  table/figure generators (Python, read estimator CSVs), `5010` copies figures to
  the paper.
- **One wrapper per Stata process (master convention).** The master `shell`s a
  fresh `stata-mp -b` per wrapper.
- **Master.** `Programs/0000_master.do`: every stage is a `local <flag> = 0`;
  set it to 1 to run. Tier C flags (`c_*`) run estimator wrappers; tier D flags
  (`d_*`) run Python generators. Tiers A/B are `sample_construction` (out of scope).
- **Result CSVs** are semicolon-separated, values quoted and padded:
  `spec;section;outcome;row_type;value` (some files omit `spec` or add `col`).
  `row_type` ∈ `main`, `main_se`, `pre`, `pre_se`, `n_obs`, `n_estab`,
  `mean_pre`, `pre_pval`. `main`/`pre` carry significance stars
  (*** p<0.01, ** p<0.05, * p<0.10). `mean_pre` = mean of the outcome over
  2009–2011 in that regression's estimation sample. `section` ∈ `direct_A`,
  `direct_B`, `direct_C`, `spill`.
- **Outputs are regenerated, not versioned.** `Tables/**/*.csv` are gitignored;
  rerunning a wrapper overwrites them.

---

## 5. Paper table → code

Run the wrapper; read the CSV. Paths relative to the project root. Hourly =
`lr_remdezr_h_w`, monthly = `lr_remdezr_w`.

| Paper table (label) | Wrapper → worker | CSV(s) | What to read |
|---|---|---|---|
| Direct effects (`tab:direct_connectivity_robust`) | `main_results/3011` → `3012` | `Tables/pct_tfpw_cc/results_direct_panelA_tfpw_07_11_pct.csv`, `..._panelC_...` | paper Panel A = `direct_A`; **paper Panel B = code `direct_C`** (code `direct_B` = connectivity ≤ 0.01, not in the paper). Outcomes `lr_remdezr_h_w`, `lr_remdezr_w`, `l_firm_emp`, `numb_clauses` |
| …equality p-values (last row) | `conn_margins/3021` → `3022` | `Tables/conn_margins/direct_sample_coef_test_currentconn.csv` | `comparison == A_vs_C`, column `p_diff` |
| Spillovers (`tab:spill_main_4tf_out`) | `main_results/3011` → `3012` | `Tables/pct_tfpw_cc/results_spill_tfpw_07_11_pct.csv` | section `spill` |
| CBA composition & value (`tab:spill_clause_decomp`) | `clause_types/3031` → `3032`; col 7: `cba_value/3041` → `3042` | `Tables/currentconn_full/clause_types/results_spill_clause_counts_tfpw_07_11.csv` (`wage_clauses`, `emp_clauses`, `other_clauses`), `..._clause_props_...` (`*_clause_prop`); `Tables/currentconn_full/cba_value/results_spill_cba_value.csv` (`cba_value`) | |
| Residualized hourly wages (`tab:resid_raw_base`) | `main_results/3111` → `residuals/3112` | `Tables/currentconn_full/residuals/results_{direct_panelA,spill}_mincer_currentconn_age_fullrais_rb.csv` | raw = `lr_remdezr_h_w`, residualized = `lr_hourly_resid` |
| Sample descriptives (`tab:descriptive_stats`) | `descriptives/3101` → `3102` | `Tables/currentconn_full/descriptives/descriptive_stats_pretreat.csv` | columns `Treated`, `Untreated`, `Untreated_Zero`. **The wrapper defaults to the estimation-sample version** (`*_estsample.csv`); the paper uses the full sample: set `global EST_SAMPLE_ONLY ""` instead of `"1"`. Paper "High School Degree" = `Prop high school` + `Prop higher ed`. |
| Robustness, hourly wages (`tab:rob_logwages`) | col 1: `3011`; cols 2–3: `robustness/3051` → `3052`; col 4: `robustness/3181` → `3182`; cols 5–6: `robustness/3061` → `3062` | `results_*_tfpw_07_11_pct.csv`; `Tables/currentconn_full/robustness/results_{direct_panelA,spill}_robustness_bins.csv` (spec `tfpw_07_11_pct_bins10`/`_bins20`); `results_demo_controls_hw.csv` (`col == 2`); `results_micro_ind_q_hw.csv` (paper cols 5–6 = specs `dir_mif_q`/`mif_q`, `dir_miw_q`/`miw_q`) | `robustness/4060` assembles all of it into `quality_reports/replication/hourly_variant_currentconn/frag/t_rob_hw.tex` (8 columns; the paper keeps 6) |
| Union controls (`tab:spill_union_4tfpe_4out`) | `robustness/3071` → `3072` | `Tables/currentconn_full/robustness/results_spill_union_controls_hw.csv` | paper cols (1)–(5) = code `col` 1, 5, 7, 6, 8 |
| Employment decomposition (`tab:turnover`) | `turnover/3081` → `3082` | `Tables/currentconn_full/turnover/results_{direct_panelA,spill}_turnover.csv` | `l_total_hours`, `retention_u`, `hiring_rate_u`, `turnover_u` (separation), `quit_rate_u`, `layoff_rate_u` |
| Workforce composition (`tab:composition`) | `composition/3091` → `3092` | `Tables/currentconn_full/composition/results_{direct_panelA,spill}_composition.csv` | `avg_age`, `male_prop`, `white_prop`, `prop_hs_plus` |
| Group-level connectivity descriptives (`tab:layer_desc_full`) | `layer_connectivity/07_within_firm/3131` → `3132` (hourly); monthly-wage row from `3121` → `3122` | `Tables/layer_connectivity/07_within_firm/a6_group_hw_hlogic.csv`, `a6_partition_hw_hlogic.csv`; monthly wage: `a6_group_hlogic.csv` | |
| Group-level spillovers (`tab:group_specs`) | same `3131` | `.../a7_hw_hlogic.csv` | `col` ∈ `firm_full`, `within`, `overall`; `outcome` ∈ `wage`, `emp` |
| Group-specific connectivity (`tab:horse_race`) | same `3131` | `.../a8_hw_hlogic.csv` | rows `col == firm`, `p90 == firm`; `b1`/`b2` = low/high group, `peq` = equality p-value |

The paper's tables were hand-edited in Overleaf (labels, layout, rounding), so
the generated `.tex` files differ in form, not in numbers.

Other estimators in the folder (linearity `314x–317x`, pure-control cutoff
`316x`, randomization inference `415x`) back appendix material or checks.

---

## 6. Inputs (`Data/`)

`check_setup.do` verifies all of these exist. Merge key everywhere: `identificad`,
a 14-character string with leading zeros (CSV inputs are numeric; workers convert
with `tostring identificad, replace format(%014.0f) force`).

| File | Read by | Contents |
|---|---|---|
| `CBA_RAIS_firm_level/lagos_sample_sep24_pct_unionexp_ext_df2.dta` | all estimators; `4120`, `4140` | **The analysis panel.** Establishment × year, 2009–2016, 140,773 rows, 551 variables |
| `RAIS_aux/totalflows_wide_2007_2011.csv` | all estimators | per-worker worker flows by year pair 2007–08 … 2010–11 (`totalflows_pw_07_08` …), one row per establishment; used for the flows control |
| `CBA_RAIS_firm_level/corrected_turnover_sample.csv` | `3012`, `3052`, `3082` | firm-year separations, hires, quit/layoff/retention rates, total hours (~27 MB) |
| `CBA_RAIS_firm_level/avg_age_firm_year.csv` | `3092`, `3102`, `3182` | average worker age, firm-year |
| `CBA_RAIS_firm_level/cba_value_firm_year.csv` | `3042` | wage-equivalent value of CBA clauses, firm-year |
| `CBA_RAIS_firm_level/mincer_residuals_firm_year_age_fullrais_rb.csv` | `3112` (via `3111`) | firm-year mean Mincer residuals (monthly and hourly), cells estimated on all of RAIS |
| `RAIS_aux/totalflows_panel_2009_2016.csv` | `3082` | firm-year total, in- and out-flows and flows to/from treated firms, levels and per worker; `3082` skips the flow outcomes if absent |
| `RAIS_aux/network_degree_full_rais.csv` | `3102` | per establishment: number of connected establishments over 4- and 6-year windows (`n_connected_4yr`, `n_connected_6yr`) |
| `RAIS_aux/connectivity_post_treat_agg.dta` | `3102` | per establishment: post-period flows and flows to/from treated firms, levels and per worker |
| `rand_inference/spill_frame.dta`, `expected_exposure.dta` | `4152`, `4130` | spillover regression frame, and expected connectivity under reassignment of treatment (`mu_C_*`, `mu_D_*`, by stratification) for the recentered design |
| `layer_connectivity/firm_layer_outcomes_{edu2,gender,ten2}.dta` | `3122`, `3132` | group (`layer_id`) × firm × year: `layer_emp`, `lr_remdezr_layer` (log monthly wage), `lr_remdezr_h_layer` (log hourly), hours, age, female and fixed-term shares. Partitions: `edu2` education, `gender`, `ten2` tenure |
| `layer_connectivity/final_measures/firm_layer_connectivity_{edu2,gender,ten2}.dta` | `3122`, `3132` | group × firm: flows to treated firms by year pair 2007–2011 (`layer_treat_pw_*`, `crosstreat_pw_*`, `sametreat_pw_*`) |
| `Docs/fixtures/figure_A2/*.csv` (in git, not `Data/`) | `4080`, `4110` | bilateral-pair regression coefficients. The only numbers not produced by `analysis/`: they come from a pair-level dataset outside this scope |

Ignore the other files and subfolders of `Data/` (`Archive/`, `Main_Results/`,
`winsor/`, older panels): no `analysis/` script reads them.

---

## 7. Computing a statistic with the paper's samples

Reproduce the estimators' definitions exactly, or counts will not match.

| Concept | Definition (variables in the analysis panel) |
|---|---|
| Base sample | `year >= 2009 & lagos_sample_avg == 1 & in_balanced_panel == 1` |
| Directly treated | `treat_ultra == 1` |
| Untreated (spillover sample) | `treat_ultra == 0` (+ base sample) |
| Zero-connectivity untreated | `treat_ultra == 0 & totaltreat_pw_n == 0` |
| Direct-effects sample, paper Panel A | treated ∪ zero-connectivity untreated (code `direct_A`) |
| Direct-effects sample, paper Panel B | treated ∪ all untreated (code `direct_C`) |
| Connectivity (regressor) | `totaltreat_pw_norm = totaltreat_pw_n / p90`, p90 = 90th percentile of `totaltreat_pw_n` among untreated base-sample firms in 2009. **Recompute it**: the panel's stored `totaltreat_pw_norm` is stale |
| Post / placebo | post = `year >= 2012`; placebo regression on `year <= 2011`, `year < 2011` vs 2011 |
| Outcomes | `lr_remdezr_h_w` log hourly wage, `lr_remdezr_w` log monthly (December) wage, `l_firm_emp` log employment, `numb_clauses` CBA clause count |
| Pre-period values | firm mean over 2009–2011 (`egen mean() if inrange(year,2009,2011)`, then `min` within firm) |
| Controls (all × year) | firm FE; `industry1`, `microregion`, `mode_base_month`; quartile bins of pre-period outcome, log pre-period employment, and per-worker flows 2007–2011 (average of the four `totalflows_pw_*` year pairs). Bins are cut on 2009 balanced-panel firms (`egen cut(), group(4)`), then held fixed within firm. SEs clustered by `identificad` |

Stata, from the project folder, e.g. the 2011 mean hourly wage of
zero-connectivity untreated firms:
```stata
use "Data/CBA_RAIS_firm_level/lagos_sample_sep24_pct_unionexp_ext_df2.dta", clear
keep if year >= 2009 & lagos_sample_avg == 1 & in_balanced_panel == 1
sum totaltreat_pw_n if treat_ultra == 0 & year == 2009, detail
gen totaltreat_pw_norm2 = totaltreat_pw_n / r(p90)
sum lr_remdezr_h_w if treat_ultra == 0 & totaltreat_pw_n == 0 & year == 2011
```
Python, from the project folder:
```python
import numpy as np, pandas as pd
p = pd.read_stata("Data/CBA_RAIS_firm_level/lagos_sample_sep24_pct_unionexp_ext_df2.dta",
                  columns=["identificad", "year", "treat_ultra", "lagos_sample_avg",
                           "in_balanced_panel", "totaltreat_pw_n", "lr_remdezr_h_w"])
p = p[(p.year >= 2009) & (p.lagos_sample_avg == 1) & (p.in_balanced_panel == 1)]
x = p.loc[(p.treat_ultra == 0) & (p.year == 2009), "totaltreat_pw_n"]
p90 = np.percentile(x, 90, method="averaged_inverted_cdf")   # = Stata's sum, detail
```
pandas' default `quantile(0.9)` interpolates linearly and differs slightly from
Stata's `summarize, detail`; use the line above to match the estimators.

Counts (2011, base sample): 12,276 treated, 4,196 untreated, 1,932 of them with
zero connectivity.

---

## 8. Adding an exercise

Copy `robustness/3181_demo_controls.do` (wrapper) and `robustness/3182_demo_controls.do`
(worker) as the template:

1. Pick an unused `NNN1`/`NNN2` pair in the right range and a topic folder.
2. Wrapper: keep the root block verbatim, set `$rais_firm`, `$rais_aux`,
   `$tables`, `$graphs`, `$logs`, `$programs` (and `$OUTVAR`/`$OUTSUF` if the
   worker is outcome-parameterized), then `do "$root/Programs/analysis/_setup.do"`,
   then `do` the worker.
3. Worker: copy the data preparation of `3182` (merges, pre-period means, bins,
   connectivity normalization) so samples match the paper; `cap mkdir` any
   `$tables/<sub>` it writes; write results with the same CSV schema (§4).
4. Register it in `Programs/0000_master.do`: a `local c_<name> = 0` flag in
   tier C, and a call `shell cd "$logs" && $stata_exe -b do "../Programs/analysis/<topic>/NNN1_<name>.do"`.
5. If a Python script turns it into a table, read the CSV (never a frozen
   `.tex`), locate the project with `Path(__file__).resolve().parents[3]`, and
   call it from the worker with `shell $python_exe "$programs/analysis/..."`.

---

## 9. Pitfalls

- `Data/RAIS_aux/corrected_turnover_sample.csv` is a 47-byte header-only stub.
  The real file is `Data/CBA_RAIS_firm_level/corrected_turnover_sample.csv`.
- `Docs/fixtures/` (except `figure_A2/`) holds stale copies of old results; never
  compare against it.
- `quality_reports/replication/.../*.orig.tex` are frozen snapshots; no generator
  should read them.
- Folder names are case-sensitive on Linux: `CBA_RAIS_firm_level`, `RAIS_aux`.
- OneDrive may keep `Data/` files online-only; the first read downloads them and
  can be slow.
- Known small differences from the paper's descriptives table: the code counts
  1,932 zero-connectivity establishments (paper: 1,931), and the paper's
  high-school shares are 0.01 higher than `Prop high school + Prop higher ed`.
- The paper's education variance shares in the group-level connectivity
  descriptives are printed as 0.27/0.73; the data give 0.275/0.725.
