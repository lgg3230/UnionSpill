# Theory Review: 4-Phase Protocol

Extracted from `theorist-critic.md`. Used by the theorist-critic agent for proof and theory review.

---

## Key Principle

Verify the proof is valid BEFORE checking whether assumptions are minimal or citations are tidy. A broken proof doesn't need better typesetting.

**Phases execute in order, with early stopping when critical issues are found.**

---

## Phase 1: What Is Being Claimed?

_Always runs. Triage._

Identify:

1. **Object type:** identification / consistency / asymptotic normality / rate / influence function / efficiency bound / uniform validity / DML / bootstrap validity / test properties / comparative-static proposition
2. **Target parameter** $\theta_0$ and how it is defined (functional of $P$, moment condition, argmax)
3. **Estimator** $\hat\theta_n$ and how it is defined
4. **Assumptions** -- list them by number with a one-line summary each
5. **Main result(s)** -- quote the theorem statement(s) verbatim
6. **Data structure** -- iid, panel, staggered, clustered, triangular array
7. **Paper type fit** -- is this theory section appropriate for the paper type (econometric methods / theory+empirics / structural / methodological reduced-form)?

If the theory does not cleanly fit any object type, flag it -- the author may be claiming something that has no standard proof strategy.

---

## Phase 2: Is the Proof Valid?

_The core of the review. If a proof is broken, everything downstream is moot._

### 2A. Logical Validity
- [ ] Every step follows from the preceding steps or from a named, correctly cited result
- [ ] No circular reasoning (using the conclusion to establish a premise)
- [ ] No undefined objects -- every symbol in the proof was introduced earlier
- [ ] Case analysis is exhaustive when used
- [ ] Quantifiers (for-all, exists, uniform vs. pointwise) are used consistently -- uniform claims are not supported by pointwise arguments

### 2B. Measurability, Integrability, Interchange
- [ ] Limit/expectation interchanges justified (DCT, MCT, Fubini) with the dominating function or monotonicity stated
- [ ] Stochastic equicontinuity / uniform convergence arguments invoke a specific tool (Donsker property, bracketing entropy, VC class, Glivenko-Cantelli)
- [ ] Function classes are measurable / envelope conditions are stated
- [ ] Conditional vs. unconditional expectations are distinguished; tower property invocations are valid

### 2C. Expansions and Remainders
- [ ] Taylor expansions state the order and the remainder form (Lagrange, integral, mean-value)
- [ ] Each remainder is shown to be $o_p(\cdot)$ or $O_p(\cdot)$ at the claimed rate -- not assumed
- [ ] Rate arithmetic is correct (e.g., $o_p(n^{-1/4}) \times o_p(n^{-1/4}) = o_p(n^{-1/2})$)
- [ ] For DML / orthogonal moments: Neyman orthogonality is verified, nuisance-rate conditions are used at the right step

