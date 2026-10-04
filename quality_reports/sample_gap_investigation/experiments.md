# Experiments and evidence register — 2026-09-22

## Diagnostic D1 (specified before execution)

Hypothesis: the preserved modal membership discrepancy is already accounted for by the date eligibility flags in 1030; the unexplained missing establishment fails the post-2012 requirement. Live outputs cannot answer this directly because they now represent the 2009-carried-forward variant (16,476; 84 missing / 88 additional).

Implementation: `extract.py` retains all establishments under the 42 distinct discrepant CNPJ roots, full years 2007–2016, and the complete exploded CBA records for those roots. Modal municipalities come from the existing full-population worker-weighted modal dictionary, never recomputed on the subset. Annual RAIS comes from the protected raw-municipality backup. Run an exact suffix of current 1020, beginning with reading the exploded coverage, then unmodified 1030 in `Data/sample_gap_investigation/modal/`. The full clean CBA source is read through a symlink; it is not modified by this suffix. Employer association fields are not needed by the active firm-agreement joins; sector agreement code is commented out. Root peers and all unions are retained.

Held fixed: existing full-population modal dictionary; cleaned/exploded rebuilt CBA sources; 1020 collapse and union selection; 1030 date/filter code. This reconstructs missing diagnostic intermediates, not historical observations and not a new municipality rule. Expected support: all 48 memberships agree with the preserved modal list, with 28 pre-period failures and the remaining missing establishment failing the post-period rule. Reject/narrow the interpretation if flags or membership disagree.

This diagnostic is not full-baseline candidate validation. The saved complete modal list supplies the existing full-baseline score. No new full reconstruction or regressions are justified by D1 alone.

## Existing experiments (artifact-inspected logs)

- `Logs/full_rerun_2026-09-06/runv_modal_restrict.log`: 1030 endpoint, 131,696 rows / 16,462 IDs; full invocation and original harness source echoed in log. The harness used production paths, so it is unsafe to rerun verbatim. Source file no longer exists at its old path.
- `runv_modal_norestrict.log`, `runv_raw_restrict.log`, `runv_modal_pretreat.log`, `runv_muni2009.log` in the same directory preserve other screens. Their scores are inherited until individually checked below; no rule search repeated.
- `run_may2025_score.log`: shadow paths `Data_may2025/{rais_aux,rais_firm,CBA,emp_assoc}`, successful 1030 endpoint, 16,462 IDs. These shadow outputs no longer survive. `Data_may2025/rais_aux_sep24` is a different directory, not the logged May reconstruction.
- `Logs/verification/churn.log`: modal diagnostic reports 28 pre-period failures, 18 post-period failures, 29 sample failures among missing IDs. Thus the post-period omission in the handoff is already visible in prior evidence, but this log does not name the exceptional ID.
- `Logs/verification/vartest.log`: 162,472 common eligible establishment–years; no year restriction, so 2007–2016. Numeric comparison excludes either-side missing values and uses relative tolerance 1e-6 * max(abs(new),abs(old),1). This is not an A7-only controlled comparison.
- `Logs/verification/basecheck.log`: published eligible panel has 162,760 rows over 2007–2016, 131,776 over 2009–2016, and 16,472 distinct establishments.

A7 variable attribution remains unproven. Membership equivalence from a pre-A7 run does not establish causality for outcome/flow differences. No A7 experiments are run here.

## Diagnostic D2 (specified before execution)

Hypothesis: holding cleaned CBA inputs, aggregation, and RAIS eligibility fixed, replacing only the annual matching municipality/state changes the CBA eligibility of the discrepant establishments. This supplies a case-level controlled contrast missing from mover correlations.

Implementation: after D1 succeeds, copy its isolated annual matching dictionaries, replace `municipio` with each year's protected raw RAIS municipality and recompute `state`, then run the identical 1020 suffix and 1030 with separate outputs in `Data/sample_gap_investigation/raw/`. Retain exactly the same establishments and roots. RAIS records consumed by 1030 are identical to D1. Expected distinguishing result: some/all date flags change with the join keys; unchanged flags identify cases this controlled contrast does not explain.

