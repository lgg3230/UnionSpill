source("/Users/gui.neri/Library/CloudStorage/OneDrive-NorthwesternUniversity/Research Projects/Org_Econ BR/UnionSpillovers/Gui_coding/within firm/gui_check/output/prep_layer.R")
options(width = 200)
SCR <- "/Users/gui.neri/Library/CloudStorage/OneDrive-NorthwesternUniversity/Research Projects/Org_Econ BR/UnionSpillovers/Gui_coding/within firm/gui_check/output"
d <- get_prepped("edu2", SCR)
p90 <- stata_pctile(d[s_base == TRUE & year == 2009, layer_treat_pw_n], 90)
d[, c_no  := {v <- layer_treat_pw_n[layer_id == "no_hs"];  if (length(v) && !all(is.na(v))) v[!is.na(v)][1] else NA_real_} / p90, by = identificad]
d[, c_has := {v <- layer_treat_pw_n[layer_id == "has_hs"]; if (length(v) && !all(is.na(v))) v[!is.na(v)][1] else NA_real_} / p90, by = identificad]

for (y in c("l_layer_emp", "lr_remdezr_layer")) {
  lv <- if (y == "l_layer_emp") "no_hs" else "has_hs"  # the two headline A8 cells
  d2 <- d[treat_ultra == 0 & in_balanced_panel == 1 & layer_id == lv &
          !is.na(get(y)) & !is.na(c_no) & !is.na(c_has)]
  d2[, b1y := paste(lr_remdezr_layer_pre4, year)]
  d2[, b2y := paste(l_layer_emp_pre4, year)]
  d2[, b3y := paste(layer_totalflows_pw_pre4, year)]
  d2[, iy := paste(industry1, year)]; d2[, my := paste(mode_base_month, year)]; d2[, ry := paste(microregion, year)]
  bins <- if (y == "l_layer_emp") c("b2y", "b3y") else c("b1y", "b2y", "b3y")
  fes_plain <- c("firm_layer_id", "year", bins)
  fes_full  <- c(fes_plain, "iy", "my", "ry")
  dm_full <- drop_singletons(copy(d2), fes_full)   # bundled-spec sample
  fml_plain <- as.formula(paste0(y, " ~ c_no:treat_year + c_has:treat_year | ", paste(fes_plain, collapse = "+")))
  a <- coeftable(feols(fml_plain, data = drop_singletons(copy(d2), fes_plain), cluster = ~identificad))
  b <- coeftable(feols(fml_plain, data = dm_full, cluster = ~identificad))   # plain FE, restricted sample
  fml_full <- as.formula(paste0(y, " ~ c_no:treat_year + c_has:treat_year | ", paste(fes_full, collapse = "+")))
  c_ <- coeftable(feols(fml_full, data = dm_full, cluster = ~identificad))
  cat(sprintf("\n%s (%s):\n  plain FE, full sample : L=%7.4f (%6.4f) H=%7.4f (%6.4f)\n  plain FE, FE-sample   : L=%7.4f (%6.4f) H=%7.4f (%6.4f)\n  full FE  (bundled)    : L=%7.4f (%6.4f) H=%7.4f (%6.4f)\n",
    y, lv, a[1,1], a[1,2], a[2,1], a[2,2], b[1,1], b[1,2], b[2,1], b[2,2], c_[1,1], c_[1,2], c_[2,1], c_[2,2]))
}
