# Within-Firm Specification Audit

Date: 2026-07-31

Scope: audit the R implementation in `Programs/within_firm_final/` against the
current canonical Stata specification in
`Programs/layer_connectivity/07_within_firm/01_within_firm_estimates.do` and
`01_within_firm_estimates_hw.do`. I did not modify the Stata pipeline or paper
outputs.

## Executive Summary

The coauthor's substantive change is confined to A7's group-level columns
(`within` and `overall`). A6, A8 printed rows, and A7's `firm` / `firm_full`
columns are unchanged at table precision, and the checked-in
`check/reference_stata/*.csv` files are a verbatim numeric copy of the canonical
`Tables/layer_connectivity/07_within_firm/` baseline up to floating export noise.

The key caveat is that "nothing is removed" is not literally true as code. The R
engine replaces some plain fixed effects with nested group-interacted versions
and explicitly drops the now-nested plain terms before estimation. Econometrically
that is a redefinition/refinement rather than omitted identifying variation, but
it is a syntactic removal relative to the old `absorb()` list.

The other important caveat is the A8 unprinted group-row discrepancy. The README
statement is false if `peq` is included: monthly `gender, g1, p90=firm` differs by
0.0021445 for the wage equality p-value and 0.0004438 for the employment equality
p-value. The coefficients themselves differ by at most 7.6e-06 in that row. The
cause is the R-side strict tie convention for group-level quartile bins combined
with the nonlinear p-value calculation. It does not indicate a bug that can touch
printed A8 rows, because printed A8 rows are `col == firm` and use firm-level bins.

`Rscript` is not available in this sandbox, so I could not rerun the R package.
All numeric checks below use the checked-in CSVs, as requested.

## Baseline Confirmation

I compared each current canonical CSV in
`Tables/layer_connectivity/07_within_firm/` to
`Programs/within_firm_final/check/reference_stata/` with one-to-one keys and
matching schemas.

| file | rows | max abs diff | result |
|---|---:|---:|---|
| `a6_group.csv` | 6 | 0 | confirmed identical |
| `a6_partition.csv` | 3 | 0 | confirmed identical |
| `a7.csv` | 24 | 1.50e-15 | confirmed copy/export noise only |
| `a8.csv` | 30 | 8.56e-14 | confirmed copy/export noise only |
| `a6_group_hw.csv` | 6 | 0 | confirmed identical |
| `a6_partition_hw.csv` | 3 | 0 | confirmed identical |
| `a7_hw.csv` | 24 | 2.00e-16 | confirmed copy/export noise only |
| `a8_hw.csv` | 30 | 1.64e-14 | confirmed copy/export noise only |

These are the baseline numbers for the current paper tables. I used the CSVs for
numeric comparison; the PDF is only relevant for table mapping.

## Code-Derived Change List

### Packaging and inputs

- `R/00_config.R:18-30` makes the R package self-contained, using `./data` or
  `WF_DATA`; Stata instead gets paths from wrappers such as
  `Programs/layer_connectivity/07_within_firm/_run_within_firm.do:11-19`.
  This is a packaging change, not an estimating-equation change.
- `R/02_build.R:29-41` reads the standard firm file, renames its legacy
  `totaltreat_pw_n`, and merges `currentconn_overlay_totaltreat.dta`. The Stata
  wrapper reads the current-connectivity overlay firm directory directly
  (`_run_within_firm.do:15`), and the do-file rebuilds
  `totaltreat_pw_norm` from the current `totaltreat_pw_n`
  (`01_within_firm_estimates.do:149-160`; hourly analog
  `01_within_firm_estimates_hw.do:149-160`). This is an implementation route
  difference, not a data-provenance explanation for coefficient differences.
