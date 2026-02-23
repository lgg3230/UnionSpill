import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

# -------------------------------------------------------------------
# 1. Load the worker-year dataset
# -------------------------------------------------------------------
path = "/Users/luisg/Library/CloudStorage/OneDrive-NorthwesternUniversity/4 - PhD/02_Research/Org_Econ BR/UnionSpillovers/Replication-Mar-2/UnionSpill/Data/CBA_rais_firm_level/lagos_sample_workers_new_inc_sep24.dta"

df = pd.read_stata(path)

# -------------------------------------------------------------------
# 2. Keep only the analysis window 2009–2015 (just in case)
# -------------------------------------------------------------------
df = df[(df["year"] >= 2009) & (df["year"] <= 2016)]

# -------------------------------------------------------------------
# 3. Collapse to firm-year level
#    share_* variables are constant within firm-year,
#    so we can just take the first observation per (firm, year)
# -------------------------------------------------------------------
firm_year = (
    df.sort_values(["identificad", "year"])
      .groupby(["identificad", "year"], as_index=False)
      .agg({
          "share_newhires": "first",
          "share_stayers_0916": "first",
          "share_other": "first"
      })
)

# -------------------------------------------------------------------
# 4. Compute across-firm averages by year
# -------------------------------------------------------------------
avg_shares = (
    firm_year
    .groupby("year")[["share_newhires", "share_stayers_0916", "share_other"]]
    .mean()
    .reset_index()
)

# Prepare a readable table (percentages) for downstream consumers/LLMs
table_path = "/Users/luisg/Library/CloudStorage/OneDrive-NorthwesternUniversity/4 - PhD/02_Research/Org_Econ BR/UnionSpillovers/Replication-Mar-2/UnionSpill/Graphs/worker_composition_2009_2016_table.csv"
table = avg_shares.copy()
share_cols = ["share_newhires", "share_stayers_0916", "share_other"]
table[share_cols] = (table[share_cols] * 100).round(2)
table.rename(
    columns={
        "share_newhires": "pct_new_hires",
        "share_stayers_0916": "pct_stayers_2009_2015",
        "share_other": "pct_other_workers",
    },
    inplace=True,
)
table.to_csv(table_path, index=False)
print("Worker composition table (percent of firm employment):")
print(table.to_string(index=False))

# -------------------------------------------------------------------
# 5. Plot stacked bar chart
# -------------------------------------------------------------------
years = avg_shares["year"].values
stayers = avg_shares["share_stayers_0916"].values
newhires = avg_shares["share_newhires"].values
other = avg_shares["share_other"].values

fig, plt_ax = plt.subplots(figsize=(8, 5))

plt_ax.bar(years, stayers, label="Stayers 2009–2015")
plt_ax.bar(years, newhires, bottom=stayers, label="New hires (post-2012)")
plt_ax.bar(years, other, bottom=stayers + newhires, label="Other workers")

# Add share labels inside the stacked segments
for idx, year in enumerate(years):
    bottom = 0
    for share in (stayers[idx], newhires[idx], other[idx]):
        height = share
        if height > 0:
            y_pos = bottom + height / 2
            plt_ax.text(
                year,
                y_pos,
                f"{height * 100:.1f}%",
                ha="center",
                va="center",
                color="white",
                fontsize=8,
            )
        bottom += height

plt_ax.set_xlabel("Year")
plt_ax.set_ylabel("Average share of firm employment")
plt_ax.set_title("Across-firm average composition of worker types by year")
plt_ax.set_xticks(years)
plt_ax.set_ylim(0, 1.05)

plt_ax.legend(loc="upper center", bbox_to_anchor=(0.5, -0.15), ncol=3)
plt.tight_layout()
plt.show()

# -------------------------------------------------------------------
# 6. Save the figure
# -------------------------------------------------------------------
save_path = "/Users/luisg/Library/CloudStorage/OneDrive-NorthwesternUniversity/4 - PhD/02_Research/Org_Econ BR/UnionSpillovers/Replication-Mar-2/UnionSpill/Graphs/worker_composition_2009_2016"

fig.savefig(save_path + ".png", dpi=300)
fig.savefig(save_path + ".pdf")

plt.show()
