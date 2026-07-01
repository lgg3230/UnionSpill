# PROGRESS — UnionSpillovers to-do (opened 2026-06-26)

Tracking file for the current 4-task list. One block per task.
Status legend: ☐ not started · ◐ in progress · ☑ done · ✖ dropped/blocked

Each block carries a **precondition pass** filled in *before* coding:
- **Data** — which file/source, does it reach the needed coverage/density, what reconciliation it must pass
- **Acceptance** — what "done" looks like (a file, a number, a figure), with a numeric anchor where possible
- **Conventions** — project rules that apply (terminology, formatting, sample defs)

Conventions that apply project-wide: outcomes are **"log wages"** (`lr_remdezr_w`) / **"log hourly wages"** (`lr_remdezr_h_w`), never "earnings". Direct effects use **Sample A** (`s_direct_A` / Panel A), spillover uses `s_spill`. No "fragile"/"VERY FRAGILE" labels in figures. Coefplot formatting per `Cluster/UnionSpill/CLAUDE.md`. Two repos: code = `lgg3230/UnionSpill`, paper = `lgg3230/UnionSpill_paper` (Overleaf bridge — watch for `overleaf-*` branch collisions).

## LIVE STATUS — updated 2026-07-01
Active list from the 2026-07-01 meeting (this supersedes the 4-task framing below; the detailed blocks + session logs still hold the history). Legend: ☑ done · ◐ in progress · ☐ todo. **"Clódio" in meeting notes = Claude** (answer methodological questions here, not an external person).

1. **Parallel-trends verdict (RM presentation)** ◐ — lit funnel DONE (`Programs/honest_did/rm_literature_review.md`; Chiu et al. 2026 distribution = load-bearing cite; Torul / Truffa–Wong = framing templates). TODO: write the subsection — honest but confident, figures→appendix, decide whether to state the magnitude. [old block: Task 1.4]
2. **6-column balance table (control-effectiveness)** ☑ — BUILT + integrated into the paper this session (see 2026-07-01 log). Method (2009/2010 lag) confirmed. [old block: Task 2]
3. **CBA similarity test (first pass)** ☐ — Luis's preferred next; could shift the paper's story. Scaffolding under `Programs/cba_similarity/`. Not started.
4. **Amenities + direct-effect autocorrelation** ☐ — repass amenities (null supports the labor-competition story); assess whether to present spillover-only. [old block: Task 3]
5. **Ben strategy chat** ☐ — tee up a recommendation on parallel-trends presentation + whether to drop the direct effect.
- (aside) **Winsorization robustness** ☑ — results robust. [old block: Task 4]

NEXT UP: (1) parallel-trends write-up, then (3) CBA similarity first pass.
OPEN: paper repo has a local commit (balance table, 27dac87) awaiting push approval; code-repo (`lgg3230/UnionSpill`) changes from Task 2 not yet committed.

---

## Task 1 — RM robustness: learn how the literature handles low breakdown values, then present ours  ☐
Highest-judgement task. Sequence: 1.1/1.2 (lit) → 1.3 (diagnostic, only if lit thin) → 1.4 (write-up).

**1.1–1.2 Literature funnel** ☐
- Funnel: papers citing Rambachan–Roth (>1,800 cites) → applied empirical → actually implement an **RM breakdown value** → report a **low / below-1** threshold and still treat the result as publishable.
- For each hit: paper, setting, main result, the RM value / how discussed, framing (acceptable / marginal / fragile / economically contextualized), RM-vs-alternative motivation.
- **Data:** web research (WebSearch / citation tools). No project data.
- **Acceptance:** short internal summary "how the literature handles low RM values when it does" → `Programs/honest_did/rm_literature_review.md`.
- **Conventions:** n/a (research output).

**1.3 Diagnostic (only if 1.1/1.2 thin)** ☐
- Test whether a pretreatment idiosyncrasy inflates the deviation from parallel trends: a firm, a cluster of firms, an odd pre-year. Leave-one-out on the spillover event study; recompute the RM breakdown each time.
- **Data:** existing `Programs/honest_did/` inputs (`pretrends_results.csv`, `honest_did_results.csv`) + re-estimation via `honest_did.do`. Spillover spec = `s_spill`. Run locally per the local-Stata recipe.
- **Acceptance:** identify whether dropping any single firm/year/cluster materially raises M̄; document. Current spillover log-wage M̄ ≈ 0.75 (p1) / 0.29 (avg) is the baseline anchor.