- I spot-checked the provenance note: `Programs/within_firm_final/data/currentconn_overlay_totaltreat.dta`
  and `layer_connectivity_standalone/data/currentconn_overlay_totaltreat.dta`
  have the same md5 (`25b12592be9874082f51b1eecfe6e876`), and no copy appears
  under `Data/`. This is a reproducibility liability to fix separately.

### Connectivity scale

- The current do-files use the firm-level P90 divisor. Monthly Stata computes
  `$P90_FIRM` from untreated balanced-panel firm-year 2009 rows and sets
  `totaltreat_pw_norm = totaltreat_pw_n / $P90_FIRM`
  (`01_within_firm_estimates.do:149-160`), then sets group connectivity as
  `conn = layer_treat_pw_n / $P90_FIRM`
  (`01_within_firm_estimates.do:246-247`). The hourly file does the same at
  `01_within_firm_estimates_hw.do:149-160` and `246-247`.
- R matches this scale in `R/02_build.R:67-74` and `R/02_build.R:124`.
  I find no evidence that this implementation uses the older pooled-group P90
  divisor.

### Bins and tie behavior

- Baseline Stata creates bins with `_pctile` and
  `(__pre>=q1)+(__pre>=q2)+(__pre>=q3)` in
  `01_within_firm_estimates.do:25-52`; hourly is identical at
  `01_within_firm_estimates_hw.do:25-52`.
- R implements the same percentile definition in `R/01_functions.R:19-39`.
- R redefines group-level bin tie placement through a `tie` argument in
  `R/01_functions.R:59-99`, and the engine sets `tie <- "down"` for group
  panels in `R/04_engine.R:75-77`. The firm-level bins keep the default
  non-strict behavior through `R/02_build.R:62-65`. This R-side tie convention
  differs from the Stata ground truth and is documented in `SPEC.md:170-203`.
  It is not a Stata instruction.

### A7 firm columns

- Baseline firm-level A7 uses `identificad`, firm pre-treatment bin-by-year
  effects, and industry/month/microregion-by-year effects
  (`01_within_firm_estimates.do:190-201` and `359-369`; hourly analog
  `01_within_firm_estimates_hw.do:190-201` and `359-369`).
- R keeps the same firm fixed effects in `R/04_engine.R:100-119` and
  `R/04_engine.R:231-249`, with the FE list defined at `R/04_engine.R:13-23`.
  The checked-in R output differs from the old CSV by at most 9.3e-10 across
  A7 firm/firm_full coefficients and standard errors; all counts match.

### A7 group columns: additions/redefinitions/removals

Baseline Stata group A7 uses:

- `within`: `i.firm_layer_id`, plain group pre-treatment bins by year, and
  `i.firm_id#i.year`
  (`01_within_firm_estimates.do:303-313`; hourly analog
  `01_within_firm_estimates_hw.do:303-313`).
- `overall`: `i.firm_layer_id`, plain group pre-treatment bins by year, plus
  plain `industry1_num#year`, `mode_base_month_num#year`, and
  `microregion_num#year`
  (`01_within_firm_estimates.do:303-313`; hourly analog
  `01_within_firm_estimates_hw.do:303-313`).

R changes these columns as follows:

- Added: group-specific industry/month/microregion year paths:
  `layer_id x mode_base_month_num x year`,
  `layer_id x industry1_num x year`, and
  `layer_id x microregion_num x year` (`R/04_engine.R:79-82` and
  `R/04_engine.R:180-181`).
- Redefined: the plain group bin-by-year fixed effects become
  `layer_id x bin x year` for the relevant wage/employment/flow bins
  (`R/04_engine.R:83-84` and `R/04_engine.R:182-184`).
- Removed from the explicit FE list: any plain term fully nested inside the new
  group-interacted terms (`R/04_engine.R:185-191`). This includes the old
  overall geography/sector/month-by-year terms and the old plain group
  bin-by-year terms once redefined.
