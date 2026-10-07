#!/usr/bin/env python3
"""
3163_verify_baseline.py
=======================
Replication gate for 3162_pure_control_cutoff.do. Called from Stata after the
three replication columns are estimated, before the quantile cutoffs run.

Compares, for the four outcomes:
    zero       vs published Panel A  (zero-connectivity controls)
    fixed_001  vs published 3012 Panel B  (connectivity <= 0.01)
    all        vs published Panel C  (all untreated; paper's Panel B)
on main, main_se, pre, pre_se (to the 4 published decimals) and n_obs,
n_estab (exactly).

Published source: the CSVs behind tab:direct_connectivity_robust,
    Tables/main_results_currentconn/results_direct_panel{A,B,C}_currentconn_wages.csv

Writes <tables>/verify_baseline.txt always, and <tables>/verify_pass.flag only
if every comparison matches. Exit code 0 on pass, 1 on fail.

Usage
-----
    python 3163_verify_baseline.py [TABLES_DIR]
"""

import csv
import sys
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[3]
PUB_DIR = PROJECT / "Tables" / "main_results_currentconn"
TABLES = Path(sys.argv[1]) if len(sys.argv) > 1 else PROJECT / "Tables" / "pure_control_cutoff"

OUTCOMES = ["lr_remdezr_w", "lr_remdezr_h_w", "l_firm_emp", "numb_clauses"]
PAIRS = [("zero", "A"), ("fixed_001", "B"), ("all", "C")]
DECIMAL_ROWS = ["main", "main_se", "pre", "pre_se"]
COUNT_ROWS = ["n_obs", "n_estab"]
# Published values are %9.4f: a match is a difference within half a unit in the
# 4th decimal (plus float slack).
TOL = 0.5e-4 + 1e-9


def load_published(panel):
    """{(outcome, row_type): float} from the semicolon-delimited published CSV."""
    path = PUB_DIR / f"results_direct_panel{panel}_currentconn_wages.csv"
    out = {}
    with open(path) as fh:
        next(fh)  # header
        for line in fh:
            parts = [p.strip().strip('"') for p in line.strip().split(";")]
            if len(parts) != 5:
                continue
            _, _, outcome, row, value = parts
            value = value.rstrip("*").replace(",", "").strip()
            out[(outcome, row)] = float(value)
    return out


def load_new():
    """{(section, outcome, row_type): float} from 3162's long CSV."""
    path = TABLES / "pure_control_cutoff.csv"
    out = {}
    with open(path, newline="") as fh:
        for r in csv.DictReader(fh):
            v = r["value"].strip()
            out[(r["section"], r["outcome"], r["row_type"])] = float("nan") if v in ("", ".") else float(v)
    return out


def main():
    new = load_new()
    lines = ["Replication check: 3162 vs published direct-effects CSVs", ""]
    ok = True
    for section, panel in PAIRS:
        pub = load_published(panel)
        lines.append(f"[{section} vs published Panel {panel}]")
        for outcome in OUTCOMES:
            for row in DECIMAL_ROWS + COUNT_ROWS:
                key_new = (section, outcome, row)
                key_pub = (outcome, row)
                if key_new not in new or key_pub not in pub:
                    ok = False
                    lines.append(f"  MISSING  {outcome:16s} {row:8s}")
                    continue
                a, b = new[key_new], pub[key_pub]
                match = (a == b) if row in COUNT_ROWS else abs(a - b) <= TOL
                ok &= match
                lines.append(
                    f"  {'ok  ' if match else 'DIFF'}     {outcome:16s} {row:8s} "
                    f"new={a:.10g}  published={b:g}"
                )
        lines.append("")
    lines.append("RESULT: PASS" if ok else "RESULT: FAIL")

    TABLES.mkdir(parents=True, exist_ok=True)
    (TABLES / "verify_baseline.txt").write_text("\n".join(lines) + "\n")
    flag = TABLES / "verify_pass.flag"
    if ok:
        flag.write_text("pass\n")
    elif flag.exists():
        flag.unlink()
    print("\n".join(lines))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
