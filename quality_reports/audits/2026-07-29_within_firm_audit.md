# Audit — Within-Firm Exercises (Tables A6 / A7 / A8)

**Date:** 2026-07-29
**Scope:** `Programs/layer_connectivity/07_within_firm/` and the A6/A7/A8 exhibits in
`UnionSpill-paper/Draft.tex` (`tab:layer_desc_full`, `tab:group_specs`, `tab:horse_race`).
**Anchor:** the paper and its table footnotes, treated as specification.
**Nothing was fixed.** No repo file modified; all re-runs went to scratch.

---

## 0. RESOLVED — the hourly group-level SE anomaly is a base-10 log

Coauthor's note ("Group-level hourly wage standard errors: something is off in Table 23")
correctly identified a real bug and characterized its fingerprint exactly. The cause is not the
variance estimator. **`lr_remdezr_h_layer` is a base-10 log; every other wage variable in the
project is a natural log.**

`06z_prep_outcomes_unified.py:131` (also `06a:71`, `06b:97`):

```sql
AVG(lr_remdezr)                                                      AS lr_remdezr_layer,   -- natural log (precomputed)
AVG(LOG((remdezr / NULLIF(horascontr * 4.348, 0)) / ({ipca_case}))) AS lr_remdezr_h_layer  -- DuckDB LOG() = LOG10
```

**In DuckDB, `LOG(x)` is base-10; `LN(x)` is the natural log.** Verified: `LOG(44)` = 1.643453
= `LOG10(44)`, while `LN(44)` = 3.784190.

So the hourly group wage equals the natural-log version divided by ln(10) = 2.302585, and
**both the coefficient and the standard error are scaled by 1/2.3026** in every hourly
group-level wage cell.

| evidence | value |
|---|---|
| mean monthly/hourly SE ratio across the 6 group wage cells | **2.2967** |
| ln(10) | **2.302585** |
| agreement | 0.3% |
| coauthor's independently measured mean ratio (12 cells incl. pre-trends) | ≈2.30 |

Corroborating: `horascontr` has median and max 44 (weekly contracted hours), yet
`EXP(AVG(LOG(horascontr)))` returns 5.008 — impossible for a natural log, exactly right for
base-10. And `l_layer_emp` uses Python `np.log` (natural), which is precisely why the
**employment columns are unaffected and identical between the two tables.**

### What this does and does not change

**t-statistics and significance are UNAFFECTED.** A common scale factor divides `b` and `se`
alike, so every t-ratio and star in the hourly group-level columns is already correct.

This means the coauthor's §7 conclusion does not follow. Correcting the bug does **not** render
anything insignificant:

- Table 23 Panel B col (3): 0.0017 (0.0009) becomes ≈0.0039 (0.0021) — **still significant at
  10%**, t ≈ 1.9 either way.
- The Panel C tenure pre-trend that fails at 5% **still fails**. It is a real pre-trend in the
  hourly group-level specification, not an artifact of the variance estimator, and cannot be
  dismissed on these grounds.

**What is wrong is every reported magnitude** in those cells: understated by a factor of 2.3.
An hourly semi-elasticity of 0.0017 is really 0.0039.

### Two further points

1. **The uncommitted fix on disk does not fix this.** The working-tree diff changes
   `AVG(LOG(remdezr / NULLIF(horascontr, 0)))` →
   `AVG(LOG((remdezr / NULLIF(horascontr * 4.348, 0)) / ({ipca_case})))`, adding the
   weeks-per-month factor and the IPCA deflator — but **still calls `LOG(`**. The variable stays
   2.3× too small. The one-word fix is `LOG(` → `LN(` in all three builders.
2. **The coauthor is right that 4.348 and the deflator cannot explain the SEs.** Both are
   absorbed: the former is a constant, the latter a pure year effect, and every specification
   carries year-interacted FE. They matter for the *level* of the variable, not its dispersion.
   Confirmed empirically — the monthly−hourly difference has a within-year sd of 0.363, so it is
   not a year effect.

Also ruled out, per their Check 1: clustering is present and correct. The hourly log records
`Number of clusters (identificad) = 4,085`, and the four `vce(cluster identificad)` lines are
byte-identical between the monthly and hourly do-files. **H1 is dead.** H2 (Mincer residual) and
H3 (collapse rule) are also dead — the wage variable is raw, and both averages are taken over
the identical worker set because `remdezr > 0 AND horascontr > 0` gates the whole query.

