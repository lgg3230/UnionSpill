## E5 — Fairness-multiplier test (Amior-San logic): if pay must move for everyone or
## no one, the wage response to group-g pressure should INCREASE in the group's
## employment share s_g (raising everyone is worth it when the exposed group is most
## of the firm), and the exposed group's EMPLOYMENT response should DECREASE in s_g.
## Spec: y_g = b (C_g x Post) + t (C_g x Post x s_c) + (s_c x Post) + FE; s_c = s_g - mean.
source("/Users/gui.neri/Library/CloudStorage/OneDrive-NorthwesternUniversity/Research Projects/Org_Econ BR/UnionSpillovers/Gui_coding/within firm/extensions/scripts/ext_common.R")

res <- list()
for (layer in c("edu2", "gender")) {
  d <- load_layer(layer)
  e <- d[year %in% 2009:2011, .(E = mean(layer_emp, na.rm = TRUE)), by = .(identificad, layer_id)]
  e[, s := E / sum(E), by = identificad]
  d <- merge(d, e[, .(identificad, layer_id, s)], by = c("identificad", "layer_id"), all.x = TRUE)
  for (y in c("lr_remdezr_layer", "l_layer_emp")) {
    for (kind in c("overall", "within")) {
      d2 <- samp(d, y)[!is.na(s)]
      sbar <- mean(unique(d2[, .(firm_layer_id, s)])$s)
      d2[, s_c := s - sbar]
      add_fe_cols(d2)
      d2[, ct  := conn * treat_year];   d2[, cts  := conn * treat_year * s_c];   d2[, st  := s_c * treat_year]
      d2[, cp  := conn * placebo_year]; d2[, cps  := conn * placebo_year * s_c]; d2[, sp  := s_c * placebo_year]
      fes <- fes_for(kind, y)
      r <- run_did(d2, y, c("ct", "cts", "st"), c("cp", "cps", "sp"), fes)
      cat(sprintf("[%s|%s] %-16s C:Post=%s  C:Post:s=%s | pre: %s / %s | N=%d F=%d\n",
          layer, kind, y, fmt(r$main["ct", 1], r$main["ct", 2]), fmt(r$main["cts", 1], r$main["cts", 2]),
          fmt(r$pre["cp", 1], r$pre["cp", 2]), fmt(r$pre["cps", 1], r$pre["cps", 2]), r$n, r$firms))
      res[[paste(layer, y, kind)]] <- data.table(layer = layer, outcome = y, fe = kind,
        b_c = r$main["ct", 1], se_c = r$main["ct", 2], b_cs = r$main["cts", 1], se_cs = r$main["cts", 2],
        b_c_pre = r$pre["cp", 1], se_c_pre = r$pre["cp", 2], b_cs_pre = r$pre["cps", 1], se_cs_pre = r$pre["cps", 2],
        n = r$n, firms = r$firms)
    }
  }
}
saveRDS(rbindlist(res), file.path(OUT, "e5_size_interaction.rds"))
cat("Saved e5_size_interaction.rds\n")
