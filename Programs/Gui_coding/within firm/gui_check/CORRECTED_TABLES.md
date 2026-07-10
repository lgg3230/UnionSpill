# Section 6.2 tables under the corrected specifications

*Numbers from the Stata-validated R replication (gui_check/scripts). "Corrected" = the specification choices argued for in REPORT.md: Table A7 keeps the paper's full sample and adds group×year FE; Table A8 adds the Table-2-baseline trend controls (industry×year, microregion×year, negotiation-month×year) to all columns. Stars: *** p<0.01, ** p<0.05, * p<0.10, firm-clustered SEs.*

## Table A7 (corrected): Group-level spillover effects — education and gender

*Changes vs. draft: group×year FE added to "Within firms" and "Overall" columns; "Groups × firms" row fixed (counting bug). Sample unchanged (full untreated balanced panel). Columns (1)/(4) are the Table 2 baseline, reprinted unchanged.*

|  | **Log Wages** | | | **Log Employment** | | |
|---|---|---|---|---|---|---|
|  | Firm-level (1) | Within firms (2) | Overall (3) | Firm-level (4) | Within firms (5) | Overall (6) |
| **Panel A: Education (no HS / has HS)** | | | | | | |
| Connectivity × Post | 0.0051** (0.0023) | | | 0.0006 (0.0083) | | |
| Group-Connectivity × Post | | −0.0041 (0.0043) | 0.0022 (0.0025) | | **−0.0200** (0.0099)** | −0.0091 (0.0069) |
| Observations | 32,498 | 52,458 | 59,391 | 32,696 | 52,458 | 59,391 |
| Groups × firms | — | 7,160 | 7,762 | — | 7,160 | 7,762 |
| Firms | 4,085 | 3,580 | 4,172 | 4,087 | 3,580 | 4,172 |
| Pre-trend (placebo) | 0.0020 (0.0025) | 0.0046 (0.0054) | 0.0020 (0.0029) | −0.0016 (0.0064) | 0.0195* (0.0118) | 0.0069 (0.0054) |
| **Panel B: Gender (female / male)** | | | | | | |
| Connectivity × Post | 0.0051** (0.0023) | | | 0.0006 (0.0083) | | |
| Group-Connectivity × Post | | −0.0006 (0.0030) | 0.0022 (0.0020) | | −0.0001 (0.0049) | 0.0029 (0.0045) |
| Observations | 32,498 | 55,358 | 60,864 | 32,696 | 55,358 | 60,864 |
| Groups × firms | — | 7,368 | 7,867 | — | 7,368 | 7,867 |
| Firms | 4,085 | 3,684 | 4,175 | 4,087 | 3,684 | 4,175 |
| Pre-trend (placebo) | 0.0020 (0.0025) | −0.0010 (0.0050) | −0.0005 (0.0025) | −0.0016 (0.0064) | −0.0054 (0.0098) | −0.0015 (0.0058) |
| Group-level Variables |  | ✓ | ✓ |  | ✓ | ✓ |
| Group × Year FE |  | ✓ | ✓ |  | ✓ | ✓ |
| Firm × Year FE |  | ✓ |  |  | ✓ |  |

**Draft → corrected, cell by cell (what moves):**

| Cell | Draft | Corrected |
|---|---|---|
| Edu, within wage | −0.0023 (0.0044) | −0.0041 (0.0043) — still ≈0 ✓ |
| Edu, overall wage | 0.0029 (0.0025) | 0.0022 (0.0025) |
| Edu, within emp | −0.0023 (0.0108) | **−0.0200** (0.0099)** ← the one problem cell |
| Edu, overall emp | −0.0056 (0.0070) | −0.0091 (0.0069) |
| Gender, within wage | 0.0001 (0.0030) | −0.0006 (0.0030) |
| Gender, within emp | −0.0025 (0.0049) | −0.0001 (0.0049) |
| Gender, overall wage/emp | 0.0026 / 0.0017 | 0.0022 / 0.0029 |
| "Groups × firms" (edu) | 6,273 / 7,751 | 7,160 / 7,762 |
| "Groups × firms" (gender) | 6,649 / 7,855 | 7,368 / 7,867 |

The section's headline (no within-firm wage differentiation) survives everywhere. The only casualty is the "no within-firm employment response" sentence: the education employment cell turns nominally significant (−0.0200**) — but with a near-mirror placebo (+0.0195*), i.e., the same pre-trend/reversion signature as A8, so it likely reflects a reverting pre-path rather than a treatment effect. Needs an event-study look and a sentence handling it either way.

## Table A8 (corrected): Low-Skill vs. High-Skill Connectivity — education groups

*Change vs. draft: industry×year, microregion×year, and negotiation-month×year FE added to all six columns (matching the Table 2 baseline and Luis's current `02a`). These are exactly the numbers in the package's bundled CSV.*

|  | **Log Wages** | | | **Log Employment** | | |
|---|---|---|---|---|---|---|
|  | Group: No HS (1) | Group: HS+ (2) | Firm-level (3) | Group: No HS (4) | Group: HS+ (5) | Firm-level (6) |
| Low-Skill Connectivity × Post | 0.0003 (0.0058) | 0.0022 (0.0022) | 0.0029 (0.0020) | −0.0100 (0.0107) | 0.0068 (0.0085) | 0.0031 (0.0080) |
| High-Skill Connectivity × Post | 0.0013 (0.0041) | 0.0019 (0.0029) | 0.0022 (0.0023) | 0.0064 (0.0102) | −0.0059 (0.0104) | 0.0026 (0.0079) |
| Observations | 25,882 | 27,651 | 28,227 | 25,882 | 27,651 | 28,227 |
| Firms | 3,492 | 3,533 | 3,546 | 3,492 | 3,533 | 3,546 |
| Pre-trend: Low-Skill | 0.0030 (0.0085) | 0.0010 (0.0026) | −0.0010 (0.0026) | 0.0016 (0.0109) | −0.0063 (0.0086) | 0.0018 (0.0072) |
| Pre-trend: High-Skill | −0.0051 (0.0045) | 0.0012 (0.0038) | 0.0021 (0.0025) | −0.0054 (0.0086) | 0.0151* (0.0077) | 0.0033 (0.0059) |
| Group-level controls | ✓ | ✓ | — | ✓ | ✓ | — |
| Firm-level controls | — | — | ✓ | — | — | ✓ |
| Ind./Micro/Neg-month × Year FE | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

**Draft → corrected (what moves):**

| Cell | Draft | Corrected |
|---|---|---|
| Wage, No-HS: Low / High | −0.0015 / 0.0062 | 0.0003 / 0.0013 |
| Wage, HS+: High | **0.0066** (0.0028)** | 0.0019 (0.0029) |
| Wage, Firm: High | **0.0058** (0.0026)** | 0.0022 (0.0023) |
| Emp, No-HS: Low / High | **−0.0209** / 0.0144*** | −0.0100 / 0.0064 |
| Placebos | two starred (−0.0080*, −0.0154*) | one starred (0.0151*) |

Under the corrected spec the table is a clean null across the board: no differential wage response by skill segment, no employment response, and the previously worrying placebo pattern largely disappears. Every starred result in the draft's A8 is gone. If this spec is adopted, the "Low- and high-skill competition" subsection cannot keep its asymmetric-adjustment narrative (wage response to high-skill pressure, employment response to low-skill pressure); the defensible statement becomes that the firm-level wage response is not detectably driven by one skill segment — which aligns with, rather than contradicts, the section's broader "wages are set at the firm level" message.