- Added to `overall` only: firm-level pre-treatment bin-by-year effects
  (`R/04_engine.R:192-199`). The employment outcome omits the wage bin, matching
  the old convention that employment regressions do not include a separate wage
  bin (`R/04_engine.R:193-198`; see also `SPEC.md:111-112`).
- Unchanged: the regressor (`conn x treat_year` / `conn x placebo_year`), initial
  sample condition, placebo window, and clustering. Baseline Stata calls are at
  `01_within_firm_estimates.do:311-312`; R calls are at
  `R/04_engine.R:201-203` and `R/03_estimate.R:139-156`.

### A8

- Printed A8 rows are firm-outcome horse races (`col == firm`) and keep the firm
  FE set from A7 column 1 (`01_within_firm_estimates.do:375-397`; R analog
  `R/04_engine.R:251-279`). They are unchanged at table precision.
- R also computes unprinted group-outcome A8 rows (`col == g1/g2`) in
  `R/04_engine.R:281-300`; Stata baseline computes analogous unprinted rows in
  `01_within_firm_estimates.do:400-419`. These rows use group-level bins and are
  therefore exposed to the R tie convention.

## Claim Audit

| claim | status | finding |
|---|---|---|
| Only A7 `within` and `overall` columns change; A6, A8 and A7 `firm`/`firm_full` are untouched. | CONFIRMED with caveat | Numeric changes at table precision are confined to A7 `within`/`overall`. A8 unprinted `g1/g2` rows differ from Stata in R output, but printed A8 `col == firm` rows are unchanged at table precision. |
| Addition 1: group x industry/microregion/negotiation-month x year replaces plain versions. | CONFIRMED | Implemented in `R/04_engine.R:79-82` and `180-191`. In `within`, these are additions relative to firm-year FE; in `overall`, plain terms are replaced/dropped because nested. |
| Addition 2: group x bin x year replaces bin x year for the three pre-treatment quartile bins. | CONFIRMED | Implemented in `R/04_engine.R:182-184`, with wage bin omitted for employment outcomes per old convention. |
| Addition 3: firm-level bins x year added to `overall`. | CONFIRMED | Implemented in `R/04_engine.R:192-199`. |
| Nothing is removed. | PARTIAL / LITERALLY CONTRADICTED | The R code explicitly drops nested plain terms (`R/04_engine.R:185-191`). Econometrically this is defensible because the new interacted FEs span the plain terms, but it is not literally "nothing removed" relative to the absorb list. |
| Sample / regressor / clustering / placebo window are unchanged. | PARTIAL | The raw `if` condition, regressor, cluster variable, and placebo window are unchanged. The realized estimation sample is not unchanged: singleton dropping reduces A7 group-column `N` by 2.45%-3.52%. |
| Cost is 2.45%-3.52% of observations to singleton dropping. | CONFIRMED | Old-vs-new `N` implies exactly 2.4459%-3.5190% in every monthly/hourly A7 group-column cell. |

## Numeric Old-vs-New A7 Comparison

`old` is canonical Stata baseline in `Tables/layer_connectivity/07_within_firm/`.
`new` is checked-in R output in `Programs/within_firm_final/output/`.
`4dp_move` flags any four-decimal change in `b`, `se`, `bpre`, or `sepre`; the
table reports `b` and `N` as requested.

### Monthly: `a7.csv`