### 2D. Identification-Specific Checks (when the result is identification)
- [ ] The functional of $P$ claimed to equal $\theta_0$ actually does so under the stated assumptions
- [ ] Counterfactual quantities are mapped to observable counterparts via a stated sequence of substitutions (conditional exogeneity, parallel trends, exclusion, monotonicity, continuity at cutoff)
- [ ] Design-specific invariants are each used explicitly where needed:
  - **DiD:** no-anticipation, parallel trends, overlap (cf. Callaway & Sant'Anna, 2021)
  - **IV:** relevance, exclusion, monotonicity for LATE (cf. Imbens & Angrist, 1994)
  - **RDD:** continuity of potential outcomes at cutoff, no manipulation (cf. Hahn-Todd-vdK, 2001)
  - **Structural:** rank/order conditions, normalizations, support
- [ ] For bad-controls / mediator problems: the conditioning set is justified; no post-treatment variables are used without a stated argument

### 2E. Asymptotic Distribution Checks
- [ ] Influence function is derived or verified (not asserted)
- [ ] Variance formula matches the influence function's second moment
- [ ] CLT invoked is appropriate (Lindeberg-Levy, Lindeberg-Feller for triangular arrays, martingale CLT for dependent data)
- [ ] Clustering / dependence structure reflected in the limit variance

**Early stop:** If Phase 2 finds a CRITICAL gap (a step does not follow, a limit interchange is unjustified, an assumption is invoked that was never stated, an identification substitution is wrong), focus the report there. Still run Phases 3-4 but prefix remaining feedback with: "These become relevant only after the Phase 2 issues are resolved."

---

## Phase 3: Are the Assumptions and Statements Right?

_Runs after Phase 2. Checks whether the result says what it should say._

### 3A. Assumption Quality
- [ ] **Minimality.** Each assumption is actually used in the proof. If an assumption is never invoked, flag it.
- [ ] **Primitiveness.** High-level conditions (e.g., "the estimator is $\sqrt{n}$-consistent") are preferred only when primitive conditions are infeasible; flag unexplained high-level conditions.
- [ ] **Non-redundancy.** No assumption is implied by another.
- [ ] **Interpretation.** Each assumption has a sentence explaining what it rules out and when it may fail.
- [ ] **Comparison to literature.** Stronger/weaker than relevant anchors in `.claude/references/domain-profile.md` (Theoretical Foundational References)? Relationship stated.
- [ ] **Overlap / positivity** is stated when conditional expectations on treatment subgroups appear.

### 3B. Statement Quality
- [ ] The conclusion is the strongest result the proof actually supports (no under-claiming)
- [ ] The conclusion is NOT stronger than the proof supports (no over-claiming) -- especially: pointwise vs. uniform, $o_p$ vs. $O_p$, consistency vs. asymptotic normality, conditional vs. unconditional
- [ ] The variance characterization is explicit, not "some $V > 0$"
- [ ] Regularity classes (Donsker, VC, etc.) are named, not hidden
- [ ] Convergence mode (in probability, in distribution, almost sure, in $L^2$) is stated and correct

### 3C. Notation Consistency (INV-7)
- [ ] Same symbol = same object throughout theory + rest of paper
- [ ] Different concepts get different symbols (no overloading)
- [ ] Subscripts/superscripts (treatment group $g$, period $t$, cluster $c$) are consistent with the empirical sections
- [ ] Bold/italic/calligraphic conventions match the paper's preamble / `preambles/header.tex`
- [ ] Symbols match the `Notation Conventions` table in `.claude/references/domain-profile.md`

---

## Phase 4: Citations, Linkage, Polish

_Runs only if Phases 2-3 have no unresolved CRITICAL issues._

### 4A. Citation Fidelity
For each named result invoked, verify:
- Correct paper, year, journal
- Correct theorem/lemma number
- The cited result actually applies (right assumptions, right space, right version)
- Foundational anchors are drawn from `.claude/references/domain-profile.md` (Theoretical Foundational References) when filled. If the domain profile is empty or silent on the relevant topic, the theorist's fallback defaults apply:
  - DiD / staggered: Callaway & Sant'Anna (2021, *JoE*); Sant'Anna & Zhao (2020, *JoE*); de Chaisemartin & D'Haultfoeuille (2020, *AER*)
  - IV / LATE: Imbens & Angrist (1994); Angrist, Imbens & Rubin (1996)
  - RDD: Hahn, Todd & van der Klaauw (2001); Calonico, Cattaneo & Titiunik (2014)
  - Potential outcomes: Imbens & Rubin (2015); Imbens (2004); Abadie & Imbens (2006)
  - DML / orthogonal moments: Chernozhukov et al. (2018, *EconJ*)
  - Semiparametric efficiency: Newey (1990, 1994); Bickel-Klaassen-Ritov-Wellner (1993)
  - Causal forests, heterogeneous effects: Athey & Imbens (2016); Wager & Athey (2018); Athey-Tibshirani-Wager (2019)
  - Synthetic control / matrix completion: Abadie-Diamond-Hainmueller (2010); Athey et al. (2021, *JASA*)
  - Empirical process: van der Vaart & Wellner (1996); van der Vaart (1998)
  - Extremum estimators: Newey & McFadden (1994)
  - GMM: Hansen (1982); Hansen & Singleton (1982)
  - Bootstrap: Hall (1992); Horowitz (2001)

Cross-check against `UnionSpill-paper/bib.bib`.

### 4B. Linkage to Empirical Claims
- [ ] Each assumption maps to a plain-language counterpart usable in the empirical section
- [ ] Every causal/inferential claim made in the paper's introduction or results section is supported by a theorem here (no orphan claims)
- [ ] Every theorem here is actually used somewhere in the paper (no orphan theorems)
- [ ] Caveats (pointwise only, requires known variance, etc.) are flagged for the writer

### 4C. Exposition
- [ ] Proof strategy is stated upfront (one sentence)
- [ ] Subclaims are labeled and the argument can be followed without reconstructing it from scratch
- [ ] Appendix deferrals are cleanly forward-referenced
- [ ] LaTeX compiles; theorem environments match project preamble

---

## Report Format

Save to `quality_reports/[FILENAME]_theory_review.md`:

```markdown
# Theory Review: [Filename]
**Date:** [YYYY-MM-DD]
**Reviewer:** theorist-critic

## Phase 1: Claim Identification
- **Object type:** [identification / consistency / asymptotic normality / ...]
- **Target parameter:** [definition]
- **Estimator:** [definition]
- **Main result(s):** [verbatim statement]
- **Assumptions (summary):** [A1: sampling; A2: parallel trends; ...]
- **Data structure:** [iid / panel / staggered / clustered]
- **Paper type:** [econometric methods / theory+empirics / structural / methodological reduced-form]

## Phase 2: Proof Validity
**Assessment:** [VALID / GAPS / CRITICAL ERRORS]

#### Issues Found: N
##### Issue 2.1: [Brief title]
- **Location:** [file:line, theorem/proof step]
- **Severity:** [CRITICAL / MAJOR / MINOR]
- **Problem:** [what is wrong]
- **Suggested fix:** [specific correction]

## Phase 3: Assumptions and Statements
### Issues Found: N
[issues]

## Phase 4: Citations, Linkage, Polish
### Issues Found: N
[issues]

## Summary
- **Overall assessment:** [SOUND / MINOR ISSUES / MAJOR ISSUES / CRITICAL ERRORS]
- **Score:** XX / 100
- **Critical issues (must fix):** N
- **Major issues (should fix):** N
- **Minor issues (consider):** N

## Priority Recommendations
1. **[CRITICAL]** [...]
2. **[MAJOR]** [...]
3. **[MINOR]** [...]

## Positive Findings
[2-3 things the theory gets right -- acknowledge rigor where it exists]
```
