# RM breakdown values in the applied literature — funnel (Task 1.1–1.2)

Goal: among papers citing Rambachan–Roth (>1,800 cites), find **applied empirical** papers that
implement a **breakdown value** (relative-magnitudes M̄ for ΔRM, or smoothness M for ΔSD), and
within those, ones reporting a **low / below-1** threshold that they still treat as publishable —
then record *how* they frame it. This gives a model for our own write-up (spillover log-wage
M̄ ≈ 0.75 first post period / 0.29 average post period).

Status: **VERIFIED.** PDF text was extracted locally with `pdftotext` (WebFetch's binary handling
failed). All M / M̄ numbers below are quoted verbatim from the source PDFs. URLs cited per row.

---

## Confirmed examples — LOW breakdown value, still reported and interpreted

| Paper | Setting + main result | Restriction & breakdown value | <1? | How they frame it |
|---|---|---|---|---|
| **Torul et al., "Defense Procurement and Local Wage Spillovers"** (Boğaziçi WP). URL: https://web.bogazici.edu.tr/torul/defpro.pdf | Local wage **spillovers** from U.S. defense procurement to non-manufacturing workers (county×quarter, local projections, 2021–2025). Headline: positive spillover to ln(WageNonMfg). | **Relative-magnitudes-style M\*** (their own breakdown formula `M* = (|β̂|−1.96σ̂)/maxₚ|β̂q|`, "largest unobserved post-treatment differential trend in multiples of the worst pre-period coefficient"): **M\* = 0.63 (h=0), 0.55 (h=1), 0.50 (h=4)** for ln(WageNonMfg). | **Yes, all <1** | **(b) translates M into the implied confounding shock + (d) economic honesty.** Verbatim: *"Because the worst pre-period coefficient is 0.00083, M\* = 0.50 implies that an unobserved post-treatment differential trend of 0.00042 per quarter—roughly half the magnitude of the largest pre-period deviation—would render the h = 4 LP estimate indistinguishable from zero. **This is a tight, not generous, bound: the result is fragile to large unobserved trends but survives modest ones in the range observed in our pre-period.**"* They concede pre-trends are formally rejected and explicitly do **not** claim unconditional parallel trends; the honest-DiD bound is one of several converging robustness checks (placebo, permutation, IV). They also use M\*=0 as a disqualifier: manufacturing outcomes get M\*=0 ("naive 95% CI already contains zero") and are reported "for completeness" but **not interpreted**. |
| **Baker, Halberstam, Kroft, Mas, Messacar, "The Impact of Unions on Wages in the Public Sector"** (NBER WP w32277, Mar 2024 rev. Feb 2025; AERI). URL: https://www.nber.org/system/files/working_papers/w32277/w32277.pdf | **Union** wage effects, public-sector (Canadian higher-ed faculty), Callaway–Sant'Anna event study. Headline: unionization raises base pay ~ several % growing over 6 yrs. | HonestDiD on the CS estimator (Fig S7). **Breakdown value "around 0.4."** Restriction type not stated explicitly in body text (figure note describes the standard CS+HonestDiD postestimation; most consistent with relative-magnitudes default, but **flagged as not fully specified**). | **Yes (~0.4)** | **(a) report directly, briefly, (d) lean on the broader pre-trend evidence.** Verbatim: *"while our evidence provides little evidence of a violation of our assumption of common pre-trends, to further assess this assumption, we construct robust confidence intervals following the method of Rambachan and Roth (2023)… **The so called 'breakdown value' is around 0.4.**"* Sentence is truncated in the circulated PDF ("0.4. With"); they frame HonestDiD as a *supplementary* check layered on top of clean visual pre-trends, not as the load-bearing identification argument. They do **not** defend 0.4 against a ">1" yardstick or contextualize it as an implied shock. |

---

## Closest design analogue — spillover paper, but NOT a low-breakdown example