| partition | col | outcome | old_b | new_b | old_N | new_N | sign_flip | 4dp_move |
|---|---|---|---:|---:|---:|---:|---|---|
| edu2 | firm_full | wage | 0.00498747 | 0.00498747 | 32498 | 32498 | no | no |
| gender | firm_full | wage | 0.00498747 | 0.00498747 | 32498 | 32498 | no | no |
| ten2 | firm_full | wage | 0.00498747 | 0.00498747 | 32498 | 32498 | no | no |
| edu2 | firm_full | emp | 0.00084291 | 0.00084291 | 32704 | 32704 | no | no |
| gender | firm_full | emp | 0.00084291 | 0.00084291 | 32704 | 32704 | no | no |
| ten2 | firm_full | emp | 0.00084291 | 0.00084291 | 32704 | 32704 | no | no |
| edu2 | within | wage | -0.00214367 | -0.00317331 | 52458 | 50612 | no | yes |
| edu2 | within | emp | -0.00233526 | -0.01226112 | 52458 | 50612 | no | yes |
| edu2 | overall | wage | 0.00266596 | 0.00280466 | 59391 | 57789 | no | yes |
| edu2 | overall | emp | -0.00515078 | -0.00695750 | 59391 | 57789 | no | yes |
| edu2 | firm | wage | 0.00402087 | 0.00402087 | 29609 | 29609 | no | no |
| edu2 | firm | emp | -0.00012761 | -0.00012761 | 29760 | 29760 | no | no |
| gender | within | wage | 0.00009232 | 0.00197510 | 55358 | 53592 | no | yes |
| gender | within | emp | -0.00236754 | -0.00063364 | 55358 | 53592 | no | yes |
| gender | overall | wage | 0.00255334 | 0.00282086 | 60864 | 59289 | no | yes |
| gender | overall | emp | 0.00162080 | 0.00380255 | 60864 | 59289 | no | yes |
| gender | firm | wage | 0.00433699 | 0.00433699 | 30434 | 30434 | no | no |
| gender | firm | emp | -0.00037692 | -0.00037692 | 30592 | 30592 | no | no |
| ten2 | within | wage | -0.00056918 | 0.00134366 | 56318 | 54650 | yes | yes |
| ten2 | within | emp | -0.00802729 | -0.00376547 | 56318 | 54650 | no | yes |
| ten2 | overall | wage | 0.00006746 | 0.00167802 | 61285 | 59786 | no | yes |
| ten2 | overall | emp | -0.00073969 | 0.00248224 | 61285 | 59786 | yes | yes |
| ten2 | firm | wage | 0.00441882 | 0.00441882 | 32167 | 32167 | no | no |
| ten2 | firm | emp | 0.00105762 | 0.00105762 | 32344 | 32344 | no | no |

### Hourly: `a7_hw.csv`

| partition | col | outcome | old_b | new_b | old_N | new_N | sign_flip | 4dp_move |
|---|---|---|---:|---:|---:|---:|---|---|
| edu2 | firm_full | wage | 0.00654516 | 0.00654516 | 32498 | 32498 | no | no |
| gender | firm_full | wage | 0.00654516 | 0.00654516 | 32498 | 32498 | no | no |
| ten2 | firm_full | wage | 0.00654516 | 0.00654516 | 32498 | 32498 | no | no |
| edu2 | firm_full | emp | 0.00084291 | 0.00084291 | 32704 | 32704 | no | no |
| gender | firm_full | emp | 0.00084291 | 0.00084291 | 32704 | 32704 | no | no |
| ten2 | firm_full | emp | 0.00084291 | 0.00084291 | 32704 | 32704 | no | no |
| edu2 | within | wage | -0.00294040 | -0.00389819 | 52458 | 50612 | no | yes |
| edu2 | within | emp | -0.00233526 | -0.01226112 | 52458 | 50612 | no | yes |
| edu2 | overall | wage | 0.00232736 | 0.00243793 | 59391 | 57789 | no | yes |
| edu2 | overall | emp | -0.00515078 | -0.00695750 | 59391 | 57789 | no | yes |
| edu2 | firm | wage | 0.00597955 | 0.00597955 | 29609 | 29609 | no | no |
| edu2 | firm | emp | -0.00012761 | -0.00012761 | 29760 | 29760 | no | no |
| gender | within | wage | 0.00030164 | 0.00231277 | 55358 | 53592 | no | yes |
| gender | within | emp | -0.00236754 | -0.00063364 | 55358 | 53592 | no | yes |
| gender | overall | wage | 0.00392656 | 0.00462732 | 60864 | 59289 | no | yes |
| gender | overall | emp | 0.00162080 | 0.00380255 | 60864 | 59289 | no | yes |
| gender | firm | wage | 0.00575638 | 0.00575638 | 30434 | 30434 | no | no |
| gender | firm | emp | -0.00037692 | -0.00037692 | 30592 | 30592 | no | no |
| ten2 | within | wage | -0.00329693 | -0.00065411 | 56318 | 54650 | no | yes |
| ten2 | within | emp | -0.00802729 | -0.00376547 | 56318 | 54650 | no | yes |
| ten2 | overall | wage | 0.00015991 | 0.00244986 | 61285 | 59786 | no | yes |
| ten2 | overall | emp | -0.00073969 | 0.00248224 | 61285 | 59786 | yes | yes |
| ten2 | firm | wage | 0.00614630 | 0.00614630 | 32167 | 32167 | no | no |
| ten2 | firm | emp | 0.00105762 | 0.00105762 | 32344 | 32344 | no | no |

