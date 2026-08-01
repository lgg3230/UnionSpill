#!/usr/bin/env python3
"""Verify the within-firm v2 Stata port.

Targets:
  * A6 monthly/hourly unchanged versus current canonical CSVs.
  * A8 printed rows (col == firm) unchanged versus current canonical CSVs.
  * A7 firm / firm_full rows unchanged versus current canonical CSVs.
  * A7 within / overall counts match the R output exactly.
  * A7 within / overall b and se match the R output at 4 printed decimals.

Writes quality_reports/audits/2026-07-31_within_firm_verify.md.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import math
import sys

import pandas as pd


ROOT = Path(__file__).resolve().parents[3]
TABLES = ROOT / "Tables/layer_connectivity/07_within_firm"
R_OUT = ROOT / "Programs/within_firm_final/output"
REPORT = ROOT / "quality_reports/audits/2026-07-31_within_firm_verify.md"


EXPECTED_N = {
    ("edu2", "within"): 50612,
    ("edu2", "overall"): 57789,
    ("gender", "within"): 53592,
    ("gender", "overall"): 59289,
    ("ten2", "within"): 54650,
    ("ten2", "overall"): 59786,
}


@dataclass
class Check:
    target: str
    key: str
    status: str
    detail: str


checks: list[Check] = []


def add(target: str, key: str, ok: bool, detail: str) -> None:
    checks.append(Check(target, key, "PASS" if ok else "FAIL", detail))


def read_csv(path: Path) -> pd.DataFrame:
    if not path.exists():
        raise FileNotFoundError(path)
    return pd.read_csv(path)


def read_csv_str(path: Path) -> pd.DataFrame:
    if not path.exists():
        raise FileNotFoundError(path)
    return pd.read_csv(path, dtype=str, keep_default_na=False)


def fmt4(x: float) -> str:
    return f"{float(x):.4f}"


def is_byte_identical(old_name: str, new_name: str) -> bool:
    return (TABLES / old_name).read_bytes() == (TABLES / new_name).read_bytes()


def subset_string_equal(
    old_name: str,
    new_name: str,
    key: list[str],
    mask_col: str,
    mask_values: set[str],
) -> tuple[bool, str]:
    old = read_csv_str(TABLES / old_name)
    new = read_csv_str(TABLES / new_name)
    old_s = old[old[mask_col].isin(mask_values)].sort_values(key).reset_index(drop=True)
    new_s = new[new[mask_col].isin(mask_values)].sort_values(key).reset_index(drop=True)
    if list(old_s.columns) != list(new_s.columns):
        return False, "schema differs"
    if old_s.shape != new_s.shape:
        return False, f"shape differs: old {old_s.shape}, new {new_s.shape}"
    neq = old_s.ne(new_s)
    if not bool(neq.to_numpy().any()):
        return True, f"{len(old_s)} rows byte/string identical after keyed sort"
    loc = list(zip(*neq.to_numpy().nonzero()))[0]
    row, col = loc
    cname = old_s.columns[col]
    row_key = ", ".join(f"{k}={old_s.loc[row, k]}" for k in key)
    return False, f"first mismatch at {row_key}, {cname}: old={old_s.loc[row, cname]} new={new_s.loc[row, cname]}"


def verify_unchanged() -> None:
    for old_name, new_name in [
        ("a6_group.csv", "a6_group_v2.csv"),
        ("a6_partition.csv", "a6_partition_v2.csv"),
        ("a6_group_hw.csv", "a6_group_hw_v2.csv"),
        ("a6_partition_hw.csv", "a6_partition_hw_v2.csv"),
    ]:
        ok = is_byte_identical(old_name, new_name)
        add("A6 unchanged", f"{old_name} vs {new_name}", ok, "byte-identical" if ok else "file bytes differ")

    for old_name, new_name in [("a8.csv", "a8_v2.csv"), ("a8_hw.csv", "a8_hw_v2.csv")]:
        ok, detail = subset_string_equal(
            old_name,
            new_name,
            ["partition", "col", "p90", "outcome"],
            "col",
            {"firm"},
        )
        add("A8 printed rows unchanged", f"{old_name} col==firm", ok, detail)

    for old_name, new_name in [("a7.csv", "a7_v2.csv"), ("a7_hw.csv", "a7_hw_v2.csv")]:
        ok, detail = subset_string_equal(
            old_name,
            new_name,
            ["partition", "col", "outcome"],
            "col",
            {"firm", "firm_full"},
        )
        add("A7 firm columns unchanged", f"{old_name} firm/firm_full", ok, detail)


def verify_a7_against_r(stata_name: str, r_name: str, exercise: str) -> pd.DataFrame:
    stata = read_csv(TABLES / stata_name)
    rout = read_csv(R_OUT / r_name)
    merged = stata.merge(
        rout,
        on=["partition", "col", "outcome"],
        suffixes=("_stata", "_r"),
        validate="one_to_one",
    )
    group = merged[merged["col"].isin(["within", "overall"])].copy()

    rows = []
    for _, row in group.sort_values(["partition", "col", "outcome"]).iterrows():
        key_tuple = (row["partition"], row["col"])
        expected_n = EXPECTED_N[key_tuple]
        key = f"{exercise}:{row['partition']},{row['col']},{row['outcome']}"

        n_ok = int(row["n_stata"]) == int(row["n_r"]) == expected_n
        firms_ok = int(row["firms_stata"]) == int(row["firms_r"])
        add(
            "A7 group counts vs R",
            key,
            n_ok and firms_ok,
            (
                f"N stata={int(row['n_stata'])}, R={int(row['n_r'])}, expected={expected_n}; "
                f"firms stata={int(row['firms_stata'])}, R={int(row['firms_r'])}"
            ),
        )

        b_ok = fmt4(row["b_stata"]) == fmt4(row["b_r"])
        se_ok = fmt4(row["se_stata"]) == fmt4(row["se_r"])
        add(
            "A7 group b,se vs R at 4dp",
            key,
            b_ok and se_ok,
            (
                f"b {row['b_stata']:.10g} vs {row['b_r']:.10g} "
                f"({fmt4(row['b_stata'])} vs {fmt4(row['b_r'])}); "
                f"se {row['se_stata']:.10g} vs {row['se_r']:.10g} "
                f"({fmt4(row['se_stata'])} vs {fmt4(row['se_r'])})"
            ),
        )

        bpre_ok = fmt4(row["bpre_stata"]) == fmt4(row["bpre_r"])
        sepre_ok = fmt4(row["sepre_stata"]) == fmt4(row["sepre_r"])
        add(
            "A7 group placebo vs R at 4dp",
            key,
            bpre_ok and sepre_ok,
            (
                f"bpre {row['bpre_stata']:.10g} vs {row['bpre_r']:.10g} "
                f"({fmt4(row['bpre_stata'])} vs {fmt4(row['bpre_r'])}); "
                f"sepre {row['sepre_stata']:.10g} vs {row['sepre_r']:.10g} "
                f"({fmt4(row['sepre_stata'])} vs {fmt4(row['sepre_r'])})"
            ),
        )

        rows.append(
            {
                "exercise": exercise,
                "partition": row["partition"],
                "col": row["col"],
                "outcome": row["outcome"],
                "b_stata": row["b_stata"],
                "b_r": row["b_r"],
                "se_stata": row["se_stata"],
                "se_r": row["se_r"],
                "n": int(row["n_stata"]),
                "firms": int(row["firms_stata"]),
                "b_4dp": fmt4(row["b_stata"]),
                "se_4dp": fmt4(row["se_stata"]),
            }
        )
    return pd.DataFrame(rows)


def verify_a8_key() -> None:
    for old_name, new_name in [("a8.csv", "a8_v2.csv"), ("a8_hw.csv", "a8_hw_v2.csv")]:
        old = read_csv(TABLES / old_name)
        new = read_csv(TABLES / new_name)
        try:
            old.merge(
                new,
                on=["partition", "col", "p90", "outcome"],
                suffixes=("_old", "_new"),
                validate="one_to_one",
            )
            add("A8 merge key", f"{old_name} vs {new_name}", True, "validated one-to-one on partition,col,p90,outcome")
        except Exception as exc:  # pragma: no cover - report path
            add("A8 merge key", f"{old_name} vs {new_name}", False, repr(exc))


def load_balance() -> pd.DataFrame:
    frames = []
    for name in ["singleton_balance_v2.csv", "singleton_balance_hw_v2.csv"]:
        path = TABLES / name
        if path.exists():
            frames.append(read_csv(path))
        else:
            add("Balance table", name, False, "missing")
    if not frames:
        return pd.DataFrame()
    bal = pd.concat(frames, ignore_index=True)
    needed = {"exercise", "partition", "col", "outcome", "variable", "sample", "n", "value"}
    missing = needed - set(bal.columns)
    add("Balance table", "schema", not missing, "schema ok" if not missing else f"missing columns: {sorted(missing)}")
    return bal


def balance_summary(bal: pd.DataFrame) -> pd.DataFrame:
    if bal.empty:
        return bal
    # The do-files record balance using the wage-outcome main regression sample.
    wide = (
        bal.pivot_table(
            index=["exercise", "partition", "col", "outcome", "variable"],
            columns="sample",
            values=["n", "value"],
            aggfunc="first",
        )
        .reset_index()
    )
    wide.columns = [
        "_".join([str(x) for x in col if str(x)])
        if isinstance(col, tuple)
        else str(col)
        for col in wide.columns
    ]
    for col in ["value_kept", "value_dropped"]:
        if col not in wide:
            wide[col] = math.nan
    wide["diff_dropped_minus_kept"] = wide["value_dropped"] - wide["value_kept"]
    return wide.sort_values(["exercise", "partition", "col", "variable"]).reset_index(drop=True)


def md_table(df: pd.DataFrame, floatfmt: str = ".6g") -> str:
    if df.empty:
        return "_No rows._"
    return df.to_markdown(index=False, floatfmt=floatfmt)


def write_report(a7_detail: pd.DataFrame, bal_wide: pd.DataFrame) -> None:
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    check_df = pd.DataFrame([c.__dict__ for c in checks])
    failed = check_df[check_df["status"] != "PASS"]
    status = "PASS" if failed.empty else "FAIL"

    balance_display = bal_wide.copy()
    if not balance_display.empty:
        keep_cols = [
            "exercise",
            "partition",
            "col",
            "variable",
            "n_kept",
            "value_kept",
            "n_dropped",
            "value_dropped",
            "diff_dropped_minus_kept",
        ]
        balance_display = balance_display[keep_cols]

    lines = [
        "# Within-Firm V2 Verification",
        "",
        f"Overall status: **{status}**",
        "",
        "Generated by `Programs/layer_connectivity/07_within_firm/03_verify_v2.py`.",
        "",
        "## Implementation Notes",
        "",
        "- The v2 Stata files keep Stata's original `_pctile` plus `>=` bin construction; the R-only `tie <- \"down\"` convention was not ported.",
        "- The implementation follows `R/04_engine.R:185-191`: nested plain fixed effects are omitted after introducing the group-interacted fixed effects. This is the main place where the code-level audit was more precise than the README claim that nothing is removed.",
        "- The group fixed effects use `layer_id_num` in Stata because string `layer_id` cannot be used as a factor variable; the string `layer_id` is still used for group labels and filters.",
        "- A8 checks merge on `(partition, col, p90, outcome)`, with `p90` included in the key.",
        "",
        "## Pass/Fail Checks",
        "",
        md_table(check_df),
        "",
        "## A7 Group Estimates Against R Output",
        "",
        "The target is exact integer agreement for `N` and firm counts, and four-decimal agreement for `b` and `se`.",
        "",
        md_table(a7_detail, floatfmt=".10g"),
        "",
        "## Kept-vs-Dropped Singleton Balance",
        "",
        "Balance is computed from the v2 wage-outcome main regression sample for each partition and A7 group column. The wage and employment rows have identical `N` in the v2 outputs, so this captures the singleton-dropping support loss that drives the revised estimand. `bal_pre_group_wage` is monthly wage level in the monthly run and hourly wage level in the hourly run; `microregion_distinct` and `microregion_hhi` summarize the categorical microregion distribution.",
        "",
        md_table(balance_display, floatfmt=".6g"),
        "",
    ]
    if not failed.empty:
        lines.extend(
            [
                "## Failures Requiring Diagnosis",
                "",
                md_table(failed),
                "",
            ]
        )
    REPORT.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    verify_unchanged()
    verify_a8_key()
    a7_monthly = verify_a7_against_r("a7_v2.csv", "a7.csv", "monthly")
    a7_hourly = verify_a7_against_r("a7_hw_v2.csv", "a7_hw.csv", "hourly")
    bal = load_balance()
    bal_wide = balance_summary(bal)
    a7_detail = pd.concat([a7_monthly, a7_hourly], ignore_index=True)
    write_report(a7_detail, bal_wide)
    return 1 if any(c.status != "PASS" for c in checks) else 0


if __name__ == "__main__":
    sys.exit(main())
