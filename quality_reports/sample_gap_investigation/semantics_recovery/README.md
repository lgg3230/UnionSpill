# Follow-up: wider worker window and Stata semantics

This directory extends the earlier root-level diagnostic investigation. It builds a new candidate from the full upstream establishment population. Published IDs and municipalities are used only in validation scripts, never to construct the candidate dictionary or membership.

Working directory for Stata commands: this directory. Python executable: `/home/lgg3230/.conda/envs/venv_python312/bin/python`. Stata: `/software/Stata/stata17/stata-mp -b do SCRIPT.do`. Inspect log completion markers, not only process exit codes. Give each concurrent Stata process its own existing `STATATMP` directory; for example, create `/tmp/rais_cba_JOB` and launch with `STATATMP=/tmp/rais_cba_JOB /software/Stata/stata17/stata-mp -b do SCRIPT.do`. Sandbox jobs can otherwise share Stata temporary filenames despite being separate processes.

First run `setup_candidate.py` to create isolated directories and input-only symlinks. The case audit uses the earlier package's retained `discrepant_ids.csv` and `reconciliation.csv`.

Reproduce the small/actual-record semantics checks with `stata_semantics.do`, `supplemental_semantics.do`, `extract_raw_2009.do`, and `profile_actual_spells.do`, in that order. Then execute:

1. `worker_early_modes.do`: municipality counts for 2007–2008 from full selected-worker files.
2. `build_full_worker_counts.do`: counts for 2009–2011 from full selected-worker files; 2012–2016 from full raw RAIS using literal production eligibility/ranking. Retains every geographically ambiguous rank-2 spell. No diagnostic ID filtering.
3. `prepare_full_annual.do`: compact projection of the full protected annual RAIS inputs, retaining all establishments and years.
4. `build_wide_dictionary.do`: exact employment-count assertions for all ten years; pooled 2007–2016 municipality votes; numeric minimum on modal ties; conservative ambiguity bounds; full annual CBA dictionaries. No published baseline assignment is read.
5. `validate_current_mode.do`: cross-check against the existing 2009–2016 dictionary. All robust assignments agree; two differences fall inside explicitly flagged tie cases.
6. `audit_wide_dictionary.py`: independent published-municipality comparison, all 48 discrepancy vote histories, and semantics summaries.
7. `uncertain_mode_eligibility.do`: establishes zero full-input firm-CBA root matches for the ten potentially order-sensitive pooled modes.
8. `run_wide_full.do`: exact existing 1020 suffix and unmodified 1030, with isolated globals and full populations through root, union, and establishment operations. Saves the eligible panel after all operations.
9. `verify_cba_build.do`, then `compare_cba_builds.do`, then `verify_full_merge.do`: independent CBA construction in `CBA_verified` with its own temporary directory; equality of all membership inputs; full-population validation of the final RAIS/CBA merge.
10. `independent_eligibility_check.do`: asserts positive employment in every upstream year and applies the exact average-date restriction block after completed CBA root/union operations. For balanced establishments, omitted RAIS-only rows have missing dates and cannot change eligibility. Then `score_wide_candidate.py`: complete baseline scoring, separate missing/additional lists, published CBA/date/treatment comparisons, and agreement with the independent calculation.
11. `extract_wide_case_panels.do`, then `enrich_wide_cases.py`: after the full run, export the 48 cases and their CBA matches, and produce individual inclusion/exclusion explanations and worker-vote windows.
12. `compare_full_historical_cba.do` and `validate_cba_keys.do`: full substantive comparison with the September 2025 exploded CBA input, and nonmissing-root assertions supporting the dictionary projection.
13. `finalize_recovery.py`: successful-log assertions, complete membership/field validation, unchanged protected hashes, and source/output manifest.

Outputs live in `Data/sample_gap_investigation/{semantics_recovery,wide_2007_2016}`. The production pin, protected baseline inputs, and production programs are not modified. The isolated full panel retains raw annual RAIS outcome/geographic fields; this exercise reconstructs CBA linkage and sample membership, not all historical panel variables or connectivity coefficients.

The `historical_*.do` files are source snapshots for comparison, separate from the executable reconstruction sequence.

Historical evidence: `historical_011_before_ecf87cd.do` is extracted from commit `786d43c01a99a076141a27c8ef400146a1a580d3`. Its worker pool starts in 2007. `historical_window_change.patch` records commit `ecf87cdedea266f2aaefba7e323b4f1d4f5648cd` changing it to 2009 on October 15, 2025, after the October 6 published artifact. The preserved script is a work-in-progress snapshot: its annual generation loop starts at 2016 and its dictionary-writing block is commented. It supports the historical window directly but is not a self-contained recovered October 6 execution log.

`stata_semantics.do`, `supplemental_semantics.do`, and `profile_actual_spells.do` distinguish fixture behavior from actual record evidence. Failed append/count-statistic attempts are retained in explicitly named error logs; they did not produce candidate outputs and were corrected before validation.
