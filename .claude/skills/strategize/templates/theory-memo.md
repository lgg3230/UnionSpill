# Theory Memo Template

**Purpose:** Prose overview produced by the theorist agent. Accompanies the formal LaTeX files (assumptions.tex, results.tex, proofs.tex). Explains what is proved, under what assumptions, and what remains open.

---

## Template

```markdown
# Theory Memo: [Project Name]

**Date:** [YYYY-MM-DD]
**Paper type:** [econometric methods / theory+empirics / structural / methodological reduced-form]

---

## 1. Summary

**What is proved:** [one paragraph -- the main theoretical contribution]
**Under what assumptions:** [list key assumptions by number and name]
**What remains open:** [what the theory does NOT cover -- caveats for the writer]

---

## 2. Theoretical Objects Produced

| Object | Status | Where |
|--------|--------|-------|
| Identification result | [complete / partial / not needed] | results.tex, Theorem [N] |
| Consistency | [complete / partial / not needed] | results.tex, Theorem [N] |
| Asymptotic normality | [complete / partial / not needed] | results.tex, Theorem [N] |
| Influence function | [complete / partial / not needed] | results.tex, Lemma [N] |
| Bootstrap validity | [complete / partial / not needed] | results.tex, Theorem [N] |
| Comparative statics | [complete / partial / not needed] | results.tex, Proposition [N] |

---

## 3. Assumptions

| # | Name | Formal Statement | Interpretation | Standard? | Stronger/Weaker than benchmark? |
|---|------|-----------------|----------------|-----------|-------------------------------|
| A1 | [Sampling] | [formal] | [what it rules out] | [cite if standard] | [comparison] |
| A2 | [Identification] | [formal] | [what it rules out] | [cite if standard] | [comparison] |
| A3 | [Smoothness] | [formal] | [what it rules out] | [cite if standard] | [comparison] |

---

## 4. Main Results

### Theorem 1: [Name]
**Statement:** [informal summary]
**Proof strategy:** [one sentence -- "We prove in three steps: ..."]
**Where each assumption is used:** [A1 in step i, A2 in step ii, ...]

### Theorem 2: [Name]
[Same structure]

---

## 5. Linkage to Empirical Strategy

| Assumption | Application Interpretation | Credibility Assessment |
|-----------|---------------------------|----------------------|
| A1 (Sampling) | [what it means for the data] | [credible because...] |
| A2 (Identification) | [what it means for the design] | [credible because...] |

---

## 6. Open Questions

- [What the theory doesn't cover]
- [Extensions that would strengthen the paper]
- [Potential issues the writer should caveat]

---

## 7. Output Files

| File | Contents |
|------|----------|
| `assumptions.tex` | Numbered assumption block, ready for paper |
| `results.tex` | Definitions, lemmas, propositions, theorems in LaTeX |
| `proofs.tex` | Full proofs with justified steps |
| `notation_glossary.md` | Every symbol, its type, and its meaning |
```