**1.4 Revise RM section + figures** ☐
- Decide which RM result to show; explain the economic meaning of the breakdown value; parsimonious-but-slightly-optimistic subsection. Honest, not defensive, not self-destructive.
- **Data:** `UnionSpill_paper/Main_Results.tex` §"Sensitivity to Parallel Trends: Honest DiD"; figures in `Programs/honest_did/`.
- **Acceptance:** revised subsection + chosen figure/table, grounded in 1.2 precedent or 1.3 internal justification.
- **Conventions:** wage terminology; no "fragile" labels in figures (one in body prose at Main_Results.tex left intentionally).

---

## Task 2 — Connectivity descriptives: rebuild on the paper's controls, test if controls absorb the correlation  ☑ (DONE 2026-07-01)

**2.1 Rebuild descriptives on the paper's variables** ☑
- Use education, age, tenure, number of clauses, and the other actual regression controls — not generic descriptives.
- **Data:** firm-level panel with connectivity + those controls. Existing scaffolding: `Programs/descriptives/` (`firm_conn_scatter_prep.do`, `firm_conn_binscatter.py`, `conn_descriptives_note.md`). VERIFY which controls enter the main spillover spec before choosing the variable set.
- **Acceptance:** descriptive set (table/figures) covering the paper's controls vs connectivity.
- **Conventions:** coefplot/figure formatting per CLAUDE.md.

**2.2 Residualization / control-effectiveness test** ☑
- Show raw control–connectivity relationships, then residualized after the usual controls; evaluate whether controls meaningfully break the correlation.
- **Acceptance:** raw vs residualized comparison demonstrating (or not) that controls neutralize the problematic correlation. The point is whether controls *neutralize*, not whether correlation exists.

---

## Task 3 — Amenities mechanism: "direction in amenity space" test  ☐
Flagged highest-value by Guilherme. **Needs a design discussion before coding (3.2).**

**3.1 Sharpen the mechanism** ☐
- Statement: higher-wage firms carry a different amenity bundle; spillover firms may move *in that direction* even without raising total clause count → recomposition, not quantity expansion. (Connects to the extpre finding that the spillover wage effect is largely a composition effect.)

**3.2 Design + first-pass code** ☐
- Use cross-sectional **wage** variation to define the "direction" of amenity differences; test whether spillover firms move along it.
- **Data:** reuse `Programs/direction_convergence/` machinery (`direction_convergence_geometry.py`, benchmark prep) — but NOTE existing code defines direction by the connected-treated CBA-clause vector; this task defines it by the wage-implied amenity direction. New benchmark, adapted geometry. Needs clause-category panel + cross-sectional wage measure.
- **Acceptance:** TBD in design discussion — first-pass regression/figure testing whether spillover firms move along the wage-defined amenity direction.
- **Conventions:** wage terminology; figure formatting per CLAUDE.md.

---

## Task 4 — Winsorization robustness (low priority, low cost)  ☐
- Winsorize **worker-level** wages first, then aggregate to firm, compare to baseline. May reveal extreme wage obs driving unstable pretrends.
- **Data:** worker panel → firm aggregation path: `Programs/worker_wages/01_prep_data.py` + `Programs/121_get_wage_pctiles_df2.do`. Worker source `worker_year_pre_new_vs_nonnew_dec26.dta` (2009–2016, local).
- **Acceptance:** re-run Main_Results with winsorized wages; compare to baseline direct effects (≈0.021–0.030, all ***) and spillover. Report whether pretrends/effects shift.
- **Conventions:** wage terminology; Sample A for direct, `s_spill` for spillover.

---

## Parallelization map
- **Independent, can run concurrently:** Task 1.1–1.2 (web), Task 2 (Stata/py descriptives), Task 4 (Stata winsorization).
- **Needs interactive design first:** Task 3.2 (discuss before coding).
- **Internal dependencies:** 1.3 and 1.4 depend on 1.1/1.2 outcome; 2.2 depends on 2.1; 3.2 depends on 3.1 design.

---

## Session log — 2026-07-01 — Task 2 balance table BUILT + integrated; list reframed