| Paper | Why relevant | What it actually shows |
|---|---|---|
| **"Big Wins, Small Net Gains: Direct and Spillover Effects of First Industry Entries in Puerto Rico"** (arXiv 2511.19469). URL: https://arxiv.org/abs/2511.19469 (PDF: https://arxiv.org/pdf/2511.19469) | Cites Rambachan–Roth (2023); explicit **direct + spillover** DiD design (CS for direct, doubly-robust DR–DiD for spillover) — structurally our closest analogue. | Uses the **smoothness ΔSD(M)** restriction (not RM), bounding curvature "in standard-deviation units," and applies it **only to the DIRECT effect** (cumulative 0–16q ATT on log covered employment = 2.317 log pts). That result is **robust even at M = 0.10** ("zero is excluded… at all curvature levels"): a *high*-breakdown, strong result — opposite of our case. The **spillover** effect (SATT[0,16] = −0.110) is **statistically insignificant under every inference method** (SE > |estimate|), so it never reaches HonestDiD. **No low breakdown value to borrow; gives no rhetorical cover.** Note: they motivate SD over RM as "well suited to settings with potentially accelerating dynamic responses," citing Roth et al. syntheses. |

---

## Counter-examples — strong (≥1) breakdown values, for calibration of "what good looks like"

| Paper | Restriction & breakdown | Note |
|---|---|---|
| **Sosinskiy (& Reich), "$20 Minimum Wage"** (IRLE Berkeley WP, 2025). URLs: https://irle.berkeley.edu/wp-content/uploads/2025/09/20_Minimum_Wage_in_CA_September-7-2025.pdf ; https://irle.berkeley.edu/publications/working-papers/sectoral-wage-setting-in-california/ | **Relative-magnitudes M̄**, displayed as M̄ varies 0→1.4. Log-wage effect **significant at every M̄ up to 1** (breakdown ≥ 1). | A *robust* labor result: they can show the CI excludes zero across the whole M̄∈[0,1] range, so they present the full curve confidently. This is the presentation style available when the breakdown is high — **not** available to us. |

---

## Candidates checked and dropped / not qualifying
- "Are Politicians Responsive to Mass Shootings?" (arXiv 2501.01084) — uses honestdid but not labor/wage; not extracted (off-topic for our funnel).
- "The Structural Bite" min-wage Spain (arXiv 2603.20809) — uses HonestDiD framing ("consistent with a continuation of pre-existing growth trajectories") but no clean low breakdown value isolated; not a wage-spillover analogue.
- Sun-Abraham / CS package vignettes and ACA-Medicaid examples — illustrative, not low-breakdown publishable cases.

---

## Method-framing notes (for our write-up)
- **M̄ (ΔRM, relative magnitudes)** = ratio of the max post-period differential trend to the max pre-period violation. A breakdown M̄ < 1 means the result dies if the post-period confounding trend is allowed to be even *smaller* than the worst pre-period wiggle — by construction a "fragile" region in the profession's vocabulary (confirmed across multiple HonestDiD explainers).
- **M (ΔSD, smoothness)** bounds the second difference / curvature of the trend (often in SD units). Choose RM when you want to discipline post-period violations *by* the observed pre-period magnitudes (natural for our spillover design where pre-trends are the relevant benchmark); choose SD when the concern is accelerating/nonlinear dynamics. The Puerto Rico paper picks SD for exactly that reason — a clean line to cite when justifying RM vs SD.
- **The persuasive move in the one genuinely-comparable low example (Torul) is economic contextualization, not number-defense:** translate the breakdown M into the *size of the per-period confounding shock* it implies, then argue that shock is implausibly specific/large relative to what the pre-period actually shows. Critically, Torul does **not** pretend <1 is fine — they call it "tight, not generous… fragile to large unobserved trends but survives modest ones in the range observed." Honesty + triangulation (placebo, permutation, IV), not bravado.
- Useful external anchors on "what counts as a benchmark for M": Dustmann et al. (2022), Fenizia & Saggio (2024) — already in our bib.

---

