# Strategy Review — UnionSpill (`Draft.tex`)

**Date:** 2026-07-16
**Agent:** strategist-critic (standalone, via `/paper-review UnionSpill-paper/Draft.tex`)
**Severity:** HIGH (Execution phase)
**Overall assessment: MAJOR ISSUES** (drops to CRITICAL ERRORS if C1 cannot be reconciled)

> **Provenance.** The strategist-critic is read-only by design (`.claude/rules/agents.md`) and has no
> Write tool, but `skills/paper-review/SKILL.md` instructs it to save its own report. It cannot.
> Report returned inline, persisted here by the orchestrator. Same pipeline defect as the
> writer-critic run — see the proofread report.
>
> **Orchestrator verification.** The three CRITICAL findings make a serious charge (that the draft
> reports the most favorable variant of each diagnostic). I verified all three against the project's
> own output files before relaying. Results annotated inline below as **[VERIFIED]** /
> **[VERIFIED — with correction]**. Reviewer framing I judged overstated is flagged under
> "Orchestrator dissent".

---

## Phase 1: Claim Identification

- **Paper type:** Reduced-form causal inference
- **Designs:** (A) continuous-exposure DiD/event study for spillovers — *the contribution*;
  (B) binary DiD/event study for direct effects — established in Lagos (2026)
- **Estimand:** Direct = ATT (2012–2016 pooled, 2011 reference). Spillover = effect of moving from
  $C_i = 0$ to the 90th percentile of connectivity
- **Treatment:** Súmula 277 ultractivity, 2012-09-25; $D_i=1$ if firm-level CBA filed before, expiring after
- **Control:** (A) all untreated, gradient in $C_i$; (B) untreated with $C_i = 0$

---

## Phase 2: Core Design Validity — CRITICAL

### C1 — Panel A vs Panel B attenuation is ~4× larger than the paper's own spillover can explain
**Severity: CRITICAL** · Draft.tex:96, :322, :675; `tab:direct_connectivity_robust`

**[VERIFIED — orchestrator reproduced the arithmetic independently, 2026-07-16]**

Draft.tex:322 claims the attenuation under the unrestricted comparison group *"implies that connected
untreated firms themselves experience positive wage spillovers."* The arithmetic:

| Quantity | Value | Source (verified) |
|---|---:|---|
| $\beta_A$ (observed pure controls) | 0.026218794 | `Tables/rand_inference/direct_cf_placebo_summary_none.csv` |
| $\beta_B$ (all controls) | 0.017846191 | same |
| **observed gap** | **0.008373** | |
| $E[C \mid \text{all untreated}]$ | 0.0124073 | `direct_cf_composition_none.csv`, "All controls" |
| $p90$ | ≈0.03 | Draft.tex:387 |
| $\delta$ (spillover) | 0.005070386 | `perm_spillover_fine.json`, `delta_obs` |
| **implied attenuation** $\delta \times E[C]/p90$ | **0.002097** | |
| **ratio observed / implied** | **3.99×** | |

Only **25%** of the attenuation is attributable to spillover contamination under the paper's own
linear model.

Three escape routes are closed:
1. **Concavity** — closed by the authors' own binstest: linearity not rejected
   (`linearity_did_notes_fd.md`, log Dec wage $p=0.132$). Even a strongly saturating $f(C)$ cannot
   reach 0.0084 with 46% of firms at $C=0$.
2. **Regression weighting** — the DiD partials out size/flow bins × year, which correlate strongly
   with $C$. This should make attenuation ≤ 0.0021, *widening* the gap.
3. **Composition is the parsimonious explanation, and the authors' own data show it**
   (`direct_cf_composition_none.csv`, verified):

| Control group | $n$ | mean `firm_emp` | mean `n_edges` |
|---|---:|---:|---:|
| All untreated (Panel B) | 4,196 | **151.4** | 6.00 |
| Observed zero-conn (Panel A) | 1,931 | **22.4** | 1.58 |

Treated firms average 143. The Panel A control group averages 22 employees and 1.58 network edges —
a different population, not a treatment contrast.

Worse, the direct effect ranges **0.0122 → 0.0262** purely as a function of control selection
(verified: Proc B 0.01225; Proc A 0.01688; all controls 0.01785; observed pure 0.02622). The reported
headline sits at the **top** of a 2× range.

**Fix (must):** either (i) reconcile 0.0084 with $\delta \times E[C]$ quantitatively; or (ii) drop the
causal reading of the Panel A/B gap and present it as descriptive; or (iii) reweight/trim
zero-connectivity controls onto the treated size distribution and show the gap survives. As written,
the claim at line 96 and the conclusion's headline lesson at line 675 (*"excluding connected firms
increases direct effect estimates by nearly half"*) are unsupported.

### C2 — RI p-values for the headline spillover span 0.0001 → 0.241; none is reported
**Severity: CRITICAL** · Draft.tex:449–469

