# Submission Checklist — Draft 2a87e5e

Paper: Outside Options and Collective Bargaining Spillovers
Snapshot: quality_reports/draft_snapshots/Draft_2026-08-03_2a87e5e.tex
Previous: 87f13b2, 89a2d24, b9a8dc9, c80cb12, 4b0f458
Line numbers refer to the current draft (2a87e5e). Re-verified 2026-08-03, full
typo sweep run (hunspell on rendered prose + doubled words + punctuation + LaTeX
abbreviation spacing). No misspellings; findings below are the complete remainder.
Sources: quality_reports/2026-08-03_Draft_review_issues.md
         quality_reports/reviews/2026-08-03_peer_review_AER_JOLE.md

Scope constraint: no changes to results; sentence- to paragraph-level text edits only.

STATUS KEY
  [DONE]     verified fixed in the current draft
  [PARTIAL]  partly applied, remainder specified
  [OPEN]     not yet addressed
  [NEW]      introduced by a later edit, not yet resolved
  [BLOCKED]  cannot be written until a prior question is resolved
  [IGNORED]  author thinks this concern is exaggerated (either for technical or semantical reasons) and decided not to act on it

TALLY   DONE 7   PARTIAL 1   IGNORED 17   BLOCKED 1   OPEN 19  (10 in scope, 9 in section F)


## A. COMPILE — author has marked these IGNORED. Verified: still 62 errors

    OUTPUT IMPACT, checked against the rendered PDF (55 pages, all content present):
      A1  the two malformed figure notes DO render; LaTeX inserts the missing \item
          and recovers. No visible defect. Log noise only.
      A2  Table A8 renders with every value present, but its negatives are typeset
          as short hyphens (-0.0008) where every other table uses proper minus signs
          ($-$0.0008). Values carry a uniform 4 decimals, so the lost decimal
          alignment is not visible. Cosmetic inconsistency, one table.
      A3  `abowd1999` is cited only inside the Data Appendix bibunit. Confirm it
          appears in the reference list of the submitted PDF; if the bibunit list is
          empty the citation shows as a bare key.
      A4  stale-label warning only; the extra pass has since been run here.
    Conclusion: the submitted PDF is not visibly broken. The 62 errors are a signal
    in the log, not a defect on the page. Ignoring is defensible for submission;
    A3 is the only one with a possible visible consequence and takes seconds.

A1. [IGNORED] L332-334 and L429-431 — `tablenotes` body text before any `\item`,
    causing "! LaTeX Error: Something's wrong--perhaps a missing \item" twice.
    FIX: insert `\item` before `\textit{Notes:}` in both. Correct pattern already
    at L247-250. Verified: only 1 of 3 tablenotes environments has an \item.

A2. [IGNORED] Packages/lgag_eesp-paper.sty line 60 — `S` column type used in Table A8
    but `\usepackage{siunitx}` is commented out. 60 array errors; Table A8 renders
    negatives as short hyphens instead of minus signs.
    FIX: uncomment line 60.

A3. [IGNORED] L1446 — `abowd1999` undefined; cited only inside the bibunit, bu1.bbl
    never regenerated. FIX: run `bibtex bu1` before the final passes.

A4. [IGNORED] "Label(s) may have changed" — committed PDF one pass stale.
    FIX: extra pdflatex pass.


## B. TEXT EDITS — the six that matter

B1. [OPEN] L104 (introduction). Still reads "consistent with positive wage spillovers".
    NOW: "raises the estimated direct effect on wages by about 40\%, consistent with
         positive wage spillovers"
    TO:  "raises the estimated direct effect on wages by about 40\%. Positive
         spillovers to connected controls account for part of this gap; the two
         comparison groups also differ in size and network position, and we do not
         decompose the two channels."

B2. [OPEN] L717 (conclusion). Unchanged.
    NOW: "In our setting, excluding untreated firms connected through worker flows
         raises the estimated direct effect by about 40\%."
    TO:  Make conditional, or cut to one clause. Stop leading with the 40% number.
         More exposed than B1 because it generalizes into a measurement lesson.

B3. [OPEN] L59 (abstract). Still reads "while amenities are unchanged".
    TO:  "with no detectable change in amenities"

B4. [OPEN] Section 4.2 — add one sentence.
    For clause counts the proportional benchmark 0.23 x 1.5544 = 0.357 lies outside
    the CI upper bound of 0.253, so proportionality IS rejected. A positive result
    currently not claimed.

B5. [IGNORED] Section 4.2, L413 — add two sentences.
    Name the estimand. State that the level interpretation of delta requires strong
    parallel trends, not just conditional parallel trends. Cite Callaway2023.

