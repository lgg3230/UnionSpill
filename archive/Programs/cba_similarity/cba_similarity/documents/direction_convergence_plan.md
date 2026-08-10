# Implementation Plan: Direction-of-Convergence Test for CBA Clause Similarity

## Goal

We currently show that treated and connected untreated firms become more similar in terms of CBA content after the ultractivity reform. However, pairwise similarity is symmetric, so it does not tell us whether:

1. untreated connected firms move toward treated firms;
2. treated firms move toward connected untreated firms;
3. both groups move toward each other;
4. both move toward some common third profile.

This exercise tests **who is moving** by comparing each firm’s post-reform CBA-content vector to a **fixed pre-reform benchmark**.

The main benchmark should be the connected treated firms’ CBA-content vector in `cba_period == 2`, which is the last pre-treatment CBA period. The average pre-treatment CBA vector should be implemented as a robustness check.

---

## 1. Conceptual Design

Each CBA has a vector of clause-category counts:

`x_it = (x_it_1, x_it_2, ..., x_it_K)`

where:

- `i` indexes the  establishment;
- `t` indexes `cba_period`;
- `k` indexes clause categories;
- `x_it_k` is the number of clauses in category `k`.

We want to test whether connected untreated firms move closer to the pre-reform CBA-content profile of their connected treated firms.

---

## 2. Main Benchmark: Connected Treated Firms in `cba_period == 2`

For each untreated firm `i`, construct a weighted average of the `cba_period == 2` CBA vectors of the treated firms it is connected to:

`Benchmark_T_cba2_i = sum_j w_ij_pre * x_T_j2`

where:

- `j` indexes treated firms;
- `w_ij_pre` is the pre-reform worker-flow-based connection weight from untreated firm `i` to treated firm `j`;
- These weights should be the same ones used in the /kellogg/proj/lgg3230/UnionSpill/Programs/cba_similarity/cba_similarity.do code
- weights should sum to 1 within untreated firm `i`;
- `x_T_j2` is treated firm `j`'s clause vector in `cba_period == 2`.

This benchmark is fixed over time for each untreated firm.

---

## 3. Main Outcome

For each untreated firm-period observation, compute similarity between its current CBA vector and its connected-treated benchmark:

`SimilarityToTreatedBenchmark_it = Sim(x_U_it, Benchmark_T_cba2_i)`

Compute this for the following similarity measures:

1. cosine similarity;
2. total variation similarity;
3. Ruzicka similarity;
4. Bray-Curtis similarity.

---

## 4. Recommended Split Between Shares and Counts

The similarity measures should be grouped into two conceptual families.

### 4.1 Composition-only measures

Use clause-category shares:

`share_it_k = clause_count_it_k / total_clauses_it`

Apply these measures to shares:

1. cosine similarity on shares;
2. total variation similarity on shares.

These outcomes test whether the **composition** of CBA content becomes more similar.

### 4.2 Count-vector measures

Use raw clause-category counts:

1. Ruzicka similarity on counts;
2. Bray-Curtis similarity on counts.

These outcomes test whether the **absolute clause-count vectors** become more similar.

---

## 5. Similarity Measures

Let `x` and `y` be two nonnegative vectors of length `K`.

### 5.1 Cosine similarity

`Cosine(x,y) = dot(x,y) / (norm(x) * norm(y))`

Implementation notes:

- undefined if either vector has norm zero;
- main rule: drop observations where either vector is all zeros;
- robustness rule: define zero-zero similarity as 1 and zero-nonzero similarity as 0.

### 5.2 Total variation similarity

For share vectors `s` and `q`:

`TVSimilarity(s,q) = 1 - 0.5 * sum_k abs(s_k - q_k)`

This ranges from 0 to 1.

Implementation notes:

- use only share vectors;
- if total clauses are zero, shares are undefined;
- main rule: drop zero-total observations;
- robustness rule: define zero-zero as 1 and zero-nonzero as 0 if needed.

### 5.3 Ruzicka similarity

For nonnegative count vectors:

`Ruzicka(x,y) = sum_k min(x_k, y_k) / sum_k max(x_k, y_k)`

Implementation notes:

- use raw count vectors;
- if both vectors are zero, denominator is zero;
- main rule: drop zero-zero cases;
- robustness rule: define zero-zero as 1.

### 5.4 Bray-Curtis similarity

