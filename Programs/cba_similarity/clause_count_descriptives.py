"""
clause_count_descriptives.py

Simple descriptive view of how the number of CBA clauses evolves at the
firm × cba_period level inside the regression sample
(lagos_sample_avg==1 & in_balanced_panel==1).

Clause count per (firm, cba_period):
  n_clauses_p = Σ_c mean(cl_c | firm, cba_period)
  i.e. for each firm-period we collapse multiple year rows by taking the mean
  of every cl_* indicator (matches `cba_similarity_prep.py`'s aggregation),
  then sum across the 139 clause indicators. So n_clauses_p is the
  expected number of active clauses in the firm's CBA during that period.

Outputs:
  Graphs/cba_similarity/clause_count_delta_hist.pdf
      Histogram of Δ n_clauses across consecutive cba_periods within firm.
  Graphs/cba_similarity/clause_count_delta_hist_by_group.pdf
      Overlay histogram of Δ with one density per group.
  Graphs/cba_similarity/clause_count_delta_hist_no_p6.pdf
      Same as clause_count_delta_hist + by-group overlay but excluding
      transitions ending in cba_period == 6 (incomplete-year drop-off).
  Graphs/cba_similarity/clause_count_did_distribution.pdf
      Two-panel DiD-style visualization: pre vs post distribution of n_clauses
      for treated firms (left) and untreated zero-connectivity firms (right).
      Pre = cba_period <= 2 (last pre-Sumula); Post = cba_period >= 3.
  Graphs/cba_similarity/clause_count_did_mean_delta.pdf
      DiD on mean Δ n_clauses. Pre = (1→2); Post = (2→3, 3→4, 4→5); the 5→6
      transition is dropped. Treated and Untreated-zero-conn lines, with the
      double difference annotated.
  Graphs/cba_similarity/clause_count_delta_hist_by_subgroup.pdf
      6×4 panel grid: histogram of Δ n_clauses for each of the 24 clause
      subgroups (sub_group in clause_variables_cnes.xlsx; "void" dropped).
  Graphs/cba_similarity/clause_count_delta_hist_by_subgroup_no_p6.pdf
      Same as above but excluding transitions ending in cba_period == 6.
  Graphs/cba_similarity/clause_count_delta_hist_by_broad.pdf
      3-panel histogram of Δ n_clauses by broad clause category
      (employment / wage / other).
  Graphs/cba_similarity/clause_count_delta_hist_by_broad_pre.pdf
      Same 3-panel layout but restricted to the 1→2 transition only
      (no-reform baseline).
  Graphs/cba_similarity/clause_count_delta_hist_pre.pdf
      Overall and by-group Δ histograms restricted to the 1→2 transition.
  Graphs/cba_similarity/clause_count_delta_hist_by_subgroup_pre.pdf
      6×4 per-subgroup Δ histograms restricted to the 1→2 transition.
  Graphs/cba_similarity/clause_count_time_trend.pdf
      Mean n_clauses by cba_period for four groups:
        - Overall
        - Treated (treat_ultra==1)
        - Untreated, positive connectivity (treat_ultra==0 & totaltreat_pw_n>0)
        - Untreated, zero connectivity     (treat_ultra==0 & totaltreat_pw_n==0)
  Tables/cba_similarity/clause_count_delta_summary.csv
      Share of positive / zero / negative deltas, plus mean and median deltas,
      by group (across all consecutive-period within-firm transitions).
  Tables/cba_similarity/clause_count_time_trend.csv
      Mean / median / N of n_clauses by cba_period × group.
  Tables/cba_similarity/clause_count_did_mean_delta.csv
      Pre / post mean Δ by group, DiD point estimate.
"""

import subprocess
from pathlib import Path

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

# ── Paths ─────────────────────────────────────────────────────────────────────
project    = Path("/gpfs/kellogg/proj/lgg3230/UnionSpill")
clauses_path = project / "Data" / "RAIS_aux" / "cba_clauses_by_period.dta"
panel_path   = project / "Data" / "CBA_RAIS_firm_level" / "cba_rais_firm_2009_2016_flows_1.dta"
graphs_dir   = project / "Graphs" / "cba_similarity"
tables_dir   = project / "Tables" / "cba_similarity"
graphs_dir.mkdir(parents=True, exist_ok=True)
tables_dir.mkdir(parents=True, exist_ok=True)

