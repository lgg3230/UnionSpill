# Section 6.2 replication check — layer_connectivity_standalone package

*Gui, July 2026*

## What I did

I went through the standalone package (scripts, data, and the `output/` CSVs from the 13 May cluster run) to verify the two Section 6.2 appendix tables (A7, A8). My local Stata license has lapsed, so I re-implemented `01a` and `02a` in R/`fixest`, matching Stata conventions (type-2 percentiles, `egen cut, group(4)` bins, reghdfe singleton dropping, firm-clustered SEs). Validation: my pipeline reproduces the CSVs in the package's `output/` folder **exactly** — every coefficient, SE, placebo, N, and firm count to 4 decimals. So everything below is apples-to-apples.

## 1. The package does not reproduce the draft's tables

Neither the scripts nor the bundled outputs contain the numbers in the current draft:

| Cell | Draft | Package (code & CSVs) |
|---|---|---|
| A7 within-firm wage, edu (col 2) | −0.0023 (0.0044), N=52,458, 3,580 firms | −0.0129* (0.0069), N=31,670, 2,048 firms |
| A7 overall wage, edu (col 3) | 0.0029 (0.0025), N=59,391, 4,172 firms | −0.0004 (0.0045), N=32,493, 2,092 firms |
| A8 wage HS+ col, High-Skill | 0.0066** (0.0028), N=28,539 | 0.0019 (0.0029), N=27,651 |
| A8 firm-level wage, High-Skill | 0.0058** (0.0026), N=29,095 | 0.0022 (0.0023), N=28,227 |
| A8 emp No-HS col, Low-Skill | −0.0209** (0.0093) | −0.0100 (0.0107) |

The **data** in the package is the draft's data: I can reproduce every published cell of both tables (both A7 panels, all six A8 columns, including placebo rows and Ns) to 4 decimals from the bundled `.dta` files — but only after undoing spec changes that are hard-coded in the current scripts:

- **A7 (draft)** = full untreated balanced-panel sample, **no** group×year FE. The package's `01a` instead (i) restricts to above-median pre-treatment firm employment and (ii) adds `layer_id×year` FE. (Its header says "Same as `07b_layer_spillover.do` but restricted…" — `07b` is not in the package; I assume that's the paper-vintage script.)
- **A8 (draft)** = firm(-cell) FE + year FE + quartile-bin×year controls. The package's `02a` additionally absorbs `industry1×year`, `microregion×year`, `mode_base_month×year`.

**Question 1: which versions are intended?** If the draft stands, the package needs the paper-vintage scripts (`07b` + the pre-FE horse race). If the current scripts are your new preferred specs, the draft tables and text need regenerating — see below, because for A8 that changes the conclusions.

## 2. A8: the results don't survive the baseline FE structure

Table 2's notes say all specs include year FE × (industry, microregion, negotiation-month). A8 as published omits these; your current `02a` adds them — and that's exactly what eliminates both headline results (High-Skill wage 0.0066** → 0.0019; Low-Skill employment −0.0209** → −0.0100). I checked it's the FE, not the induced sample change: the published spec run on the FE-restricted sample gives −0.0204 (0.0093) / 0.0069 (0.0030), essentially unchanged.

Adding the FE blocks one at a time:

| Cell | published | +ind×yr | +micro×yr | +mode×yr | all |
|---|---|---|---|---|---|
| High-Skill wage (HS+ col) | 0.0066** | 0.0033 | 0.0040 | 0.0058** | 0.0019 |
| Low-Skill emp (No-HS col) | −0.0209** | −0.0192* | −0.0137 | −0.0199** | −0.0100 |

So the wage result is roughly half industry-, half region-trend; the employment result is mostly region-trend. Consistent with this, microregion FE alone explain 19–21% of the cross-firm variance in the group connectivity measures (industry 7–10%; all three ≈30%).

Related red flag visible in the published table itself: the placebo rows mirror the effects (emp No-HS: pre +0.0133 / −0.0154* vs post −0.0209** / +0.0144*; wage pre −0.0080*). The event study is worse: relative to 2011, the 2009 coefficients are +0.0216 (Low) / −0.0214 (High) — near-exact mirror images of the post effects, with a near-monotone drift through 2016. With two pre-years this looks like a continuing pre-trend / mean reversion at least as much as a treatment effect.

**Question 2: was adding the FE in `02a` a deliberate harmonization with the baseline?** If so, the low-/high-skill asymmetry subsection doesn't survive and needs rewriting (the null is arguably consistent with the section's broader message). If we want to defend the sparse spec, we need an argument for excluding region×year trends that the rest of the paper includes, plus something like a permutation placebo or longer pre-period.

## 3. A7: core result robust, two things to settle

- The within-firm **wage** null is robust everywhere (full sample: −0.0023 published spec → −0.0041 with group×year FE; gender 0.0001 → −0.0006). Good — and I'd argue group×year FE is the right spec (group-specific national trends, e.g. minimum-wage compression, otherwise load on the coefficient), so the fix strengthens the claim.
- But with group×year FE, the education within-firm **employment** cell becomes −0.0200 (0.0099) — nominally significant, with a mirror placebo (+0.0195). The draft's "employment shows no within-firm response either" is spec-sensitive; worth an event-study look before deciding how to phrase it.
- Note also the current code's within-firm wage output (−0.0129*) contradicts the draft's "small and centered near zero" — another reason to settle on one version.

## 4. Small code/reporting fixes (no effect on estimates unless noted)

1. **"Groups × firms" row in published A7 is wrong** (6,273; correct is 7,160 = 2×3,580). Cause: in the cell counter, `bys identificad layer_id (in_samp): gen cell_first = (_n==1 & in_samp==1)` — ascending sort puts out-of-sample rows first, so only fully-in-sample cells are counted. Fix: `_n==_N`. Same bug in `03a`. (Internal check: 6,273 cells can't generate 52,458 obs in 8 years.)
2. `in_layer_balanced_panel` is computed but never used, while the Section 2i comment claims the restricted set is layer-balanced. Decide which sample is meant.
3. P90 anchors are inconsistent within the package (layer connectivity scaled to the above-median subsample's P90; `firmrestr` firm connectivity to the full-sample P90).
4. Table-note wording: both group measures are scaled by the *pooled* P90 across the two groups (pooled 0.0312 vs no-HS 0.0210 / HS+ 0.0378). Pooled is the right choice for the horse race (keeps coefficients per-unit comparable) but the note should say so.
5. README describes the above-median variant as the main spec with no pointer to what the draft actually uses.

## Files

My replication scripts and full write-up are in `within firm/gui_check/` (`REPORT.md`; `scripts/*.R` — `run_spill2.R` for the A7 grid, `run_horse.R` for the A8 grid, `run_a8_source.R` for the FE decomposition, `run_diag.R` for the cell-count bug / event studies / clustering checks).
