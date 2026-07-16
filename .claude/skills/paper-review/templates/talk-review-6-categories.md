# Talk Review: 6 Check Categories

Extracted from `storyteller-critic.md`. Used by the storyteller-critic agent for presentation review.

---

## Prerequisite Checks

**Before running categories:**

- Read `.claude/rules/content-invariants.md` -- enforce INV-20 and INV-21. Cite invariant numbers (e.g., "violates INV-20") in report alongside deductions.
- Identify the paper type (reduced-form, structural, theory+empirics, descriptive). This determines which narrative arc checks apply.

---

## 1. Narrative Flow

- Does the hook work? (first 2 slides)
- Is there a clear story arc?
- Does the audience know "so what" by the end?
- Is the key slide clearly identifiable?

**Paper-type-specific arc checks:**

| Paper Type | The talk must... |
|-----------|-----------------|
| Reduced-form | Lead with the policy question, show the variation, present the main result with magnitude |
| Structural | Motivate why a model is needed, present the counterfactual as the payoff, include model fit |
| Theory+empirics | Present competing explanations, show the distinguishing prediction, be honest about where the model fails |
| Descriptive | Lead with what's missing in current measures, present the data innovation, show the most surprising fact |

---

## 2. Visual Quality

- Text overflow on any slide?
- Font sizes readable for projection (>= 10pt)?
- Tables readable (not too many columns/rows)?
- Figures at appropriate size with clear labels?
- Consistent formatting throughout?
- One idea per slide? (flag slides trying to do two things)

---

## 3. Content Fidelity

- Do numbers on slides match the paper exactly?
- Is the identification strategy correctly represented?
- Are robustness results accurately summarized?
- No results that aren't in the paper?

**Structural papers additionally:**
- Are parameter estimates on slides interpreted economically, not just reported?
- Is model fit shown (predicted vs. actual)?
- Are counterfactual magnitudes stated clearly?

**Theory+empirics additionally:**
- Are predictions stated before evidence?
- Is the distinguishing prediction clearly flagged?

---

## 4. Scope for Format

- Is the talk the right length for the format?
- Is the content depth appropriate? (job market != lightning)
- Are the right things cut for shorter formats?
- Backup slides available for anticipated questions?

**What to cut by paper type (shorter formats):**

| Paper Type | Keep | Cut |
|-----------|------|-----|
| Reduced-form | Main result + one robustness | Extra robustness, heterogeneity details |
| Structural | Counterfactual + key mechanism | Estimation details, sensitivity (move to backup) |
| Theory+empirics | Distinguishing prediction + test | Other predictions, model derivation (move to backup) |
| Descriptive | Most surprising fact + validation | Construction details, decompositions |

---

## 5. Compilation

- **Beamer:** Does it compile without errors? No overfull hbox warnings?
- **Quarto:** Does `quarto render` produce clean HTML? No missing references?
- All referenced figures/tables exist?

---

## 6. Paper-Type Coherence

- Does the narrative arc match the paper type?
- Structural talk without counterfactuals? Flag it -- that's the whole point of having a model.
- Theory talk without the distinguishing prediction? Flag it -- the audience needs to know what's unique.
- Descriptive talk that makes causal claims? Flag it -- the paper doesn't have a design for that.

---

## Report Format

```markdown
# Talk Review -- [Format]
**Date:** [YYYY-MM-DD]
**Reviewer:** storyteller-critic
**Paper type:** [Reduced-form / Structural / Theory+Empirics / Descriptive]
**Score:** [XX/100] (advisory)

## Narrative Arc: [Correct for type / Wrong arc]
## Issues Found
[Per-issue with severity and deduction]

## Score Breakdown
- Starting: 100
- [Deductions]
- **Final: XX/100**
```
