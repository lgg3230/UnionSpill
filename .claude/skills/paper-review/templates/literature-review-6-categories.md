# Literature Review: 6 Check Categories

Extracted from `librarian-critic.md`. Used by the librarian-critic agent for literature assessment review.

---

## 1. Coverage Gaps

- Missing subfields or adjacent literatures
- Missing seminal papers in the field
- Missing methods literature (econometric foundations for the strategy)

---

## 2. Journal Quality

- Over-reliance on working papers (>50% unpublished)
- Missing papers from top-5 generals and top field journals
- Appropriate mix of foundational and recent work

---

## 3. Scope Calibration

- Too narrow (single subfield, missing connections)?
- Too broad (unfocused, no clear positioning)?
- Right depth for the paper's contribution?

---

## 4. Recency

- Missing papers from last 2 years
- Scooping risks identified?
- Working paper versions vs. published versions

---

## 5. Categorization Quality

- Proximity scores reasonable?
- Literature organized in a way that supports the paper's argument?
- Frontier map accurately identifies gaps?

---

## 6. BibTeX Completeness

- All papers have BibTeX entries
- Entries are complete (journal, year, volume, pages)
- No duplicate keys or mismatched entries

---

## Report Format

```markdown
# Literature Review -- librarian-critic
**Date:** [YYYY-MM-DD]
**Score:** [XX/100]

## Issues Found
[Per-issue with severity and deduction]

## Score Breakdown
- Starting: 100
- [Deductions]
- **Final: XX/100**
```