## Bottom line (honest)
Applied papers that report a **relative-magnitudes breakdown value below 1 and still treat the result
as interpretable are RARE** — that scarcity is itself the finding, and it suggests the profession
largely filters low-RM results out (the available high-profile labor examples, e.g. Sosinskiy's $20
min wage, are exactly the ones whose breakdown sits at or above 1, which is why they can show the full
M̄∈[0,1] curve confidently). The literature gives us **limited but real cover**: the Torul defense-procurement
**wage-spillover** paper (M\* = 0.50–0.63, our closest analogue) and the NBER public-sector **union**
wage paper (≈ 0.4) both report sub-1 breakdowns in print. The **dominant — and most defensible —
rhetorical move is to NOT defend the bare number against a ">1" yardstick, but instead (i) translate
the breakdown into the implied per-period confounding trend and argue that specific shock is
implausible, (ii) frankly label the bound "tight, not generous," and (iii) lean on converging
independent checks (placebos, permutation/randomization inference, alternative estimators/IV) so that
HonestDiD is one leg of a triangulated argument rather than the sole identification claim.** We should
mirror Torul: report M̄ ≈ 0.75 / 0.29 directly, convert them to the implied confounding shock, concede
fragility plainly, and surround the bound with our other robustness evidence.

## Next steps
- [x] Extract exact M values + framing quotes from Torul (Boğaziçi) and w32277 (NBER) — DONE, verbatim above.
- [x] Resolve the Puerto Rico spillover paper — DONE: it's an SD-restriction, *high*-breakdown direct effect; spillover is insignificant. No low-RM cover, but a clean citation for the RM-vs-SD choice.
- [ ] Optional: chase the un-truncated w32277 sentence (find the published AERI version) and confirm whether 0.4 is ΔRM or ΔSD — currently flagged unspecified.
- [ ] Optional: one more pure spillover labor paper with a sub-1 RM breakdown would strengthen the analogy, but the search suggests they are scarce; if the funnel stays thin, this scarcity supports presenting our number with the Torul-style economic-contextualization framing rather than apologizing for it.

---

## Broadened cross-field search (2026-06-28)

Goal of this pass: cast a **wide net across ALL applied micro fields** (not just labor/wages/spillovers)
for papers that cite Rambachan–Roth, implement a HonestDiD **breakdown value** (M for ΔSD smoothness,
or M̄ for ΔRM relative-magnitudes), and report a **relatively low / sub-1 value while still treating the
result as interpretable**. All M / M̄ values below are quoted verbatim from PDFs extracted locally with
`pdftotext` (URLs per row). Each row is tagged **[LABOR/WAGE/SPILLOVER]** (most relevant analogue) or by
its other field. Verified = number read in the source; UNVERIFIED = could not confirm the exact figure.

### A. The headline meta-finding (most important for the "profession doesn't filter" argument)

| Paper | Field | Setting + design | Restriction & breakdown value(s) | <1? | Framing |
|---|---|---|---|---|---|
| **Chiu, Lan, Liu & Xu, "Causal Panel Analysis under Parallel Trends: Lessons from a Large Reanalysis Study"** (American Political Science Review, vol. 120(1), Feb 2026; SSRN/arXiv). URLs: https://arxiv.org/abs/2309.15983 ; https://ssrn.com/abstract=4490035 | Political economy / methods **meta-study** | Re-analyzes **49 published TWFE studies** from leading political-science journals; for the **42** with ≥3 pre-periods, computes the ΔRM breakdown value M̃ (smallest M̄ at which the robust CI first includes zero), benchmarking post-period violations against **placebo-period** discrepancies. | **ΔRM (relative magnitudes), breakdown M̃.** Verbatim: *"Among the 42 studies, the median is close to 0 and the mean is 0.33. Focusing only on the studies that remain statistically significant with the imputation estimator, the median and mean are still as low as 0.10 and 0.47, respectively."* Figure 6 labels: **All Feasible (42): Median = 0.01**; significant-subset **Median = 0.10**. At **M̄ = 0.5 the null is rejected in only 8 (19%) of 42 studies.** They also report **Grumbach & Sahn (2020) breakdown M̃ = 2.5** as the rare "highly robust" case. | **YES — overwhelmingly.** Median published breakdown ≈ 0.01–0.10. | This is direct, large-sample evidence that **sub-1 (indeed sub-0.5) breakdown values are the norm, not the exception, in published applied work**. Their own gloss: *"in the vast majority of these studies, accounting for potential PT violations—even very mild ones … prevents us from rejecting the null."* They do **not** retract those papers; they recast HonestDiD as a power/robustness diagnostic. Mirrors Yiqing Xu's public summary that *"few of the remaining studies are robust to very mild violations of the parallel trends assumption."* **This is the single strongest citation that a low breakdown is normal and publishable.** |

