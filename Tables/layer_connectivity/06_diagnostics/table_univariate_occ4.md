# Univariate Cross-Firm Spillover by Occupation Layer (Check 3 Diagnostic)

Each column is a **separate** cross-firm regression restricted to that layer only.
FE: firm + year + micro×year + industry×year + mode×year.
Connectivity scaled to P90 of that layer's control firms at 2009.

## Log Dec. wage

| | Managers | High-skill | Bur. lower | Low-skill |
|---|---|---|---|---|
| **Post × Connectivity** | -0.0088*** | 0.0005 | -0.0017 | -0.0001 |
| | (0.0029) | (0.0030) | (0.0031) | (0.0025) |
| **Pre-trend (placebo)** | 0.0072 | -0.0025 | 0.0066 | -0.0018 |
| | (0.0046) | (0.0044) | (0.0043) | (0.0028) |
| *Observations* | 16,307 | 22,198 | 26,379 | 28,369 |
| *Firms* | 2,338 | 3,037 | 3,511 | 3,675 |
| *Pre-F p-value* | 0.650 | 0.556 | 0.410 | 0.276 |

## Log employment

| | Managers | High-skill | Bur. lower | Low-skill |
|---|---|---|---|---|
| **Post × Connectivity** | 0.0144*** | 0.0190* | -0.0048 | -0.0023 |
| | (0.0050) | (0.0114) | (0.0051) | (0.0104) |
| **Pre-trend (placebo)** | -0.0182*** | -0.0113 | -0.0045 | 0.0119 |
| | (0.0066) | (0.0078) | (0.0066) | (0.0078) |
| *Observations* | 16,307 | 22,198 | 26,379 | 28,369 |
| *Firms* | 2,338 | 3,037 | 3,511 | 3,675 |
| *Pre-F p-value* | 0.011 | 0.029 | 0.553 | 0.063 |

---
*\*p<0.10, \*\*p<0.05, \*\*\*p<0.01. Standard errors clustered at firm level.*