**Task 2 (☑ DONE — 6-column control-effectiveness balance table).** Decisions: outcome-control window = **2009/2010 lag** (avoids same-period circularity; pre-determined-covariate rule — sound; precedents Borusyak–Hull–Jaravel 2022, Pei–Pischke–Schwandt 2019, standard regression-adjusted balance) and a **focused variable subset**.
- Build: `Programs/descriptives/balance_table_task2.do` → `Tables/descriptives/balance_table_task2.csv` (flag `outcome_ctrl_window` = 0910|full|none; the flows row drops its own-flows quartile control to avoid mechanical self-adjustment; ~8s local). `Programs/descriptives/generate_balance_table_task2_latex.py` → `Tables/descriptives/balance_table_task2.tex` (tenure & age in years).
- Results (window 0910) — raw→controlled collapse toward zero IS the argument: log wages +0.254***→−0.013***; age 1.47***→−0.04 ns; tenure 1.92***→+0.05 ns; # clauses 7.28***→+0.73*; flows (own-control dropped) −0.0085**; connectivity slope on log wages +0.009 ns. N all/zero/spill = 16,444 / 14,187 / 4,183.
- Paper integration (option A, `UnionSpill_paper`): replaced the univariate slopes table with `\input{Tables/balance_table_task2.tex}`; made the connectivity histogram spillover-sample only; removed the treated-firm figures + 4 orphan treated PDFs; killed the dangling `fig:conn_resid_treated` ref; anchored the two control binscatters. Local commit **27dac87**; PUSH PENDING approval.
- Cleanup: guarded treated-graph generation in `firm_conn_binscatter.py`, `firm_conn_scatter.py`, `firm_conn_residualize_plots.py`, `conn_descriptives/hist_connectivity.py`, and the treated-frame block in `firm_conn_residualize.do` (`local do_treated 0`).
- TODO next: commit code-repo changes (do-file + generator + guards) to `lgg3230/UnionSpill`; then push the paper commit.

## Session log — 2026-06-26