### B. Individual cross-field papers reporting a sub-1 (or ~1 borderline) breakdown and still interpreting

| Paper | Field | Setting + main result | Restriction & breakdown value | <1? | Framing |
|---|---|---|---|---|---|
| **Berkes, Coluccia, Dossche & Manera (?), "When Shocks Divide: Religiosity and Science in the Time of Adversity"** (working paper). URL: https://dcoluccia.github.io/docs/DealingWithAdversity.pdf | Political economy / economic history (1918 influenza → religiosity & innovation; JEL J24, N13, Z12) | Event-study DiD: pandemic exposure raised both religiosity and science orientation, widening polarization. | **ΔSD (smoothness), M.** Verbatim: *"The estimates remain significant at the 90% level for values of M below 0.1, suggesting that our results are robust to low power of pre-trends tests and nonlinear violations of parallel trends."* | **YES (M < 0.1)** | **(a) report directly + (d) lean on convergent evidence.** They present the sub-0.1 smoothness breakdown as supportive ("robust to … nonlinear violations") and surround it with placebo/specification checks ("coefficients remain virtually unchanged"). A very low M treated as adequate at the 90% level. Note: uses ΔSD, so M is in curvature units, not directly comparable to our M̄. |
| **Biliotti, Bargagli-Stoffi, Fraccaroli, Puliga & Riccaboni, "Breaking Down the Lockdown: The Causal Effects of Stay-At-Home Mandates on Uncertainty and Sentiments During COVID-19"** (arXiv 2212.01705, rev. 2023; IMT Lucca / Harvard / Brown). URL: https://arxiv.org/pdf/2212.01705 | Political economy / text-as-data (Italian Feb-2020 lockdown; Twitter sentiment, staggered DiD) | Lockdown raised health/policy uncertainty and negative political sentiment. | **ΔRM (relative magnitudes), M̄.** Verbatim: *"By allowing up to 1.5 times the maximal violation in pre-treatment trends we still retain a robust significant effect for uncertainty and negative sentiments towards health and the policy, and up to 1 time for negative sentiments towards politics."* The politics-uncertainty outcome is *"not robust to any violations."* | **Borderline: M̄ = 1.0** for the negative-politics-sentiment outcome (and =1.5 for others) | **(a) report directly, outcome-by-outcome + uses M̄=0 as disqualifier.** They explicitly interpret outcomes that survive only to M̄=1 (the RR "natural benchmark") as still informative, while flagging the M̄≈0 outcome as significant "only … [under] zero violations." Shows the standard move of accepting results at the M̄=1 boundary, not demanding M̄>1. |
| **(Single-author) "Large-Scale Land Acquisitions, Elite Capture, and Dissent"** (arXiv 2606.09642, 2026). URL: https://arxiv.org/pdf/2606.09642 | Development / political economy (land deals → civic protest, 50 km buffer) | Land acquisitions raise local protest activity. | **ΔRM, breakdown M = 4.99** (Figure 4). | **No (4.99 ≫ 1)** | **Calibration point for "what a robust result looks like."** Verbatim: protest effect *"maintains statistical significance under substantial violations of parallel trends, well beyond the M = 1 benchmark."* Useful contrast: when a result really is robust, authors say so loudly with a high M — so the *absence* of such language elsewhere is informative. |

### C. Health — a cautionary "breakdown ≈ 0 / not robust" case (NOT a low-but-usable example)