**[VERIFIED exactly — `Tables/rand_inference/perm_spillover_*.json`, 2026-07-16]**

For `lr_remdezr_w`, $\delta_{obs} = 0.005070$:

| Scheme | placebo mean | placebo sd | **p (2-sided)** |
|---|---:|---:|---:|
| none | −0.00168 | 0.00105 | 0.0001 |
| coarse | −0.00177 | 0.00120 | 0.0002 |
| medium | −0.00075 | 0.00189 | 0.0031 |
| **fine** | **+0.003955** | 0.001475 | **0.2409** |

Under the finest scheme **78% of the estimate (0.003955 of 0.005070) is reproduced by a randomly
assigned placebo treated set**. The paper reports only the Borusyak–Hull control-function version
("essentially unchanged") and no RI p-value at all.

**In fairness:** the authors' `direct` positive control shows the fine scheme loses power (direct
$p$: 0.0001 medium → 0.028 fine). Since the direct effect is 5× the spillover, a scheme that barely
detects 0.0262 has little power against 0.0051. **This is a legitimate defense and it belongs in the
paper.** `Programs/rand_inference/06_fill_section.py` was evidently built to populate exactly such a
section; that section does not exist in Draft.tex.

Also: the paper's $\mu_i$ uses `mu_C_ind_month` (industry × negotiation-month, per
`5152_recentered_eventstudy.do:11`), matching **none** of the four RI schemes. State and justify.

**Fix (must):** report the full RI suite with the positive-control power calibration; state which
scheme models assignment and why.

### C3 — Honest DiD targets a different estimand than the headline
**Severity: CRITICAL** (orchestrator: **MAJOR** — see dissent) · Draft.tex:474–482

**[VERIFIED — with correction]** The numbers are confirmed, but the reviewer mis-sourced them.
They are in `Programs/honest_did/honest_did_task4_reporting.md` (lines 14–20), **not** in
`honest_did_breakdown.csv` (which has no p1/avg split; its `restriction` column is rm/sd). The CSV's
direct rm value is 1.8216, while both the note and the draft say 1.78/1.77.

| Effect | $\bar{M}$ (p1, reported in draft) | $\bar{M}$ (avg, the actual estimand) |
|---|---:|---:|
| Direct, log wages | 1.78 | **0.64** |
| Spillover, log wages | **0.75** | **0.29** |

The headline coefficient is the **2012–2016 pooled average**; the reported breakdown targets the
**first post-period**. Verified: the avg numbers appear nowhere in Draft.tex.

Draft.tex:480–482 concludes *"the effects are not a result of differential trends."* With
$\bar{M} = 0.75 < 1$, the result does **not** survive a post-violation as large as the worst
pre-period violation. That sentence is over-claimed regardless of which target is led with.

**Fix (must):** report avg-target breakdowns alongside p1, disclose the mismatch, and correct the
concluding sentence.

#### Orchestrator dissent on C3
The reviewer called this **"spin"** and said *"a disclosure was removed."* Both overstate:

1. **The authors have a documented, reasoned position** for leading with p1
   (`honest_did_task4_reporting.md:32–40`): avg < p1 is *mechanical* (a longer post-window lets an
   unobserved trend accumulate, widening the robust CI), p1 is *"most comparable to the applied RR
   literature, which typically targets an early/representative post-period"*, and the ordering
   *"should be stated as such, not apologized for."* The same note directs reporting **avg as the
   conservative full-window number**. The authors planned to report both. That cuts against
   concealment.
2. **"Removed" is unsupported.** The note records the p1-vs-avg paragraph as *"APPLIED (2026-06-24)"*
   to `Main_Results.tex`. I grepped `Main_Results.tex`: it is **not there either**. The paragraph is
   in neither file, so the note is stale or the edit was lost — a draft-sync gap, not a removal.

The substance survives the reframing: the avg numbers should be in the draft and are not, and
line 480–482 is too strong. But this reads as an omission of analyses the authors themselves
specified, not as selective reporting. Severity **MAJOR**, not CRITICAL.

### Sanity Check
- **Sign:** plausible (direct +2.6% wages / +1.6 clauses; spillover +0.51%)
- **Magnitude:** spillover ratio 0.19 in line with Bassier (2024), but internally inconsistent — see C1
- **Dynamics:** only 3 pre-periods; spillover pre-trend SE (0.0025) is half the effect (0.0051) — the
  test cannot detect a trend large enough to generate the result
- **Consistency — the tell:** the spillover survives every *conditioning-on-observables* check
  (0.0045–0.0056 across 6 specs) but fails every *design-based inference* check: RI fine ($p=0.24$),
  Honest DiD avg ($\bar{M}=0.29$), union × year FE (0.0044, se 0.0026). That pattern is the signature
  of a nonrandom-exposure problem.

---

## Phase 3: Inference — 4 MAJOR

