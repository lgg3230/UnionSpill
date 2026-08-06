# Simulated Peer Review — AER and JOLE

**Paper:** "Outside Options and Collective Bargaining Spillovers" (de Azevedo-Gomes & Neri)
**Manuscript:** `quality_reports/draft_snapshots/Draft_2026-08-03_87f13b2.tex` (Overleaf `87f13b2`)
**Date:** 2026-08-03
**Process:** editor desk review → two blind referees per journal → editorial decision

---

## Verdicts

| | **AER** | **JOLE** |
|---|---|---|
| Desk | Send to referees (close call) | Send to referees (ideal fit) |
| Domain referee | **Reject** — 63/100 (CREDIBILITY) | Major Revisions — 73/100 (MEASUREMENT) |
| Methods referee | Major Revisions — 67/100 (STRUCTURAL) | Major Revisions, borderline reject — 56/100 (CREDIBILITY) |
| **Decision** | **REJECT** | **MAJOR REVISIONS** (high risk) |

**AER's reasoning:** "At AER, Major Revisions is a statement that I expect to publish the paper. I do not." Two claims classified FATAL — fatal to the claims, not the paper. Lagos (2026) is already accepted at AER on the same reform and registry; AER takes a second paper on the same variation only for a substantially larger jump. Suggested: AEJ:Applied, JOLE, or ReStat.

**JOLE's reasoning:** No concern is unfixable in principle. One is *conditionally* fatal — the intra-corporate transfer channel — "addressable in the sense that the test is easy to run, fatal in the sense that the paper may not survive the test."

---

## The consensus

Four referees, four different dispositions, no contact with each other. **All four** independently flagged the same three problems:

1. **The 40% attenuation claim fails its own arithmetic.** Three separate derivations converge: measured mean/p90 = 0.424 → implied gap 0.0028 vs observed 0.0083. Spillovers explain roughly a third.
2. **Clustering is finer than the level of treatment assignment.** Establishment (14-digit) vs company (8-digit). Additionally, the spillover design is a shift-share/network-exposure structure where clustering on the outcome unit is invalid regardless of level.
3. **Parallel-trends sensitivity is missing** though the analysis exists in the repo.

---

## The pattern that decided both letters

Five diagnostics that bear directly on headline claims **exist in the authors' own files and are not in the paper**:

| Diagnostic | Location | What it shows |
|---|---|---|
| Rambachan–Roth breakdown | `Tables/honest_did/` + `Figures/h_honest_*.pdf` | Spillover M̄ = 0.4177 "VERY FRAGILE" (CSVs) / 0.29 (figures); direct 1.6412 / 1.40 |
| Direct effect on CBA value | `Tables/currentconn_full/cba_value/` | 0.0073*** (0.0027) — the missing amenity benchmark |
| Nonparametric dose-response | `Tables/conn_margins/results_quartiles_vs_zero.csv` | Q1 −0.0038, Q2 −0.0206, Q3 −0.0040, Q4 +0.0045 — non-monotone, top quartile null |
| Intermediate control arm | `direct_sample_coef_test.csv` | C≤0.01 controls give 0.0233; exposure permits at most 0.0022 of movement |
| Linearity binstest | `Programs/conn_margins/linearity_did_fd.do` | The defense the level interpretation needs |

Plus `rambachan2023more`, `roth2022pretest`, `Callaway2023`, `Aronow2017`, `Cattaneo2024`, `Engbom2022`, `corradini2025collective` — all in `bib.bib`, all uncited.

AER: "the two pieces of evidence most damaging to the two claims carrying this paper are the two that exist and are not shown." Neither editor read this as bad faith; both noted the paper's honest reporting elsewhere. JOLE: "In a revision, a diagnostic that exists and is omitted is no longer an oversight."

**The CSVs and figures disagree with each other** (0.4177 vs 0.29). As of today neither the authors nor the editors know what the spillover's breakdown value is.

---

## New findings from review

**Intra-corporate transfers (JOLE R1, verified).** 62.6% of worker flows in the bilateral connectivity network — 52.8% of pairs — are between establishments sharing an 8-digit CNPJ root. Since agreements match on 8 digits × coverage geography, two establishments of one company can differ in treatment status. JOLE's editor: "A control establishment can be 'highly connected to treated firms' primarily through internal transfers to its own treated siblings. If that is where the spillover lives, the estimate is not a labor-market outside-option effect at all; it is the direct effect leaking across corporate boundaries through a common HR function."

**The amenity asymmetry is not established (AER R1, verified).** With the unreported direct effect of 0.0073, the proportional benchmark 0.23 × 0.0073 = 0.0017 lies inside the spillover CI [−0.0040, +0.0022].

**The December 2012 response is off-mechanism (JOLE R2).** 75% of the direct effect and 74% of the spillover are realized by Dec 2012, for a 25 Sept 2012 ruling under a mechanism that binds only at the next negotiation — which by construction had not occurred.

**Composition, not contamination (both editors).** Zero-connectivity controls average 23.3 employees vs 143.4 treated and 161.0 all-untreated. Under the composition reading, **0.0285 is the more contaminated estimate, not the cleaner one**, and the spillover/direct ratio is 0.32 rather than 0.23.

**Institutional items neither critic caught:** the 2015–16 recession (GDP −3.5%/yr) is never mentioned; ADPF 323 (Oct 2016 STF injunction suspending ultractivity) predates the 2017 endpoint; Brazil's minimum wage rose substantially over the window with documented spillovers.

---

## JOLE's MUST list (8 items — revision won't go back to referees without all)

1. **Net out the 8-digit company everywhere** — rebuild C excluding same-root pairs; separate inflows from outflows
2. **Withdraw or re-derive the 40% claim**
3. **Report the full nonparametric dose-response** for every headline outcome
4. **Fix inference at the assignment level** + exposure-robust or randomization inference
5. **Report honest-DiD and resolve the CSV/figure inconsistency**; re-run the pre-trend test without `outcome_pre4 × year`
6. **Address the December 2012 timing** — re-center on event time relative to first post-reform filing
7. **Rescale the tenure horse race**; fix origin-year group assignment
8. **Make the replication package match the paper** (per the repo's own `INVENTORY.md`) and fix the 62 LaTeX errors

**Do 1 and 3 first.** Both editors: they are cheap and they are the two that can end the project.

---

## What both editors credited

All 27 headline numbers match their tables; 48/48 pipeline outputs reproduce byte-identically; the stacked Wald test is correctly specified and was verified line by line in the code; pre-trends reported for every specification with the awkward ones flagged rather than buried; the Mincer residualization is the right design for the right reason; the data appendix is "exemplary"; the connectivity measure and its Figure 1 Panel B validation are "the best methodological work in the paper."

AER called the replication score of 85 "if anything, low."

---

## Where editors overruled their own referees

- **AER vs R1:** R1 said losing the 40% claim collapses the contribution to "Lagos with a different control group." The editor disagreed and told the authors to push back — the spillover is identified off continuous variation in C across the full untreated sample, not off the Panel A/B contrast. Advice: stop *leading* with the 40% number.
- **JOLE vs R2:** declined to let the replication-package complaints move the decision — "not scientific evidence about whether the paper is right."
- **JOLE vs R1:** declined to require an aggregate spillover estimate — a linear extrapolation across a distribution that is 46% zeros is exactly what the dose-response evidence puts in doubt.

---

## Bottom line

The research is publishable; this draft is not yet submittable, and AER is out of reach on this reform given Lagos. JOLE is live but conditional on one test the authors have not run: does the spillover survive excluding intra-company flows? Run that before anything else on either list.
