# Verifier Submission-Mode Audit: 10 Checks

The verifier runs in two modes. Standard mode (checks 1-4) runs between phase transitions. Submission mode (checks 1-10) runs before journal submission. All checks are pass/fail.

## Standard Checks (Always Run)

### 1. LaTeX Compilation
- Paper compiles cleanly via `latexmk`
- No undefined citations
- Count overfull `\hbox` warnings
- PDF generated successfully

### 2. Script Execution
- All scripts run without errors
- Output files created
- File sizes > 0

### 3. File Integrity
- Every `\input{}` and `\include{}` resolves to an existing file
- Every referenced table in `Tables/` exists
- Every referenced figure in `Graphs/` exists

### 4. Output Freshness
- Output file timestamps match latest script run
- No stale outputs (generated before latest code change)

## Submission Checks (Additional)

### 5. Package Inventory
- All scripts present and numbered sequentially
- Master script exists (runs everything in order)
- No orphan scripts (scripts not called by master)

### 6. Dependency Verification
- R: `renv.lock` or `sessionInfo()` output exists
- Python: `requirements.txt` or `pyproject.toml` exists
- Non-standard packages documented with install instructions

### 7. Data Provenance
- Every dataset has a documented source
- Access instructions for restricted data
- No hardcoded paths
- Data availability statement present

### 8. Execution Verification
- Run master script end-to-end
- Capture all output and errors
- Report runtime

### 9. Output Cross-Reference
- Every table and figure in the paper traced to a specific script
- No orphan outputs (generated but not referenced)
- No missing outputs (referenced but not generated)

### 10. README Completeness (AEA Format)
- Data availability statement
- Computational requirements (software, packages, hardware, runtime)
- Description of programs (numbered, with inputs/outputs)
- Instructions for replication
- List of tables and figures with generating scripts

## Content Invariants Checked

The verifier also enforces these invariants (any violation is FAIL):
- INV-9: `biblatex` + `biber`, not `natbib` + `bibtex`
- INV-10: `hyperref` loaded second-to-last; `cleveref` after
- INV-14: `set.seed()` exactly once at top if stochastic
- INV-15: All packages loaded at top
- INV-16: No absolute paths
- INV-19: No prohibited functions (`setwd()`, `rm(list = ls())`, `install.packages()`, `attach()`)

## Scoring

Pass/fail per check. Binary for aggregation: 0 (any failure) or 100 (all pass). Contributes 5% to weighted overall score.
