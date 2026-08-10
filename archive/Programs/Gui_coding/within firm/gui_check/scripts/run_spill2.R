source("/Users/gui.neri/Library/CloudStorage/OneDrive-NorthwesternUniversity/Research Projects/Org_Econ BR/UnionSpillovers/Gui_coding/within firm/gui_check/output/prep_layer.R")
options(width = 220)

run_one <- function(d, y, samp_col, fes_spec, conn_col) {
  d2 <- d[get(samp_col) == TRUE & !is.na(get(y)) & !is.na(get(conn_col))]
  d2[, fy := paste(identificad, year)]
  d2[, ly := paste(layer_id, year)]
  d2[, b1y := paste(lr_remdezr_layer_pre4, year)]
  d2[, b2y := paste(l_layer_emp_pre4, year)]
  d2[, b3y := paste(layer_totalflows_pw_pre4, year)]
  d2[, iy := paste(industry1, year)]
  d2[, my := paste(mode_base_month, year)]
  d2[, ry := paste(microregion, year)]
  bins <- if (y == "l_layer_emp") c("b2y", "b3y") else c("b1y", "b2y", "b3y")
  fes <- c(fes_spec, bins)
  dm <- drop_singletons(copy(d2), fes)
  fml <- as.formula(paste0(y, " ~ ", conn_col, ":treat_year | ", paste(fes, collapse = " + ")))
  est <- feols(fml, data = dm, cluster = ~identificad)
  dp <- drop_singletons(d2[year <= 2011], fes)
  fmlp <- as.formula(paste0(y, " ~ ", conn_col, ":placebo_year | ", paste(fes, collapse = " + ")))
  estp <- feols(fmlp, data = dp, cluster = ~identificad)
  ct <- coeftable(est); ctp <- coeftable(estp)
  # buggy n_cells as in do-file: cells whose obs are ALL in estimation sample (8 years)
  full_cells <- dm[, .N, by = firm_layer_id][N == 8, .N]
  list(b = ct[1, 1], se = ct[1, 2], bp = ctp[1, 1], sep = ctp[1, 2],
       n = est$nobs, firms = uniqueN(dm$identificad), cells = uniqueN(dm$firm_layer_id), cells8 = full_cells)
}

VARIANTS <- list(
  within_ly    = c("firm_layer_id", "fy", "ly"),
  within_noly  = c("firm_layer_id", "fy"),
  cross_ly     = c("firm_layer_id", "iy", "my", "ry", "ly"),
  cross_noly   = c("firm_layer_id", "iy", "my", "ry")
)

for (layer in c("edu2", "gender")) {
  d <- get_prepped(layer, "/Users/gui.neri/Library/CloudStorage/OneDrive-NorthwesternUniversity/Research Projects/Org_Econ BR/UnionSpillovers/Gui_coding/within firm/gui_check/output")
  p90_full <- stata_pctile(d[s_base == TRUE & year == 2009, layer_treat_pw_n], 90)
  d[, conn_full := layer_treat_pw_n / p90_full]
  cat(sprintf("\n================ LAYER %s (FULL sample) ================\n", layer))
  for (y in c("lr_remdezr_layer", "l_layer_emp")) {
    for (v in names(VARIANTS)) {
      r <- run_one(d, y, "s_base", VARIANTS[[v]], "conn_full")
      cat(sprintf("%-18s %-12s b=%8.4f se=%6.4f | pre=%8.4f (%6.4f) | N=%6d F=%5d cells=%5d cells8=%5d\n",
        y, v, r$b, r$se, r$bp, r$sep, r$n, r$firms, r$cells, r$cells8))
    }
  }
}
cat("\nPAPER A7 edu2:  within wage -0.0023 (0.0044) pre 0.0044 (0.0053) N=52,458 F=3,580 G×F=6,273 | overall wage 0.0029 (0.0025) pre 0.0019 (0.0029) N=59,391 F=4,172 G×F=7,751\n")
cat("PAPER A7 edu2:  within emp  -0.0023 (0.0108) pre 0.0133 (0.0118) | overall emp -0.0056 (0.0070) pre 0.0052 (0.0054)\n")
cat("PAPER A7 gender: within wage 0.0001 (0.0030) pre -0.0011 (0.0050) N=55,358 F=3,684 G×F=6,649 | overall wage 0.0026 (0.0020) pre -0.0005 (0.0025) N=60,864 F=4,175 G×F=7,855\n")
cat("PAPER A7 gender: within emp  -0.0025 (0.0049) pre -0.0024 (0.0098) | overall emp 0.0017 (0.0045) pre 0.0001 (0.0057)\n")
