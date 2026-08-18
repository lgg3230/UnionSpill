# Domain Profile

<!--
All agents read this file to calibrate field-specific behavior.
Grounded in UnionSpill-paper/bib.bib and CLAUDE.md as of 2026-07-15.
Lines marked [CONFIRM] are Claude's inference, not established fact — correct them.
-->

## Field

**Primary:** Labor Economics
**Adjacent subfields:** Public Economics; Development (Brazil / middle-income labor markets); IO (monopsony, employer concentration)

**Project:** UnionSpill — how improvements in union bargaining power following Brazil's Súmula 277 reform (2012) spread through labor markets to firms that are *not* directly unionized but are connected via worker flows.

**Authors:** Luis de Azevedo-Gomes, Guilherme Neri

---

## Target Journals (ranked by tier)

<!-- [CONFIRM] These are conventional labor tiers, not a stated target list. -->

| Tier | Journals |
|------|----------|
| Top-5 | AER, Econometrica, JPE, QJE, REStud |
| Top field | JOLE, AEJ: Applied, AEJ: Economic Policy, JHR |
| Strong field | ILR Review, Labour Economics, JPubE, Economic Journal |
| Specialty | Journal of Development Economics, World Bank Economic Review |

---

## Common Data Sources

| Dataset | Type | Access | Notes |
|---------|------|--------|-------|
| RAIS | Matched employer-employee admin (Brazil) | Restricted | Universe of formal employment. Cleaned via Dahis procedure. One spell per worker-firm: rank by contracted hours, then hourly December wage, then random tiebreak (seed 12345). |
| CBAs (Sistema Mediador) | Collective bargaining agreements | Restricted | Source for `numb_clauses`, clause types. Coverage exploded to municipality level via `explode_cba_coverage_*.py`. Basis of Lagos (2026). |
| IBGE | Geographic / microregion crosswalks | Public | Microregion is the standard local-labor-market unit here. |

**Deflation:** all wages to December 2015 prices via IPCA.

---

## Common Identification Strategies

| Strategy | Typical Application | Key Assumption to Defend |
|----------|-------------------|------------------------|
| Event study / DiD around Súmula 277 (2012) | Direct effect on firms with affected CBAs (`treat_ultra`) | Parallel trends; no anticipation. Defended with Honest DiD (Rambachan & Roth 2023) and Roth (2022) pre-trend power. |
| Connectivity-weighted spillover exposure | Effect on untreated firms connected to treated firms via pre-period worker flows (2007-2011) | Exposure is not driven by selection into connectedness. Defended with randomization inference permuting treated-set *identity*. |
| Randomization inference | Placebo treated sets drawn by CEM reshuffle inside sample (cardinality 13,202) | Connectivity is exactly linear in the destination set, so recentering is valid. |
| Binscatter linearity tests | Whether exposure enters linearly | Cattaneo et al. (2024) binstest. Canonical test is first-difference internal-w (`linearity_did_fd.do`). |

---

## Field Conventions

<!-- The Coder and Writer follow these. The writer-critic checks for them. -->

- Outcomes in logs: `l_firm_emp`, `lr_remdezr`, `lr_remmedr`. Flow rates (`turnover`, `retention`, `hiring`, `layoffs`, `quits`) in levels.
- **Never** omit `i.mode_base_month#i.year` (or `#i.cba_period`) from event studies. If it will not converge, use `tolerance(1e-2)`, do not drop the term.
- For flow outcomes (`totalflows`, `outflows`, `inflows`): **always** exclude `extra_year` from `absorb`, use `capture testparm`, and guard with `cond(_rc==0, r(p), .)`. Otherwise R² = 1.0000 and the run aborts.
- `vce(robust)` with establishment FE is the default; `reghdfe` in Stata, `pf.feols(..., vcov='hetero')` in Python (identical to machine precision).
- No log(zero) and no zero-fill. Leave missing as missing; keep only observations present in the outcomes data.
- Proximity measures are **negative absolute differences** (higher = more similar); geographic proximity is `-ln(distance + 0.1)`.
- Stata emits CSV only. **LaTeX tables are always written by Python**, never by Stata.
- Reuse existing variable definitions verbatim (e.g. `pre_treat_cba` from `3012_pct_tfpw.do`). Do not reinvent them.
- `cap drop` takes **one variable per line**. `cap drop x y z` silently drops only `x`.
- Significant logic change means a new file (`06b_*`), not an edit in place.

---

## Notation Conventions