### Singleton Cost from Old-vs-New `N`

| partition | col | old_N | new_N | drop | drop_pct |
|---|---|---:|---:|---:|---:|
| edu2 | within | 52458 | 50612 | 1846 | 3.52 |
| edu2 | overall | 59391 | 57789 | 1602 | 2.70 |
| gender | within | 55358 | 53592 | 1766 | 3.19 |
| gender | overall | 60864 | 59289 | 1575 | 2.59 |
| ten2 | within | 56318 | 54650 | 1668 | 2.96 |
| ten2 | overall | 61285 | 59786 | 1499 | 2.45 |

The wage and employment rows have identical drops within each partition/column,
and the monthly/hourly files have the same drops.

## A8 `gender, g1, p90=firm` Discrepancy

The README says unprinted A8 group rows differ from Stata by under 1e-05 in
absolute terms. That is true for the coefficients in the specific monthly
`gender, g1, p90=firm` rows, but false for the equality p-value `peq`.

| outcome | field | old | new | abs diff |
|---|---:|---:|---:|---:|
| wage | `b1` | 0.0002825597 | 0.0002901327 | 0.0000075730 |
| wage | `b2` | -0.0003676923 | -0.0003714332 | 0.0000037409 |
| wage | `peq` | 0.8751974336 | 0.8730528851 | 0.0021445485 |
| emp | `b1` | -0.0026812563 | -0.0026853071 | 0.0000040509 |
| emp | `b2` | 0.0033411979 | 0.0033441103 | 0.0000029124 |
| emp | `peq` | 0.4619945636 | 0.4615507518 | 0.0004438118 |

Cause: the group-output A8 rows use group-level pre-treatment bins. Baseline
Stata assigns cutpoint ties with `>=` (`01_within_firm_estimates.do:45-48` and
`411-415`), while R runs group panels with `tie <- "down"` and strict `>`
(`R/04_engine.R:75-77`; `R/01_functions.R:85-91`). Small coefficient and variance
differences then pass through the nonlinear normal-approximation equality test
(`R/03_estimate.R:168-176`; Stata analog `01_within_firm_estimates.do:102-104`).

Assessment: this does not indicate a bug that can touch printed A8 rows. Printed
A8 rows are `col == firm`, read by the table generator at
`Programs/within_firm_final/scripts/05b_make_tables_within_firm.py:329-386`, and
use firm-level bins and firm outcomes (`R/04_engine.R:251-279`). Printed A8 rows
match the old Stata baseline very closely: max absolute difference is 8.8e-09
for monthly and 2.8e-08 for hourly, both in `peq`.

The documentation should be corrected to say "under 1e-05 for the reported
coefficient/SE fields, but not for `peq`."

## Undocumented or Under-Documented Changes

