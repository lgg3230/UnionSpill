# Specification

Precise statement of what each regression estimates. `README.md` covers how to
run the package; this file is the reference for what it computes.

---

## 1. Objects produced

| exhibit | unit of observation | file |
|---|---|---|
| Table A6 | establishment × group cell (descriptives, 2009–2011) | `a6_group{,_hw}.csv`, `a6_partition{,_hw}.csv` |
| Table A7 | establishment × group × year | `a7{,_hw}.csv` |
| Table A8 | establishment × year | `a8{,_hw}.csv` |

`_hw` denotes log hourly wages; the unsuffixed files use log monthly wages.
Employment outcomes are identical across the two, since only the wage variable
changes.

Partitions: `edu2` (no high school / high school+), `gender` (female / male),
`ten2` (under 12 months / 12 months or more).

Sample throughout: untreated establishments in the balanced panel
(`treat_ultra == 0`, `in_balanced_panel == 1`, `lagos_sample_avg == 1`),
2009–2016. Standard errors cluster on `identificad`.

Connectivity is scaled so that 1 equals the 90th percentile of the **firm-level**
distribution among untreated balanced-panel establishments in 2009
(`P90_FIRM = 0.02926`). Group connectivity uses the same scale.

Treatment indicators: `treat_year = 1{year >= 2012}`,
`placebo_year = 1{year < 2011}`. The placebo regression runs on `year <= 2011`
only, so it compares 2009–2010 against 2011.

---

## 2. Table A7 — the only revised exhibit

### 2.1 What changed

Three controls are **added** to the two group-level columns. Nothing is removed;
the sample, the regressor, the clustering and the placebo definition are
untouched.

**Addition 1 — the year interactions may differ by worker group.**
`industry × year`, `microregion × year` and `negotiation-month × year` become
`group × industry × year` and so on. The plain versions are then omitted from
the "Overall" column: they are fully nested inside the interacted ones, so
keeping both leaves coefficients unchanged but counts collinear parameters in
the degrees-of-freedom adjustment.

These terms also enter "Within firms". The plain versions never could, because
establishment × year absorbs anything defined at the establishment level, but
the group-interacted versions are identified: the two groups of an
establishment-year share an industry and differ in group.

**Addition 2 — the pre-treatment quartile bins become group-specific.**
The three bins (group wage, group employment, group flows per worker) are
already computed separately for each establishment × group cell; what was common
across groups was their *year path*. Each becomes `group × bin × year`. This is a
refinement rather than an addition, since the interacted term nests the plain
one.

**Addition 3 — the "Overall" column gains the firm-level pre-treatment bins.**
The same wage, employment and flow bins that Table A7 column (1) uses. The
previous specification substituted group-level analogues for these and never
carried the firm-level versions. "Within firms" does not need them:
establishment × year absorbs them.

**Cost.** Addition 1 removes 2.45% to 3.52% of observations through singleton dropping in
the thin `group × microregion × year` cells. Additions 2 and 3 remove none.

### 2.2 Fixed effects, in full

Regressor throughout: `group connectivity × treat_year` (or `× placebo_year`).

**Column (1) and (4), firm-level benchmark** — unchanged, firm × year unit:

```
identificad
firm-wage bin × year        firm-employment bin × year   firm-flow bin × year
industry × year             negotiation-month × year     microregion × year
```

**Columns (2) and (5), "Within firms"** — establishment × group × year unit:

```
establishment × group
group × group-wage bin × year
group × group-employment bin × year
group × group-flow bin × year
establishment × year
group × negotiation-month × year
group × industry × year
group × microregion × year
```

**Columns (3) and (6), "Overall"**:

```
establishment × group
group × group-wage bin × year
group × group-employment bin × year
group × group-flow bin × year
group × negotiation-month × year
group × industry × year
group × microregion × year
firm-wage bin × year        firm-employment bin × year   firm-flow bin × year
```

Employment outcomes drop the wage bin in every column, exactly as before: for an
employment outcome the "outcome bin" and the "size bin" are the same variable.

---

## 3. Tables A6 and A8 — unchanged

Neither is affected. Table A6 is descriptive. Table A8 prints only firm-level
regressions, which have no group dimension, and its fixed effects are the same
as Table A7 column (1). `check/verify.R` confirms both reproduce the original
Stata estimates.

The engine also computes a group-outcome version of the A8 horse race, stored
under `col == "g1"` and `col == "g2"` in `a8{,_hw}.csv`. No table prints these.
They are left in place because they cost nothing to compute.

---

## 4. Translating to Stata

The specification maps onto `reghdfe` without contortion. The additions are
ordinary interacted absorb terms:

```stata
* Within firms, wage outcome
local bins  i.layer_id#i.wage_pre4_layer#i.year        ///
            i.layer_id#i.l_layer_emp_pre4#i.year       ///
            i.layer_id#i.layer_totalflows_pw_pre4#i.year
local fes   i.firm_layer_id `bins' i.firm_id#i.year    ///
            i.layer_id#i.mode_base_month_num#i.year    ///
            i.layer_id#i.industry1_num#i.year          ///
            i.layer_id#i.microregion_num#i.year

reghdfe `y' c.conn#c.treat_year if `cond', absorb(`fes') vce(cluster identificad)
```

```stata
* Overall, wage outcome
local fes   i.firm_layer_id `bins'                     ///
            i.layer_id#i.mode_base_month_num#i.year    ///
            i.layer_id#i.industry1_num#i.year          ///
            i.layer_id#i.microregion_num#i.year        ///
            i.wage_pre4_firm#i.year                    ///
            i.l_firm_emp_pre4#i.year                   ///
            i.totalflows_pw_pre4#i.year
```

Everything else is unchanged: same `_pctile` bins, same `reghdfe` defaults, same
`vce(cluster identificad)`, same iterative singleton dropping.

Two points on the translation:

- Omit the plain `i.industry1_num#i.year`, `i.mode_base_month_num#i.year` and
  `i.microregion_num#i.year` from the "Overall" column once the group-interacted
  versions are in. `reghdfe` would drop them as collinear anyway, but leaving
  them in inflates the reported degrees of freedom.
- Keep the quartile bins exactly as they are, `(x >= q1) + (x >= q2) + (x >= q3)`.
  See below.

### The quartile tie-break: an R-side approximation, not a Stata instruction

`R/02_build.R` takes a `tie` argument controlling whether a value sitting exactly
on a quartile cutpoint goes up or down. It exists to make R approximate Stata.

`l_layer_emp` is the log of a small integer headcount, so its 2009–2011 group
mean lands on identical floating-point values for many cells: 120 establishment
× group cells for education, 253 for gender and 120 for tenure sit *exactly* on
a cutpoint. R and Stata disagree about which side those fall on, by one unit in
the last place of the cutpoint itself.

**In Stata, keep the original `>=` construction.** That is the ground truth, and
changing it there would break the match rather than fix it.

**But be aware this is the largest source of R-versus-Stata disagreement in the
package, and it is not fully resolved.** The strict inequality in R lands much
closer to Stata than the non-strict one, but not exactly. Measured against the
Stata output on the group-outcome rows of A8, which use these bins:

| R convention | max relative difference | max absolute difference |
|---|---|---|
| strict, `>` (used here) | 2.6e-02 | 7.6e-06 |
| non-strict, `>=` | 1.6e-01 | 4.6e-04 |

Under the revised A7 specification the choice matters more than it did under the
original: group coefficients move by up to 4% between the two R conventions,
which is enough to change a printed digit (for example tenure "Within firms"
wages prints 0.0013 under one and 0.0014 under the other). The observation
counts are identical either way, so the sample is not the difference.

The practical implication: when you re-estimate in Stata with `>=`, expect the
group-level columns of A7 to agree with this package at the printed precision
for most cells but not necessarily all. The firm-level columns, A6 and A8 are
unaffected, because their bins are built from continuous variables with no mass
points.

---

## 5. Standard errors

`R/03_estimate.R` reconstructs `reghdfe`'s cluster-robust small-sample
correction, because `fixest` counts degrees of freedom differently. Two rules,
both `reghdfe`'s and both validated against the "Absorbed degrees of freedom"
tables in the original Stata logs:

- a fixed-effect dimension nested within the cluster variable contributes
  nothing (`reghdfe` flags these with `*`);
- every other dimension contributes its level count minus a redundancy. The
  first gives up only the constant. For each later one the redundancy is the
  number of connected components of the bipartite graph it forms with an
  earlier dimension, maximised over earlier dimensions — what `reghdfe` calls a
  mobility group.

The components rule is not optional. A simpler "redundancy equals the number of
years" rule is right for plain `X × year` terms but wrong once a dimension also
carries the group, where the graph splits by (group, year) and the redundancy
doubles.

Validation: the firm-level A7 regression yields absorbed degrees of freedom of
3803, matching the Stata log exactly (31 + 24 + 24 + 1544 + 88 + 2092), with
redundancies 1, 8, 8, 8, 8, 8. The rule also reproduces the redundancy of 16
that `reghdfe` reports for `microregion × year` in the original specification,
which the simpler rule cannot.

None of this arises in Stata, where `reghdfe` does its own accounting.
