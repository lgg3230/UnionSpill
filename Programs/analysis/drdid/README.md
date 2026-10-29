# Doubly robust DiD (Sant'Anna & Zhao 2020)

Re-estimates the paper's main direct and spillover effects with the doubly robust
DiD estimators of the R package [DRDID](https://psantanna.com/DRDID/), through its
Stata port `drdid` (Rios-Avila, Sant'Anna & Naqvi; `ssc install drdid`), next to
TWFE benchmarks that isolate what changes between the two.

| File | Role |
|---|---|
| `3251_drdid.do` → `3252_drdid.do` | wrapper → worker. Writes `Tables/drdid/results_drdid.csv`, `Tables/drdid/overlap_drdid.csv`, `Data/RAIS_aux/drdid_firm_wide.dta` |
| `3253_drdid_crosscheck.R` | re-estimates every pooled 2x2 with R `DRDID` from `drdid_firm_wide.dta`; writes `Tables/drdid/crosscheck_drdid_R.csv` |
| `4350_table_drdid_latex.py` | `Tables/drdid/t_drdid_direct.tex`, `t_drdid_spill.tex`, standalone `drdid_tables.tex` |
| `4360_figure_drdid_es.py` | `Graphs/drdid/es_drdid_<design>[_<outcome>].pdf` |

Run (~10 min): `cd Logs && stata-mp -b do ../Programs/analysis/drdid/3251_drdid.do`,
then `Rscript Programs/analysis/drdid/3253_drdid_crosscheck.R` from the project root.
Quick subsets: set `global DRDID_OUTCOMES` / `global DRDID_DESIGNS` before the wrapper.

## Design

- **2x2s.** DRDID is a two-period estimator, so each estimand is one firm-level 2x2:
  `post` = mean 2012–16 minus mean 2009–11 (the paper's pooled `treat × post`);
  `placebo` = mean 2009–10 minus 2011 (the paper's placebo); `es_t` = year t minus
  2011. Clauses use CBA periods (post: 3–6 vs 1–2; placebo and base: period 1 vs 2).
- **Covariates** (pre-treatment, time-invariant), mirroring the paper's absorbed
  controls: quartiles of the outcome's own 2009–11 mean, of employment and of
  2007–11 flows; CBA base month; **state** and **industry group**
  (`industry1/100`). The paper's microregion (502) × industry1 (261) cells are
  coarsened because 1,175 treated firms sit in microregions with no
  zero-connectivity control: an outcome regression extrapolates there, a
  propensity score is undefined. `nolag` variants drop the outcome's own quartile.
- **Support.** Firms in covariate cells lacking either group are dropped and
  controls with p(X) ≥ 0.995 trimmed (R's default), re-applied inside every 2x2.
- **Designs.** `dA` treated vs zero-connectivity untreated (paper Panel A); `dC`
  treated vs all untreated (paper Panel B); `sAny` untreated with connectivity > 0
  vs = 0; `sT1–3` each tercile of positive connectivity vs = 0. DRDID needs a
  binary treatment, so spillovers are exposure effects; `mean_dose` rows convert
  them to the paper's per-unit (p90-scaled) slope.
- **Benchmarks.** `twfe_paper` reproduces `Tables/pct_tfpw_cc` exactly;
  `twfe_paper_bin` = paper controls, binary D, DRDID sample; `twfe_coarse` = DRDID
  covariates × period.
- **Inference.** Influence-function SEs (clustered by firm). The joint pre-trend
  test is a Wald test on the 2009 and 2010 event-study ATTs using their saved
  influence functions.
- **Convergence.** The improved DR estimator fits the propensity score by inverse
  probability tilting, and `drdid` does not report non-convergence. At a solution,
  tilting balances every covariate exactly, so each `dr_drimp` row has an
  `ipt_imbalance` row (≈1e-8 when converged); above 1e-4 the tables print n.c.

## CSV schema (`results_drdid.csv`)

`design;outcome;estimand;estimator;b;se;p;n_treat;n_ctrl`. `estimand` ∈ `post`,
`placebo`, `es_<period>`, `pretrend_p` (p-value in `b`), `mean_dose` (in `b`).
`estimator` ∈ `twfe_paper`, `twfe_paper_cont`, `twfe_paper_bin`, `twfe_coarse[_nolag]`,
`dr_reg`, `dr_stdipw`, `dr_dripw`, `dr_drimp[_nolag]`, `ipt_imbalance[_nolag]`.

## Fine region/industry variant

`3254_drdid_fine.do` reruns 3252 with the paper's microregion and industry1 as
DRDID covariates (globals `DRDID_GEO`/`DRDID_IND`), outputs in `Tables/drdid_fine/`.
Not usable as an estimator: the improved DR never converges and the control-only
outcome model is rank-deficient (see the project notes). Kept for the record.

## Continuous treatment: Zhang (2026)

ATT(d) for each level d of connectivity (Zhang, *Econometrics Journal* 29:256–276),
untreated establishments only, zero-connectivity establishments as controls.

| File | Role |
|---|---|
| `Zhang/zhang_drdid_cont.py` | the author's code as downloaded (reference; not run) |
| `Zhang/zhang_cdid.py` | his `cdid_panel` as a module, minimal changes listed in its docstring: seeded multipliers shared across d, d-independent nuisances fitted once per fold, single-threaded forests |
| `3261_zhang_cdid.py` | data prep, support screen, estimation → `Tables/drdid/zhang_cdid_att.csv`, `zhang_cdid_support.csv` |
| `4370_figure_zhang_cdid.py` | Figure 2 style → `Graphs/drdid/zhang_cdid[_<outcome>].pdf` |

Run (~3 min, needs scikit-learn and scipy; runs are byte-identical):
`python Programs/analysis/drdid/3261_zhang_cdid.py && python Programs/analysis/drdid/4370_figure_zhang_cdid.py`.
Requires `drdid_firm_wide.dta` from a 3251 run made after 2026-10-19 (it carries `mreg0`, `ind4`).

- **Support screen.** Cells are the levels of the paper's absorbed controls (own-outcome,
  employment and flows quartiles, base month, microregion, industry1). A level is kept if
  it holds ≥1 zero-connectivity firm and ≥1 exposed firm in each tercile of positive
  connectivity, iterated until stable. Keeps ~1,126 of 1,929 controls and ~1,335 of
  2,260 exposed firms.
- **Log-dose kernel.** The kernel runs on log connectivity, so zero-connectivity firms get
  zero kernel weight (on the raw scale, they carry 40–70% of the weight at d ≤ 0.25).
  Bandwidth, grid, folds, forests and bootstrap follow the author.
- **Unfixed author choices** (deliberately left as they are): outcome model fitted on all
  units with a control dummy, not on controls only; bootstrap perturbs the raw score
  without the density correction; P(D=0|X) clipped only at 1e-6.
- **Interpretation.** Under Zhang's conditional parallel trends, each ATT(d) is
  identified, but differences across d are not a dose response (selection across doses;
  Callaway, Goodman-Bacon & Sant'Anna 2024).

## Nonparametric average causal response (ACR)

With a continuous dose, the TWFE coefficient need not equal the average causal
response (Callaway, Goodman-Bacon & Sant'Anna 2025, Sec. 4). Following their recipe as
implemented in Appendix Table C9 of the QJE national-health-insurance paper
(`Docs/ATT/qjag024*`), `3271_np_acr.do` → `3272_np_acr.do` fits E[ΔY | D = d] among
exposed firms (ΔY net of the zero-connectivity mean) and averages its derivative over
them (ACRT^glob), next to TWFE and the binarized DiD (ATT^glob). Output
`Tables/drdid/np_acr.csv`; `4380_table_np_acr_latex.py` → `Tables/drdid/t_np_acr.tex`
(preview `np_acr_table.tex`). ~1 min; needs `drdid_firm_wide.dta` from 3251.

- **A** the paper's code (`npregress series`: polynomial(3), bspline, spline; its own CV
  knots), no covariates.
- **A2** explicit bases (cubic polynomial, cubic B-spline, natural cubic spline) with the
  knot count npregress chose, knots at quantiles; reproduces A exactly for the polynomial
  and B-spline (npregress puts the knot at the median).
- **B** A2's bases plus the main controls absorbed (reghdfe), all untreated firms with a
  1{D>0} indicator (CGBS fn. 9). Its TWFE column reproduces the main spillover estimates.
- Bases are QR-orthonormalized: the raw truncated-power spline columns are collinear on
  this skewed dose and reghdfe silently dropped columns.
- Leave-one-out CV with quantile knots picked 5–6 knots for wages and fit noise in the
  dense low-dose region (ACRs near −0.1), so knot counts follow npregress instead.