# ── Load clauses by period ────────────────────────────────────────────────────
print("Loading cba_clauses_by_period.dta...", flush=True)
clauses = pd.read_stata(str(clauses_path), convert_categoricals=False)
clauses["identificad"] = clauses["identificad"].astype(str).str.strip().str.zfill(14)

clause_vars = [c for c in clauses.columns if c.startswith("cl_")]
print(f"  {len(clause_vars)} clause indicators, {len(clauses):,} rows", flush=True)

clauses[clause_vars] = clauses[clause_vars].fillna(0)

agg = clauses.groupby(["identificad", "cba_period"]).agg(
    {**{v: "mean" for v in clause_vars},
     "treat_ultra":       "max",
     "lagos_sample_avg":  "max",
     "in_balanced_panel": "max"}
).reset_index()
agg["cba_period"] = agg["cba_period"].astype(int)
agg["n_clauses"] = agg[clause_vars].sum(axis=1)

# Sample restriction
agg = agg[(agg["lagos_sample_avg"] == 1) & (agg["in_balanced_panel"] == 1)].copy()
print(f"  Firm-period rows in lagos+balanced sample: {len(agg):,}", flush=True)
print(f"  Unique firms: {agg['identificad'].nunique():,}", flush=True)

# ── Per-firm connectivity from firm panel (collapse year dimension) ───────────
print("\nLoading firm-level connectivity from firm panel...", flush=True)
panel_cols = ["identificad", "treat_ultra",
              "lagos_sample_avg", "in_balanced_panel", "totaltreat_pw_n"]
parts = []
it = pd.read_stata(str(panel_path), columns=panel_cols,
                   convert_categoricals=False, chunksize=500_000)
for i, chunk in enumerate(it, 1):
    keep = (chunk["lagos_sample_avg"] == 1) & (chunk["in_balanced_panel"] == 1)
    parts.append(chunk.loc[keep, ["identificad", "totaltreat_pw_n"]].copy())
    if i % 10 == 0:
        print(f"  ... chunk {i}", flush=True)
panel = pd.concat(parts, ignore_index=True)
panel["identificad"] = panel["identificad"].astype(str).str.strip().str.zfill(14)
conn = panel.groupby("identificad", as_index=False)["totaltreat_pw_n"].max()
print(f"  Connectivity rows after firm-level collapse: {len(conn):,}", flush=True)

# Merge connectivity onto firm-period table
agg = agg.merge(conn, on="identificad", how="left")
agg["totaltreat_pw_n"] = agg["totaltreat_pw_n"].fillna(0)

# ── Group assignment ──────────────────────────────────────────────────────────
def assign_group(row):
    if row["treat_ultra"] == 1:
        return "Treated"
    if row["totaltreat_pw_n"] > 0:
        return "Untreated, positive conn."
    return "Untreated, zero conn."

agg["group"] = agg.apply(assign_group, axis=1)
print("\nGroup sizes (firm-period obs):")
print(agg["group"].value_counts())
print("\nGroup sizes (unique firms):")
print(agg.groupby("group")["identificad"].nunique())

# ── Time trend table (by cba_period × group) ──────────────────────────────────
trend_overall = (agg.groupby("cba_period")["n_clauses"]
                 .agg(["mean", "median", "count"])
                 .reset_index()
                 .assign(group="Overall"))
trend_by_grp  = (agg.groupby(["cba_period", "group"])["n_clauses"]
                 .agg(["mean", "median", "count"])
                 .reset_index())
trend = pd.concat([trend_overall, trend_by_grp], ignore_index=True)
trend["cba_period"] = trend["cba_period"].astype(int)

trend_csv = tables_dir / "clause_count_time_trend.csv"
trend.to_csv(trend_csv, index=False)
print(f"\nWrote {trend_csv}", flush=True)

# ── Δ across consecutive cba_periods within firm ──────────────────────────────
agg = agg.sort_values(["identificad", "cba_period"]).reset_index(drop=True)
agg["prev_n"]      = agg.groupby("identificad")["n_clauses"].shift(1)
agg["prev_period"] = agg.groupby("identificad")["cba_period"].shift(1)
agg["delta"] = np.where(
    agg["cba_period"] - agg["prev_period"] == 1,
    agg["n_clauses"] - agg["prev_n"],
    np.nan,
)

deltas = agg.dropna(subset=["delta"]).copy()
print(f"\nWithin-firm consecutive-period transitions with Δ defined: "
      f"{len(deltas):,}", flush=True)


