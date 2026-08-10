# Pre-period extension to 2007–2008 (task 5) — notes & verdict

## What was done
The main-results panel `lagos_sample_sep24_pct_unionexp_ext_df2.dta` starts in **2009**, so the
event studies baseline on `ib2011.year` had only **two** free pre-period coefficients (2009, 2010).
We pushed the pre-window back to **2007** by rebuilding 2007–2008 firm-year outcomes from the **full
RAIS** (parquet, `/Users/luisg/data/LMMergers/raw/RAIS/RAIS_2007.parquet`, RAIS_2008), giving **four**
pre-period coefficients (2007–2010). 2005/2006 are not reachable (parquet starts at 2007; outcomes are
within-year December snapshots so each year needs only its own RAIS — 2006 is not required for 2007/08).

## Pipeline (all local)
1. `Simulating`/DuckDB selection from parquet → worker panels `Data/RAIS_aux/extpre/worker_pre_{2007,2008,2009}.dta`
   and firm-employment counts `firmemp_pre_{...}.dta`. Worker selection replicates `1060_rais_worker_panel.do`:
   Dec-active (`empem3112==1 & tempempr>1`), **max-hours spell within (firm,worker)**, one spell per worker-firm.
   Wages deflated `remdezr/ipca_y`, with **ipca pos = year−2006** (2007 = 0.607949, 2008 = 0.643835, 2009 = 0.671595);
   the deflator was decoded from the 2009–2012 offsets and matches `1060_rais_worker_panel.do` exactly.
2. `extpre_build.do` — collapses worker panels to firm-year via the **exact** `2030_get_wage_pctiles_df2.do`
   method (`egen pctile, by(cnpj_year)` + mean), merges the wage-filter-free `firm_emp`, then appends
   2007–2008 rows to the panel by cloning each firm's 2009 row (inherits all time-invariant covariates:
   treat_ultra, connectivity, sample flags, microregion/industry) and overwriting year + outcomes.
   Output: `lagos_sample_sep24_pct_unionexp_ext_df2_extpre.dta`. Flag `extpre_row` = 1 for 2007–08 rows.
3. `Main_Results_pct_tfpw_07_11_extpre.do` — full headline spec on the extended panel. Static (2×2) post/pre
   estimates and numb_clauses are **guarded to `extpre_row==0`** (i.e. year≥2009) so they reproduce the
   headline exactly; the **dynamic event study uses the full 2007–2016 window**, and the joint pre-trend
   F-test is reported for both the original 2-period window (2009-10) and the extended 4-period (2007-10).
   Outputs suffixed `_extpre`.
