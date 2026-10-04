# Recovery of the historical establishment assignment

**Recovered an upstream rule that exactly reproduces the historical 16,472-establishment membership: zero missing and zero additional IDs.** The independent eligibility calculation and the original full-panel program agree. All 29 missing establishments are restored and all 19 additional establishments are excluded. The production pin and protected baselines remain untouched.

| Construction | Establishments | Missing from baseline | Additional to baseline |
|---|---:|---:|---:|
| Preserved 2009–2016 modal reconstruction | 16,462 | 29 | 19 |
| Recovered 2007–2016 worker-mode rule | 16,472 | 0 | 0 |

Across **131,776 baseline establishment-years**, all 12 checked union, filing/coverage-date, eligibility, balance, and treatment fields also match exactly. The geographic CBA key independently matches the published municipality for every baseline establishment. The candidate construction never reads the published membership list or municipality values.

Start with [the membership validation](wide_membership_validation.json) and [the 48-case table](case_recovery_table.md). The exact original October execution file remains unavailable; the recovered rule has direct historical code support and a complete upstream reproduction.

## Rule identified from upstream records

Use the literal RAIS spell eligibility and ranking expressions to select worker–establishment observations. Pool their municipality votes over **2007–2016**, select the most frequent nonmissing municipality within establishment, and choose the smallest numeric municipality on a modal tie. Use that fixed municipality and its state in each 2009–2016 establishment dictionary for firm-CBA matching. Run the existing CBA coverage joins, main-union selection, date aggregation, positive-employment restrictions, and balanced-panel restrictions.

The failing reconstruction pools workers over **2009–2016**. The outcome/balance years do not need to be expanded: the relevant change is the worker window used to assign the geographic CBA key.

The candidate reads full upstream populations, not published IDs or output municipalities. The omitted employer-association fields do not enter the active firm-CBA joins; using-only association records have missing roots, and all 5,523,176 firm-CBA input records have nonmissing roots. Such records therefore cannot create an omitted firm-CBA match. The baseline worker panel was used in an initial diagnostic only. The independent build uses surviving full selected-worker files for 2007–2011 and full raw RAIS for 2012–2016; its annual selected-worker totals match protected annual employment exactly in all ten years. The full dictionaries contain 6,366,774 establishments.

## Historical code and input evidence

- The preserved `Programs/011_rais_to_firm.do` before commit `ecf87cd` starts the worker pool with `worker_estab_2007.dta`, appends 2008–2016, and computes `egen modemun = mode(municipio), minmode`.
- Commit `ecf87cdedea266f2aaefba7e323b4f1d4f5648cd`, dated October 15, 2025, changes the pool to start in 2009 and append 2010–2016. The published artifact was saved October 6, before that change.
- The CBA matching/aggregation suffix is text-identical to the preserved October 2025 code. The sample-selection program differs only in the names of ancillary treatment exports. Neither comparison reveals a competing selection-rule change.
- All **5,523,176 rows and all seven variables** of the surviving September 24, 2025 exploded firm-CBA input match the current input exactly after sorting, including multiplicities. Different file hashes reflect file-level differences, not different substantive records.

The historical RAIS source is a work-in-progress snapshot: its annual loop starts at 2016 and its dictionary-writing block is commented. It is direct evidence for the old pooling rule and its later change, not a recovered October 6 execution log. Original historical geographic dictionaries and a complete October 6 raw-input snapshot remain unavailable. The reconstruction uses identified surviving upstream inputs; it does not claim byte-for-byte recovery of that entire historical run.

## Why the different establishments switch

Every one of the original 48 discrepancies changes geographic assignment under the wider window. All 48 modal assignments are robust to the geographically ambiguous spell choices detected in the extraction. `wide_reconciliation.csv` records the old and recovered municipality, the membership comparison, vote totals, and uncertainty bounds for each establishment. The 19 additional establishments are removed because 12 fail both pre- and post-2012 date requirements, six fail only the pre-2012 requirement, and one fails only the post-2012 requirement. These are reconstructed exclusion mechanisms, not falsely labeled observed historical flags for absent IDs. `discrepancy_worker_votes_by_year.csv` preserves the annual evidence.

Examples of worker votes:

| Establishment | Municipality | 2007–2008 votes | 2009–2016 votes | Consequence for pooled mode |
|---|---:|---:|---:|---|
| 03380763000101 | 522140 | 1,165 | 0 | Wins only when early workers enter the pool |
| 03380763000101 | 355030 | 6 | 85 | Wins in the truncated window |
| 29167442000109 | 330452 | 512 | 0 | Wins only when early workers enter the pool |
| 29167442000109 | 330455 | 32 | 160 | Wins in the truncated window |
| 00297598000203 | 510340 | 18 | 28 | Wider window gives 46 votes |
| 00297598000203 | 510730 | 0 | 30 | Truncated window gives this location the lead |
| 01029312000190 | 353650 | 453 | 495 | Wider window gives 948 votes |
| 01029312000190 | 410180 | 19 | 680 | Truncated window selects this location |