`BrayCurtisSimilarity(x,y) = 1 - sum_k abs(x_k - y_k) / sum_k (x_k + y_k)`

Implementation notes:

- use raw count vectors;
- if both vectors are zero, denominator is zero;
- main rule: drop zero-zero cases;
- robustness rule: define zero-zero as 1.

---

## 6. Main Regression: Untreated Firms Moving Toward Treated Benchmark

Run the main specification on untreated firms only.

### 6.1 Regression equation

`Sim(x_U_it, Benchmark_T_cba2_i) = alpha_i + lambda_t + beta * (Connectivity_i x Post_t) + X_i x lambda_t + epsilon_it`

where:

- outcome is similarity to the connected-treated `cba_period == 2` benchmark;
- `alpha_i` are firm / establishment / CBA-unit fixed effects;
- `lambda_t` are CBA-period fixed effects;
- `Connectivity_i` is the pre-reform connectivity measure;
- `Post_t` equals 1 for post-reform CBA periods;
- `X_i x lambda_t` are the same baseline controls interacted with time that we use in the main spillover specification.

### 6.2 Expected sign

The coefficient of interest is `beta`.

If `beta > 0`, then more connected untreated firms become more similar to the pre-reform CBA profile of their connected treated firms.

This is evidence that untreated connected firms are moving toward treated firms.

---

## 7. Dynamic Event-Study Version

Estimate the dynamic version:

`Sim(x_U_it, Benchmark_T_cba2_i) = alpha_i + lambda_t + sum_tau beta_tau * (Connectivity_i x 1[cba_period_t = tau]) + X_i x lambda_t + epsilon_it`

Use `cba_period == 2` as the omitted period.

### 7.1 Interpretation

- Pre-period coefficients should be close to zero if the identifying assumption is plausible.
- Post-period coefficients should be positive if connected untreated firms move toward treated firms after the reform.

---

## 8. Key Direction Check: Similarity to Own Pre-Reform CBA

To show that untreated connected firms are not merely becoming more stable or changing randomly, also compute similarity to their own last pre-treatment CBA:

`SimilarityToOwnPre_it = Sim(x_U_it, x_U_i2)`

Then estimate:

`Sim(x_U_it, x_U_i2) = alpha_i + lambda_t + gamma * (Connectivity_i x Post_t) + X_i x lambda_t + epsilon_it`

Expected pattern:

- `beta > 0` for similarity to connected treated benchmark;
- `gamma < 0` for similarity to own pre-reform benchmark.

That is:

- connected untreated firms become more similar to treated pre-reform profiles;
- connected untreated firms become less similar to their own pre-reform profiles.

This gives stronger evidence of directional movement toward treated-style CBA content.

---

## 9. Mirror Test: Do Treated Firms Move Toward Untreated Firms?

Construct the mirror benchmark for each treated firm `j`.

For each treated firm, compute the weighted average of connected untreated firms’ `cba_period == 2` CBA vectors:

`Benchmark_U_cba2_j = sum_i omega_ji_pre * x_U_i2`

Then compute:

`Sim(x_T_jt, Benchmark_U_cba2_j)`

Run the same type of regression on treated firms.

### 9.1 Mirror regression

`Sim(x_T_jt, Benchmark_U_cba2_j) = alpha_j + lambda_t + delta * Post_t + X_j x lambda_t + epsilon_jt`

If there is a treated-side exposure measure to untreated firms, use:

`Sim(x_T_jt, Benchmark_U_cba2_j) = alpha_j + lambda_t + delta * (ExposureToUntreated_j x Post_t) + X_j x lambda_t + epsilon_jt`

### 9.2 Interpretation

If the untreated-side coefficient is positive but the treated-side mirror coefficient is small, zero, or negative, then convergence is mainly driven by untreated connected firms moving toward treated firms.

---

## 10. Robustness Benchmark: Average Pre-Treatment CBA

Construct a second benchmark using the average pre-treatment CBA vector of connected treated firms.

For each treated firm `j`:

`xbar_T_j_pre = mean over pre-periods of x_T_jtau`

Then for each untreated firm `i`:

`Benchmark_T_preavg_i = sum_j w_ij_pre * xbar_T_j_pre`

Repeat the main analysis using this benchmark.

### 10.1 Interpretation

If results are similar using:

1. `cba_period == 2` benchmark;
2. average pre-treatment benchmark;

then the findings are not driven by idiosyncratic clauses in one pre-reform CBA.

---

## 11. Additional Robustness: `cba_period == 1` Benchmark

As an additional robustness check, construct the treated benchmark using `cba_period == 1`:

`Benchmark_T_cba1_i = sum_j w_ij_pre * x_T_j1`

Repeat the main analysis.

This checks whether the result depends specifically on the last pre-treatment period.

---

## 12. Category-Level Decomposition

After estimating the similarity regressions, decompose which clause categories are driving movement.

For each clause category `k`, estimate among untreated firms:

`x_it_k = alpha_i + lambda_t + beta_k * (Connectivity_i x Post_t) + X_i x lambda_t + epsilon_it`

Also estimate using shares:

`share_it_k = alpha_i + lambda_t + beta_k * (Connectivity_i x Post_t) + X_i x lambda_t + epsilon_it`

Then compare each `beta_k` to the pre-reform treated-minus-untreated gap in that category.

For each category, compute:

`Gap_k = mean_share_T_k_cba2 - mean_share_U_k_cba2`

or, preferably, the connected-weighted gap:

`Gap_ik = Benchmark_T_cba2_share_i_k - own_share_U_i2_k`

Then check whether:

`sign(beta_k) = sign(Gap_k)`

### 12.1 Output table

Create a table with:

- clause category;
- treated-minus-untreated pre-reform gap;
- spillover coefficient on untreated firms;
- whether the direction is consistent with movement toward treated firms.

Example columns:

| Clause category | Pre-reform treated-minus-untreated gap | Spillover effect | Direction consistent? |
|---|---:|---:|---|
| Wages | + | + | Yes |
| Benefits | + | + | Yes |
| Work rules | - | - | Yes |
| Union rights | + | 0 | No/weak |

---

## 13. Data Requirements

Need the following datasets or objects.

### 13.1 CBA clause-category panel

Required variables:

- firm / establishment / CBA-unit ID;
- `cba_period`;
- treatment indicator, e.g. `treat_ultra`;
- clause-category counts, one variable per category;
- total number of clauses;
- any controls used in the main CBA specification;
- any fixed-effect variables used in the main CBA specification.

Example clause variables:

- `clause_cat_1`;
- `clause_cat_2`;
- ...
- `clause_cat_K`.

### 13.2 Connectivity / pairwise flow dataset

Required variables:

- untreated firm ID;
- treated firm ID;
- pre-reform worker-flow weight or raw flow;
- connectivity measure.

Need to construct normalized weights:

`w_ij_pre = flow_ij_pre / sum_j flow_ij_pre`

for each untreated firm `i`.

For the mirror exercise, construct:

`omega_ji_pre = flow_ij_pre / sum_i flow_ij_pre`

for each treated firm `j`.

---

## 14. Implementation Steps

### Step 1: Load CBA clause panel

Load the firm-period CBA panel with clause-category counts.

Confirm that each firm-period has at most one observation.

Check uniqueness with:

`isid firm_id cba_period`

or equivalent.

### Step 2: Define clause-category count vector

Create a local/list of all clause-category count variables.

Example Stata local:

`local clause_vars clause_cat_1 clause_cat_2 clause_cat_3 clause_cat_4 clause_cat_5 clause_cat_6 clause_cat_7 clause_cat_8 clause_cat_9 clause_cat_10 clause_cat_11`

Adjust variable names to the actual data.

### Step 3: Create total clauses and shares

For each firm-period:

`total_clauses_it = sum_k clause_cat_it_k`

Then create shares:

`share_cat_it_k = clause_cat_it_k / total_clauses_it`

Implementation rule:

- if `total_clauses == 0`, set shares to missing in the main specification;
- keep an indicator `zero_clause_vector = total_clauses == 0`.

### Step 4: Build treated benchmark using `cba_period == 2`

Keep treated firms in `cba_period == 2`.

For each treated firm `j`, keep:

- treated firm ID;
- count vector;
- share vector.

Rename variables to benchmark-source names, e.g.:

- `t_clause_cat_1_cba2`;
- ...
- `t_share_cat_1_cba2`;
- ...

### Step 5: Merge treated benchmark into pairwise connectivity data

the weights shoudl follow the construction implemented in /kellogg/proj/lgg3230/UnionSpill/Programs/cba_similarity/cba_similarity_prep.py