| Paper | Field | What it shows | Restriction & value | Note |
|---|---|---|---|---|
| **"Heart Failure's First Shock and Nurse-Led Chronic Care"** (arXiv 2603.23024, Univ. of Bologna). URL: https://arxiv.org/pdf/2603.23024 | Health economics (nurse-led chronic-care program; Sun–Abraham staggered event study) | Program raises preventive-care engagement. | **ΔRM, M ∈ {0, 0.5, 1, 1.5, 2}.** Verbatim: *"the HonestDiD 95% robust confidence intervals include zero for all outcomes across sensitivity values M ∈ [0, 2], including the benchmark case M = 0."* | **Breakdown effectively ≤ 0** (CIs include zero even at exact parallel trends). They **downgrade to "suggestive rather than definitive"** rather than claim a causal effect. This is the "honest retreat" template: when the breakdown is *truly* at/below zero, authors soften claims — distinct from our case, where M̄ ≈ 0.75 (first post) excludes zero up to a real, if modest, threshold. Good contrast to show our result is *not* in this zone. |

### Field coverage summary (verified this pass)
- **Political economy / methods:** Chiu–Lan–Liu–Xu meta-study (median breakdown ≈0.01–0.10 across 42 published papers) — the load-bearing citation.
- **Economic history / political economy:** Coluccia et al. (ΔSD, M<0.1, interpreted).
- **COVID / text-as-data political economy:** Biliotti et al. (ΔRM, M̄=1.0–1.5, interpreted outcome-by-outcome).
- **Development / political economy:** Land Acquisitions (M=4.99, robust calibration point).
- **Health economics:** Heart-Failure/NPCP (breakdown ≈0, retreats to "suggestive") — cautionary contrast.
- Searched but no qualifying *new* low-breakdown extraction surfaced in: pure **trade/tariff**, **IO/firm productivity**, **urban/housing/migration**, **environmental/pollution/crime**, **finance/corporate**, **education**. The canonical Benzarti–Carloni (2019) **VAT/France** illustration used inside Rambachan–Roth is a *high*-breakdown teaching example, not a low one. (Absence here ≠ proof none exist; these fields use HonestDiD but rarely print the bare breakdown number, which is itself consistent with selective reporting.)

### Updated bottom line (after broadening)
**Sub-1 breakdown values are demonstrably common across fields once you look — and the broadened evidence
materially strengthens the case that reporting a low M̄ is acceptable.** The decisive new result is the
**Chiu–Lan–Liu–Xu (APSR 2026) reanalysis of 42 published studies: the median ΔRM breakdown value is ≈0.01
(≈0.10 even among the still-significant subset), and at M̄=0.5 only 19% of these *already-published* papers
reject the null.** That is hard, large-sample evidence that the profession does **not** silently filter out
low-robustness DiD results — a large share of the published applied-micro corpus would, under a strict
HonestDiD yardstick, have breakdown values well below ours. Individual cross-field papers corroborate this:
Coluccia et al. interpret a ΔSD result robust only to **M < 0.1**, and Biliotti et al. interpret outcomes
that survive only to **M̄ = 1.0** (the RR "natural benchmark"). Combined with the labor/spillover anchors
from Task 1.1 (Torul M*=0.50–0.63; NBER public-sector union ≈0.4), our spillover **M̄ ≈ 0.75 (first post) /
0.29 (average)** sits comfortably *inside*, and often *above*, the range that published work routinely reports
and interprets. **Recommended framing is unchanged and now better supported:** report M̄ directly, translate
it into the implied per-period confounding shock (Torul style), concede fragility plainly, cite the
Chiu–Lan–Liu–Xu distribution to show a sub-1 breakdown is normal rather than disqualifying, and triangulate
with our independent robustness evidence. We are clearly **not** in the Heart-Failure "breakdown ≤ 0, retreat
to suggestive" zone — our first-post M̄ excludes zero up to a real, if modest, threshold.

