# PAP Interview Flow

**Purpose:** 6-question guided interview for building a pre-analysis plan. Used when `/strategize pap interactive` is invoked. Ask each question one at a time, wait for the answer, then proceed.

---

## The 6 Questions

### Question 1: Research Question
> What is the research question?

**Listen for:** A precise, falsifiable question. If vague, probe:
- "What is the specific causal effect you want to estimate?"
- "Who is affected? By what?"
- "What is the counterfactual?"

**Red flag:** "I want to see if X is related to Y" -- needs sharpening into a causal or descriptive question.

---

### Question 2: Study Design
> What is the study design? (RCT / natural experiment / quasi-experimental / observational)

**Listen for:** The source of identifying variation.

**Follow-ups by design:**
- **RCT:** How is randomization done? Individual or cluster? Stratified?
- **Natural experiment:** What is the exogenous shock? When did it happen?
- **Quasi-experimental:** DiD, IV, RDD? What is the running variable / instrument / treatment timing?
- **Observational:** What is the selection-on-observables argument?

---

### Question 3: Primary Outcome Variables
> What are the primary outcome variables? (names, measurement, data source)

**Listen for:** Precise variable definitions, not vague concepts.

**Probe if needed:**
- "How exactly is this measured?"
- "What data source provides this variable?"
- "At what level is it measured? (individual / household / firm / market)"
- "What is the timing of measurement relative to treatment?"

**Red flag:** More than 3-4 primary outcomes without a multiple testing plan.

---

### Question 4: Identification Strategy
> What is the identification strategy? (randomization mechanism / treatment assignment / source of variation)

**Listen for:** The specific variation that identifies the causal effect.

**Probe if needed:**
- "What is the comparison group and why is it valid?"
- "What must be true for this comparison to give you the causal effect?" (parallel trends, exclusion restriction, continuity, etc.)
- "Is there any reason this variation might not be exogenous?"

**Connect to Question 2:** The design and identification strategy should be consistent.

---

### Question 5: Subgroup Analyses
> What subgroup analyses are pre-specified? (with justification for each)

**Listen for:** Theory-driven subgroups, not data-driven fishing.

**Good examples:** Gender (if mechanism is gender-specific), baseline outcome level (if heterogeneous dose-response), geographic region (if institutional differences).

**Red flag:** "We'll look at all possible subgroups and report what's significant." This is exactly what pre-registration is designed to prevent.

**Probe:** "What theoretical reason justifies this subgroup analysis?"

---

### Question 6: Multiple Testing
> What multiple testing concerns exist? (number of primary outcomes, family-wise error rate plan)

**Listen for:** Awareness of the problem and a planned correction method.

**Key dimensions:**
- How many primary outcomes? (if >1, correction needed)
- How many subgroups? (each additional subgroup multiplies tests)
- Are outcomes in the same "family"? (corrections apply within families)

**Correction methods to suggest:**
- **Bonferroni:** Simple, conservative. Good for 2-3 outcomes.
- **Benjamini-Hochberg:** Controls false discovery rate. Good for 4-10 outcomes.
- **Romano-Wolf:** Accounts for correlation structure. Best for many correlated outcomes.

---

## After All 6 Answers

1. Summarize what was collected
2. Ask: "Is there anything else you'd like to pre-specify?" (mechanisms, exploratory analyses, data handling decisions)
3. Ask: "Which registry platform?" (AEA RCT Registry / OSF / EGAP)
4. Proceed to PAP drafting using the appropriate template

---

## Observational Study Adaptations

For observational/quasi-experimental designs, adapt Questions 2, 4, and 5:

**Question 2 (Design):** Focus on the source of quasi-random variation, not randomization.
**Question 4 (Identification):** Focus on the key identifying assumption and its testable implications.
**Question 5 (Subgroups):** Also include pre-committed specification choices:
- Bandwidth (RDD)
- Control variables (selection-on-observables)
- Sample restrictions (all designs)
- Functional form (polynomial order, log vs. levels)