def delta_summary(sub: pd.DataFrame) -> dict:
    n = len(sub)
    if n == 0:
        return dict(n=0, share_pos=np.nan, share_zero=np.nan, share_neg=np.nan,
                    mean_delta=np.nan, median_delta=np.nan)
    return dict(
        n=n,
        share_pos =(sub["delta"] > 0).mean(),
        share_zero=(sub["delta"] == 0).mean(),
        share_neg =(sub["delta"] < 0).mean(),
        mean_delta=sub["delta"].mean(),
        median_delta=sub["delta"].median(),
    )

rows = [{"group": "Overall", **delta_summary(deltas)}]
for g, sub in deltas.groupby("group"):
    rows.append({"group": g, **delta_summary(sub)})
delta_csv = tables_dir / "clause_count_delta_summary.csv"
pd.DataFrame(rows).to_csv(delta_csv, index=False)
print(f"Wrote {delta_csv}", flush=True)
print(pd.DataFrame(rows).to_string(index=False))

# ── Plot 1: histogram of Δ across consecutive cba_periods ─────────────────────
plt.rcParams["font.family"] = "DejaVu Sans"
fig, ax = plt.subplots(figsize=(8, 5))

dvals = deltas["delta"].values
lo, hi = np.percentile(dvals, [0.5, 99.5])
bins = np.linspace(np.floor(lo), np.ceil(hi) + 1, 50)
ax.hist(dvals, bins=bins, color="#2166AC", alpha=0.75, edgecolor="white")
ax.axvline(0, color="black", linestyle="--", linewidth=0.8)
ax.set_xlabel(r"$\Delta$ n_clauses (cba_period $t$ vs $t-1$, within firm)")
ax.set_ylabel("Within-firm period transitions")
ax.set_title("")
ax.spines["top"].set_visible(False)
ax.spines["right"].set_visible(False)

share_pos  = (dvals > 0).mean()
share_neg  = (dvals < 0).mean()
share_zero = (dvals == 0).mean()
note = (f"Pos: {share_pos:.1%}   "
        f"Zero: {share_zero:.1%}   "
        f"Neg: {share_neg:.1%}   "
        f"N = {len(dvals):,}")
ax.text(0.98, 0.96, note, transform=ax.transAxes,
        ha="right", va="top", fontsize=9,
        bbox=dict(boxstyle="round", facecolor="white", edgecolor="gray"))

hist_path = graphs_dir / "clause_count_delta_hist.pdf"
fig.tight_layout()
fig.savefig(hist_path)
plt.close(fig)
print(f"Wrote {hist_path}", flush=True)

# ── Plot 2: time trend by cba_period × group ──────────────────────────────────
group_order = ["Overall", "Treated",
               "Untreated, positive conn.", "Untreated, zero conn."]
colors = {
    "Overall":                    "black",
    "Treated":                    "#B2182B",
    "Untreated, positive conn.":  "#2166AC",
    "Untreated, zero conn.":      "#4DAF4A",
}

fig, ax = plt.subplots(figsize=(8, 5))
for g in group_order:
    sub = trend[trend["group"] == g].sort_values("cba_period")
    lw  = 2.0 if g == "Overall" else 1.6
    ax.plot(sub["cba_period"], sub["mean"], marker="o", linewidth=lw,
            color=colors[g], label=g)

ax.axvline(2.5, color="gray", linestyle=":", linewidth=0.8)
ax.text(2.55, ax.get_ylim()[0], "Súmula 277",
        rotation=90, va="bottom", color="gray", fontsize=8)
ax.set_xlabel("CBA period (1 = pre-2009 ... 6 = 2016)")
ax.set_ylabel("Mean n_clauses")
ax.set_xticks([1, 2, 3, 4, 5, 6])
ax.set_title("")
ax.spines["top"].set_visible(False)
ax.spines["right"].set_visible(False)
ax.legend(frameon=False, loc="best", fontsize=9)

trend_path = graphs_dir / "clause_count_time_trend.pdf"
fig.tight_layout()
fig.savefig(trend_path)
plt.close(fig)
print(f"Wrote {trend_path}", flush=True)

# ── Plot 3: overlay histogram of Δ across the four groups ─────────────────────
# Use a common bin grid; plot densities so groups with different N are comparable.
all_dvals = deltas["delta"].values
lo, hi = np.percentile(all_dvals, [0.5, 99.5])
common_bins = np.arange(np.floor(lo), np.ceil(hi) + 2) - 0.5

