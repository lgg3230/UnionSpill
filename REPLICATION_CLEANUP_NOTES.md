# Replication Cleanup Notes

This file records cleanup rules for files that should not be treated as disposable
intermediates while the project is being moved toward a replication-package layout.

## Protected Reference Dataset

Do not delete, overwrite, or regenerate in place:

`Data/CBA_RAIS_firm_level/lagos_sample_sep24_pct_unionexp_ext_df2.dta`

Reason: this is the main analysis dataset currently being used. Its connectivity
measure came from an older patchwork pipeline that has not yet been exactly
reconstructed. It should remain available as the reference target until the
pipeline can reproduce the same connectivity measure.

Recorded metadata:

- Size: 194,200,617 bytes
- Modified: 2026-03-02 17:09:42 -0600
- SHA-256: `9419b1e462e76464bf4ba6c1fea64919c16f1c12e932df8f682292f7640eec67`

Related likely predecessor/sample files, also avoid deleting until the
connectivity reconstruction is resolved:

- `Data/CBA_RAIS_firm_level/lagos_sample_sep24.dta`
- `Data/CBA_RAIS_firm_level/lagos_sample_sep24_str.dta`
- `Data/CBA_RAIS_firm_level/lagos_sample_sep24_test.dta`

## Cleanup Implication

For now, cleanup can target obvious clutter and generated artifacts, but should
not remove datasets used to audit or reverse-engineer the protected file. In
particular, defer deletion of connectivity inputs/outputs under `Data/RAIS_aux`
and firm-level analysis datasets under `Data/CBA_RAIS_firm_level` until their
relationship to the protected file has been checked.
