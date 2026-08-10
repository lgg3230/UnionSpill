# Within-firm exhibits — Tables A6, A7 and A8

Self-contained package. It bundles its own data and depends on nothing outside
this folder.

Table A7 is estimated with three added controls; Tables A6 and A8 are unchanged
and reproduce the original Stata estimates. `SPEC.md` states the specification
precisely, including the Stata translation.

---

## Run it

```bash
cd within_firm_final

Rscript run_all.R                                # ~1 min  -> output/*.csv
python3 scripts/05b_make_tables_within_firm.py   #         -> output/*.tex
python3 scripts/build_pdf.py                     #         -> tables_A6_A7_A8.pdf

Rscript check/verify.R                           # optional
```

**Requirements.** R with `data.table`, `fixest`, `haven`, `igraph`. Python 3.9+.
`pdflatex` for the PDF step only.

```r
install.packages(c("data.table", "fixest", "haven", "igraph"))
```

Inputs are read from `./data`. Override with `WF_DATA=/path/to/data` if you
would rather point at your own copies.

---

## What is in the folder

```
run_all.R                    entry point
SPEC.md                      the specification, and how to translate it to Stata
R/00_config.R                paths and the .dta reader
R/01_functions.R             Stata-equivalent helpers (percentiles, bins, singletons)
R/02_build.R                 builds the firm and group panels
R/03_estimate.R              reghdfe-equivalent estimation in fixest
R/04_engine.R                the exhibits; mirrors 05a_within_firm_estimates.do
scripts/05b_make_tables_...  your table generator, unmodified
scripts/build_pdf.py         compiles the six fragments into one PDF
check/verify.R               A6 and A8 against the original Stata output
check/reference_stata/       those original CSVs, copied verbatim
data/                        the inputs, copied verbatim (266 MB)
output/                      estimates (.csv) and table fragments (.tex)
tables_A6_A7_A8.pdf          the tables
```

`R/04_engine.R` keeps the section numbering of
`05a_within_firm_estimates.do`, so the two can be read side by side.

---

## The change, in one paragraph

Three controls are added to the two group-level columns of Table A7. Nothing is
removed and the sample, regressor, clustering and placebo definition are
unchanged.

1. **The year interactions may differ by worker group.** `industry × year`,
   `microregion × year` and `negotiation-month × year` become
   `group × industry × year` and so on. These are controls the table already
   had, now permitted to act differently on the two groups. The plain versions
   are omitted once the interacted ones are in, being nested inside them.
2. **The pre-treatment quartile bins become group-specific.** They are already
   computed per establishment × group; only their year path was shared across
   groups. Each becomes `group × bin × year`, which nests the plain term.
3. **The "Overall" column gains the firm-level pre-treatment bins × year** —
   the same wage, employment and flow bins column (1) uses. The previous
   specification substituted group-level analogues and never carried the
   firm-level versions. "Within firms" does not need them, since
   establishment × year absorbs them.

The first costs 2.45% to 3.52% of observations to singleton dropping in the
thin `group × microregion × year` cells; the other two cost none, which was
checked by running the singleton pass with each addition in isolation.

Full fixed-effect lists for every column are in `SPEC.md` §2.2, and the
`reghdfe` syntax is in §4.

---

## Verification

`check/verify.R` compares this package's output against the original Stata
estimates, which ship in `check/reference_stata/`.

| exhibit | result |
|---|---|
| Table A6 (both wage definitions) | max relative difference **1.1e-13** |
| Table A8, printed rows | max relative difference **1.6e-07** |
| Table A7, columns (1) and (4) | max relative difference **3.5e-07** |
| Table A7, group columns | revised specification, no external reference |

All observation and establishment counts match exactly. Columns (1) and (4) of
Table A7 are firm-level regressions and are also untouched by the revision, so
they are checked too.

Table A8's CSV also holds group-outcome rows under `col == "g1"` and
`col == "g2"` that no table prints. Those differ from Stata by up to 2.6e-02 in
relative terms but under 1e-05 in absolute terms; the cause is documented in
`SPEC.md` §4. It does not touch anything printed.

---

## Notes for translating to Stata

`SPEC.md` §4 gives the `reghdfe` calls. The short version: the three additions
are ordinary interacted `absorb()` terms, everything else is untouched, and

- omit the plain `i.industry1_num#i.year`, `i.mode_base_month_num#i.year` and
  `i.microregion_num#i.year` from the "Overall" column once the group-interacted
  versions are in;
- keep the quartile bins exactly as written, `(x >= q1) + (x >= q2) + (x >= q3)`.
  The `tie` argument in `R/02_build.R` has no Stata counterpart: it is an R-side
  approximation to what Stata's `>=` does at the mass points of log group
  employment. **Expect the group columns of A7 to differ slightly between this
  package and your Stata re-run for that reason.** `SPEC.md` §4 quantifies it.
  The firm-level columns, A6 and A8 are unaffected.

Nothing in the specification requires non-standard `reghdfe` options, a changed
tolerance, or any departure from how the original do-file works.