- **M1 — Roth (2022) pre-trend power omitted while the paper leans on flat pre-trends.** Authors' note:
  *"spillover 80%-detectable slope 0.0046 vs mean post-effect 0.0065, i.e. the pre-test is only weakly
  informative."* Draft.tex:480 nonetheless argues from flat pre-trends. Roth (2022) not cited. **Must report.**
- **M2 — Linearity in exposure never defended in the paper.** `fig:binscatter` is a *balance* figure,
  not a dose-response test. The proper test exists (`conn_margins/linearity_did_fd.do`, Cattaneo et al.
  2024 binstest, validated to ~1e-5) but is absent, and Cattaneo et al. is not cited. $p=0.132$ is the
  weakest of four outcomes; add trimming/winsorizing robustness.
- **M3 — Inference ignores the exposure-design correlation structure.** $C_i = \sum_j C_{ij} D_j$ is a
  shift-share/exposure design with a common shock vector; establishment clustering assumes independence
  across $i$. Adão–Kolesár–Morales (2019) not cited. 91% of untreated firms share a union with a treated
  firm, yet SEs are never union-clustered. $t = 2.2$; modest SE inflation kills it.
- **M4 — Clause counts conditioned on an endogenous event.** Post-treatment obs restricted to CBAs
  *filed* after 2012-09-25; filing is itself an outcome. Also: 73,177 obs / 14,176 establishments ≈ 5.2
  each is inconsistent with "observed only when an agreement is filed"; and
  `04_permutation_engine.py:20` shows `numb_clauses` uses **CBA-period FE and `post_treat_cba`**, a spec
  differing from equation (3) and never stated.

---

## Phase 4: Polish — 3 MAJOR, 9 MINOR

- **M5 — Common support of the zero-connectivity control group never diagnosed.** Treated 143.4 vs
  zero-conn 23.3 employees. The authors' own diagnostic documents 856 always-zero controls and
  Procedure A overlap of **0.93**. **Must report** the treatment × size-bin cross-tab.
- **M6 — "No union mediation" over-claimed.** Column (7): −0.0009 (0.0016) → 95% upper bound +0.0022,
  which cannot rule out **~43%** of the spillover being union-mediated. Column (2) gives 0.0044 (0.0026),
  not significant at 5%, described as *"largely unchanged."*
- **M7 — Second-order network SUTVA unaddressed.** $C_i=0$ firms may be exposed at distance 2,
  contaminating the "clean control group" premise underlying C1.

**MINOR:** (m1) `\ref{tab:spillover}` line 988 — label does not exist, renders "Table ??"
*(independently confirmed by verifier and writer-critic)*. (m2) INV-6: no JEL codes/keywords.
(m3) three unresolved `% VERIFY:` notes at 821, 866, 1087. (m4) line 649 hardcodes "equation (2)".
(m5) pre-trend placebo sign convention never stated. (m6) $\bar{M}=1.77$ draft vs 1.78 note vs 1.8216 CSV.
(m7) establishment counts vary unexplained (14,134/14,137/14,176). (m8) em-dashes at 73, 118, 282, 322.
(m9) line 458 `\citet` where `\citep` needed.

**Citation fidelity:** Rambachan & Roth (2023) ✓; Borusyak & Hull (2023) ✓; Wooldridge §7.3 + Weesie
(1999) ✓. **Missing:** Roth (2022), Cattaneo et al. (2024), Adão–Kolesár–Morales (2019).

---

## Priority Recommendations

1. **[CRITICAL] Reconcile or retract the Panel A/B contamination claim** (0.0084 observed vs 0.0021 implied).
2. **[CRITICAL] Report the full RI suite** (p = 0.0001 → 0.241) with the positive-control power calibration.
3. **[MAJOR] Report Honest DiD at the avg target** (0.29 spillover / 0.64 direct); correct line 480–482.
4. **[MAJOR] Add the Roth (2022) power diagnostic and the binstest linearity table** — both already produced.
5. **[MAJOR] Union-level and exposure-robust (AKM 2019) SEs;** address filing-selection in clause counts.

---

## Positive Findings

1. **The connectivity measure is unusually well validated.** The early→late predictive test conditional
   on observables and $R^2 \approx 0.22$ from saturated industry×microregion pair FE are a genuinely
   persuasive answer to "why worker flows rather than industry or geography."
2. **The stacked cross-equation test for Panel A vs B equality is done correctly** — recovering the
   covariance via a single cluster per establishment is more careful than most papers manage.
3. **The diagnostic infrastructure is top-5 caliber.** FD linearity validated to 1e-5, RI engine with a
   positive control, Borusyak–Hull counterfactual exposure, composition placebo. *The problem is not the
   analysis. It is that the least favorable outputs never reached the manuscript.*
4. **The within-firm null and its measurement implication** (granular exposure *attenuates* rather than
   sharpens) is a sharp, honest, genuinely novel methodological point.