| Symbol | Meaning | Anti-pattern |
|--------|---------|-------------|
| $Y_{it}$ | Outcome for firm $i$ in year $t$ | Bare $y$ with no subscripts |
| `treat_ultra` | Direct treatment: firm's CBA affected by Súmula 277 | Do not call this "union status" |
| $\sum_k u^{(k)}$ | Total clause count / $L_1$ norm | Do not call this "mass" of clauses |
| Connectivity | Share of pre-period worker flows to treated firms (`totaltreat_pw_n`) | Do not describe as "exposure intensity" without defining |

**Prose:** no em-dashes (use commas, parentheses, or colons; en-dashes only for ranges). No colloquial analogies; state relationships algebraically.

---

## Seminal References

<!-- Resolved from UnionSpill-paper/bib.bib. Cite these when relevant. -->

| Paper | Why It Matters |
|-------|---------------|
| Lagos (2026), *Union Bargaining Power and the Amenity-Wage Tradeoff* | The direct-effect antecedent. Súmula 277 setting, CBA data, `lagos_sample`. Referees will ask what UnionSpill adds beyond it. |
| Bassier (2024), *Collective Bargaining and Spillovers in Local Labor Markets* | Closest prior on bargaining spillovers. Main comparison for the spillover claim. |
| Jäger, Naidu & Schoefer (2025), *Collective Bargaining, Unions, and the Wage Structure* | Framing reference for institutions and wage structure. |
| Freeman & Medoff (1981), *Impact of the Percentage Organized on Union and Nonunion Wages* | Canonical union threat / spillover effect. |
| Fortin, Lemieux & Lloyd (2021), *Labor Market Institutions and the Distribution of Wages* | Institutions and wage distribution. |
| Derenoncourt & Weil (2025), *Voluntary Minimum Wages* | Voluntary/spillover wage-setting in local labor markets. |
| Arnold (2022), *Privatization of State-Owned Enterprises* | Brazil + RAIS firm-level design precedent. |
| Schubert, Stansbury & Taska (2024), *Employer Concentration and Outside Options* | Outside options as the spillover mechanism. |
| Caldwell & Danieli (2024), *Outside Options in the Labour Market* | Outside-options measurement via worker flows. |
| Jäger, Heining & Lazarus (2024), *How Substitutable Are Workers?* | Worker-flow-based substitutability. |
| Nimczik (2023), *Job Mobility Networks and Data-Driven Labor Markets* | Defining labor markets from worker-flow networks — direct precedent for connectivity. |
| Manning (1994), *Labour Markets with Company Wage Policies* | Theory anchor for firm wage policies. |

---

## Theoretical Foundational References

| Topic | Anchor references |
|-------|------------------|
| Parallel trends / sensitivity | Rambachan & Roth (2023), *A More Credible Approach to Parallel Trends* |
| Pre-testing and event studies | Roth (2022), *Pretest with Caution* |
| Binscatter / functional form | Cattaneo, Crump, Farrell & Feng (2024), *On Binscatter* |
| Worker-flow labor market definition | Nimczik (2023) |
| Firm wage policies | Manning (1994); Postel-Vinay & Robin (2002) |

---

## Paper Author Team

<!-- Used by theorist-critic to calibrate respect. The authors are not (yet) among the
     reference literature on these topics, so critics may explain methods freely. -->

| Author | Foundational on |
|--------|----------------|
| de Azevedo-Gomes | — |
| Neri | — |

---

## Field-Specific Referee Concerns

- **"What does this add beyond Lagos (2026)?"** The direct effect is established there. The contribution is the *spillover* onto connected untreated firms. This must be crisp in the intro.
- **"Is connectivity exogenous?"** Firms do not randomly connect to treated firms. Addressed by randomization inference permuting treated-set identity, plus the Bergeaud-style nonrandom-exposure table.
- **"SUTVA / control contamination."** If spillovers are real, control firms are treated too. The connectivity gradient is the answer, not a nuisance.
- **"Parallel trends."** Expect Honest DiD sensitivity and pre-trend power (Roth 2022), not just a visual event study.
- **"Why linear in exposure?"** Binscatter linearity tests; all outcomes fail to reject linearity (log wage p = 0.132).
- **"Why worker flows rather than industry or geography?"** Must show connectivity is not just proxying microregion or industry. This is what the proximity/gravity decomposition is for.
- **"Pre-period flows are measured with error."** 2007-2011 flow shares are noisy for small firms.

---

## Quality Tolerance Thresholds

| Quantity | Tolerance | Rationale |
|----------|-----------|-----------|
| Point estimates | 1e-6 | Numerical precision; Stata reghdfe vs pyfixest agree to ~1e-8 |
| Standard errors | 1e-4 | MC variability |
| Decomposition identity | 1e-3 | Ordered decomposition drifts at ~1e-3 if the pre4 bin is not common per measure |
| Randomization inference p-values | ± 0.01 | Finite permutation draws |