**Task 1.1–1.2 (☑ DONE):** funnel complete (research subagent, verified verbatim via pdftotext) → `Programs/honest_did/rm_literature_review.md`. VERDICT: sub-1 RM breakdowns that are still treated as publishable are **rare** (the profession largely filters them out — itself informative), but **limited real cover exists**: (1) Torul et al. defense-procurement WAGE SPILLOVERS — M\*=0.63/0.55/0.50 (h=0/1/4), our closest analogue and the framing MODEL to copy: translate breakdown into implied per-quarter confounding shock, call it "tight, not generous… fragile to large unobserved trends but survives modest ones," concede pre-trends rejected, triangulate (placebo/permutation/IV); (2) NBER w32277 public-sector unions — breakdown ≈0.4, reported directly+briefly, leans on clean visual pre-trends (RM-vs-SD type unverified). NOT cover: Puerto Rico spillovers (arXiv 2511.19469) uses ΔSD, only on the DIRECT effect (robust at M=0.10), spillover insignificant so never reaches HonestDiD — but a clean cite for justifying RM-vs-SD choice. Counter-example: Sosinskiy $20 min wage, breakdown ≥1 (the confident-full-curve style we can't use). → For Task 1.4: mirror Torul directly with our M̄≈0.75/0.29.

**Task 2 (◐) — scoped, ready to build:** existing `descriptives/` covers wages/emp/turnover/hiring/churn/retention/female/non-white but NOT the paper's controls (educ/age/tenure/# clauses) and does NO residualization — so this is additive. Two variable roles, both resolved:
- CHARACTERISTICS to add to the descriptive set: education = `no_hs_c`/`hs_c`/`sup_c` (no-HS/HS/college shares, firm-level, in panel ✓); tenure = `avg_tenure` (✓); # clauses = `numb_clauses` (✓); AGE = **not firm-level** in this panel — must aggregate mean worker age (`idade_w`) from `worker_year_pre_new_vs_nonnew_dec26.dta` by firm-year. (Plus the existing 8 characteristics.)
- CONTROLS to residualize on ("the usual controls" = main-spec FE, from `firm_conn_scatter_prep.do`): `identificad`, `i.industry1#i.year`, `i.mode_base_month#i.year`, `i.microregion#i.year`, `ib0.lr_remdezr_w_pre4#i.year`, `ib0.l_firm_emp_pre4#i.year` (cross-section ⇒ drop the ×year on the 2011 slice).
Plan: extend the prep do-file to add educ/age/tenure/#clauses, then for each characteristic compare the RAW connectivity slope to the slope CONDITIONAL on the main-spec controls (FWL: `reghdfe X conn, absorb(controls)`); controls "work" if the conditional slope collapses toward 0. Base panel local (185M).

**Task 4 (◐) — scoped, ready to build:** firm wage outcome = MEAN of worker-level log wages, built by `121_get_wage_pctiles_df2.do` (collapse (mean) `lr_remdezr_w lr_remmedr_w lr_remdezr_h_w lr_remmedr_h_w` by cnpj_year) from `worker_year_pre_new_vs_nonnew_dec26.dta` (1.8G, local, 2009–2016). Plan: winsorize worker-level wage levels (default 1/99 two-sided, within year) BEFORE the collapse → write to a NEW panel filename (must NOT overwrite canonical `lagos_sample_sep24_pct_unionexp_ext_df2.dta`) → re-run Main_Results on it → compare to baseline (direct ≈0.021–0.030***; spillover ≈0.005**). Default winsorization params pending user confirmation.

**Deferred:** Task 3 (design talk), Task 1.3/1.4 (await funnel outcome).

## Session log — 2026-06-29 — Task 1 manual deep-dives + lit-review consolidation
Read full papers (user-supplied PDFs in Docs/) and appended a consolidated section to `rm_literature_review.md`. KEY THEME: almost all applied examples use **ΔSD smoothness M** (Dahl–Knepper merit breakdown 0.05; Merchants of Death M up to 1×SE; Truffa–Wong 0.010/0.015/0), NOT our **ΔRM M̄** — their numbers are NOT comparable to our 0.75. Comparability anchor stays Chiu et al. (ΔRM). Best presentation template = Truffa–Wong (justify restriction on economic grounds + translate M into an interpretable per-period trend, e.g. their "1% growth-rate change/period" + report failures honestly). Dahl–Knepper A17: confirmed = merit/NC-UI-reform; authors gloss M=0.05 as "5pp decline in merit" (outcome units, NOT 5% of pre-trend); pre-period 2nd-differences ≈0 so the low breakdown is benign (clean pre-trend) — motivates our Task 1.3 diagnostic. FLAGGED MISCITATION: Economic Modelling 2025 supplement claims "bound M̄ by 1×SE, per Biasi–Sarsons" — false (B&S QJE 2022 has no honest-DiD content; and it's a dimensional category error: 1×SE is a ΔSD-M device, not an M̄ rule). DO NOT adopt "bound M̄ by 1 SE".

## Session log — 2026-06-28 — Task 1 funnel BROADENED
User asked to broaden the low-breakdown-value search (slip called it "task 2"; it's the Task 1 RM funnel). Narrow first pass found only 2 solid sub-1 examples; broadening across ALL applied micro fields (health/public/trade/IO/dev/educ/finance), not just labor, to build a body of precedent for the "1,800 cites ⇒ low-RM papers must exist" argument. Research subagent running (background), appending a "Broadened cross-field search" section to `rm_literature_review.md` (won't touch the verified table). Already-covered (excluded from re-search): Torul, NBER w32277, Puerto Rico, Sosinskiy.

DONE (broadened) — GAME-CHANGER FINDING: **Chiu, Lan, Liu & Xu, "Causal Panel Analysis under Parallel Trends" (APSR vol.120(1), Feb 2026)** reanalyzes 42 PUBLISHED DiD studies and computes their ΔRM breakdowns: **median ≈0.01 across all 42; ≈0.10 (mean 0.47) among still-significant; at M̄=0.5 only 19% reject**. Same restriction (ΔRM) ⇒ directly comparable ⇒ our spillover M̄≈0.75/0.29 sits INSIDE AND OFTEN ABOVE the normal published range; the profession does NOT filter low breakdowns out. This is the load-bearing distributional citation for Task 1.4 (replaces "2 thin anecdotes" with a distribution). Supporting: Coluccia et al. (robust below M=0.1, but ΔSD curvature units — NOT directly comparable), Biliotti et al. (survives to M̄=1.0, borderline). Contrasts: land-acquisitions M=4.99 (loud-robust), heart-failure ≈0 (true dead zone — our 0.75 well above it). Caveats for write-up: APSR is poli-sci (method/units match); ΔSD≠ΔRM; Biliotti is AT 1.0 not below. → Task 1.4 framing: report M̄ directly, translate to implied confounding shock (Torul style), cite Chiu et al. distribution, triangulate.

## Session log — 2026-06-26 (cont.) — Tasks 2 & 4 launched

**Age (Task 2):** recomputed firm-level mean worker age from `worker_panel_lagos.parquet` (the only local worker file with age) → `Data/RAIS_aux/firm_mean_age.csv` (131,776 firm-years, mean 37.4). The `worker_year_pre_new_vs_nonnew_dec26.dta` panel has NO age field; the parquet that had `idade_w` is not local.

**Education var confirmed:** `no_hs_c`+`hs_c`+`sup_c` = 1.0 exactly → genuine education shares (no-HS/HS/college). `avg_tenure` in months (~80). 

**Task 2 (☑ estimation done; table/figure polish optional):** `Programs/descriptives/firm_conn_residualize.do` ran clean (exit 0) → `Tables/descriptives/firm_conn_residualize.csv`. 2011 cross-section, spillover sample, 14 characteristics, RAW vs control-CONDITIONAL slope on normalized connectivity.
VERDICT: the main-spec controls NEUTRALIZE the identification-threatening dimensions — **firm size** (raw 0.060** → cond 0.008 ns, 87% gone), **wages** (already weak, raw ns), most of **%female** (53%). They do NOT absorb **turnover/hiring/churn/retention, avg tenure (−5.2→−4.8 mo***), worker age (−0.36→−0.40***), # clauses (0.68→0.57**)** — BUT connectivity is built from worker flows, so those residual correlations are close to MECHANICAL/definitional, not hidden confounds; and **education shows zero connectivity gradient (all ns raw & cond)**. Net: reassuring for identification. CAVEAT for write-up: size/wage absorption is partly mechanical (control set includes pre-wage & pre-emp quartiles). TODO (optional): LaTeX table + residualized binscatters.

**Task 4 (☑ DONE — results robust):** both do-files ran clean (exit 0) → `Tables/winsor/winsor_compare.csv`. BASELINE REPLICATION VALIDATES the from-scratch pipeline (reproduces headline exactly: direct lr_remdezr_w 0.0262***, lr_remdezr_h_w 0.0287***; spillover 0.0051**, 0.0066***). WINSORIZED (1/99 within year) vs baseline: direct effects essentially UNCHANGED (0.0262→0.0262, 0.0287→0.0287); spillover attenuates slightly (monthly 0.00507→0.00486, −4%, still **; hourly 0.00664→0.00609, −8%, still ***); PRE-TRENDS stay null in both. VERDICT: extreme wage obs are NOT driving the results or pretrends — findings robust to winsorization. winsor panel at `Data/CBA_rais_firm_level/winsor/` (gitignore-able). Original two-do-file detail below.

**Task 4 build detail:** two do-files. (1) `Programs/worker_wages/121_get_wage_pctiles_df2_winsor.do` — copy of 121 with worker log wages winsorized 1/99 within year before the firm collapse; writes to `Data/CBA_rais_firm_level/winsor/lagos_sample_sep24_pct_unionexp_ext_df2.dta` (separate dir, canonical panel SAFE). (2) `Programs/worker_wages/compare_winsor.do` — replicates the exact headline Panel-A direct + spillover pooled specs (base_fe + outcome_pre4×year + l_firm_emp_pre4×year + totalflows_pw_pre_07_114×year, conn=totaltreat_pw_norm) on baseline AND winsor panels for lr_remdezr_w + lr_remdezr_h_w; output → `Tables/winsor/winsor_compare.csv` (new dir, canonical tables SAFE). Background job bewkbjxvz (121 then compare, sequential). ACCEPTANCE: baseline replication should reproduce headline (direct ≈0.021–0.030***, spillover ≈0.005**); winsor column shows the shift.

Verified before launch: Stata binary present; `identificad` is string on both panels; `mmerge`+`reghdfe` installed.
