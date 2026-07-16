# Strategy Decision Record

**Purpose:** Document the identification strategy decision with alternatives considered and rationale. Saved to `quality_reports/decisions/`. Enables traceability and helps the writer explain design choices.

---

## Template

```markdown
# Strategy Decision Record: [Project Name]

**Date:** [YYYY-MM-DD]
**Decision type:** [identification-strategy / theory-approach / estimation-method]

---

## Decision

[What was decided -- one clear sentence]

Example: "We use a staggered difference-in-differences design with Callaway-Sant'Anna (2021) estimator, using never-treated units as the comparison group."

---

## Alternatives Considered

### Alternative 1: [Design Name]
- **Description:** [what it would look like]
- **Why rejected:** [specific reason -- e.g., "no valid instrument available," "insufficient density at cutoff," "no clean donor pool"]
- **What would make this viable:** [what data or variation would be needed]

### Alternative 2: [Design Name]
- **Description:** [what it would look like]
- **Why rejected:** [specific reason]
- **What would make this viable:** [what would be needed]

### Alternative 3: [Design Name]
- **Description:** [what it would look like]
- **Why rejected:** [specific reason]
- **What would make this viable:** [what would be needed]

---

## Rationale

[Why the chosen approach is best given the data, question, and institutional setting. 2-3 sentences.]

---

## Key Assumptions

| Assumption | Statement | Credibility | If violated |
|-----------|-----------|-------------|-------------|
| [A1] | [what must hold] | [why we believe it] | [what happens to results] |
| [A2] | [what must hold] | [why we believe it] | [what happens to results] |

---

## What Would Invalidate This Strategy

- [Finding 1]: [e.g., "Pre-trends test shows significant pre-period coefficients"]
- [Finding 2]: [e.g., "First-stage F < 10"]
- [Finding 3]: [e.g., "Manipulation detected at the RDD cutoff"]

If any of these occur, the fallback is: [what we would do instead]

---

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| [risk] | [low/med/high] | [low/med/high] | [what we do about it] |
```