- The phrase "nothing is removed" under-documents the actual implementation:
  nested plain fixed effects are explicitly removed from the FE list
  (`R/04_engine.R:185-191`). This is harmless for point estimates when nesting is
  exact, and it avoids degrees-of-freedom overcounting, but it should be stated
  as "plain terms are replaced by nested group-interacted terms and omitted."
- The README's A8 unprinted-row verification sentence omits that `peq` can move by
  more than 1e-05. This is a documentation error, not an estimating bug for
  printed rows.
- The package-only location of `currentconn_overlay_totaltreat.dta` is not an
  estimating change, but it is a reproducibility liability: the file exists under
  `Programs/within_firm_final/data/` and `layer_connectivity_standalone/data/`,
  not under canonical `Data/`.

## Econometric Assessment

The group-interacted industry, microregion, and negotiation-month year effects are
defensible if the identifying concern is group-specific exposure to local,
sectoral, or bargaining-calendar shocks. In `within`, these controls are
identified because two groups inside the same firm-year share the firm-year shock
but differ by group. In `overall`, they are a stricter version of the old controls.
The tradeoff is that they absorb more variation and shift the estimand toward
cells with enough group-by-location/year support.

The group-specific pre-treatment bin paths are also defensible. The bins are
pre-treatment controls and are already measured at the firm-group level; allowing
their year paths to differ by group is a natural refinement. The main concern is
not endogeneity, but discreteness/fragility: log group employment has mass points
at small integers, and exact cutpoint ties make R-vs-Stata binning fragile. For
Stata, the old `>=` rule should remain the ground truth.

Adding firm-level pre-treatment bins to `overall` is defensible and arguably
improves comparability with the firm benchmark. These are predetermined
firm-level controls and do not change the regressor or clustering.

Dropping about 3% of observations to singletons is an acceptable price only if it
is reported and checked. Those observations do not identify the coefficient after
the richer fixed effects, and keeping them would not solve the lack of within-FE
support. The risk is not mechanical selection on the realized outcome: the drop is
driven by fixed-effect support and is identical across wage/employment and
monthly/hourly group columns. The real risk is a change in the estimand if thin
group x microregion x year cells are systematically small, rural, low-connectivity,
or otherwise different. Before putting the revised estimates in the paper, I would
run a simple kept-vs-dropped balance table on pre-treatment group employment,
wages, connectivity, firm size, microregion, and group shares. If the dropped cells
are materially different, the new specification remains interpretable but should
be described as estimating effects on the supported connected-cell sample.

## Open Questions Answered

1. Do the tenure-only `a7_ten2.csv` / `a7_hw_ten2.csv` files and
   `_run_tenure_standalone.sh` need updating?

   Yes, if the revised A7 specification is adopted for the canonical pipeline.
   `_run_tenure_standalone.sh:56-64` calls `_run_tenure.do` and
   `_run_tenure_hw.do`, which in turn call the old `01_within_firm_estimates.do`
   and `01_within_firm_estimates_hw.do` with `global partitions "ten2"` and
   `global table_suffix "_ten2"` (`_run_tenure.do:19-30`;
   `_run_tenure_hw.do:19-30`). Therefore the suffixed tenure CSVs would otherwise
   remain on the old spec while the all-partition `a7.csv` / `a7_hw.csv` move to
   the revised spec. A6 and A8 are substantively unchanged, but the tenure route
   should still be regenerated for consistency after approval.

2. Should the paper's Tables 12 and 24 be regenerated now?

   No. The paper should not be touched until the revised numbers are approved.
   The right workflow is: finish the Stata v2 port, write v2 CSVs or otherwise
   keep old CSVs recoverable, run the verification script, review the changed A7
   numbers, then update `UnionSpill-paper/` only after explicit approval.

## Deliverable 2 Gate

This memo is the first deliverable. Per the instruction not to start the port
until the audit is written and read, I have not created `01b_*`, changed wrappers,
overwritten tables, or written the v2 verification script.