This revisits raw-per-year assignment only for a new purpose: named case-level causal attribution with identical inputs and intermediate match records. It is not a search for a better rule, and cannot establish the published assignment rule. Its subset membership counts must not be used to score full-sample accuracy. The prior full raw score remains 121 missing / 32 additional (inherited report; full exported ID list not located).

## D3 — observed published municipality (specified before execution)

New evidence: all 29 missing establishments have a constant observed municipality in the published panel, and in every case it differs from the rebuilt worker-weighted mode. Two (`03380763000101`, `29167442000109`) have no such municipality in any protected annual row during 2009–2016; both have it in 2007. Moreover all 29 published values equal the first available raw annual municipality since 2007 (27 in 2007, two first present in 2008). This is newly inspected evidence, not a chosen rule fitted to a coefficient.

D3 will substitute the observed published municipality only where the published panel supplies it, retaining modal values elsewhere, with all other D1 inputs/code fixed. Its purpose is to test whether that observed output field plausibly reflects the missing historical match key and reproduces the published CBA dates/unions for the missing establishments. It is not a complete candidate reconstruction because the additional establishments lack published municipality values.

Before considering an earliest-year candidate, check the observed municipality relationship on other available establishments, not merely the 29 selected failures. A wider year-window or first-record hypothesis is distinguishable from the current 2009–2016 worker mode, but agreement alone is not provenance.

## Final diagnostic results

- **D1:** all 48 memberships match the preserved modal reference. Missing: 11 pre-only failures, 17 pre-and-post failures, one post-only failure (`01029312000190`). All 19 additions pass all reconstructed conditions.
- **D2:** municipality/state changes alone alter membership for 16 missing and 17 additional establishments. Thirteen missing and two additional memberships remain unchanged in this contrast.
- **D3:** published municipality substitution restores all 29 missing establishments. Across 278 published root peers / 2,717 establishment-years, all 12 compared CBA/date/treatment/sample fields agree exactly with the published panel. This does not recover historical input provenance or define keys for the additional establishments.
- **Earliest-year hypothesis screen:** all 29 missing cases' published municipalities equal their first available annual raw municipality since 2007, but 46/278 published root peers fail that equality. No full earliest-year reconstruction was run; the evidence does not establish a general historical rule.
- **Older-artifact comparison:** August 15, 2025 unbalanced sample (17,826 IDs), combined with current RAIS balance flags, gives exactly the modal 16,462-ID set; full-baseline difference remains 29/19. May 6 sample flags also reproduce this direction for all 48 cases. Different date specifications and mixed-vintage balance conditioning are explicit limits, not ignored differences.

No current result demonstrates that A7 caused the membership discrepancy. The earlier sample lineage already exhibits the same 48-case split.


## D4 — independent 2007–2016 worker-mode recovery (2026-09-22)

The wider pooling window reproduces the full historical membership: 16,472 establishments, zero missing, zero additional. All 48 D1 discrepancies are resolved, and all 12 compared CBA/date/treatment/selection fields match across 131,776 baseline establishment-years. This candidate uses full upstream worker counts, all establishment dictionaries and CBA records, the existing 1020 suffix and unmodified 1030. No published ID or municipality is an assignment input. The 2007 window is directly present in preserved source before commit ecf87cd; that commit changes it to 2009. Full historical/current exploded firm-CBA records are substantively identical.

See `semantics_recovery/recovery_findings.md`, `wide_membership_validation.json`, `case_recovery_table.md`, and `recovery_manifest.json` (all in that subdirectory). The exact old execution file remains unavailable; membership and its geographic assignment rule are recovered. The independent CBA rerun and full merge audit address a temporary-filename collision encountered by an auxiliary Stata job. Production and protected baselines remain unchanged.