### Step 6: Construct untreated-level connected-treated benchmark

For each untreated firm `i`, compute the weighted average of connected treated firms’ clause vectors.

For each clause category `k`:

`bench_T_cba2_count_i_k = sum_j w_ij * clause_j2_k`

And for shares:

`bench_T_cba2_share_i_k = sum_j w_ij * share_j2_k`

Collapse to untreated firm level.

The resulting benchmark dataset should have one observation per untreated firm ID.

Variables:

- `firm_id`;
- `bench_T_cba2_count_1`, ..., `bench_T_cba2_count_K`;
- `bench_T_cba2_share_1`, ..., `bench_T_cba2_share_K`;
- possibly `num_connected_treated`;
- possibly `sum_pair_flows`;
- connectivity measure.

### Step 7: Merge benchmark into untreated firm-period panel

Merge the untreated-level benchmark onto the untreated CBA panel by firm ID.

Keep untreated firms only for the main exercise.

Check merge quality:

- number of untreated firms with a valid benchmark;
- number of untreated firms without connected treated firms;
- number of missing benchmark vectors;
- number of zero benchmark vectors.

### Step 8: Compute similarity to connected-treated benchmark

For every untreated firm-period observation, compute:

1. `sim_cosine_to_T_cba2`;
2. `sim_tv_to_T_cba2`;
3. `sim_ruzicka_to_T_cba2`;
4. `sim_braycurtis_to_T_cba2`.

Use:

- shares for cosine and TV;
- counts for Ruzicka and Bray-Curtis.

Main missingness rules:

- cosine missing if current vector or benchmark vector has zero norm;
- TV missing if current shares or benchmark shares missing;
- Ruzicka missing if both current and benchmark count vectors are all zero;
- Bray-Curtis missing if both current and benchmark count vectors are all zero.

Store missingness indicators for diagnostics.

### Step 9: Construct own-pre benchmark

For each untreated firm, extract its own CBA vector in `cba_period == 2`.

Create:

- `own_cba2_count_1`, ..., `own_cba2_count_K`;
- `own_cba2_share_1`, ..., `own_cba2_share_K`.

Merge back to the untreated firm-period panel.

Compute similarity to own pre-reform vector:

1. `sim_cosine_to_own_cba2`;
2. `sim_tv_to_own_cba2`;
3. `sim_ruzicka_to_own_cba2`;
4. `sim_braycurtis_to_own_cba2`.

### Step 10: Define post indicator

Define:

`gen post = cba_period >= 3`

assuming:

- `cba_period == 1` and `cba_period == 2` are pre-reform;
- `cba_period >= 3` are post-reform.

Confirm this matches the existing project convention.

### Step 11: Run main pooled regressions

For each similarity outcome to connected-treated `cba_period == 2` benchmark, estimate:

`reghdfe sim_outcome c.connectivity##i.post [controls interacted with period], absorb(firm_id cba_period [other FE if applicable]) vce(cluster firm_id)`

Important:

- use the same connectivity variable as the main spillover analysis;
- use the same baseline sample restrictions as the existing CBA similarity analysis;
- use the same fixed effects and controls as the main spillover specification whenever possible.

If `post` is collinear with `cba_period` FE, the standalone `post` will be absorbed. The coefficient of interest is:

`1.post#c.connectivity`

### Step 12: Run dynamic event-study regressions

For each similarity outcome:

`reghdfe sim_outcome c.connectivity##ib2.cba_period [controls interacted with period], absorb(firm_id cba_period [other FE if applicable]) vce(cluster firm_id)`

Coefficient of interest:

`c.connectivity#cba_period`

with `cba_period == 2` omitted.

Save coefficients and confidence intervals for event-study figures.

### Step 13: Run own-pre regressions

Repeat pooled and dynamic regressions using the similarity-to-own-pre outcomes.

Expected sign for pooled effect:

`connectivity x post < 0`

This complements the main result:

`similarity to treated benchmark increases, similarity to own pre-reform CBA decreases`

### Step 14: Build average pre-treatment benchmark robustness

For each treated firm, average its clause vectors across all pre-treatment CBA periods.

Main pre-period set:

`cba_period in {1, 2}`

For each treated firm `j` and category `k`:

`avg_pre_count_j_k = mean(x_jtau_k) for tau in {1,2}`