4. `extpre_eventstudy_export.do` — focused rerun (base outcomes, direct Panel A + spillover): clean figures
   (`Graphs/es_*_{directA,spill}_extpre.pdf`) and per-period coefficient export
   (`Tables/es_coefs_extpre.csv`) for honest-DiD (#4).

## Validation (the reconstruction is exact)
Rebuilt 2009 firm-year outcomes vs the live panel (n≈17,810 firms):
- `lr_remdezr_w`, `lr_remdezr_h_w`, and all 14 percentiles (p10–p90): **corr 1.00000, sd 0.00000**.
- `l_firm_emp`: **corr 1.00000**, sd 0.0017 (residual from random tie-breaks only).
- Headline reproduction (B6): extpre static **post** coefficients are byte-identical to the published
  `results_*_tfpw_07_11_pct.csv` (e.g. direct log wages 0.0262***/0.0049; spillover 0.0051**/0.0023).
Coverage: 2007 has outcomes for 16,253 / 17,836 sample firms (91%), 2008 for 17,084 (96%) — the rest were
founded after 2007, giving an expectedly unbalanced (but unbiased) pre-window.

## Results — base outcomes (post effect; pre-trend joint-F p: 2-period → 4-period)

DIRECT (Panel A):
| outcome | post | F p (2009-10) | F p (2007-10) |
|---|---|---|---|
| log wages        | 0.0262*** | 0.724 | **0.798** |
| log hourly wages | 0.0287*** | 0.689 | **0.632** |
| log employment   | −0.0018 (ns) | 0.016 | 0.010 |

SPILLOVER:
| outcome | post | F p (2009-10) | F p (2007-10) |
|---|---|---|---|
| log wages        | 0.0051**  | 0.726 | 0.431 |
| log hourly wages | 0.0066*** | 0.778 | 0.548 |
| log employment   | 0.0004 (ns) | 0.874 | 0.271 |

## Verdict (FINAL — two samples side by side; see Tables/extpre_robustness.tex)

The analysis is reported for TWO sample definitions to separate "adding 2007-08 years" from
"changing firm composition":
- **(a) Unbalanced**: headline balanced-2009-16 firms + 2007-08 obs where the firm operated.
- **(b) Balanced throughout 2007-16**: firms operating every year 2007-2016 (drops ~9% of firms
  overall, ~12% of spillover firms = the post-2007 entrants).

Pooled DiD by sample (2009-16 window | 2007-16 window):

| | log wages | log hourly |
|---|---|---|
| direct, unbal   | 0.0262*** \| 0.0266*** | 0.0287*** \| 0.0303*** |
| direct, bal     | 0.0212*** \| 0.0234*** | 0.0248*** \| 0.0283*** |
| spill,  unbal   | 0.0051**  \| 0.0018(ns) | 0.0066*** \| 0.0040(ns) |
| spill,  bal     | **0.0026(ns)** \| $-$0.0004(ns) | **0.0032(ns)** \| 0.0011(ns) |

KEY FINDINGS:
1. **Direct wage effects are robust** to both the pre-period extension AND balancing
   (0.021--0.030, all \*\*\* in every cell). Solid.
2. **The spillover wage effect is mostly a COMPOSITION effect, not a pre-period effect.** On the
   balanced-throughout sample the spillover pooled estimate is already insignificant *in the original
   2009-16 window* (0.0026, p=0.48 monthly; 0.0032, p=0.39 hourly). So dropping the post-2007 entrants
   alone kills significance; adding the 2007-08 years on top moves it a little further toward zero.
   Decomposition (monthly): headline all-firms 0.0051** -> drop entrants 0.0026(ns) -> add years -0.0004(ns).
   => the spillover wage result is carried by firms that ENTERED after 2007 (younger/growing untreated
   firms), and is sensitive to sample composition. This is the substantive payoff of "show both."
3. **No pre-trend rejection for wages** in any spillover cell (joint-F p 0.43-0.67); direct employment
   retains its pre-existing pre-trend (p 0.01-0.02) with null effect.
4. For honest-DiD (#4): 4 pre-periods exported for BOTH samples (`Tables/es_coefs_extpre.csv`, `sample`
   column = unbal/bal); figures `es_*_{directA,spill}_extpre[_bal].pdf`.

## (superseded) earlier single-sample framing — pooled DiD on the EXTENDED sample

The graphs/table report the **pooled DiD re-estimated on the full 2007–2016 sample** (the static
`treat##post`, so the pre-baseline is now 2007–2011 instead of 2009–2011), next to the published
2009–2016 pooled estimate. Pooled comparison (headline → extended):

| | log wages | log hourly | log emp |
|---|---|---|---|
| direct (Panel A)   | 0.0262*** → **0.0266*** | 0.0287*** → **0.0303*** | −0.0018 → −0.0120 (ns) |
| spillover          | 0.0051**  → **0.0018 (ns)** | 0.0066*** → **0.0040 (ns)** | 0.0004 → 0.0060 (ns) |

- **Direct wage effects are robust.** The pooled estimate barely moves (and the dynamic event study is
  clean: flat 2007–2010, sharp post-2011 jump; pre-trend joint-F p 0.72→0.80 monthly, 0.69→0.63 hourly).
- **Spillover wage effects ATTENUATE on the extended sample.** The pooled estimate falls from 0.0051**/0.0066***
  to 0.0018/0.0040 and loses significance. Mechanism: the 2007 and 2008 spillover event-study coefficients are
  positive (≈0.011, 0.015 for monthly) though imprecise; including them in the pre-baseline raises it and
  shrinks the post-vs-pre gap. The pre-trend joint-F never rejects (p 0.43 / 0.55), so this is *not* a
  significant pre-trend — but the point estimates do drag the pooled effect down. **The spillover result is
  sensitive to the pre-period definition** — consistent with the honest-DiD fragility flagged in task 4.
  Note the event study still shows the spillover clearly emerging post-2011 relative to the 2011 base; what
  changes is the pooled average once 2007–2008 enter the baseline.
- **Employment**: no effect either design (pooled ≈ 0, ns). Direct employment shows a pre-existing positive
  pre-trend (F p 0.016→0.010) with null effect — report honestly; it doesn't bear on the wage story.
- **For honest-DiD (#4)**: event-study vectors now carry **4 pre-periods** (`Tables/es_coefs_extpre.csv`),
  and the spillover attenuation above is exactly the kind of fragility RR is meant to quantify.

## Caveats
- `numb_clauses` cannot gain pre-periods (its event study is on CBA-period structure, 1 pre by
  construction); the calendar extension leaves it unchanged — guarded to `extpre_row==0`.
- Percentile/ratio outcomes were also extended and their pre-trend F-tests written to the `_extpre` table
  CSVs, but the base outcomes above are the event-study / honest-DiD objects of interest.
- The extension is a **pre-trends robustness**, not a re-estimation of the treatment effect: the static DiD
  uses 2011 as reference and post-periods as before; 2007–2008 only add earlier placebo periods.
