#!/usr/bin/env python3
"""Build within-firm group-spec TeX fragments from A7 CSV outputs."""

from __future__ import annotations

import csv
import math
import argparse
from datetime import date
from pathlib import Path

ROOT = Path("/kellogg/proj/lgg3230/UnionSpill")
TABLE_DIR = ROOT / "Tables/layer_connectivity/07_within_firm"
FRAG_DIR = ROOT / "quality_reports/replication/hourly_variant_currentconn/frag"
FRAG_DIR.mkdir(parents=True, exist_ok=True)

PANELS = [
    ("edu2", "Panel A:", "Education (no HS / HS+)"),
    ("gender", "Panel B:", "Gender (female / male)"),
    ("ten2", "Panel C:", r"Tenure ($<$12mo / $\geq$12mo)"),
]
PANEL_BY_PARTITION = {part: (part, panel, label) for part, panel, label in PANELS}


def read_rows(path: Path) -> dict[tuple[str, str, str], dict[str, str]]:
    with path.open(newline="") as f:
        return {
            (row["partition"], row["col"], row["outcome"]): row
            for row in csv.DictReader(f)
        }


def as_float(row: dict[str, str], key: str) -> float:
    val = row[key]
    return float(val) if val not in ("", ".") else math.nan


def stars(b: float, se: float) -> str:
    if not math.isfinite(b) or not math.isfinite(se) or se == 0:
        return ""
    z = abs(b / se)
    if z >= 2.575829:
        return "***"
    if z >= 1.959964:
        return "**"
    if z >= 1.644854:
        return "*"
    return ""


def fmt_num(x: float) -> str:
    if not math.isfinite(x):
        return "---"
    s = f"{x:.4f}"
    if s.startswith("-"):
        s = "$-$" + s[1:]
    return s


def fmt_est(row: dict[str, str], key: str = "b", se_key: str = "se") -> str:
    b = as_float(row, key)
    se = as_float(row, se_key)
    return f"{fmt_num(b)}{stars(b, se)}"


def fmt_se(row: dict[str, str], key: str = "se") -> str:
    return f"({fmt_num(as_float(row, key))})"


def fmt_int(row: dict[str, str], key: str) -> str:
    val = row[key]
    if val in ("", "."):
        return "---"
    return f"{int(float(val)):,}".replace(",", "{,}")