Similarly for shares.

Then repeat Steps 5 to 8 to create:

- `sim_cosine_to_T_preavg`;
- `sim_tv_to_T_preavg`;
- `sim_ruzicka_to_T_preavg`;
- `sim_braycurtis_to_T_preavg`.

Repeat pooled and dynamic regressions.

### Step 15: Build `cba_period == 1` benchmark robustness

For each untreated firm, construct connected-treated benchmark using treated firms’ `cba_period == 1` vectors.

Repeat Steps 4 to 8, replacing `cba_period == 2` with `cba_period == 1`.

Create outcomes:

- `sim_cosine_to_T_cba1`;
- `sim_tv_to_T_cba1`;
- `sim_ruzicka_to_T_cba1`;
- `sim_braycurtis_to_T_cba1`.

Repeat pooled and dynamic regressions.

### Step 16: Mirror exercise for treated firms

Construct the weighted average of connected untreated firms’ `cba_period == 2` CBA vectors for each treated firm.

Use pairwise connectivity data and normalize weights within treated firm:

`omega_ji = flow_ij / sum_i flow_ij`

For each treated firm `j`, compute:

`Benchmark_U_cba2_j = sum_i omega_ji * x_U_i2`

Then merge this benchmark to the treated firm-period panel.

Compute:

- `sim_cosine_to_U_cba2`;
- `sim_tv_to_U_cba2`;
- `sim_ruzicka_to_U_cba2`;
- `sim_braycurtis_to_U_cba2`.

Run mirror regressions on treated firms.

Basic version:

`reghdfe sim_outcome i.post [controls interacted with period], absorb(firm_id cba_period [other FE if applicable]) vce(cluster firm_id)`

If `post` is collinear with period FE, this will not work with period FE. In that case, use either:

1. dynamic event-study without a continuous exposure, if there is identifying variation;
2. treated-side exposure measure interacted with post;
3. descriptive plots of treated firms’ similarity to untreated benchmarks over time.

Preferred version if treated-side exposure exists:

`reghdfe sim_outcome c.exposure_to_untreated##i.post [controls interacted with period], absorb(firm_id cba_period [other FE if applicable]) vce(cluster firm_id)`

---

## 15. Tables to Produce

### Table 1: Main direction-of-convergence test

Sample: untreated firms.

Benchmark: connected treated firms’ `cba_period == 2` vector.

Columns:

1. cosine similarity, shares;
2. total variation similarity, shares;
3. Ruzicka similarity, counts;
4. Bray-Curtis similarity, counts.

Rows:

- `Connectivity x Post`;
- standard error;
- mean dependent variable;
- firm FE;
- CBA-period FE;
- controls x period;
- observations;
- firms.

Expected sign: positive.

### Table 2: Similarity to own pre-reform CBA

Sample: untreated firms.

Benchmark: own `cba_period == 2` vector.

Same four columns.

Expected sign: negative.

### Table 3: Robustness to benchmark definition

Sample: untreated firms.

Show pooled coefficient `Connectivity x Post`.

Panel A: connected treated benchmark from `cba_period == 2`.

Panel B: connected treated benchmark from average pre-treatment CBA.

Panel C: connected treated benchmark from `cba_period == 1`.

Columns:

1. cosine similarity;
2. total variation similarity;
3. Ruzicka similarity;
4. Bray-Curtis similarity.

### Table 4: Mirror test

Sample: treated firms.

Benchmark: connected untreated firms’ `cba_period == 2` vector.

Columns:

1. cosine similarity;
2. total variation similarity;
3. Ruzicka similarity;
4. Bray-Curtis similarity.

Interpretation:

- weak or zero movement here strengthens the interpretation that untreated connected firms are the ones moving.

### Table 5: Clause-category decomposition

Sample: untreated firms.

Rows: clause categories.

Columns:

1. category name;
2. connected treated benchmark minus own pre-reform value;
3. spillover coefficient on category count;
4. spillover coefficient on category share;
5. direction consistent with movement toward treated benchmark.

---

## 16. Figures to Produce

### Figure 1: Event study, similarity to connected treated benchmark

Four panels or four separate figures:

1. cosine similarity;
2. total variation similarity;
3. Ruzicka similarity;
4. Bray-Curtis similarity.

Outcome:

`Sim(x_U_it, Benchmark_T_cba2_i)`