overall_color = "0.35"

fig, ax = plt.subplots(figsize=(8.5, 5))
ax.hist(all_dvals, bins=common_bins, density=True, histtype="step",
        color=overall_color, linewidth=1.8, label="Overall")
for g in ["Treated", "Untreated, positive conn.", "Untreated, zero conn."]:
    sub = deltas.loc[deltas["group"] == g, "delta"].values
    if len(sub) == 0:
        continue
    ax.hist(sub, bins=common_bins, density=True, alpha=0.35,
            color=colors[g], label=f"{g}  (N={len(sub):,})", edgecolor="none")
    ax.hist(sub, bins=common_bins, density=True, histtype="step",
            color=colors[g], linewidth=1.3)

ax.axvline(0, color="black", linestyle="--", linewidth=0.8)
ax.set_xlabel(r"$\Delta$ n_clauses (consecutive cba_period transitions)")
ax.set_ylabel("Density")
ax.set_title("")
ax.spines["top"].set_visible(False)
ax.spines["right"].set_visible(False)
ax.legend(frameon=False, loc="upper left", fontsize=9)

hist_grp_path = graphs_dir / "clause_count_delta_hist_by_group.pdf"
fig.tight_layout()
fig.savefig(hist_grp_path)
plt.close(fig)
print(f"Wrote {hist_grp_path}", flush=True)

# ── Plot 4: DiD-style pre/post distribution comparison ────────────────────────
# Compare the full n_clauses distribution pre (cba_period <= 2) vs post
# (cba_period >= 3) for treated and zero-connectivity firms. The horizontal
# shift between pre and post in each panel = the average treatment / control
# trend; the difference of those shifts is the DiD.
pre_mask  = agg["cba_period"] <= 2
post_mask = agg["cba_period"] >= 3

panels = [
    ("Treated",                "#B2182B"),
    ("Untreated, zero conn.",  "#4DAF4A"),
]

n_max = max((agg["n_clauses"].max() for _ in panels))
hi95  = np.percentile(agg["n_clauses"], 99)
common_bins_lvl = np.arange(0, np.ceil(hi95) + 4) - 0.5

fig, axes = plt.subplots(1, 2, figsize=(11, 4.6), sharex=True, sharey=True)
for ax, (g, color) in zip(axes, panels):
    pre_vals  = agg.loc[pre_mask  & (agg["group"] == g), "n_clauses"].values
    post_vals = agg.loc[post_mask & (agg["group"] == g), "n_clauses"].values
    ax.hist(pre_vals,  bins=common_bins_lvl, density=True, alpha=0.45,
            color=color, label=f"Pre  (N={len(pre_vals):,})",
            edgecolor="none")
    ax.hist(post_vals, bins=common_bins_lvl, density=True, histtype="step",
            color=color, linewidth=2.0, label=f"Post (N={len(post_vals):,})")
    ax.axvline(pre_vals.mean(),  color=color, linestyle=":",  linewidth=1.0)
    ax.axvline(post_vals.mean(), color=color, linestyle="--", linewidth=1.2)
    shift = post_vals.mean() - pre_vals.mean()
    ax.set_title(f"{g}\nmean pre = {pre_vals.mean():.2f}, "
                 f"mean post = {post_vals.mean():.2f}  (Δ = {shift:+.2f})",
                 fontsize=10)
    ax.set_xlabel("n_clauses")
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.legend(frameon=False, loc="upper left", fontsize=9)
axes[0].set_ylabel("Density")

# DiD annotation
pre_T  = agg.loc[pre_mask  & (agg["group"] == "Treated"),               "n_clauses"]
post_T = agg.loc[post_mask & (agg["group"] == "Treated"),               "n_clauses"]
pre_C  = agg.loc[pre_mask  & (agg["group"] == "Untreated, zero conn."), "n_clauses"]
post_C = agg.loc[post_mask & (agg["group"] == "Untreated, zero conn."), "n_clauses"]
did_mean = (post_T.mean() - pre_T.mean()) - (post_C.mean() - pre_C.mean())
fig.suptitle(f"DiD in mean n_clauses (treated − zero-conn): {did_mean:+.2f}",
             fontsize=11, y=1.02)