def make_fragment(
    rows: dict[tuple[str, str, str], dict[str, str]],
    *,
    hourly: bool,
    panels: list[tuple[str, str, str]],
) -> str:
    wage_title = "Log Hourly Wages" if hourly else "Log Wages"
    title_suffix = r" (\textbf{log hourly wages})" if hourly else ""
    panel_labels = [label.split(" (", 1)[0].lower() for _, _, label in panels]
    caption_scope = ", ".join(panel_labels)
    out = [
        r"\begin{table}[H]",
        r"\centering",
        rf"\caption{{Group-level spillover effects --- {caption_scope}{title_suffix}}}",
        r"\scriptsize",
        r"\begin{tabular}{lcccccc}",
        r"\toprule\toprule",
        rf" & \multicolumn{{3}}{{c}}{{{wage_title}}} & \multicolumn{{3}}{{c}}{{Log Employment}} \\",
        r"\cmidrule(lr){2-4} \cmidrule(lr){5-7}",
        r" & \shortstack{Firm-\\level} & \shortstack{Within\\firms} & Overall",
        r" & \shortstack{Firm-\\level} & \shortstack{Within\\firms} & Overall \\",
        r" & (1) & (2) & (3) & (4) & (5) & (6) \\",
        r"\midrule",
    ]

    for idx, (part, panel, label) in enumerate(panels):
        fw = rows[(part, "firm_full", "wage")]
        fe = rows[(part, "firm_full", "emp")]
        ww = rows[(part, "within", "wage")]
        ow = rows[(part, "overall", "wage")]
        we = rows[(part, "within", "emp")]
        oe = rows[(part, "overall", "emp")]
        out.extend(
            [
                rf"\textbf{{{panel}}} {label} &  &  &  &  &  &  \\",
                rf"Connectivity $\times$ Post & {fmt_est(fw)} &  &  & {fmt_est(fe)} &  &  \\",
                rf" & {fmt_se(fw)} &  &  & {fmt_se(fe)} &  &  \\",
                rf"Group-Connectivity $\times$ Post &  & {fmt_est(ww)} & {fmt_est(ow)} &  & {fmt_est(we)} & {fmt_est(oe)} \\",
                rf" &  & {fmt_se(ww)} & {fmt_se(ow)} &  & {fmt_se(we)} & {fmt_se(oe)} \\",
                r" &  &  &  &  &  &  \\",
                rf"Observations & {fmt_int(fw, 'n')} & {fmt_int(ww, 'n')} & {fmt_int(ow, 'n')} & {fmt_int(fe, 'n')} & {fmt_int(we, 'n')} & {fmt_int(oe, 'n')} \\",
                rf"Groups $\times$ firms & --- & {fmt_int(ww, 'gxf')} & {fmt_int(ow, 'gxf')} & --- & {fmt_int(we, 'gxf')} & {fmt_int(oe, 'gxf')} \\",
                rf"Firms & {fmt_int(fw, 'firms')} & {fmt_int(ww, 'firms')} & {fmt_int(ow, 'firms')} & {fmt_int(fe, 'firms')} & {fmt_int(we, 'firms')} & {fmt_int(oe, 'firms')} \\",
                rf"Pre-trend (placebo) & {fmt_est(fw, 'bpre', 'sepre')} & {fmt_est(ww, 'bpre', 'sepre')} & {fmt_est(ow, 'bpre', 'sepre')} & {fmt_est(fe, 'bpre', 'sepre')} & {fmt_est(we, 'bpre', 'sepre')} & {fmt_est(oe, 'bpre', 'sepre')} \\",
                rf" & {fmt_se(fw, 'sepre')} & {fmt_se(ww, 'sepre')} & {fmt_se(ow, 'sepre')} & {fmt_se(fe, 'sepre')} & {fmt_se(we, 'sepre')} & {fmt_se(oe, 'sepre')} \\",
            ]
        )
        out.append(r"\midrule")

    out.extend(
        [
            r"\textbf{Additional Controls} &  &  &  &  &  &  \\",
            r"Group-level Variables &  & \checkmark & \checkmark &  & \checkmark & \checkmark \\",
            r"Firm $\times$ Year FE &  & \checkmark &  &  & \checkmark &  \\",
            r"\bottomrule\bottomrule",
            r"\end{tabular}",
        ]
    )

    if hourly:
        fw = rows[(panels[0][0], "firm_full", "wage")]
        note = (
            r"\begin{minipage}{\linewidth}\vspace{3pt}"
            rf"\scriptsize\textit{{Notes:}} Hourly-wage counterpart of the group-level spillover table. "
            rf"The firm-level hourly spillover benchmark is {fmt_num(as_float(fw, 'b'))} "
            rf"with standard error {fmt_num(as_float(fw, 'se'))}. "
            r"The ``Within firms'' columns add firm $\times$ year fixed effects, so identification comes "
            r"from differential group connectivity across groups within the same firm-year; the ``Overall'' "
            r"columns instead use industry, microregion, and negotiation-month interactions with year. "
            r"Group-level employment columns are reported for completeness but remain mechanically "
            r"division-biased because group employment enters the connectivity denominator. Standard errors "
            rf"are clustered by establishment. Produced from the {date.today().isoformat()} run of the "
            r"hourly within-firm pipeline using corrected layer-level hourly wages."
            r"\end{minipage}"
        )
    else:
        note = (
            r"\begin{minipage}{\linewidth}\vspace{4pt}"
            r"\scriptsize\textit{Notes:} Each panel partitions workers into two groups---by education "
            r"(Panel~A), gender (Panel~B), or tenure (Panel~C)---and estimates spillover effects at the "
            r"firm and group level, on the sample of untreated, balanced-panel establishments. Group-"
            r"Connectivity is defined analogously to firm-level Connectivity, replacing total firm "
            r"employment with group-specific employment when normalizing worker flows to directly treated "
            r"establishments. Both measures are scaled so that a value of~1 corresponds to the 90th "
            r"percentile of the firm-level distribution. In the ``Within firms'' and ``Overall'' columns, "
            r"the unit of observation is a group $\times$ firm $\times$ year cell and all regressions "
            r"include group $\times$ firm fixed effects. ``Within firms'' columns add firm $\times$ year "
            r"fixed effects; ``Overall'' columns instead include microregion $\times$ year, industry "
            r"$\times$ year, and negotiation-month $\times$ year fixed effects. Group-level controls are "
            r"year-interacted quartile bins of pre-treatment group wage, group employment, and group "
            r"per-worker flows. Pre-trend (placebo) reports the coefficient from a placebo regression "
            r"estimated on pre-treatment data only (2009--2010 relative to 2011). Standard errors clustered "
            r"at the establishment level in parentheses. *** p$<$0.01, ** p$<$0.05, * p$<$0.10."
            r"\end{minipage}"
        )
    out.extend([note, r"\end{table}"])
    return "\n".join(out) + "\n"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--monthly-csv", type=Path, default=TABLE_DIR / "a7.csv")
    parser.add_argument("--hourly-csv", type=Path, default=TABLE_DIR / "a7_hw.csv")
    parser.add_argument("--partitions", nargs="+", default=["edu2", "gender", "ten2"],
                        choices=sorted(PANEL_BY_PARTITION))
    parser.add_argument("--monthly-out", type=Path, default=FRAG_DIR / "t_groupspecs.tex")
    parser.add_argument("--hourly-out", type=Path, default=FRAG_DIR / "t_groupspecs_hw.tex")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    panels = [PANEL_BY_PARTITION[p] for p in args.partitions]
    args.monthly_out.parent.mkdir(parents=True, exist_ok=True)
    args.hourly_out.parent.mkdir(parents=True, exist_ok=True)
    args.monthly_out.write_text(
        make_fragment(read_rows(args.monthly_csv), hourly=False, panels=panels)
    )
    args.hourly_out.write_text(
        make_fragment(read_rows(args.hourly_csv), hourly=True, panels=panels)
    )


if __name__ == "__main__":
    main()