Stata modal tie handling is substantively necessary for missing establishment **02869763005834**: municipality 410580 receives 10 early plus 14 later votes, while 412660 receives 24 later votes. The wider window produces a 24–24 tie; `minmode` selects 410580, the published municipality.

The first two establishments have support for their published municipality only in 2007. An earliest-observed-municipality rule is nevertheless wrong: that hypothesis disagrees with 325 published establishments with early observations. Worker weighting explains why shrinking movers retain an early location while growing movers can acquire a later modal location.

The prior root-level controlled run already traced 01029312000190 from municipality 410180 and union 81.398.794/0001-95 to municipality 353650 and union 46.058.160/0001-92, restoring the qualifying post-2012 contract. The new rule obtains that municipality from upstream worker votes, rather than substituting the observed published value.

## Stata semantics and competing explanations

Small Stata fixtures confirm that numeric missing tenure passes `>1`, all-missing wages can satisfy equality-based rankings, inactive high-hours spells can defeat active lower-hours spells, and multiplication by a zero ranking flag can make zero beat a negative ranked wage. String missing is `""`; a literal `"."` is not string missing. Numeric and string missing sort differently. Missing end dates pass a lower-bound date comparison; the explicit `!missing(file_date)` condition prevents missing filing dates from qualifying.

Fixtures also distinguish `(first)` from `(firstnm)`, show master-variable retention in default merges versus `update`, and reproduce numeric modal tie behavior. These are behavior tests, not evidence that a particular historical merge took place.

In the actual 2009 records for all discrepancy roots, 1,948 rank-2 spell records have missing log wages. One worker–establishment pair has active spells but no rank-1 spell; another reaches rank 1 but not rank 2. None of these roots has an ambiguous geographic rank-2 choice in that year, and reversing municipality order changes zero selected municipalities. Among the 48 discrepancy establishments themselves, there are 249 missing-wage rank-2 spell records (141 in missing establishments and 108 in additional establishments), but neither of those two worker-pair exclusion quirks occurs. The literal ranking quirks are preserved rather than repaired.

Across the full 2012–2016 extraction, conservative vote bounds leave ten potentially order-sensitive pooled municipalities. None of their ten CNPJ roots occurs anywhere in the full firm-CBA input, so none can affect membership in the active firm-CBA pipeline. Two are balanced, which is why simply dropping unbalanced cases would not have been an adequate check. Every published baseline municipality and all 48 discrepancy assignments are robust.

A separate 2009–2016 reconstruction agrees with the existing dictionary for all 5,867,902 assignments outside its nine flagged tie cases. Two differences occur within those nine exceptions; they are not hidden or treated as exact reconstructions. The full 2007–2016 candidate's membership does not depend on their choices.

Earlier May/August sample artifacts still document a distinct 16,462-establishment lineage. They should not be relabeled as the October published assignment. Their existence is compatible with a stale dictionary or different pooling window at an earlier stage; recovering their precise execution history is separate from reproducing the October membership.

## Validation and scope

`wide_membership_validation.json` contains the full-baseline missing/additional counts and published CBA/date/treatment comparisons; every comparison is exact. No case-year among the 48 discrepancies has a nonmissing average filing date and missing end date, so that missing-date comparison quirk does not explain their eligibility changes. `wide_missing_ids.csv` and `wide_additional_ids.csv` keep the two directions separate. The full baseline is read directly from the protected worker parquet during final scoring.

An auxiliary historical-input comparison initially encountered a shared Stata temporary filename. Subsequent jobs use distinct `STATATMP` directories. As an additional integrity check, CBA construction was repeated in an isolated temporary directory: every membership input matches exactly. The final full-population RAIS/CBA merge also matches that independent build and all **30,962,306 upstream establishment-year keys**, employment counts, and annual municipalities. This specifically addresses the collision concern rather than assuming that a process exit code proves a valid run.

This exercise reconstructs geographic CBA linkage and sample membership. The isolated full panel retains raw annual RAIS outcome/geographic fields; it is not presented as a complete replacement for all historical panel variables. Connectivity and spillover coefficients have not been rerun. The production pin remains in place.

The final [recovery manifest](recovery_manifest.json) verifies unchanged hashes for the production pin, protected historical panel, and protected worker baseline, and records code hashes and upstream input provenance.