did_path = graphs_dir / "clause_count_did_distribution.pdf"
fig.tight_layout()
fig.savefig(did_path, bbox_inches="tight")
plt.close(fig)
print(f"Wrote {did_path}", flush=True)

# ── Plot 5: Δ histogram excluding transitions ending in cba_period 6 ──────────
deltas_no_p6 = deltas[deltas["cba_period"] != 6].copy()

fig, axes = plt.subplots(1, 2, figsize=(13, 4.6))

# Left: overall histogram
ax = axes[0]
dvals = deltas_no_p6["delta"].values
lo, hi = np.percentile(dvals, [0.5, 99.5])
bins = np.linspace(np.floor(lo), np.ceil(hi) + 1, 50)
ax.hist(dvals, bins=bins, color="#2166AC", alpha=0.75, edgecolor="white")
ax.axvline(0, color="black", linestyle="--", linewidth=0.8)
ax.set_xlabel(r"$\Delta$ n_clauses (cba_period transitions; 5→6 excluded)")
ax.set_ylabel("Within-firm period transitions")
ax.spines["top"].set_visible(False)
ax.spines["right"].set_visible(False)
sp = (dvals > 0).mean(); sn = (dvals < 0).mean(); sz = (dvals == 0).mean()
ax.text(0.98, 0.96, f"Pos: {sp:.1%}   Zero: {sz:.1%}   Neg: {sn:.1%}\nN = {len(dvals):,}",
        transform=ax.transAxes, ha="right", va="top", fontsize=9,
        bbox=dict(boxstyle="round", facecolor="white", edgecolor="gray"))
ax.set_title("Overall", fontsize=10)

# Right: overlay by group
ax = axes[1]
common_bins = np.arange(np.floor(lo), np.ceil(hi) + 2) - 0.5
ax.hist(dvals, bins=common_bins, density=True, histtype="step",
        color="0.35", linewidth=1.8, label="Overall")
for g in ["Treated", "Untreated, positive conn.", "Untreated, zero conn."]:
    sub = deltas_no_p6.loc[deltas_no_p6["group"] == g, "delta"].values
    if len(sub) == 0:
        continue
    ax.hist(sub, bins=common_bins, density=True, alpha=0.35,
            color=colors[g], label=f"{g}  (N={len(sub):,})", edgecolor="none")
    ax.hist(sub, bins=common_bins, density=True, histtype="step",
            color=colors[g], linewidth=1.3)
ax.axvline(0, color="black", linestyle="--", linewidth=0.8)
ax.set_xlabel(r"$\Delta$ n_clauses")
ax.set_ylabel("Density")
ax.spines["top"].set_visible(False)
ax.spines["right"].set_visible(False)
ax.legend(frameon=False, loc="upper left", fontsize=8)
ax.set_title("By group", fontsize=10)

fig.suptitle("Excluding transitions ending in cba_period 6", fontsize=11, y=1.02)
no_p6_path = graphs_dir / "clause_count_delta_hist_no_p6.pdf"
fig.tight_layout()
fig.savefig(no_p6_path, bbox_inches="tight")
plt.close(fig)
print(f"Wrote {no_p6_path}", flush=True)

# ── Plot 6: DiD on mean Δ (treated vs zero-conn, pre = 1→2, post = 2→3..4→5) ──
# `cba_period` on a delta row records the destination period.
did_deltas = deltas.copy()
did_deltas["era"] = pd.Series("", index=did_deltas.index, dtype="object")
did_deltas.loc[did_deltas["cba_period"] == 2,             "era"] = "Pre (1→2)"
did_deltas.loc[did_deltas["cba_period"].isin([3, 4, 5]),  "era"] = "Post (2→5)"
did_deltas = did_deltas[did_deltas["era"] != ""]
did_deltas = did_deltas[did_deltas["group"].isin(
    ["Treated", "Untreated, zero conn."])]

did_tbl = (did_deltas.groupby(["group", "era"])["delta"]
           .agg(["mean", "std", "count"])
           .reset_index())
did_csv = tables_dir / "clause_count_did_mean_delta.csv"

means_wide = (did_deltas.groupby(["group", "era"])["delta"]
              .mean().unstack())
counts_wide = (did_deltas.groupby(["group", "era"])["delta"]
               .count().unstack())
