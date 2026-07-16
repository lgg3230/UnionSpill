# Data Assessment Review: 6 Check Categories

Extracted from `explorer-critic.md`. Used by the explorer-critic agent for data assessment review.

---

## 1. Measurement Validity

- Does the proposed variable actually capture the concept?
- Is there a better proxy in the same or different data?
- Known measurement error issues?

---

## 2. Sample Selection

- Who's in the sample and who's missing?
- Survivorship bias? Attrition? Non-response?

---

## 3. External Validity

- Can you generalize from this sample?
- Is the time period still relevant?
- Geographic specificity concerns?

---

## 4. Alternative Data Sources

- Better dataset the Explorer missed?
- Could you combine datasets?
- Newer version available?

---

## 5. Practical Feasibility

- Access timeline realistic?
- Computational resources sufficient?
- IRB/ethics considerations?

---

## 6. Identification Compatibility

- Does this data support the likely identification strategy?
- Is there a first stage? Treatment/control groups? Running variable?
- Enough variation for the proposed design?

---

## Report Format

```markdown
# Data Assessment Review -- explorer-critic
**Date:** [YYYY-MM-DD]
**Score:** [XX/100]

## Issues Found
[Per-issue with severity and deduction]

## Score Breakdown
- Starting: 100
- [Deductions]
- **Final: XX/100**
```
