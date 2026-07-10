source("/Users/gui.neri/Library/CloudStorage/OneDrive-NorthwesternUniversity/Research Projects/Org_Econ BR/UnionSpillovers/Gui_coding/within firm/gui_check/output/prep_layer.R")
options(width = 200)
SCR <- "/Users/gui.neri/Library/CloudStorage/OneDrive-NorthwesternUniversity/Research Projects/Org_Econ BR/UnionSpillovers/Gui_coding/within firm/gui_check/output"
d <- get_prepped("edu2", SCR)
p90 <- stata_pctile(d[s_base == TRUE & year == 2009, layer_treat_pw_n], 90)
d[, c_no  := {v <- layer_treat_pw_n[layer_id == "no_hs"];  if (length(v) && !all(is.na(v))) v[!is.na(v)][1] else NA_real_} / p90, by = identificad]
d[, c_has := {v <- layer_treat_pw_n[layer_id == "has_hs"]; if (length(v) && !all(is.na(v))) v[!is.na(v)][1] else NA_real_} / p90, by = identificad]

## 1) How much of the cross-firm variation in connectivity do industry/region/month explain?
fs <- unique(d[s_base == TRUE & !is.na(c_no) & !is.na(c_has),
               .(identificad, c_no, c_has, industry1, microregion, mode_base_month)], by = "identificad")
for (v in c("c_no", "c_has")) {
  r2i <- r2(feols(as.formula(paste0(v, " ~ 1 | industry1")), fs), "r2")
  r2m <- r2(feols(as.formula(paste0(v, " ~ 1 | microregion")), fs), "r2")
  r2a <- r2(feols(as.formula(paste0(v, " ~ 1 | industry1 + microregion + mode_base_month")), fs), "r2")
  cat(sprintf("R2 of %s on: industry=%.3f  microregion=%.3f  all three=%.3f\n", v, r2i, r2m, r2a))
}

## 2) Add the three FE blocks one at a time to the two headline A8 cells
add_one <- function(y, lv) {
  d2 <- d[treat_ultra == 0 & in_balanced_panel == 1 & layer_id == lv &
          !is.na(get(y)) & !is.na(c_no) & !is.na(c_has)]
  d2[, b1y := paste(lr_remdezr_layer_pre4, year)]
  d2[, b2y := paste(l_layer_emp_pre4, year)]
  d2[, b3y := paste(layer_totalflows_pw_pre4, year)]
  d2[, iy := paste(industry1, year)]; d2[, my := paste(mode_base_month, year)]; d2[, ry := paste(microregion, year)]
  bins <- if (y == "l_layer_emp") c("b2y", "b3y") else c("b1y", "b2y", "b3y")
  base <- c("firm_layer_id", "year", bins)
  vars <- list(published = base, `+ind*yr` = c(base, "iy"), `+micro*yr` = c(base, "ry"),
               `+mode*yr` = c(base, "my"), `all (bundled)` = c(base, "iy", "my", "ry"))
  cat(sprintf("\n%s, %s column:\n", y, lv))
  for (nm in names(vars)) {
    dm <- drop_singletons(copy(d2), vars[[nm]])
    ct <- coeftable(feols(as.formula(paste0(y, " ~ c_no:treat_year + c_has:treat_year | ",
          paste(vars[[nm]], collapse = "+"))), data = dm, cluster = ~identificad))
    cat(sprintf("  %-14s Low=%8.4f (%6.4f)   High=%8.4f (%6.4f)   N=%d\n",
        nm, ct[1,1], ct[1,2], ct[2,1], ct[2,2], nrow(dm)))
  }
}
add_one("lr_remdezr_layer", "has_hs")   # High-Skill wage cell (0.0066** published)
add_one("l_layer_emp", "no_hs")         # Low-Skill employment cell (-0.0209** published)