T_pre,  T_post  = means_wide.loc["Treated",               ["Pre (1→2)", "Post (2→5)"]]
C_pre,  C_post  = means_wide.loc["Untreated, zero conn.", ["Pre (1→2)", "Post (2→5)"]]
did_delta_val = (T_post - T_pre) - (C_post - C_pre)
did_tbl_out = did_tbl.copy()
did_tbl_out.loc[len(did_tbl_out)] = ["DiD", "post - pre", did_delta_val, np.nan, np.nan]
did_tbl_out.to_csv(did_csv, index=False)
print(f"\nWrote {did_csv}")
print(did_tbl_out.to_string(index=False))

# Plot: connected dots
fig, ax = plt.subplots(figsize=(7, 4.6))
order = ["Pre (1→2)", "Post (2→5)"]
x = [0, 1]
for g, color in [("Treated", "#B2182B"),
                 ("Untreated, zero conn.", "#4DAF4A")]:
    y  = [means_wide.loc[g, e] for e in order]
    n  = [int(counts_wide.loc[g, e]) for e in order]
    ax.plot(x, y, marker="o", markersize=10, linewidth=2.2,
            color=color, label=g)
    for xi, yi, ni in zip(x, y, n):
        ax.annotate(f"{yi:.2f}\n(N={ni:,})",
                    (xi, yi), textcoords="offset points",
                    xytext=(8, 4), ha="left", va="bottom",
                    fontsize=9, color=color)

ax.axhline(0, color="black", linestyle=":", linewidth=0.6)
ax.set_xticks(x)
ax.set_xticklabels(order)
ax.set_ylabel(r"Mean $\Delta$ n_clauses per transition")
ax.spines["top"].set_visible(False)
ax.spines["right"].set_visible(False)
ax.set_title(f"DiD on mean $\\Delta$: {did_delta_val:+.3f} clauses per transition",
             fontsize=11)
ax.legend(frameon=False, loc="upper left", fontsize=9)
did_mean_path = graphs_dir / "clause_count_did_mean_delta.pdf"
fig.tight_layout()
fig.savefig(did_mean_path, bbox_inches="tight")
plt.close(fig)
print(f"Wrote {did_mean_path}", flush=True)

# ── Plot 7: per-subgroup Δ histograms (24 panels) ─────────────────────────────
mapping_path = Path("/kellogg/proj/lgg3230/UnionSpill/Data/CBA/clause_variables_cnes.xlsx")
print(f"\nLoading clause→subgroup mapping from {mapping_path.name}...", flush=True)
mapping = pd.read_excel(mapping_path).rename(columns={"broad _group": "broad_group"})
mapping = mapping.dropna(subset=["sub_group_id"])
mapping = mapping[mapping["sub_group_id"] != 0.0].copy()  # drop "void"
mapping["sub_group_id"] = mapping["sub_group_id"].astype(int)

mapping_in_data = mapping[mapping["Variable"].isin(clause_vars)].copy()
print(f"  Mapped {len(mapping_in_data):,} cl_* variables to "
      f"{mapping_in_data['sub_group_id'].nunique()} subgroups", flush=True)

subgroup_info = (mapping_in_data[["sub_group_id", "sub_group"]]
                 .drop_duplicates()
                 .sort_values("sub_group_id")
                 .reset_index(drop=True))

# Build per-subgroup clause-count columns on the firm-period table
agg = agg.sort_values(["identificad", "cba_period"]).reset_index(drop=True)
for _, row in subgroup_info.iterrows():
    sid = row["sub_group_id"]
    cl_cols = mapping_in_data.loc[
        mapping_in_data["sub_group_id"] == sid, "Variable"].tolist()
    cl_cols = [c for c in cl_cols if c in agg.columns]
    agg[f"n_sub_{sid}"] = agg[cl_cols].sum(axis=1)
    prev = agg.groupby("identificad")[f"n_sub_{sid}"].shift(1)
    agg[f"delta_sub_{sid}"] = np.where(
        agg["cba_period"] - agg["prev_period"] == 1,
        agg[f"n_sub_{sid}"] - prev,
        np.nan,
    )


