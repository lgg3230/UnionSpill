# Reference R estimates (test fixtures)

Verbatim copies of `Programs/within_firm_final/output/*.csv`, the coauthor's R
implementation of the revised within-firm specification.

They live here so `03_verify_v2.py` can check the Stata port without reading
that package. They are **fixtures, not output**: regenerate them only when the
reference implementation itself changes, never from our own Stata runs.

Tracked via `git add -f` -- the repo-wide `*.csv` ignore would otherwise skip
them, and a verification harness with no baseline is not a verification harness.
