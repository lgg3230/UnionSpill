## Shared machinery for the extension analyses.
## Data construction identical to gui_check/scripts/prep_layer.R (validated against
## Luis's Stata outputs to 4 decimals); adds FE-column builder and a generic runner.
EXT <- "/Users/gui.neri/Library/CloudStorage/OneDrive-NorthwesternUniversity/Research Projects/Org_Econ BR/UnionSpillovers/Gui_coding/within firm/extensions"
source(file.path(EXT, "scripts", "ext_prep.R"))   # prep_layer(), get_prepped(), stata_pctile(), drop_singletons()
OUT <- file.path(EXT, "output")
options(width = 220)

## build all FE/interaction columns used across specs
add_fe_cols <- function(d2) {
  d2[, fy  := paste(identificad, year)]
  d2[, gy  := paste(layer_id, year)]
  d2[, b1y := paste(lr_remdezr_layer_pre4, year)]
  d2[, b2y := paste(l_layer_emp_pre4, year)]
  d2[, b3y := paste(layer_totalflows_pw_pre4, year)]
  d2[, iy  := paste(industry1, year)]
  d2[, my  := paste(mode_base_month, year)]
  d2[, ry  := paste(microregion, year)]
  invisible(d2)
}
bins_for <- function(y) if (y == "l_layer_emp") c("b2y", "b3y") else c("b1y", "b2y", "b3y")

## FE sets: "within" = firm x year (+ group x year); "overall" = ind/micro/mode x year (+ group x year)
fes_for <- function(kind, y) {
  base <- c("firm_layer_id", bins_for(y), "gy")
  if (kind == "within") c(base, "fy") else c(base, "iy", "my", "ry")
}

## generic DiD + placebo runner; rhs_terms are strings like "conn:treat_year"
## iv: optional list(endo=..., inst=...) using :treat_year / :placebo_year suffixes handled by caller
run_did <- function(d2, y, rhs_post, rhs_pre, fes, es_var = NULL) {
  dm <- drop_singletons(copy(d2), fes)
  ffe <- paste(fes, collapse = " + ")
  est <- feols(as.formula(paste0(y, " ~ ", paste(rhs_post, collapse = " + "), " | ", ffe)),
               data = dm, cluster = ~identificad)
  dp <- drop_singletons(d2[year <= 2011], fes)
  estp <- feols(as.formula(paste0(y, " ~ ", paste(rhs_pre, collapse = " + "), " | ", ffe)),
                data = dp, cluster = ~identificad)
  esF <- NA_real_
  if (!is.null(es_var)) {
    dm[, yearf := factor(year)]
    ese <- feols(as.formula(paste0(y, " ~ i(yearf, ", es_var, ", ref = '2011') | ", ffe)),
                 data = dm, cluster = ~identificad)
    w <- tryCatch(fixest::wald(ese, keep = "yearf::(2009|2010)", print = FALSE), error = function(e) NULL)
    if (!is.null(w)) esF <- w$p
  }
  list(main = coeftable(est), pre = coeftable(estp), n = nrow(dm),
       firms = uniqueN(dm$identificad), cells = uniqueN(dm$firm_layer_id), esF = esF)
}

stars <- function(b, se, df = 1e6) {
  p <- 2 * pt(-abs(b / se), df)
  if (p < .01) "***" else if (p < .05) "**" else if (p < .10) "*" else ""
}
fmt <- function(b, se) sprintf("%8.4f%-3s (%6.4f)", b, stars(b, se), se)

## standard prep wrapper: load layer, define sample + scaled connectivity (pooled P90, paper convention)
load_layer <- function(layer) {
  d <- get_prepped(layer, OUT)
  p90 <- stata_pctile(d[s_base == TRUE & year == 2009, layer_treat_pw_n], 90)
  d[, conn := layer_treat_pw_n / p90]
  attr(d, "p90") <- p90
  d
}
## estimation sample: untreated, firm balanced panel (paper A7 convention), outcome + conn nonmissing
samp <- function(d, y, conn_col = "conn") d[s_base == TRUE & !is.na(get(y)) & !is.na(get(conn_col))]