B6. [DONE] Equations (1) and (2), L229 and L261 — three `\frac{1}{4}` still present.
    The code divides by the number of NON-MISSING year pairs, not by four
    (Programs/1050_yearly_employers.do:314-326). The appendix is correct; the equation
    is not. The divisor is firm-specific, so the two conventions produce different
    RANKINGS of firms, not a common rescaling — and the measure is normalized by its
    own p90, so ranking is what the regressor is made of.
    FIX (lowest-attention option, fewer words than now):
      - Equations: replace the `\frac{1}{4}` prefactor with an overbar average,
        e.g. \overline{( Flows / Avg. employment )}, and say "averaged across the
        pre-treatment year pairs".
      - L225: "averaged across four pairs of years (2007--2008, ...)" becomes
        "averaged across the pre-treatment pairs of years (2007--2008 through
        2010--2011)". Deletes one word.
      - Appendix L1454: once nothing contradicts it, delete the contrastive clause
        "and the average is taken over the pairs in which it does appear rather than
        over four". Keep "An establishment absent from a given pair contributes no
        ratio for it."
    NOTE: the estimator itself is Stata's default (egen rowmean skips missings and
    divides by the non-missing count) and is arguably the better choice. Nothing to
    defend; the equation just should not assert a divisor the code does not use.

WHY B1/B2: measured mean C_i = 0.01241, p90 = 0.02926, so mean/p90 = 0.424.
    Implied gap = 0.0065 x 0.424 = 0.0028 against 0.0083 observed. Spillovers explain
    roughly one third. Four referees derived this independently.

WHY B3: direct effect on wage-equivalent CBA value = 0.0073 (0.0027), so the
    proportional prediction is 0.23 x 0.0073 = 0.0017, inside the reported spillover
    CI of [-0.0040, +0.0022].


## C. OTHER SENTENCE-LEVEL INCONSISTENCIES

C1. [IGNORED] L302 vs appendix — main text reads as one pre-treatment clause period;
    appendix describes two. Two are required, since all three clause tables report
    a placebo.

C2. [IGNORED] L205 / L208 vs appendix — sample restriction 3 stated loosely in the main
    text and strictly in the appendix. The appendix version forces every untreated
    establishment to have filed between 25 Sept and 31 Dec 2012.

C3. [DONE] Appendix — "select a single spell per worker per year" corrected to the
    worker-establishment pair rule. Phrase no longer present in 89a2d24. Worth one
    read-through of the surrounding sentence after the Data Appendix restructuring.

C4. [IGNORED] Tables 1, 2, 3 notes — clause regressions are CBA-period indexed, but the
    notes describe "2012--2016" and "(2009--2010 relative to 2011)". Column (4) has
    no such years.

C5. [OPEN] L936 — turnover note calls the establishment hours aggregate "the same
    variable that forms the denominator of the hourly wage outcome". It is not;
    hourly wages are built worker-by-worker.

C6. [OPEN] Layer descriptives note — opens "pre-treatment (2009--2011)" but two rows
    are measured over 2007--2011. Add "unless otherwise noted". See also N4.

C7. [IGNORED] Table 3 note — clause-type coefficients do not sum to the total (0.0312
    vs 0.0227) while the text claims no offsetting movements. Add a note that the
    pre-treatment outcome bins are outcome-specific.

C8. [OPEN] Table A1 note — counts do not reconcile with the regression tables:
    14,207 vs 14,136; 16,472 vs 16,398; 4,196 vs 4,084. The clause column also
    reports MORE establishments than the wage column.

C9. [OPEN] L409 and equation (4) — C_i denotes the raw ratio in eq (2) and Table A1,
    and the normalized version in eq (4) and L409. Introduce C-tilde.

C10. [IGNORED] Data Appendix pointers. One \ref to app:sample now exists, but it sits
    inside the appendix itself. Still no pointer from the main text.
    REMAINING: add pointers at Section 3 (L197 / L203) and in the outline at L139.

C11. [DONE] Percent labels reporting proportions.
    DONE: tab:descriptive_stats L784-786 — `\%` removed, now "High School Degree
      (share)", "Female (share)", "Non-white (share)".
    DONE: tab:layer_desc_full — values converted from 85.8% to 0.86 and labels
      renamed to "Share of ...".
    DONE: tab:composition L956 — `\%` removed from all three headers (N1).
    DONE: tab:layer_desc_full note label updated (N4).
    OPTIONAL: a clause in each table's notes, "Worker characteristics are shares
      of establishment employment." Labels now carry "(share)", so not required.


## D. CITATIONS — additions only, all already in bib.bib. Verified 0 occurrences each

D1. [IGNORED] rambachan2023more — uncited.
D2. [IGNORED] roth2022pretest — uncited.
D3. [IGNORED] Callaway2023 — uncited, AND malformed: no year field, no venue. Will not
    render even once cited.
D4. [IGNORED] Engbom2022 — uncited. Brazilian minimum-wage spillovers over the same
    window.
D5. [IGNORED] corradini2025collective — uncited. Same country, same registry, amenities
    and gender. Called "the most conspicuous omission in the manuscript".


## E. COPY EDITS

E1. [IGNORED] Em-dashes in prose — 6 occurrences of `---` remain.