def plot_per_subgroup(panel_df: pd.DataFrame, suffix: str, fname: str):
    """6x4 grid of Δ histograms, one per subgroup."""
    n = len(subgroup_info)
    nrows, ncols = 6, 4
    fig, axes = plt.subplots(nrows, ncols, figsize=(13, 17))
    axes = axes.flatten()
    for i, row in subgroup_info.reset_index(drop=True).iterrows():
        ax  = axes[i]
        sid = row["sub_group_id"]
        nm  = row["sub_group"]
        vals = panel_df[f"delta_sub_{sid}"].dropna().values
        if len(vals) == 0:
            ax.set_visible(False)
            continue
        lo = np.floor(vals.min()); hi = np.ceil(vals.max())
        bins = np.arange(lo, hi + 2) - 0.5
        ax.hist(vals, bins=bins, color="#2166AC", alpha=0.8, edgecolor="white")
        ax.axvline(0, color="black", linestyle="--", linewidth=0.6)
        n_cl = int((mapping_in_data["sub_group_id"] == sid).sum())
        ax.set_title(f"{nm}\n({sid:02d}; {n_cl} clauses)", fontsize=9)
        ax.tick_params(labelsize=7)
        sp = (vals > 0).mean(); sn = (vals < 0).mean()
        m  = vals.mean()
        ax.text(0.97, 0.94,
                f"+:{sp:.0%}  -:{sn:.0%}\nmean Δ = {m:+.2f}\nN = {len(vals):,}",
                transform=ax.transAxes, ha="right", va="top", fontsize=7,
                bbox=dict(boxstyle="round", facecolor="white",
                          edgecolor="0.8", alpha=0.9))
        ax.spines["top"].set_visible(False)
        ax.spines["right"].set_visible(False)
    for j in range(i + 1, len(axes)):
        axes[j].set_visible(False)
    fig.suptitle(f"$\\Delta$ n_clauses per CBA subgroup{suffix}",
                 fontsize=12, y=1.00)
    fig.tight_layout(rect=[0, 0, 1, 0.99])
    out = graphs_dir / fname
    fig.savefig(out, bbox_inches="tight")
    plt.close(fig)
    print(f"Wrote {out}", flush=True)


print("Plotting 24-panel per-subgroup histograms...", flush=True)
plot_per_subgroup(agg, "",
                  "clause_count_delta_hist_by_subgroup.pdf")
plot_per_subgroup(agg[agg["cba_period"] != 6],
                  "  (excluding transitions ending in cba_period 6)",
                  "clause_count_delta_hist_by_subgroup_no_p6.pdf")

# ── Plot 8: per broad-group Δ histograms (3 panels) ───────────────────────────
broad_order = ["employment", "wage", "other"]
broad_to_cl = {}
for b in broad_order:
    cl_cols = mapping_in_data.loc[
        mapping_in_data["broad_group"] == b, "Variable"].tolist()
    cl_cols = [c for c in cl_cols if c in agg.columns]
    broad_to_cl[b] = cl_cols
    agg[f"n_broad_{b}"] = agg[cl_cols].sum(axis=1)
    prev = agg.groupby("identificad")[f"n_broad_{b}"].shift(1)
    agg[f"delta_broad_{b}"] = np.where(
        agg["cba_period"] - agg["prev_period"] == 1,
        agg[f"n_broad_{b}"] - prev,
        np.nan,
    )


def plot_broad_histograms(panel_df: pd.DataFrame, fname: str, suffix: str = ""):
    fig, axes = plt.subplots(1, 3, figsize=(14, 4.6))
    for ax, b in zip(axes, broad_order):
        vals = panel_df[f"delta_broad_{b}"].dropna().values
        if len(vals) == 0:
            ax.set_visible(False); continue
        lo = np.floor(np.percentile(vals, 0.5))
        hi = np.ceil(np.percentile(vals, 99.5))
        bins = np.arange(lo, hi + 2) - 0.5
        ax.hist(vals, bins=bins, color="#2166AC", alpha=0.8, edgecolor="white")
        ax.axvline(0, color="black", linestyle="--", linewidth=0.6)
        n_cl = len(broad_to_cl[b])
        sp = (vals > 0).mean(); sn = (vals < 0).mean()
        ax.set_title(f"{b.capitalize()} ({n_cl} clauses)", fontsize=10)
        ax.set_xlabel(r"$\Delta$ n_clauses")
        ax.text(0.98, 0.96,
                f"+:{sp:.0%}  -:{sn:.0%}\n"
                f"mean $\\Delta$ = {vals.mean():+.2f}\nN = {len(vals):,}",
                transform=ax.transAxes, ha="right", va="top", fontsize=8,
                bbox=dict(boxstyle="round", facecolor="white", edgecolor="0.8"))
        ax.spines["top"].set_visible(False)
        ax.spines["right"].set_visible(False)
    axes[0].set_ylabel("Within-firm period transitions")
    fig.suptitle(f"$\\Delta$ n_clauses by broad clause category{suffix}",
                 fontsize=11, y=1.02)
    fig.tight_layout()
    out = graphs_dir / fname
    fig.savefig(out, bbox_inches="tight")
    plt.close(fig)
    print(f"Wrote {out}", flush=True)