### URLs (broadened pass)
- Chiu–Lan–Liu–Xu (APSR 2026): https://arxiv.org/abs/2309.15983 · https://ssrn.com/abstract=4490035
- Coluccia et al., "When Shocks Divide": https://dcoluccia.github.io/docs/DealingWithAdversity.pdf
- Biliotti et al., "Breaking Down the Lockdown": https://arxiv.org/pdf/2212.01705
- "Large-Scale Land Acquisitions…": https://arxiv.org/pdf/2606.09642
- "Heart Failure's First Shock…": https://arxiv.org/pdf/2603.23024
- Yiqing Xu summary thread: https://x.com/xuyiqing/status/1802899839451275334

---

## Restriction type matters: ΔRM (M̄) vs ΔSD (M) — manual deep-dives (2026-06-29)

**The single most important practical point from the manual paper reads.** Rambachan–Roth have two restriction classes, and their "M" parameters are *different objects in different units* — you cannot compare the numbers across them:

| | **ΔRM — relative magnitudes (M̄)** | **ΔSD — smoothness (M)** |
|---|---|---|
| Bounds | post-period violation ≤ M̄ × (largest pre-period violation, in first differences) | second difference (curvature): \|δ_{t+1} − 2δ_t + δ_{t−1}\| ≤ M |
| Units | **unitless ratio** (a multiple of the worst pre-period jump) | **outcome units** (per-period change in slope) |
| Natural benchmark | **M̄ = 1** (post violation = worst pre violation) — the R&R reference | case-specific; some scale M to **1×SE** of the coefficient |
| Who uses it | **OUR paper** (spillover M̄ ≈ 0.75 / 0.29) | most applied examples below |

⇒ For the **number** comparison, only ΔRM sources are admissible (Chiu et al. meta-study; Torul). For **presentation**, the best models are ΔSD papers (Truffa–Wong). Do not line up a ΔSD "0.01" or "0.05" against our ΔRM 0.75.

### Bucketing of every paper examined

| Paper | Restriction | Breakdown | Notes |
|---|---|---|---|
| Chiu–Lan–Liu–Xu (APSR) | **ΔRM** | median ≈0.01–0.10 across 42 published studies | the comparability anchor; our 0.75 is *above* the published norm |
| Torul (defense wage spillovers) | ΔRM-style M* | 0.50–0.63 | translates M into implied per-quarter confounding shock; **framing template** |
| Sosinskiy ($20 min wage) | ΔRM (M̄) | ≥1 | the confident "show whole curve" style we can't use |
| **Dahl–Knepper** (SH merit, NC UI reform) | **ΔSD (M)** | **0.05** (NC), 0.03 (moderate) | see deep-dive below |
| **Merchants of Death** (hospital/credit) | **ΔSD (M)** | survives to ~1×SE for main outcomes | M scaled to coefficient SE; well-documented; applied only to F-test failures |
| **Truffa–Wong** (gender diversity/research) | **ΔSD (M)** | 0.010 / 0.015 / **0** | gold-standard documentation; see deep-dive below |
| Coluccia ("When Shocks Divide") | ΔSD | robust below 0.1 | curvature units; not comparable to M̄ |
| Biliotti ("Breaking Down the Lockdown") | ΔRM | survives to M̄=1.0 | borderline (at 1.0, not below) |

