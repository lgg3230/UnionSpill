********************************************************************************
* Toy pair dataset: 100k unordered pairs (i>j)
* Variables:
*   conn_post  : post connectivity (0..3)
*   conn_pre   : pre connectivity  (0..3)
*   cell_i     : industry×microregion for firm i
*   cell_j     : industry×microregion for firm j
* Requirements:
*   - N = 100000
*   - ~99% of pairs have 0 connectivity (both pre and post, with persistence)
********************************************************************************

clear all
set more off
version 17
set seed 123456

*----------------------------
* Parameters
*----------------------------
local N       = 100000
local NCELLS  = 200            // number of industry×microregion cells
local p_nz    = 0.01           // probability a pair has nonzero connectivity
local p_persist = 0.60         // persistence of having any connection from pre->post

*----------------------------
* Build base dataset
*----------------------------
set obs `N'
gen long pair_id = _n

* cell assignments for i and j
gen int cell_i = ceil(runiform()*`NCELLS')
gen int cell_j = ceil(runiform()*`NCELLS')

* ensure unordered pair-cells (i>j analog): store min/max of cells
gen int cell_min = min(cell_i, cell_j)
gen int cell_max = max(cell_i, cell_j)

* pair-cell id (unordered {cell_i, cell_j})
egen long paircell = group(cell_min cell_max), label

label var cell_i    "industry×microregion cell of i"
label var cell_j    "industry×microregion cell of j"
label var paircell  "unordered pair-cell {cell_i, cell_j}"

*----------------------------
* Simulate sparse connectivity_pre (0..3)
*----------------------------
gen byte any_pre = (runiform() < `p_nz')          // about 1% nonzero
gen byte conn_pre = 0
replace conn_pre = 1 + floor(runiform()*3) if any_pre   // uniform over {1,2,3}

label var conn_pre "connectivity pre (0..3)"

*----------------------------
* Simulate sparse connectivity_post with persistence + some noise
*----------------------------
* baseline: most zeros
gen byte any_post = 0

* persistence: if connected pre, remain connected with prob p_persist
replace any_post = 1 if any_pre==1 & runiform() < `p_persist'

* new links: if not connected pre, small chance to become connected
replace any_post = 1 if any_pre==0 & runiform() < (`p_nz'*(1-`p_persist'))

gen byte conn_post = 0
replace conn_post = 1 + floor(runiform()*3) if any_post

* add mild dependence on conn_pre for connected cases (optional)
replace conn_post = min(3, conn_pre + (runiform() < 0.20)) if any_post==1 & any_pre==1

label var conn_post "connectivity post (0..3)"

*----------------------------
* Check sparsity
*----------------------------
di "Share conn_pre==0:  " %6.4f (sum(conn_pre==0)/_N)
di "Share conn_post==0: " %6.4f (sum(conn_post==0)/_N)

* quick tab
tab conn_pre
tab conn_post
