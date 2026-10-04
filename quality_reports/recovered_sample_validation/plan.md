# Recovered sample downstream validation

1. Rebuild 2007–2011 worker employer choices and transitions from full upstream selected-worker inputs using literal current 1040 code. No worker or network subsetting to the analysis sample.
2. Recompute connectivity with recovered full-population 1030 flags, preserving its pre-balance destination definition. Compare published firm-level values and published/current-connectivity analysis ingredients separately.
3. Join upstream annual outcomes to recovered membership and compare every available outcome to the historical firm and frozen analysis panels. Rebuild worker outcomes where necessary; do not silently reuse published outcomes as reconstructed data.
4. Run published spillover specifications in fresh Stata processes, isolated output directories. Compare numeric coefficients, standard errors, N and rendered published precision. Use controlled overlays to distinguish connectivity, outcomes and controls if discrepancies remain.

Production pins, protected baseline files and published tables are input-only. Every concurrent Stata job gets a unique STATATMP directory.