Their diagnostic reasoning that the driver had to be mechanical and partition-independent was
correct, and is what a base-10 log looks like.

**Scope:** the hourly within-firm tables live in `Main_Results.tex`, not `Draft.tex`, so no
number currently in the Draft is affected.

---

## 0a. Why a log base changes the standard error (the mechanism)

`log10(w) = ln(w) / ln(10) = ln(w) / 2.302585`. So using `LOG()` did not distort the outcome —
it **divided the entire dependent variable by 2.3026**. It is a change of units, nothing more.

In `Y = b·X + FE + e`, replace `Y` with `Y/2.3026`:

| quantity | effect |
|---|---|
| fitted `b` | ÷ 2.3026 (predictions must shrink by the same factor) |
| residuals `e` | ÷ 2.3026 |
| residual sd (Root MSE) | ÷ 2.3026 |
| `SE(b)` ∝ residual sd | **÷ 2.3026** |
| `t = b / SE` | **unchanged** |

The SE is not a pure property of the data — it carries the units of `Y`. Measure the outcome in
cents instead of dollars and every coefficient and SE grows 100×, with no gain or loss of
precision. Here the ruler changed by ln(10).

Concretely: a 10% wage rise is 0.0953 log points but only 0.0414 base-10 log points. Same event,
number 2.3× smaller.

**Direct evidence — Root MSE (the residual sd) from the two logs:**

| cell | monthly | hourly (log10) | ratio |
|---|---|---|---|
| edu2 within | 0.1700 | 0.0653 | 2.60 |
| edu2 overall | 0.1754 | 0.0713 | 2.46 |
| gender within | 0.1608 | 0.0671 | 2.40 |
| ten2 within | 0.2277 | 0.0963 | 2.36 |

The regression was fitting a compressed variable, so every output it produced was compressed.

**Verification run** (scratch, `lr_remdezr_h_layer × ln(10)`, which is exactly the `LOG(`→`LN(`
fix since `log10(x)·ln(10) = ln(x)`):

| cell | b before | b after | ×    | se before | se after | ×    | t before | t after |
|---|---|---|---|---|---|---|---|---|
| edu2 within | −0.001291 | −0.002972 | 2.302 | 0.001708 | 0.003942 | 2.308 | −0.756 | −0.754 |
| edu2 overall | 0.001013 | 0.002332 | 2.301 | 0.000987 | 0.002277 | 2.307 | 1.027 | 1.024 |
| gender within | 0.000120 | 0.000276 | 2.300 | 0.001237 | 0.002856 | 2.309 | 0.097 | 0.097 |
| gender overall | 0.001710 | 0.003937 | 2.302 | 0.000884 | 0.002041 | 2.309 | 1.934 | 1.929 |

Both columns scale by ln(10); t-statistics are unchanged. The coauthor's flagged cell,
0.0017\* → 0.0039\*, **keeps its star**. Column (1) `firm_full` is untouched (0.0066457 both
runs), confirming the firm-level path was never affected.

---

## 0b. Blast radius — where else does `LOG(` appear?

**The bug is exactly 5 lines, all the same expression.** A repo-wide sweep of every uppercase
`LOG(` in Python, plus every lowercase `log(` inside the 38 scripts that use DuckDB (the two
lowercase hits are comments, not SQL):

| # | file:line | status |
|---|---|---|
| 1 | `00_pipeline/06z_prep_outcomes_unified.py:131` | **LIVE** |
| 2 | `00_pipeline/06a_prep_layer_outcomes.py:71` | **LIVE** |
| 3 | `00_pipeline/06b_prep_demog_outcomes.py:97` | **LIVE** |
| 4 | `99_archive/06_prep_layer_outcomes.py:50` | archived |
| 5 | `99_archive/06_prep_demog_outcomes.py:77` | archived |

There is exactly **one** correct `LN(` in the entire repo
(`turnover/_test_ll_totalflows_variation.py:18`) and **no** `LOG10(` anywhere — so there is no
intentional base-10 use to preserve.

### Contaminated data

**All 9 `Data/layer_connectivity/firm_layer_outcomes_*.dta`** files: `edu`, `edu2`,
`edu2_full`, `edu_full`, `gender`, `gender_full`, `race`, `race_full`, `ten2`.