E2. [PARTIAL] Typos in Draft.tex. Full sweep re-run against 2a87e5e.

    DONE:
      L250   missing period -> "univariate regressions. Filled red markers"
      L679   "vs.\ with a high school degree" spacing normalized (first pass)
      L1267  "We construct three samples: 1) ..." colon added, stray "the" removed
      L1276  BOTH occurrences now correct: "compensation in December" (month) and
             "spells that were active on December 31st" (date)
      L129   "outside option channel" -> "outside-option channel"
      L627   "at 4 and 2 percent respectively" -> "\%," with comma
      L1019  "per contracted hour and per month, respectively" comma added

    NOT IN Draft.tex: "tiest" and "web-scrapping" live only in
      Appendices/online_appendix.tex, a separate standalone document that Draft.tex
      does not \input. Out of scope for this file.

    IGNORED (2 items):
      L679   two `vs.` still need the backslash-space. LaTeX reads "vs. " mid-sentence
             as a sentence end and inserts wider inter-word space.
               "(without vs. with a high school degree)"        -> vs.\ with
               "(fewer than twelve months vs. twelve months...)" -> vs.\ twelve
             A third instance elsewhere in the file, "vs. filing", has the same issue.
      L216   double space, introduced after c80cb12:
               "to address how  spillovers may bias direct effects"
             Two spaces after "how". Harmless in output, one keystroke to fix.

E3. [IGNORED] Delete editorial leftovers. Both still present in 2a87e5e:
      L69    commented-out longer abstract stating the spillover is "about one-fifth
             of the direct effect" — contradicts the live abstract's "one-quarter".
      L1188  "% VERIFY: definition of negotiation month (start date vs. filing date)"
    Also: stale merge instruction, red to-do comments, commented threeparttable at
    L771/L804, stray \footnotesize at L890/L987.

E4. [DONE] L679 now uses \ref{eq:conn} instead of hardcoded "equation (2)"
    (fixed in c80cb12).

E5. [IGNORED] AEA journals only: remove significance stars from all 12 tables.

E6. [IGNORED, advisory] \toprule\toprule doubled throughout; four different float
    placement specifiers; three different multi-line-header mechanisms; subcaption
    loaded twice.


## N. INTRODUCED BY THE 89a2d24 EDITS — ALL RESOLVED IN b9a8dc9

N1. [DONE] L956, tab:composition header — `\%` removed from all three headers.
    Header now reads Male\\ Share | White\\ Share | High\\School+ Share.

N2. [DONE] L1014 — doubled "of" removed; now "Share of connectivity variance
    between firms".

N3. [DONE] L784 — leading space removed.

N4. [DONE] L1020, note to tab:layer_desc_full — quoted label realigned with the
    renamed row; note now quotes ``share of firms w/ both groups''.


## F. REQUIRES RE-ESTIMATION — not for this submission

F1. [BLOCKED] Honest-DiD disclosure. The CSVs say M-bar = 0.4177, the figures say
    0.29. Resolve which is correct before writing anything.
F2. [OPEN] Clustering at the 8-digit company; exposure-robust or randomization
    inference.
F3. [OPEN] Intra-company flow exclusion. 62.6% of network flows share an 8-digit
    CNPJ root.
F4. [OPEN] Nonparametric dose-response. Tables/conn_margins/results_quartiles_vs_
    zero.csv is non-monotone with a null top quartile.
F5. [OPEN] Missing-bin zero-fill at 4012_pct_tfpw.do:216.
F6. [OPEN] Tenure horse-race rescaling; origin-year group assignment for inflows.
F7. [OPEN] December 2012 timing — 75% of the effect is realized three months
    post-ruling.
F8. [OPEN] Romano-Wolf correction across outcome families.
F9. [OPEN] Direct effect on CBA value (0.0073), already in the pipeline output.
F10. [OPEN] Claim-source map (INV-22).


## NON-TEXT LEVER

Lagos (2026) is accepted at AER on the same reform and the same CBA registry. That is
the single largest desk-rejection risk at AER and cannot be fixed with words.
AEJ:Applied or JOLE lowers it for the identical manuscript.


## SUGGESTED ORDER — 11 open items, ignored ones excluded

1. B1, B2, B3   the three highest-risk sentences: intro 40%, conclusion 40%, abstract
                "amenities are unchanged". Verified all three still present. Nothing
                else on this list moves desk risk as much.
2. B6           equation divisor (3 x \frac{1}{4} still present). The fix is fewer
                words than what is there now, and the appendix contradicts the
                printed equation as it stands.
3. B4           one sentence claiming the clause-count proportionality rejection.
                This one ADDS a result rather than qualifying one.
4. E3           delete the commented-out abstract saying "one-fifth" (contradicts the
                live "one-quarter") and the "% VERIFY:" comment. Both still present.
5. E2           L679 vs.\ spacing (x2, plus "vs. filing"); L216 double space.
6. C8, C5       Table A1 count reconciliation note; turnover note hours denominator.
7. C9, C6       C-tilde notation; "unless otherwise noted" in the layer desc note.

Marked IGNORED by the author, not listed above:
  A1, A2, A3, A4   compile errors (output verified not visibly broken)
  B5               estimand / strong parallel trends statement
  C1, C2, C4, C7   main-text vs appendix wording, table-note windows
  C10              main-text pointers into the Data Appendix
  D1-D5            the five uncited references, incl. the malformed Callaway2023 entry
  E1, E5, E6       em-dashes (6 remain), AEA stars, booktabs/float style

Section F is unchanged and out of scope for this submission.
