# Table A7: testing each group coefficient against the firm-level coefficient

This adds one row per panel to Table A7, "Test: = Firm-level (p-value)". It is the p-value of the
test that each Group-Connectivity coefficient (columns 2, 3, 5, 6) equals the firm-level
coefficient of its block (column 1 for wages, column 4 for employment).

The test is a stacked regression, the same design as the Table 1 Panel A vs. B test in
`conn_margins/3022_direct_sample_coef_test.do`:
- the firm-level and group-level samples are stacked;
- each sample keeps its own fixed effects;
- the connectivity term is interacted with a sample indicator;
- standard errors are clustered by establishment.

`A7_test_note.pdf` explains the motivation, the procedure and the assumptions. It also has the
proposed footnote and the table as it would appear.

## Files

| file | what it is |
|---|---|
| `stata/a7_stacktest.do` | the test: one program, `_stacktest_a7` |
| `stata/3132_additions.do` | four short blocks to paste into `3132_within_firm_hourly.do` |
| `A7_test_note.pdf` | explanation, footnote, table |

## Adding it to the pipeline

1. Copy `stata/a7_stacktest.do` into `Programs/analysis/layer_connectivity/07_within_firm/`.
2. Paste the four blocks of `stata/3132_additions.do` into `3132_within_firm_hourly.do`, at the
   places marked in that file: after the helper programs, in Section 2, at the end of 4c, and in
   Section 5.
3. Run 3131 → 3132 as usual. Nothing existing changes. One new file is written:
   `$tables/a7_tests_hw<suffix>.csv`, one row per partition × column × outcome. Its `p` column is
   the bracketed number in the table.

## Table row (4090_table_within_firm.py, `make_groupspecs`)

Read the new CSV keyed on `(partition, kind, outcome)`. In each panel, add this line after the
Group-Connectivity standard-error row:

```python
rf"Test: = Firm-level ($p$-value) &  & [{pw:.3f}] & [{po:.3f}] &  & [{pwe:.3f}] & [{poe:.3f}] \\",
```

Here `pw`, `po`, `pwe` and `poe` are `p` for (within, wage), (overall, wage), (within, emp) and
(overall, emp).

Add to the table notes:

> Test: = Firm-level reports, in brackets, the $p$-value of the test that the Group-Connectivity
> coefficient equals the firm-level coefficient of column (1) or (4), from a stacked regression of
> the firm- and group-level samples that interacts the connectivity term and all fixed effects with
> a sample indicator, with standard errors clustered at the establishment level.

## Expected values

These come from hourly wages, run inside 3132 on the inputs that reproduce the published Table A7.

| | within (col 2) | overall (col 3) | within emp (col 5) | overall emp (col 6) |
|---|---|---|---|---|
| Education | 0.028 | 0.067 | 0.312 | 0.105 |
| Gender | 0.190 | 0.312 | 0.873 | 0.623 |
| Tenure | 0.043 | 0.098 | 0.675 | 0.852 |

With the blocks added, 3132 reproduces every published A7 estimate unchanged, and the
stacked copies reproduce the A7 coefficients and samples exactly.

Optional robustness: `_stacktest_a7 ... both` re-estimates the firm-level coefficient on the
firms that employ both groups. The within-column p-values become 0.044 / 0.301 / 0.055.
