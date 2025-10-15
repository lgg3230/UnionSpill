# Auto-install required packages
import importlib.util
import subprocess
import sys
import site
import os

def install_package(package):
    subprocess.check_call([sys.executable, "-m", "pip", "install", "--user", package])
    # Add user site-packages to sys.path
    user_site = site.getusersitepackages()
    if user_site not in sys.path:
        sys.path.insert(0, user_site)
    # Also try to find other potential locations
    home = os.path.expanduser("~")
    potential_paths = [
        os.path.join(home, ".local/lib/python3.6/site-packages"),
        os.path.join(home, ".local/lib/python3/site-packages")
    ]
    for path in potential_paths:
        if os.path.exists(path) and path not in sys.path:
            sys.path.insert(0, path)
    print(f"Added user site packages to path: {user_site}")

# Check if pandas is installed, install if needed
if importlib.util.find_spec("pandas") is None:
    print("Pandas not found. Installing...")
    install_package("pandas")
    print("Pandas installed successfully!")
    # Force reload of importlib to detect newly installed packages
    importlib.invalidate_caches()

# Now import pandas (it should work now)
import pandas as pd
import os
import getpass
import gc


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


# Define a function to clean text for Stata compatibility
def clean_text(text):
    if isinstance(text, str):
        # Replace problematic characters
        return text.replace('\u2013', '-').replace('\u2014', '--').replace('\u2018', "'").replace('\u2019', "'").replace('\u201c', '"').replace('\u201d', '"')
    return text

cba_firm = pd.read_stata(os.path.join(main, 'UnionSpill/Data/CBA/cba_coverage_clean_firm.dta'))

# Split the 'codigo_municipio' column by comma and explode the resulting lists into separate rows
cba_firm['codigo_municipio'] = cba_firm['codigo_municipio'].str.split(',')
cba_firm_exp = cba_firm.explode('codigo_municipio').reset_index(drop=True)

# Clean text for all string columns
for col in cba_firm_exp.select_dtypes(include=['object']).columns:
    cba_firm_exp[col] = cba_firm_exp[col].apply(clean_text)

cba_firm_exp.to_stata(os.path.join(main,'UnionSpill/Data/CBA/cba_firm_exploded.dta'), write_index=False)
