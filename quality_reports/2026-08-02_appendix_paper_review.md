# Paper + Appendix review — 2026-08-02

Three passes over `Draft.tex` with both appendices attached (`Review.tex`, 55 pp., built in a
scratch copy; the paper repo was never written to).

| Pass | Reader | Sources |
|---|---|---|
| A | Claude, direct | merged document **+ Stata/Python** |
| B | Independent agent | merged document only, no code |
| C | Independent agent | merged document only, no code |

B and C ran in parallel and did not see each other. Denying them the code is what forces the
appendices to be judged as companion pieces rather than as documentation of the implementation.

Raw yield: 13 findings + 6 judgment calls. After dedup and verification against the code:
**9 confirmed, 1 needs a rerun, 1 killed as a false positive, all judgment calls dropped.**

---

## Confirmed — fix in the paper

**1. Industry fixed effects are three-digit, six table notes say two-digit.**
`4012_pct_tfpw.do:319` absorbs `i.industry1#i.year`, and
`1040_merge_cba_rais.do:169-172` builds `industry1` from `substr(clascnae20,1,3)`. `big_industry`
(two-digit, `:218`) never enters the FE. Notes at Draft.tex lines 379, 456, 590, 658, 892, 938.
→ Change six table notes to three-digit. The appendix is already correct.

**2. The retention rate note is stated backwards.**
Note: "the share of December-employed workers who were already at the establishment at the start
of year $t$." Code (`turnover/011b_corrected_turnover.py:438-441`): numerator is workers present
in both January and December, denominator is **January** employment. Agent C added independent
proof from the document alone: under the note's own definition the rate could never be
undefined, yet the column reports 112,620 obs against 113,112.
→ Restate the Table A4 note in the appendix's terms.

**3. The main text's clause window does not match the estimation.**
Text (line 298): "restrict post-treatment observations to CBAs filed after September 25, 2012."
Code (`4012_pct_tfpw.do:120-126`): `cba_period` 3–6 is assigned only to filings in
calendar 2013–2016, so **every 2012 filing is dropped**. An agreement filed 1 October 2012 is in
by the text and out in fact.
→ The appendix is right. Fix the main text.

**4. The clause column's reference period and window are wrong in the table notes.**
Notes say "average effect for 2012--2016, with 2011 as the reference year" and a placebo of
"2009--2010 relative to 2011". Column (4) is a clause regression, which runs
`i.treat_ultra##ib2.cba_period` (`:560`) with `post_treat_cba` = periods 3–6 = 2013–2016.
→ Add one sentence to the clause columns giving the period indexing and the period-1-vs-2 placebo.

**5. Equation (2) divides by four; the estimator divides by the number of observed pairs.**
`1050_yearly_employers.do` builds `totaltreat_pw_n` by summing non-missing pairs and dividing by
the count of non-missing pairs. Affects the few hundred establishments absent from a pair
(724 / 103 / 27 / 35 across the four pairs).
→ Either put the count of non-missing pairs in the equation's denominator, or state the
assumption. Both agents found this independently.

**6. Figure A4 describes a simulation that is not run.**
Note: "average connectivity ... over 1,000 reshuffles." `rand_inference/09_expected_exposure.py`
computes the expectation in closed form, as the flow-weighted sum of within-cell treated shares.
Same estimand, exact rather than simulated.

**7. Table A4's hours note overstates.**
"Log hours is ... the same variable that forms the denominator of the hourly wage outcome." The
hourly wage divides by worker-level weekly hours × 4.348 before logging; log hours is an
establishment-level sum of weekly hours. Same RAIS field, different scaling and level.
→ Drop the "same variable" clause.

**8. `Draft.tex:548` is missing a word.** "We take the weights \cite{Lagos2026}" → "from".

---

## Confirmed — fix in the appendix

**9. "In force at the end of 2012" overstates the sample condition.**
The appendix says the third condition requires "at least one agreement filed on or after 1
January 2012 that was in force at the end of 2012." The code
(`1040_merge_cba_rais.do:114`) requires only `file_date >= 1jan2012 & end_date >= 31dec2012`. It
never checks that the agreement had started by end-2012, so a 2014 filing running into 2015
satisfies it. As written the appendix describes a stricter rule than the one imposed.
→ Reword to: an agreement filed on or after 1 January 2012 whose term runs at least to the end
of 2012.

---

## Needs a rerun, cannot be settled from the documents

**10. Table A8's firm-level cells disagree with Table 2.**
A8 claims columns (1) and (4) reproduce Table 2. Wages agree (0.0065***) but N does not
(32,498 vs 32,495, establishments 4,085 vs 4,084). Employment disagrees on the coefficient
(0.0008 vs 0.0009) while N matches (32,704). A6 makes the same claim and matches exactly, so A8
is the outlier. Likely the firm-level benchmark was estimated inside the layer pipeline on a
marginally different sample rather than copied from Table 2.

---

## Killed — false positive from both agents

Both argued that the third sample condition is self-defeating: that requiring a filing on or
after 1 January 2012 in force at end-2012 forces a 2012 filing, and that all 2012 filings are
excluded from the clause periods, so the condition guarantees an agreement whose content is
never analysed. The inference fails on the code. `end_date >= 31dec2012` is satisfied by any
later agreement, so a 2013 or 2014 filing meets the condition. The agents could not see this
because they had no code access. The underlying wording problem is real but is finding 9, not this.

---

## Also surfaced during assembly

`Draft.tex` does not compile cleanly on its own: **62 errors**, all from Table A8's
`S[table-format=-1.4]` columns, because `siunitx` is commented out at
`Packages/lgag_eesp-paper.sty:60`. The PDF still builds and the merge added no errors, so this is
pre-existing and presumably masked by a different preamble on Overleaf.

---

## Dropped

Six judgment calls, all correctly self-classified by the agents: the treatment-date boundary
(differs only for agreements filed on the ruling date), the three-way education grouping, the
"in 2009" qualifier on the connectivity percentile, and the Table A7 window label. No action.

**Verdict on the appendices:** one wording fix (finding 9). Every other confirmed item is in the
paper, and in each case the appendix states the code correctly and the paper does not. That is
the answer to the question this exercise was set up to ask.
