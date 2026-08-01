### 2026-07-16 — strategist-critic
**Phase:** Execution (standalone `/paper-review`)
**Target:** UnionSpill-paper/Draft.tex
**Score:** MAJOR ISSUES (→ CRITICAL ERRORS if C1 unreconciled)
**Verdict:** 3 CRITICAL findings. C1: Panel A/B attenuation (0.0084) is 3.99x larger than the paper's own spillover can imply (0.0021) — orchestrator reproduced the arithmetic independently. C2: RI p for headline spillover spans 0.0001→0.241 across schemes; none reported (verified exactly). C3: Honest DiD reports p1 target (M̄=0.75) but headline estimand is pooled avg (M̄=0.29) — numbers verified, but reviewer's "spin"/"disclosure removed" framing overstated; downgraded to MAJOR with dissent recorded.
**Report:** quality_reports/2026-07-16_Draft_strategy_review.md

### 2026-07-16 — writer-critic
**Phase:** Execution (standalone `/paper-review`)
**Target:** UnionSpill-paper/Draft.tex
**Score:** 52/100 (categories 4,5,6,8; voice + compile not scorable)
**Verdict:** Paper would FAIL TO BUILD — siunitx commented out in the loaded .sty while Draft.tex:999 uses S[table-format] (orchestrator confirmed statically). Score decomposes as −21 pre-existing house preamble, −22 real defects, −5 prose rule. All 17 headline numbers traced to tables with zero mismatches; all 60 cite keys resolve.
**Report:** quality_reports/2026-07-16_Draft_proofread_report.md

### 2026-07-16 — verifier
**Phase:** Execution (standalone `/paper-review`)
**Target:** UnionSpill-paper/Draft.tex
**Score:** PARTIAL (compilation NOT PERFORMABLE — no LaTeX toolchain on cluster)
**Verdict:** Orphan \ref{tab:spillover} at Draft.tex:988 renders "Table ??" (independently found by writer-critic). Draft.tex has never been compiled in this tree (no .aux/.log/.pdf). 15 live figures all resolve; 60 cite keys 0 undefined; 40 labels 0 dupes; 104/104 environments balanced. Advisory: two headline event-study figures have no traceable generator (INV-22 risk).
**Report:** quality_reports/2026-07-16_Draft_verification_report.md

