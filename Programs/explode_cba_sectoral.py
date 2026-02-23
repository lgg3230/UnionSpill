# Teste
# Auto-install required packages
import importlib.util
import subprocessdfijhfhadji
import sys

def install_package(package):
    subprocess.check_call([sys.executable, "-m", "pip", "install", package])

# Check if pandas is installed, install if needed
if importlib.util.find_spec("pandas") is None:
    print("Pandas not found. Installing...")
    install_package("pandas")
    print("Pandas installed successfully!")

# Now import pandas (it should work now)
import pandas as pd
import os
import getpass

# Define the directory paths
klc = "/kellogg/proj/lgg3230"
luis = "/Users/luisg/Library/CloudStorage/OneDrive-NorthwesternUniversity/4 - PhD/02_Research/Org_Econ BR/UnionSpillovers/Replication_Mar 2"


# Get the current username
username = getpass.getuser()

# Set the main directory based on the username
if username == "luisg":
    main = luis
elif username == "lgg3230":
    main = klc
else:
    # Optional: handle the case where username is neither
    main = None
    print(f"Warning: Unrecognized username '{username}'. Directory path not set.")



cba_sector = pd.read_stata(os.path.join(main, 'UnionSpill/Data/CBA/cba_coverage_clean_sample.dta'))

# Split the 'codigo_municipio' column by comma and explode the resulting lists into separate rows
cba_sector['codigo_municipio'] = cba_sector['codigo_municipio'].str.split(',')
cba_sector = cba_sector.explode('codigo_municipio').reset_index(drop=True)



cba_sector.to_stata(os.path.join(main,'UnionSpill/Data/CBA/cba_coverage_exploded.dta'), write_index=False)