print("\nPlotting broad-category Δ histograms...", flush=True)
plot_broad_histograms(agg, "clause_count_delta_hist_by_broad.pdf")
plot_broad_histograms(agg[agg["cba_period"] == 2],
                      "clause_count_delta_hist_by_broad_pre.pdf",
                      "  (period 1→2 transitions only)")

# ── Plot 9: 1→2 only versions of overall + by-group and subgroup grids ────────
print("\nPlotting 1→2-only (pre-reform) versions...", flush=True)
deltas_pre = deltas[deltas["cba_period"] == 2].copy()
print(f"  1→2 transitions: {len(deltas_pre):,}", flush=True)

# Overall + by-group (pre-only)
fig, axes = plt.subplots(1, 2, figsize=(13, 4.6))
ax = axes[0]
dvals = deltas_pre["delta"].values
lo, hi = np.percentile(dvals, [0.5, 99.5])
bins = np.linspace(np.floor(lo), np.ceil(hi) + 1, 50)
ax.hist(dvals, bins=bins, color="#2166AC", alpha=0.75, edgecolor="white")
ax.axvline(0, color="black", linestyle="--", linewidth=0.8)
ax.set_xlabel(r"$\Delta$ n_clauses (period 1$\to$2)")
ax.set_ylabel("Within-firm transitions")
ax.spines["top"].set_visible(False)
ax.spines["right"].set_visible(False)
sp = (dvals > 0).mean(); sn = (dvals < 0).mean(); sz = (dvals == 0).mean()
ax.text(0.98, 0.96,
        f"Pos: {sp:.1%}   Zero: {sz:.1%}   Neg: {sn:.1%}\nN = {len(dvals):,}",
        transform=ax.transAxes, ha="right", va="top", fontsize=9,
        bbox=dict(boxstyle="round", facecolor="white", edgecolor="gray"))
ax.set_title("Overall", fontsize=10)

ax = axes[1]
common_bins = np.arange(np.floor(lo), np.ceil(hi) + 2) - 0.5
ax.hist(dvals, bins=common_bins, density=True, histtype="step",
        color="0.35", linewidth=1.8, label="Overall")
for g in ["Treated", "Untreated, positive conn.", "Untreated, zero conn."]:
    sub = deltas_pre.loc[deltas_pre["group"] == g, "delta"].values
    if len(sub) == 0:
        continue
    ax.hist(sub, bins=common_bins, density=True, alpha=0.35,
            color=colors[g], label=f"{g}  (N={len(sub):,})", edgecolor="none")
    ax.hist(sub, bins=common_bins, density=True, histtype="step",
            color=colors[g], linewidth=1.3)
ax.axvline(0, color="black", linestyle="--", linewidth=0.8)
ax.set_xlabel(r"$\Delta$ n_clauses (period 1$\to$2)")
ax.set_ylabel("Density")
ax.spines["top"].set_visible(False)
ax.spines["right"].set_visible(False)
ax.legend(frameon=False, loc="upper left", fontsize=8)
ax.set_title("By group", fontsize=10)

fig.suptitle("Pre-reform baseline: period 1$\\to$2 transitions only",
             fontsize=11, y=1.02)
pre_path = graphs_dir / "clause_count_delta_hist_pre.pdf"
fig.tight_layout()
fig.savefig(pre_path, bbox_inches="tight")
plt.close(fig)
print(f"Wrote {pre_path}", flush=True)

# Per-subgroup pre-only
plot_per_subgroup(agg[agg["cba_period"] == 2],
                  "  (period 1→2 transitions only)",
                  "clause_count_delta_hist_by_subgroup_pre.pdf")

# ── Notify ────────────────────────────────────────────────────────────────────
subprocess.run(
    ["curl", "-s", "-o", "/dev/null",
     "-H", "Title: clause_count_descriptives done",
     "-d", f"{len(deltas):,} firm-period transitions; outputs in "
           f"Graphs/cba_similarity and Tables/cba_similarity",
     "https://ntfy.sh/lgg3230-kellogg"],
    check=False,
)
print("Done.", flush=True)
