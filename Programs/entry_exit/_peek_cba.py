import pandas as pd

reader = pd.read_stata(
    "/kellogg/proj/lgg3230/UnionSpill/Data/CBA/collapsed_cba_firm_updated.dta",
    chunksize=5
)
cba = next(iter(reader))
print("Columns:", cba.columns.tolist())
print("\nDtypes:\n", cba.dtypes)
print("\nSample:\n", cba.head(2).to_string())
