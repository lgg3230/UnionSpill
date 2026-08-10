import os
import glob
import pandas as pd

CSV_FOLDER = "/Users/luisg/Library/CloudStorage/OneDrive-NorthwesternUniversity/4 - PhD/02_Research/Org_Econ BR/UnionSpillovers/Replication-Mar-2/UnionSpill/Programs/results/tables"
OUTPUT_FILE = "/Users/luisg/Library/CloudStorage/OneDrive-NorthwesternUniversity/4 - PhD/02_Research/Org_Econ BR/UnionSpillovers/Replication-Mar-2/UnionSpill/Programs/results/mega_tables.xlsx"

csv_files = sorted(glob.glob(os.path.join(CSV_FOLDER, "*.csv")))

if not csv_files:
    print("No CSV files found.")
else:
    used_names = set()
    with pd.ExcelWriter(OUTPUT_FILE, engine="openpyxl") as writer:
        for csv_path in csv_files:
            base_name = os.path.splitext(os.path.basename(csv_path))[0]
            sheet_name = (base_name[-31:] or "sheet")
            # Ensure unique sheet names if collisions occur
            original = sheet_name
            counter = 1
            while sheet_name in used_names:
                suffix = f"_{counter}"
                sheet_name = (original[: (31 - len(suffix))] + suffix) if len(original) + len(suffix) > 31 else original + suffix
                counter += 1
            used_names.add(sheet_name)

            df = pd.read_csv(csv_path)
            df.to_excel(writer, sheet_name=sheet_name, index=False)

    print(f"Combined {len(csv_files)} CSV files into {OUTPUT_FILE}")
