# Counterfactual-connectivity placebo (direct effect)

A randomization-inference-style robustness exercise for the **direct effect**. It is
a placebo/validation device, not a formally established estimator in the
literature, and the code and notes are written to say so.

## The question

The estimated direct effect rises when the control group is narrowed from all
untreated firms to untreated firms with **zero observed connectivity** to the
treated set:

| Specification | Control firms | Log wages |
|---|---|---|
| Panel C, all controls ("Lorenzo-style" baseline) | 4,196 | 0.0178 (0.0032) |
| Panel A, observed pure controls (zero connectivity) | 1,931 | 0.0262 (0.0049) |

The inflation is +0.0084. Two readings compete:

1. **True spillovers.** Connected controls are contaminated upward by the reform,
   so dropping them widens the treated-control gap. The inflation is then tied to
   the *actual* spillover structure.
2. **Selection/composition.** Zero-connectivity controls are a peculiar subset of
   firms (small, few worker flows). Any rule that selects such a subset would
   inflate the estimate, whatever the connectivity measure it selects on.

The exercise discriminates between them by replacing observed connectivity with
**counterfactual connectivity** generated from treatment permutations, and asking
whether placebo pure-control groups reproduce the inflation. Under reading 1 they
should not; under reading 2 they should.

## Design: what is held fixed, what varies

**Held fixed (the core rule):**

- the **actual treated group** (12,276 firms) and the **actual treatment
  indicator** `treat_ultra` in the regression. The regression's treated group is
  never permuted and treatment assignment is never re-estimated;
- the regression specification: outcome, fixed effects, clustering, weights,
  sample restrictions and event-time structure, identical to
  `Main_Results_pct_tfpw_07_11.do:320-384`;
- the pool of candidate controls: the 4,196 actual untreated balanced firms.

**Varies across draws:**

- **only** the connectivity object used to *classify* controls as pure. Each draw
  reshuffles the treated label, rebuilds counterfactual connectivity
  `C_i(S) = Σ_j W_ij S_j` for every actual control, and reselects the pure-control
  subset from it.

The permutation object is the one already used for the spillover/recentering
exercise (`04_permutation_engine.py`, `07_placebo_diag.py`): the treated label is
reshuffled within CEM strata among the 16,472 balanced firms (12,276 treated
permuted), while the 926 non-balanced treated are held fixed as always-treated
destinations ("option C"). Every draw therefore has 13,202 destinations, as
observed. Connectivity is exactly linear in the destination set, so each draw is
one sparse matrix-vector product.

## The two selection rules

- **Procedure A — counterfactual zero connectivity.** Keep actual controls with
  `C_i(S_p) == 0`. Mirrors the Panel A rule exactly; the set size floats.
- **Procedure B — counterfactual bottom-X%.** Keep the bottom `X` = 1,931/4,196 =
  **46.02%** of actual controls by `C_i(S_p)`, so the placebo control group has
  the same size as the observed one. Ties broken at random within a draw.

## Running it

```bash
P=~/.conda/envs/venv_python312/bin/python
$P Programs/rand_inference/17_direct_cf_placebo.py --R 1000 --scheme intermediate \
      --outcomes lr_remdezr_w lr_remdezr_h_w        # ~65 min (3.8 s/draw)
$P Programs/rand_inference/17b_direct_cf_composition.py --R 1000 --scheme intermediate
$P Programs/rand_inference/18_direct_cf_placebo_report.py --scheme intermediate
```

Inputs are all existing `rand_inference` objects: `spill_frame.dta`,
`flow_weights.parquet`, `firm_keys_2009_ext.csv`. `--scheme` selects the
stratification (`none`, `intermediate`, `fine_vingtile`, `control_match`), copied
verbatim from `07_placebo_diag.py` — including the **correct** 2-digit CNAE
division. (`04_permutation_engine.py` uses `industry1 // 100`, which is wrong:
`industry1` carries an artificial leading "1", see `041_merge_cba_rais.do:169-172`.)

Estimation uses `pyfixest` with the exact main spec, which reproduces the
published `reghdfe` baselines to the printed precision (Panel C 0.01785/0.00318,
Panel A 0.02622/0.00492).