### Deep-dive 1 — Dahl–Knepper, "Why is Sexual Harassment Underreported?" (AER 2026, vol.116(3))
- Table A17 = **smoothness (ΔSD)**; outcome confirmed in the main text (p.929) as **merit** (charge quality) for the NC UI reform (cols 1–2) and moderate reforms (cols 3–4). Files: appendix `24257.pdf`, main `dahl-knepper-2026-…pdf` (Figure 6 panel B = the NC merit event study).
- **Authors' own gloss:** M = 0.05 ⇒ "rule out violations up to a **5 percentage-point decline in merit**" (NC); 0.03 (moderate). So M is in the OUTCOME's units (merit is a 0–1 fraction), **NOT** "5% of the pre-trend" — confirms the original intuition. The "5pp" gloss is loose (it's a curvature/2nd-difference bound; level deviation compounds at longer horizons).
- **Pre-period 2nd differences ≈ 0.** Reading Figure 6b, pre-period merit coefs ≈ {+0.03, +0.02, +0.01, 0} — nearly linear. So the observed curvature is ~0, M=0.05 is *large* relative to it, and the effect already survives at M=0 (A17 CI [0.033, 0.139]). Their "not particularly sensitive" claim is defensible **because the pre-trend is clean** — not because 0.05 is intrinsically big.
- LESSON for us: a low-looking ΔSD breakdown is benign when the pre-trend is linear. The analogous diagnostic for OUR low ΔRM M̄ is Task 1.3 (is the low M̄ driven by genuine pre-period curvature / a specific firm/year, or just a thin/noisy pre-period?).

### Deep-dive 2 — Merchants of Death (Aghamolla et al., AER 2024). Files: main `aghamolla-…-merchants-of-death.md`, appendix `21636.pdf` (§B, Table B.3)
- **ΔSD (M), scaled to the coefficient's standard error** (0 → 1×SE, reported at 0/25/50/75/100%×SE), period-by-period for t=2,3,4. Applied ONLY to the 2–3 outcomes that failed a pre-trend F-test (bed utilization, pneumonia readmission).
- Results mostly survive to M = 1×SE (a *robust*, not low, showcase). Weakest: pneumonia readmission PSM (borderline). This is the SE-scaling that Dahl–Knepper's raw "0.05" lacked — a clean benchmark device.

### Deep-dive 3 — Truffa–Wong, "Undergraduate Gender Diversity…" (2025). Files: main `truffa-wong-2025-…pdf`, appendix `22966.pdf` (§F.2)
- **ΔSD (M)**, breakdown **0.010 baseline, ~0.015 incumbent/male, 0 female incumbent** (→ cannot reject null; openly stated).
- **GOLD-STANDARD presentation:** (1) justifies smoothness on economic grounds ("secular trends in gender norms… evolve smoothly"); (2) translates the bare number — M=0.010 ⇒ in their Poisson model a change in the growth-rate slope of e^0.01−1 ≈ **1% between consecutive periods**; (3) reports per-subgroup including the failures. This is the template to imitate.

## Presentation templates for OUR §1.4
1. **State the restriction and justify it** — we use **ΔRM** because the pre-period worker-flow violations are the natural yardstick for the spillover (Truffa–Wong justify ΔSD by the opposite logic; cite the Puerto Rico paper for ΔSD-choice contrast).
2. **Report M̄ period-by-period + the average** (our honest_did already emits p1…p5 + avg).
3. **Translate M̄ into the implied confounding trend** (Torul move) and benchmark against M̄=1.
4. **Anchor to the published distribution** (Chiu et al. median ≈0.01–0.10 ⇒ our 0.75/0.29 is above the norm).
5. **Be honest** about which post-periods are weaker (Truffa–Wong model).

## ⚠️ Benchmark note + a miscitation to avoid
- **M̄'s natural benchmark is 1** (R&R), interpreted against the *pre-period* violations — NOT against the coefficient's standard error. The "1×SE" device is a **ΔSD-M** convention (Merchants of Death), not an M̄ rule.
- **MISCITATION (do not repeat):** an Economic Modelling 2025 supplement (`1-s2.0-S0264999325002548-mmc1.pdf`, Figure D1) states "the maximum value of M̄ is calibrated to one standard error of the coefficient of interest, as recommended by Biasi and Sarsons (2021)." This does not check out: (a) **dimensional category error** — M̄ is a unitless ratio, "1 SE" is in outcome units (that's the ΔSD-M convention); (b) **unsupported attribution** — Biasi–Sarsons (QJE 2022 gender-gap paper, `qjab026.pdf`) contains **no** Rambachan–Roth / honest-DiD / M̄ / smoothness content; its only "Roth" is Jonathan Roth's *empirical* Wisconsin Act-10 paper, cited for teacher-retirement facts. (Residual caveat: only the published main article was checked, not any separate B&S online appendix; but the dimensional point stands regardless.) ⇒ **Do not adopt "bound M̄ by 1 SE."**