Omitted period: `cba_period == 2`.

Expected pattern:

- flat pre-period;
- positive increase after reform for connected untreated firms.

### Figure 2: Event study, similarity to own pre-reform CBA

Outcome:

`Sim(x_U_it, x_U_i2)`

Omitted period: `cba_period == 2`.

Expected pattern:

- connected firms become less similar to their own pre-reform content after the reform.

### Figure 3: Mirror event study

Outcome:

`Sim(x_T_jt, Benchmark_U_cba2_j)`

Interpretation:

- if there is no comparable increase, treated firms are not the main movers.

---

## 17. Diagnostics and Validations

### 17.1 Benchmark construction diagnostics

Report:

- number of untreated firms with non-missing connected-treated benchmark;
- average number of connected treated firms per untreated firm;
- distribution of total connection weight;
- distribution of benchmark total clauses;
- share of zero benchmark vectors.

### 17.2 Current vector diagnostics

Report by `cba_period`:

- mean total clauses;
- share of zero vectors;
- mean and standard deviation of each similarity outcome;
- number of observations used by each measure.

### 17.3 Weight diagnostics

Check:

`For each untreated firm, sum_j w_ij = 1`

Check:

`For each treated firm in mirror exercise, sum_i omega_ji = 1`

Flag cases where sums differ from 1 due to missing treated/untreated CBA vectors.

### 17.4 Missingness diagnostics

For each similarity measure, report number of missing observations due to:

- zero current vector;
- zero benchmark vector;
- missing CBA vector in benchmark period;
- missing connectivity weights.

---

## 18. Important Interpretation Rules

### 18.1 Main result

If similarity to connected-treated `cba_period == 2` benchmark increases with connectivity after the reform:

`Connected untreated firms move toward the pre-reform content profile of their connected treated counterparts.`

### 18.2 Stronger result

If, at the same time, similarity to own `cba_period == 2` vector falls:

`Connected untreated firms are not merely preserving their old CBA style. They are changing away from their own pre-reform profile and toward treated firms’ pre-reform profile.`

### 18.3 Mirror result

If treated firms do not move toward connected untreated firms:

`The convergence documented in the pairwise similarity analysis is primarily driven by untreated connected firms adjusting toward treated firms, rather than by treated firms adjusting toward untreated firms.`

---

## 19. Preferred Output File Structure

Create a new subfolder under the existing CBA similarity analysis folder.

Suggested structure:

Programs/cba_similarity_direction/
    01_build_clause_vectors.do
    02_build_treated_benchmarks.do
    03_compute_directional_similarity.do
    04_run_directional_regressions.do
    05_make_directional_tables.do
    06_make_directional_figures.do

Data/cba_similarity_direction/
    clause_panel_with_shares.dta
    treated_cba2_benchmark_by_untreated.dta
    treated_preavg_benchmark_by_untreated.dta
    treated_cba1_benchmark_by_untreated.dta
    own_cba2_benchmark_by_untreated.dta
    untreated_directional_similarity_panel.dta
    treated_mirror_similarity_panel.dta

Results/cba_similarity_direction/
    tables/
    figures/
    logs/

---

## 20. Final Deliverables

The coding agent should produce:

1. a cleaned firm-period clause-vector panel with counts and shares;
2. connected-treated `cba_period == 2` benchmark for each untreated firm;
3. connected-treated average-pre benchmark for each untreated firm;
4. connected-treated `cba_period == 1` benchmark for each untreated firm;
5. own-`cba_period == 2` benchmark for each untreated firm;
6. similarity-to-treated-benchmark outcomes;
7. similarity-to-own-pre outcomes;
8. mirror treated-firm similarity outcomes;
9. pooled regression tables;
10. event-study figures;
11. benchmark and missingness diagnostics;
12. category-level decomposition table.

---

## 21. Minimal Success Criteria

The exercise is successful if it can answer:

`Do connected untreated firms become more similar to the fixed pre-reform CBA-content profile of their connected treated firms after the reform?`

The preferred evidence is:

1. Similarity to connected treated `cba_period == 2` benchmark increases after the reform.
2. Similarity to own `cba_period == 2` benchmark decreases after the reform.
3. Treated firms do not show a comparable movement toward connected untreated firms.
4. Category-level changes are in the direction predicted by pre-reform treated-minus-untreated differences.