## Outputs

| File | Contents |
|---|---|
| `Data/rand_inference/direct_cf_placebo_<scheme>.npz` | per-draw estimate, SE, N, controls kept, overlap |
| `Tables/rand_inference/direct_cf_placebo_<scheme>.json` | baselines + summary statistics + p-values |
| `Tables/rand_inference/direct_cf_placebo_summary.csv/.tex` | compact headline table |
| `Tables/rand_inference/direct_cf_placebo_dist.csv` | distribution moments, quantiles, p-values |
| `Tables/rand_inference/direct_cf_placebo_diag.csv` | selection diagnostics |
| `Tables/rand_inference/direct_cf_composition_<scheme>.csv` | control-group composition |
| `Graphs/rand_inference/direct_cf_placebo_{A,B}_<outcome>.pdf` | placebo density with baseline and observed-pure lines |

## Validation

Evaluating the W engine **at the observed treated set** must reproduce the
panel-defined Panel A pure-control set. It does: 1,932 W-reconstructed vs 1,931
panel-defined, 1,930 in common, Jaccard 0.998. The counterfactual selection rule
is therefore faithful to the real one.

## Results (R = 1,000)

Log wages (`lr_remdezr_w`); hourly wages give the same picture.

| Scheme | Rule | Placebo mean (sd) | Baseline | Observed pure | Percentile of observed pure | p |
|---|---|---|---|---|---|---|
| intermediate | A | 0.0154 (0.0036) | 0.0178 | 0.0262 | 100.0 | 0.001 |
| intermediate | B | 0.0094 (0.0024) | 0.0178 | 0.0262 | 100.0 | 0.001 |
| none | A | 0.0169 (0.0036) | 0.0178 | 0.0262 | 99.1 | 0.010 |
| none | B | 0.0122 (0.0024) | 0.0178 | 0.0262 | 100.0 | 0.001 |

The observed pure-control estimate exceeds every one of the 1,000 placebo draws in
three of the four cells (99.1st percentile in the fourth). The Procedure A placebo
distribution centres close to the baseline (0.0169 vs 0.0178 unstratified; 0.0154
vs 0.0178 stratified), which is the pattern the exercise was designed to look for:
reclassifying pure controls on counterfactual connectivity reproduces the baseline
direct effect, not the observed inflation.

One asymmetry to state honestly rather than smooth over: the placebo distributions
sit slightly *below* the baseline, most of all for Procedure B (0.0094 vs 0.0178).
So the gap between the observed pure-control estimate and the placebo distribution
is not purely the observed estimate being pushed up; placebo selection also pushes
estimates down. For Procedure B, the composition table shows why -- see below.

## How to read the distribution

The reference point is the **observed pure-control estimate** (Panel A). The
reported `p_upper` is the share of draws whose placebo estimate weakly exceeds it.
A small p-value says the observed inflation is unusual relative to placebo control
selections, supporting the spillover reading.

**Read the p-value together with the diagnostics, not on its own.** Two facts
limit what it can carry:

1. **856 of the 4,196 controls have no flow edge to any analysis-sample firm.**
   They are counterfactual-zero in *every* draw, so they sit in every Procedure A
   placebo set. The placebo sets are not independent of the observed one: mean
   overlap is 0.93 for Procedure A and 0.62 for Procedure B.
2. **Neither placebo rule reproduces the composition of the observed pure-control
   group** (see the composition table). Procedure A keeps ~1,200 near-isolated
   firms averaging 19 employees, against 22 for the observed pure controls and 151
   for all controls; Procedure B hits the target size of 1,931 but averages 163
   employees, because connectivity is normalised per worker and large firms
   mechanically rank low on it.

Point 2 is the main threat to the interpretation and should be stated in the
paper. It does not run in a single direction: Procedure A is *more* extreme than
the observed pure-control group on exactly the margins the selection story
invokes (smaller, more isolated firms), so its failure to reproduce the inflation
is evidence against a purely compositional account rather than for it. Procedure
B's composition, by contrast, differs from the observed pure-control group in a
way that is not obviously conservative, so it is best read as a size-matched
companion to A rather than as a stand-alone test.