⚠️ **They were all rebuilt today at 13:36, and the hourly variable did not change** (mean
1.6522, sd 0.3276 — identical to the pre-rebuild read). So the rebuild ran the *committed*
formula; the data on disk is still base-10, still nominal, still weekly-hours. Within those
files only `lr_remdezr_h_layer` is affected — `lr_remdezr_layer`, `layer_emp`, `l_layer_emp`,
and `l1p_layer_emp` are all natural logs (precomputed or via `np.log`/`np.log1p`).

### Live consumers

| consumer | reaches the paper? |
|---|---|
| `07_within_firm/01_within_firm_estimates_hw.do` | **YES** — hourly A6/A7/A8 in `Main_Results.tex` (coauthor's Tables 23–24). The only paper-facing exposure. |
| `03_disentangling/` (`01a_disentangle_edu.do`, `01b_disentangle_occ4.do`, `02a_make_table_edu.py`) | no — outputs not in either .tex |
| `05_cross_layer/` (`01_cross_layer.do`, `02_make_table.py`) | no |
| `TEST_layers_balance.do` | no — test harness |
| `99_archive/` (~12 scripts) | no |

### Verified NOT affected

- **`02_spillover/`** — uses the firm-level `lr_remdezr_h_w`, not the layer variable.
- **Firm/worker-level hourly wages** — `011_rais_to_firm_parallel.do:118` and
  `011_rais_to_firm_optimized.do:132` use Stata `log()`, which **is** the natural log;
  `worker_wages/01_prep_data.py:44` uses numpy. This is exactly why the coauthor measured a
  normal 0.96 firm-level SE ratio.
- `educ_premia_fullrais/01:170` (`np.log`), all employment outcomes, all monthly wages.
- All `tab:layer_specs*` references in `Main_Results.tex` are **commented out** (lines 1894,
  1958, 1995, 2050), so the old race-era hourly layer tables are not live.
- The corrupted A6 hourly wage row (`Avg.\ wage & 4 & 5 & …`) does **not** appear in any .tex.

### Three stacked defects in that one expression

As the data currently stands, `lr_remdezr_h_layer` is the base-10 log of *nominal* monthly
earnings divided by *weekly* hours:

1. **base-10 log** → every `b` and `se` 2.3026× too small (t's correct) ← the SE anomaly
2. **no IPCA deflation** → nominal; a pure year effect, absorbed by the year-interacted FE
3. **weekly not monthly hours** (no ×4.348) → a constant, absorbed by the group × firm FE

Evidence: `10^mean` = **44.90** R$/h, i.e. nominal monthly ÷ weekly hours. A correct real hourly
wage is ~12–13 R$/h (2266 / (41.5 × 4.348)).

Only defect 1 affects any estimate. Defects 2 and 3 corrupt the A6 descriptive wage level only.
**The uncommitted working-tree edit fixes 2 and 3 but keeps `LOG(`,** so it leaves the variable
2.3× too small.

### ⚠️ 0b-bis. The applied fix works, but has introduced a NEW blocking bug (2026-07-29 17:31)

The `LOG(` → `LN(` change has been made in all three live builders and the 9 layer files were
rebuilt at 17:29–17:31. **The log base is now correct** — `e^mean` of the hourly variable is
11.68 R$/h (edu2) and 12.21 R$/h (ten2), exactly the plausible real hourly wage, versus the
nonsensical 5.22 before.

**But the same edit also added `/ ({ipca_case})`, and `IPCA` only covers 2007–2011.**

`layer_config.py:168-172` defines `IPCA` for 2007, 2008, 2009, 2010, 2011 — and nothing else.
`ipca_case_sql()` (`06z:38-40`) builds `CASE … ELSE NULL END`, so for 2012–2016 the deflator is
`NULL`, `x / NULL` is `NULL`, `LN(NULL)` is `NULL`, and `AVG` over all-NULL cells returns `NULL`.

Measured on the rebuilt `firm_layer_outcomes_edu2.dta`:

| year | rows | monthly non-missing | hourly non-missing |
|---|---|---|---|
| 2009 | 27,952 | 27,952 | 27,952 (100%) |
| 2010 | 27,936 | 27,936 | 27,936 (100%) |
| 2011 | 27,851 | 27,851 | 27,851 (100%) |
| 2012 | 27,807 | 27,807 | **0** |
| 2013 | 27,753 | 27,753 | **0** |
| 2014 | 27,727 | 27,727 | **0** |
| 2015 | 27,440 | 27,440 | **0** |
| 2016 | 26,974 | 26,974 | **0** |

**The entire post-treatment period is now missing from the hourly layer wage** — 62% of cells
(83,739 of 221,440 survive). The hourly within-firm DiD cannot identify a post-treatment effect
at all in this state. This is also what corrupted my own verification run's `ten2` cells
(b = se = 0, N = 20,768): it read the file mid-rebuild.

The monthly path is immune because `lr_remdezr` is precomputed upstream in
`011c_worker_panel.py:240` with a deflator covering all years.

**Fix:** either extend `IPCA` in `layer_config.py` to 2012–2016, or drop `/ ({ipca_case})` and
deflate the way the monthly variable does. Note that deflation is absorbed by the year-interacted
FE anyway, so it only matters for the A6 descriptive wage level — it is not worth breaking the
panel over.

### Fix sequence

1. `LOG(` → `LN(` in the three live builders (and the two archived ones, for consistency).
2. Rebuild all 9 `firm_layer_outcomes_*.dta`.
3. Re-run `_run_within_firm_hw.do`; regenerate the hourly tables.
4. Expect: all hourly group-level coefficients and SEs ×2.3026; **every t-statistic, star, and
   the tenure pre-trend verdict unchanged.**

---

## 1. Bottom line (monthly A6/A7/A8 — the original audit)

Two separate questions were on the table. They have different answers.

**Q1: Why did the within-firm standard errors fall? — Benign. It is a change of units.**
The divisor moved from the pooled-group 90th percentile to the firm 90th percentile. SEs scale
by exactly that ratio and **every t-statistic is unchanged**. Tenure's 35% drop is the largest
and is entirely scaling. See §3.

**Q2: Is the normalization itself sound? — For A7 yes. For A8 no.** This is the real issue, and
my first pass got it wrong by treating "the code matches the footnote" as sufficient. A7 has one
regressor, so the divisor is pure units. **A8 has two regressors forced onto a common divisor
despite having very different natural scales, and then compares them.** That comparison is not
scale-invariant: the tenure equality test reads p = 0.078 on the divisor shown in the paper,
0.175 per standard deviation, and **0.721** on each group's own 90th percentile. See §4.

Mechanics are clean otherwise: the re-run reproduces the tracked CSVs **byte-for-byte**, all
**168** numbers printed in A6/A7/A8 match, and A6 matches the R package exactly.

---

## 2. The procedure I believe is correct

From the A7 footnote (`Draft.tex:958`), the A8 footnote (`Draft.tex:1012`), and `fn:groupconn`
(`Draft.tex:622`):

1. **Sample:** untreated, balanced-panel Lagos-sample establishments, 2009–2016.
2. **Group panel:** one observation per group × firm × year; three binary partitions
   (education no-HS/HS+, gender, tenure <12mo/≥12mo).
3. **Group connectivity:** `layer_treat_pw_n` — pre-period flows to treated establishments per
   *group* worker, averaged over the four 2007–2011 year-pairs.
4. **Scaling:** divide by the 90th percentile of the **firm-level** connectivity distribution
   among untreated balanced-panel firms at 2009.
5. **Controls:** year-interacted quartile bins of pre-treatment group wage, group employment,
   group per-worker flows (type-2 percentiles at p25/p50/p75 on 2009 balanced-panel
   observations, held constant per firm × group, missing → bin 0).
6. **Fixed effects:** group × firm throughout; "within firms" adds firm × year; "overall"
   instead adds industry × year, microregion × year, negotiation-month × year. **No group ×
   year FE** — the footnote enumerates the FE and omits them, and `01_estimates.R:4-5` says so
   explicitly.
7. **Inference:** SEs clustered at establishment; singletons dropped iteratively. Placebo is
   2009–2010 vs 2011.
8. **A8:** both group measures enter simultaneously on the firm-level outcome.

The code matches this in every respect. Step 4 is where the substantive problem lies — not
because the code deviates, but because the specification itself does something that
contaminates step 8. That is §4.

---

## 3. Q1 — why the standard errors fell

The prior pipeline divided by the **pooled-group** p90 (partition-specific); the current one
divides by the **firm** p90 (one common scalar). Measured in Stata on the estimation panel:

| partition | old divisor | new divisor | ratio |
|---|---|---|---|
| edu2 | 0.03117769 | 0.02932389 | 0.9405 |
| gender | 0.02960659 | 0.02932389 | 0.9905 |
| ten2 | **0.04490187** | 0.02932389 | **0.6531** |

Expected SE change: −6.0% education, −1.0% gender, **−34.7% tenure**.

I re-ran the estimator under the old divisor rather than assume. Across all 12 within/overall
cells the **SE ratio equals the divisor ratio to four decimals**, and **every t-statistic is
identical to three decimals**:

| partition | col | outcome | old (pooled) | current (firm) | se ratio | divisor | t old | t new |
|---|---|---|---|---|---|---|---|---|
| edu2 | within | wage | −0.0023 (0.0044) | −0.0021 (0.0041) | 0.9405 | 0.9405 | −0.519 | −0.519 |
| edu2 | within | emp | −0.0025 (0.0108) | −0.0023 (0.0102) | 0.9405 | 0.9405 | −0.230 | −0.230 |
| edu2 | overall | wage | 0.0028 (0.0025) | 0.0027 (0.0023) | 0.9405 | 0.9405 | 1.141 | 1.141 |
| edu2 | overall | emp | −0.0055 (0.0070) | −0.0052 (0.0066) | 0.9405 | 0.9405 | −0.787 | −0.787 |
| gender | within | wage | 0.0001 (0.0030) | 0.0001 (0.0030) | 0.9905 | 0.9905 | 0.031 | 0.031 |
| gender | within | emp | −0.0024 (0.0049) | −0.0024 (0.0048) | 0.9905 | 0.9905 | −0.491 | −0.491 |
| gender | overall | wage | 0.0026 (0.0020) | 0.0026 (0.0020) | 0.9905 | 0.9905 | 1.279 | 1.279 |
| gender | overall | emp | 0.0016 (0.0045) | 0.0016 (0.0044) | 0.9905 | 0.9905 | 0.367 | 0.367 |
| ten2 | within | wage | −0.0009 (0.0042) | −0.0006 (0.0028) | 0.6531 | 0.6531 | −0.210 | −0.210 |
| ten2 | within | emp | −0.0123 (0.0106) | −0.0080 (0.0069) | 0.6531 | 0.6531 | −1.162 | −1.162 |
| ten2 | overall | wage | 0.0001 (0.0033) | 0.0001 (0.0022) | 0.6531 | 0.6531 | 0.028 | 0.028 |
| ten2 | overall | emp | −0.0011 (0.0089) | −0.0007 (0.0058) | 0.6531 | 0.6531 | −0.126 | −0.126 |

The baseline is genuine: every SE in the old published table
(`Archive/PreviousDrafts/Within-Firm_Groups-Old.tex`, Panel B) matches the pooled-divisor
variant exactly.

**Nothing about precision changed.** A "1 unit" move simply means a different amount of
connectivity than it used to. For a single regressor this is harmless — which is exactly why it
is *not* harmless in A8.

**Note for the record:** the A7 note in `Main_Results.tex` claims "scaling is immaterial for A7
— pooled-group scaling moves cols 2–3, 5–6 by <7%." True for education (6.0%) and gender
(1.0%), **false for tenure (34.7%)** — off by a factor of five.

---

## 4. Q2 — the normalization contaminates A8 (the real issue)

Rescaling a single regressor cannot change its t-statistic. But **an equality test between two
coefficients is not scale-invariant.** Dividing two regressors by the same number is not
neutral when their underlying distributions differ — and here they differ enormously.

All six group measures are divided by 0.02932 (the firm p90):

| partition | group | mean | own p90 | 0.02932 as a multiple of own p90 |
|---|---|---|---|---|
| edu2 | no_hs | 0.00951 | 0.02020 | 1.45 |
| edu2 | has_hs | 0.01478 | 0.03704 | 0.79 |
| gender | female | 0.01030 | 0.02241 | 1.31 |
| gender | male | 0.01492 | 0.03540 | 0.83 |
| ten2 | **lt12mo** | 0.02611 | **0.06881** | **0.43** |
| ten2 | **ge12mo** | 0.00680 | **0.01389** | **2.11** |

Since `b_scaled = b_raw × divisor`, the common divisor **compresses the low-tenure coefficient
to 42%** and **inflates the high-tenure coefficient to 205%** of their own-p90 values — a
**4.9× tilt**, in precisely the direction of the paper's claim.

Measured, A8 Panel C, firm-level log wage (all three scalings are already in `a8.csv`):

| scaling | low-tenure (<12mo) | high-tenure (≥12mo) | equality p |
|---|---|---|---|
| **firm p90 — shown in the paper** | 0.0006 (0.0013) | **0.0052 (0.0022)** | **0.078** |
| per standard deviation | 0.0011 (0.0023) | 0.0060 (0.0025) | 0.175 |
| each group's own p90 | 0.0014 (0.0030) | 0.0025 (0.0011) | **0.721** |

The individual t-statistics are **identical across all three** (0.46 and 2.41 throughout).
So the two claims separate cleanly:

- **Scale-invariant, robust:** "high-tenure connectivity raises wages (t = 2.41); low-tenure
  does not (t = 0.46)."
- **Scale-dependent, fragile:** that the two *differ*. p swings 0.078 → 0.721 on divisor choice
  alone. This is what the table reports as p = 0.078, and what `Draft.tex:631` and the abstract
  rest on ("more so where competition runs through costlier-to-replace workers").

**A support problem sits underneath.** ge12mo connectivity has mean 0.0068 and p90 0.0139, yet
the reported coefficient is expressed per 0.0293-unit move — **2.1× that group's 90th
percentile, 4.3× its mean.** Essentially no firm has ge12mo connectivity that high, so β₂ on
the firm yardstick is a linear extrapolation outside the group's support. lt12mo has the mirror
problem: 0.0293 is only 0.43 of its p90, comfortably inside support.

**The stated justification is factually inverted.** The A8 note in `Main_Results.tex` says
own-p90 scaling "understates the gap because ≥12mo connectivity is right-skewed, so its 90th
percentile is an inflated denominator." ge12mo's own p90 (0.0139) is the **smallest of all six**
group p90s — a deflated denominator, not an inflated one. The argument runs backwards, and it is
used to justify the one scaling that produces p < 0.10.

*Classification:* **specification/inference problem, not a coding bug.** The code does exactly
what the footnote says; the footnote's choice is what manufactures the comparison. Education
(tilt 1.83×) and gender (1.58×) carry the same asymmetry but no headline — their equality p's
are 0.84 and 0.71 under every scaling. Tenure is the one case where a large tilt and a headline
claim coincide.

**Also undisclosed in the Draft.** `Main_Results.tex` reports all three p-values; `Draft.tex`
prints only 0.078, with no indication that the comparison is scale-dependent.

---

## 5. Reproducibility

| check | result |
|---|---|
| Re-run vs tracked CSVs | **identical md5** on all four files |
| `P90_FIRM` in fresh log | 0.02932 |
| reghdfe convergence warnings | none (14–18 iterations) |
| Draft.tex A6/A7/A8 printed numbers | **168 / 168 match** |
| A6 vs R replication package | exact (0.0000%) |

---

## 6. Within-firm estimates are not reproducible at the 4th decimal

Stata port vs R package on **identical samples** (N and firm counts match exactly everywhere):

| specification family | max coefficient gap | printed-digit flips |
|---|---|---|
| firm-level only | **4 × 10⁻¹² SE** | 0 / 12 |
| absorbs `firm_layer_id` | **0.023 SE** | 6 / 12 |

The split is perfectly clean: firm-level regressions agree to machine precision, and every
divergence is in a specification absorbing group × firm FE — the ill-conditioned case, where
after absorbing firm × year the identifying variation is only the within-firm connectivity gap.

Statistically this is nothing (max 0.023 SE). But because the within-firm coefficients sit only
0.2–0.5 SE from zero, it changes what prints: **6 of 24** A7 cells round differently at 4
decimals (edu2 within wage −0.0021 vs −0.0022; ten2 within wage −0.0006 vs −0.0005), and
**15 of 30** A8 equality p's differ at 3 decimals — including the headline tenure test,
**0.07833 vs 0.07852**, i.e. printed 0.078 versus 0.079.

Not a bug in either implementation. A numerical-conditioning limit. Don't quote the 4th decimal.

---

## 7. Sensitivity to the redone connectivity

The redone measure is a near-exact reproduction: correlation **0.9990**, p90 **0.02925788** vs
**0.02932389** (0.23% apart), means equal to 5 digits. Re-running on the overlay with
`totaltreat_pw_norm` rebuilt so both sides keep one yardstick:

- **Group-level columns:** every coefficient and SE moves by exactly ×0.997749; **no t-statistic
  changes at all**; no printed digit flips.
- **Firm-level columns:** headline spillover 0.00506 → 0.00499 (t 2.247 → 2.219, still
  significant). Printed: **0.0051 → 0.0050**.

**Trap:** `Programs/main_results/3020_build_currentconn_overlay_panel.do` swaps `totaltreat_pw_n` for
the current measure and keeps the legacy as `totaltreat_pw_n_frozen`, but **never regenerates
`totaltreat_pw_norm`**. Verified: in the overlay, p90(`totaltreat_pw_n`) = 0.02925788 while the
divisor implied by `totaltreat_pw_norm` is still 0.02932389. The within-firm wrapper reads the
base directory so the shipped run is consistent — but repointing it without rebuilding the norm
would put column (1) on the legacy scale and columns (2)–(3) on the current one.

---

## 8. Hourly variant — estimates sound, table broken

`01_within_firm_estimates_hw.do` is a pure variable substitution. Sound: `lr_remdezr_h_layer`
exists in all three outcome files; `P90_FIRM` correctly untouched (connectivity does not depend
on the wage measure); bins, sample, FE, clustering inherit correctly. **Validation:** hourly
`firm_full` wage = **0.006646 = 0.66%**, exactly the paper's hourly headline (`Draft.tex:384`);
all employment columns numerically identical to monthly, as required.

Two table-layer defects:

1. **`tabA6_hw.tex:9` is corrupted.** Hourly wages of R$4.22–4.91 pass through the monthly
   thousands-separator integer format, producing `Avg.\ wage & 4 & 5 & 5 & 5 & 4 & 5`. The note
   still reads "the mean December wage in 2015 BRL ... (education 1,796/2,613)".
2. **Duplicate labels.** `tabA6_hw/A7_hw/A8_hw.tex` reuse `\label{tab:A6}` / `{tab:A7}` /
   `{tab:A8}` with identical captions.

Neither reaches `Draft.tex` — the hourly within-firm tables appear nowhere in the paper.

---

## 9. All findings, classified

| # | Finding | Class |
|---|---|---|
| 1 | **A8 compares two coefficients forced onto a common divisor despite 4.9× different natural scales; tenure equality p = 0.078 / 0.175 / 0.721 across scalings** | **Specification/inference problem — the real issue** |
| 2 | ge12mo coefficient is a linear extrapolation to 2.1× that group's own p90 | **Specification problem** |
| 3 | `Main_Results.tex` A8 note justifies firm-scaling with an inverted claim (ge12mo p90 is the smallest of six, not "inflated") | **Wrong rationale** |
| 4 | `Draft.tex` prints only p = 0.078, omitting the scale sensitivity `Main_Results.tex` discloses | **Disclosure gap** |
| 5 | `Main_Results.tex` A7 note claims scaling moves cols 2–3, 5–6 "by <7%" — true for edu/gender, false for tenure (34.7%) | **False quantitative claim** |
| 6 | Divisor changed pooled-group → firm p90 | **Intentional; benign for A7** (pure units, t invariant) |
| 7 | Prior table's "Layers × firms" = 6,273 was arithmetically impossible (6,273 × 8 < N = 52,458); current 7,160 = 2 × 3,580 | **Prior-version bug, fixed** |
| 8 | Within-firm coefficients differ ≤0.023 SE between Stata and R; 6/24 A7 and 15/30 A8 printed values flip | **Numerical conditioning** |
| 9 | Overlay `totaltreat_pw_norm` not rebuilt (§7) | **Latent trap** |
| 10 | A6 note says `exp(mean log w)`; code computes `mean(exp log w)` | **Innocuous wording** |
| 11 | `tabA*.tex` (13 Jul) stale vs CSVs (24 Jul); `Draft.tex` itself matches the CSVs | **Innocuous** |
| 12 | 13 other layer pipelines still use pooled-group p90; none feed `Draft.tex` | **Latent inconsistency** |
| 13 | `07_within_firm/` and its outputs untracked in git | **Reproducibility risk** |
| 14 | Within-firm split-half reliability 0.06–0.17 vs 0.16–0.40 between-firm (Gui's `REPORT_extensions.md`) — the A7 null is partly a measurement-error null | **Interpretive, understated** |

---

## 10. Tenure construction — excluded by instruction, but already answered

I did no new work here. A prior session resolved it from code and I confirmed that against the
current pipeline while auditing, because §11 depends on it.

**The answer is construction A — tenure measured at the focal firm:**
`00_pipeline/02a_aggregate.py:66-89` groups by **`layer_id_focal``; `01a_build_transitions.py:156-232`
assigns that label from the focal-year spell at the focal firm (`for_origin=True`, Stage 2 keyed
on `tempempr`); `layer_config.py:89-94` bins raw `tempempr` at 12 months.

The mechanical consequence is the one Gui's memo warned about. An inflow record is a worker at
another firm in *t* and at firm *i* in *t+1*, so they were hired at *i* within that year and
their December `tempempr` is necessarily under 12 months → classified `lt12mo`. **`ge12mo`
connectivity is outflow-only by construction** — established workers of firm *i* being drawn
away by treated establishments.

`tenure_connectivity_memo.md` still records this as open and leans toward B/C, and states that
under A "the retention/preemption interpretation would not go through." An outflow-based measure
of pressure on established workers is a coherent object, but it is narrower than the memo
assumed, and the framing at `Draft.tex:631` (replacement costs, `jager2022substitutable`) rests
on the reading the memo says fails.

**Interpretation question for the authors, not a coding defect.** Nothing in `07_within_firm/`
is affected.

---

## 11. Should the results be trusted?

**A7 — yes.** The within-firm wage estimates are centered near zero under every divisor,
specification, and connectivity vintage tested. The claim that firms do not tailor pay to
within-firm differences in outside options is robust. The SE reduction is units.

**A8 tenure — the level claim yes, the comparison no.** "High-tenure connectivity raises wages,
low-tenure does not" is scale-invariant (t = 2.41 vs 0.46 under all three scalings). But the
*differential* claim — the mechanism story in the abstract and §6.2 — is not: p = 0.078 only on
the divisor the paper happens to show, and 0.721 on the one that keeps each group inside its own
support. Combined with §10 (ge12mo is outflow-only), this is the finding I would not take to a
referee as currently framed.

**Printed precision — no.** Do not quote the 4th decimal of within-firm coefficients or the 3rd
of A8 equality p-values.

---

## 12. Recommendations (none applied)

1. **Decide what "the same exposure" means for A8 and defend it explicitly.** Per-SD or own-p90
   scaling keeps both groups inside support; firm-p90 does not. If firm-p90 is kept, report the
   other two alongside it and drop the inverted "inflated denominator" rationale.
2. Carry the scale-sensitivity disclosure from `Main_Results.tex` into `Draft.tex`; fix the A7
   note's "<7%" claim (§3).
3. Reconcile the A8 tenure framing with construction A (§10), and update
   `tenure_connectivity_memo.md`, which still records the question as open.
4. Report within-firm coefficients at 3 decimals, or tighten `reghdfe tolerance()` on the
   `firm_layer_id` specifications and confirm convergence to the R values (§6).
5. Fix `02_make_tables_hw.py`: wage number format, note text, duplicate labels (§8).
6. Regenerate stale `tabA*.tex`; git-track `07_within_firm/`.
7. If the redone connectivity becomes standard, rebuild `totaltreat_pw_norm` in
   `3020_build_currentconn_overlay_panel.do`; expect the headline to print 0.0050 (§7).

---

## Appendix — how this was verified

Scratch: `<scratchpad>/wf_audit/` (survives; `tables/decomp_se.csv` holds the 2×2 grid).
No repo file modified.

| artifact | what it did |
|---|---|
| `_audit_run_within_firm.do` | re-ran the **unmodified** estimator with output redirected to scratch |
| `_decomp_se.do` | 2 × 2: divisor (firm vs pooled-group p90) × group × year FE (on/off) |
| `_ovl_run.do` | overlay re-run on the redone connectivity, `totaltreat_pw_norm` rebuilt |
| `cmp_r_vs_stata.py`, `gap_in_se.py` | cell-by-cell vs the R package, gaps in SE units |
| `draft_recon.py` | all 168 numbers printed in A6/A7/A8 of `Draft.tex` |

**Note on this file:** an earlier copy written 2026-07-29 ~00:45 was lost when the working tree
was cleaned (`quality_reports/audits/`, `plans/`, `session_logs/` removed and
`research_journal.md` reverted). This version is rewritten from the same evidence and adds §4,
which the first version got wrong.
