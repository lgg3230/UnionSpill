# Reproduce the diagnostic package

Start with [the recovered-rule findings](semantics_recovery/recovery_findings.md) and [the follow-up reproduction instructions](semantics_recovery/README.md). The 2007–2016 worker-weighted municipality rule recovers exactly 16,472 establishments, with zero missing and zero additional IDs. [The 48-case table](semantics_recovery/case_recovery_table.md) explains the original discrepancies.

The sequence below reproduces the earlier D1–D3 diagnostic package. Its original reconstruction blocker is superseded by the follow-up full-population run. Its `finalize.py` refreshes only the earlier package; use `semantics_recovery/finalize_recovery.py` for the recovered rule's validation and manifest.

Run from `/gpfs/kellogg/proj/lgg3230/UnionSpill`, with `/home/lgg3230/.conda/envs/venv_python312/bin/python` as `PYTHON` below. Only report outputs and `Data/sample_gap_investigation/` are written. Never redirect these script globals into production. The directory is a diagnostic workspace; repeat runs overwrite only its own outputs.

Execute sequentially:

1. `PYTHON quality_reports/sample_gap_investigation/compare.py`
2. `PYTHON quality_reports/sample_gap_investigation/extract.py`
3. In the report directory: `/software/Stata/stata17/stata-mp -b do run_modal_cases.do`
4. Back at root: `PYTHON quality_reports/sample_gap_investigation/reconcile.py`
5. `PYTHON quality_reports/sample_gap_investigation/prepare_raw_control.py`
6. In the report directory: `/software/Stata/stata17/stata-mp -b do run_raw_cases.do`
7. Back at root: `PYTHON quality_reports/sample_gap_investigation/control_results.py`
8. `PYTHON quality_reports/sample_gap_investigation/join_details.py`
9. `PYTHON quality_reports/sample_gap_investigation/enrich_cases.py`
10. `PYTHON quality_reports/sample_gap_investigation/prepare_published_control.py`
11. In the report directory: `/software/Stata/stata17/stata-mp -b do run_published_cases.do`
12. Back at root: `PYTHON quality_reports/sample_gap_investigation/published_control_results.py`
13. `PYTHON quality_reports/sample_gap_investigation/older_artifacts.py`
14. `PYTHON quality_reports/sample_gap_investigation/older_membership.py`
15. `PYTHON quality_reports/sample_gap_investigation/fingerprint.py`
16. `PYTHON quality_reports/sample_gap_investigation/finalize.py`

`PYTHON` means the literal interpreter path above, not a required preexisting environment variable. Stata batch process exit codes alone are not sufficient: inspect logs for normal completion and `r(...)` failures. `finalize.py` verifies log completion, unique cases, source-status blanks, complete-set comparisons, and date flags, and writes the manifest/validation results. It also rechecks both published-panel MD5s.

The scripts intentionally avoid rerunning RAIS cleaning, CBA expansion, 1040, regressions, or a full candidate reconstruction. They reuse a full-population mode dictionary and full root dependencies, execute the exact 1020 suffix and unmodified 1030, and score the existing modal set against the entire baseline. None of D1–D3 defines or validates a new full-population historical procedure.

## Main outputs

- `reconciliation.csv`: exactly 48 establishment rows; read identifiers as strings. Historical October exclusion flags for additional IDs are explicitly unavailable. Older May/August flags are separate columns.
- `full_membership_comparison.csv`, `comparison_summary.json`: complete baseline scoring, including the fact that the current live test file is the 16,476-ID variant.
- `legacy_case_panel.csv`, `modal_case_panel.csv`, `raw_control_case_panel.csv`, `published_municipio_case_panel.csv`: observed published versus three isolated diagnostics.
- `raw_municipality_history.csv`: protected annual raw backup, never modal files.
- `baseline_worker_municipality_counts.csv`: supplemental worker-level multiplicity evidence for baseline cases only.
- `cba_matches_modal.csv`, `cba_matches_raw_control.csv`: actual intermediate matched contracts and dates.
- `cba_join_outcomes.csv`: root-related candidate coverage records, contract IDs, dates, and explicit matching outcomes under modal/raw keys. Includes unmatched candidates.
- `published_control_summary.json`: exact 278-establishment / 2,717-row D3 comparison; `published_control_differences.csv` is empty apart from headers.
- `older_membership_summary.json`: August sample plus current balance flags exactly equals preserved modal membership. This is explicitly a mixed-vintage comparison.
- `experiments.md`, `searches.md`, input fingerprints, `run_manifest.json`, `validation.json`: hypotheses, audit trail, limits, software, and verification.

Dates in raw diagnostic CSVs use numeric Stata days since 1960-01-01; `priority_case_chronology.csv` also supplies ISO dates. Empty strings/missing union IDs are normalized consistently for comparisons. The broader published comparison excludes only geography-only rows with blank establishment IDs introduced by 1030's IBGE merge, then asserts one-to-one establishment-year keys.