### 2026-07-16 — writer-critic (proofread pass)
**Phase:** Execution (standalone `/paper-review --proofread`)
**Target:** UnionSpill-paper/Draft.tex
**Score:** 74/100 (proofread-only: categories 4,5,6,8)
**Verdict:** Found a confirmed DATA ERROR: tab:turnover Panel A "Log Hours" mean prints 7.2869 (the spillover panel's value); correct value is 6.1516 per results_direct_panelA_turnover.csv. 13/14 cells correct — table is hand-assembled because generate_turnover_latex.py emits direct A/B/C, not direct+spillover. Also RESOLVED all three of the author's % VERIFY flags against the Stata code: (821) outcome bins ARE included — note is wrong; (866) same; (1087) negotiation month = modal base_month from Lagos registry, minmode — neither filing nor start date. Line 988 group-wage bins wrong for employment columns. 26 missing ~\ref ties; collectively-bargained (8x) violates CMOS 7.86.
**Report:** quality_reports/2026-07-16_Draft_proofread_detail.md

### 2026-07-16 — orchestrator (apply corrections)
**Phase:** Execution
**Target:** UnionSpill-paper/Draft.tex + Packages/lgag_eesp-paper.sty
**Score:** N/A
**Verdict:** Applied 42 confirmed corrections; pushed to Overleaf as 0c0159b. Build blocker fixed (siunitx was commented while tab:horse_race uses S columns). Data error fixed (tab:turnover Panel A Log Hours 7.2869 -> 6.1516, was the spillover panel's value). All 3 %VERIFY flags resolved against Stata code. ⚠️ Coauthor had pushed 3 Overleaf commits the same day (pairwise-connectivity rename + robustness-section rewrite); rebase hit 10 conflicts, so aborted and replayed fixes onto their head instead — their work preserved verbatim, verified (pairwise x5, bilateral x0). 5 fixes obsolete after their rewrite; 2 of my own flags were false positives ("unexpectedly" matched by substring grep; \citet{borusyak} now correct textual use). NOT applied (author decisions): JEL codes, C1 Panel A/B claim, RI suite, Honest DiD avg target.
**Report:** quality_reports/2026-07-16_Draft_proofread_detail.md

### 2026-07-29 14:20 — Auditor (within-firm A6/A7/A8)
**Phase:** Execution (audit, no fixes)
**Target:** `Programs/layer_connectivity/07_within_firm/` + A6/A7/A8 in `UnionSpill-paper/Draft.tex`
**Score:** N/A (audit)
**Verdict:** Two questions, two answers. (1) The SE drop is benign — divisor moved from pooled-group p90 (edu2 0.03118 / gender 0.02961 / ten2 0.04490) to firm p90 (0.02932); SE ratio == divisor ratio in all 12 cells, every t identical to 3dp. Tenure's 35% drop is units. (2) THE REAL ISSUE: A8 forces two regressors onto that common divisor despite 4.9x different natural scales (lt12mo own p90 0.0688, ge12mo 0.0139), compressing lt12mo to 42% and inflating ge12mo to 205%. Individual t's are scale-invariant (2.41 / 0.46) so "ge12mo raises wages" is robust, but the EQUALITY test is not: p = 0.078 (firm) / 0.175 (per SD) / 0.721 (own p90). ge12mo's coefficient extrapolates to 2.1x its own p90. The Main_Results.tex rationale ("its p90 is an inflated denominator") is inverted — ge12mo's p90 is the smallest of all six. Draft.tex prints only 0.078. Also: A7 note's "<7%" claim is false for tenure (34.7%); within-firm coefficients differ <=0.023 SE between Stata and R but flip 6/24 A7 printed digits and the headline tenure p (0.078 vs 0.079); tenure is construction A (focal-firm tenure) so ge12mo connectivity is outflow-only; hourly A6 wage row corrupted by the monthly number format. Re-run reproduces tracked CSVs byte-for-byte; all 168 Draft.tex numbers match.
**Report:** `quality_reports/audits/2026-07-29_within_firm_audit.md`

### 2026-07-29 15:40 — Auditor (hourly group-level SE anomaly — RESOLVED)
**Phase:** Execution (diagnosis, no fixes)
**Target:** `lr_remdezr_h_layer` in `00_pipeline/06z_prep_outcomes_unified.py:131` (also `06a:71`, `06b:97`)
**Score:** N/A
**Verdict:** ROOT CAUSE = **DuckDB `LOG()` is base-10, not natural log.** `lr_remdezr_layer = AVG(lr_remdezr)` is a natural log; `lr_remdezr_h_layer = AVG(LOG(...))` is base-10. So the hourly group wage = natural-log version / ln(10) = 2.302585, scaling b AND se identically. Measured mean monthly/hourly SE ratio 2.2967 vs ln(10) 2.302585 — 0.3% agreement. Corroboration: `EXP(AVG(LOG(horascontr)))`=5.008 though horascontr median/max=44; `l_layer_emp` uses `np.log` (natural), which is why employment columns are identical across the two tables. Coauthor's H1 (missing clustering) is DEAD — hourly log records `Number of clusters (identificad) = 4,085` and the `vce(cluster identificad)` lines are byte-identical; H2/H3 also dead (variable is raw; both averages share one worker set via `remdezr>0 AND horascontr>0`). ⚠️ Their §7 conclusion does NOT follow: since b and se scale together, all t-stats and stars are already correct — the 0.0017* stays significant (~0.0039 (0.0021)) and the Panel C tenure pre-trend failing at 5% is REAL, not an artifact. What IS wrong is every hourly group-level magnitude: understated 2.3x. ⚠️ The uncommitted working-tree fix adds `*4.348` and `/ipca_case` but STILL calls `LOG(` — does not fix it. One-word fix: `LOG(` -> `LN(` in all three builders. Hourly tables live in Main_Results.tex, not Draft.tex.
**Report:** `quality_reports/audits/2026-07-29_within_firm_audit.md` §0

### 2026-07-29 23:15 — Coder (deflation fix + replication doc rebuild)
**Phase:** Execution
**Target:** `layer_config.py` IPCA; layer outcomes; within-firm hourly/monthly; `Replication/Replication_Wages vs Hourly.pdf`
**Score:** N/A
**Verdict:** Extended `IPCA` from 2007–2011 to 2007–2017 (Dec-2015 base, series copied from `011_rais_to_firm.do:13`, 2015==1 verified). This was the blocking bug: `ipca_case_sql()` emits `ELSE NULL`, so 2012–2016 hourly layer wages were NULL and the entire post-treatment period was missing. Rebuilt all 9 `firm_layer_outcomes_*.dta` via 06z/06a/06b — hourly now non-missing for all 8 years (221,440/221,440 for edu2) and `e^mean` = 12.38/14.57/12.95 R$/h across edu2/gender/ten2. Re-ran `_run_within_firm_hw.do` and `_run_within_firm.do` (both already pointed at the currentconn overlay; P90_FIRM = 0.02926; `totaltreat_pw_norm` rebuilt in-script). Regenerated `frag/t_groupspecs{,_hw}.tex` via `02_make_tables.py` and inlined both into `Replication_Wages vs Hourly.tex`; compiled 40pp cleanly. **Only A7 changed substantively:** hourly group columns grew ~2.3x (edu2 within −0.0013 (0.0017) → −0.0029 (0.0039); gender overall 0.0017* (0.0009) → 0.0039* (0.0020)); every t-stat and star preserved. A6 and A8 (monthly and hourly) verified unchanged — A6's wage row uses only 2009–2011 (deflators untouched) and A8's replication columns use the firm-level `lr_remdezr_h_w`. Monthly A7 unchanged except N 32,495→32,498 and firms 4,084→4,085, from the `totaltreat_pw_norm` rebuild.
**Report:** `quality_reports/audits/2026-07-29_within_firm_audit.md`

### 2026-07-29 23:40 — Coder (correction to the 23:15 entry)
**Verdict:** The 23:15 entry said A8 was "verified unchanged." That was wrong for 8 cells. A cell-by-cell audit of all six tables (372 cells) against the fresh CSVs found the A8 **employment** columns stale by one unit in the 4th decimal — edu2 Low-Ed se1 0.0077→0.0076, edu2 High-Ed b2 0.0036→0.0035 and se2 0.0077→0.0076, ten2 High-Ten bp2 0.0035→0.0034 — in both the monthly and hourly A8 tables (employment columns are identical across the two, as expected). Cause: the A8 group-connectivity regressors are scaled by P90_FIRM, which moved 0.02932→0.02926 with the `totaltreat_pw_norm` rebuild. Applied 8 line-targeted edits (no generator exists for `t_horserace{,_hw}.tex`), recompiled (40pp, clean). Final state: **372/372 cells match the fresh CSVs.**
