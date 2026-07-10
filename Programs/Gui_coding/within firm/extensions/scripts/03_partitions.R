## E3 — Where does the within-firm null hold? Same within-firm spec (group x firm FE,
## firm x year FE, group x year FE, bin x year controls) across five worker partitions.
## ten2 (tenure) is the "legitimate differentiation" margin: firms CAN differentiate
## new-hire pay. occ4 is the occupational-ladder margin.
source("/Users/gui.neri/Library/CloudStorage/OneDrive-NorthwesternUniversity/Research Projects/Org_Econ BR/UnionSpillovers/Gui_coding/within firm/extensions/scripts/ext_common.R")

res <- list()
for (layer in c("edu2", "gender", "race", "occ4", "ten2")) {
  d <- load_layer(layer)
  for (y in c("lr_remdezr_layer", "l_layer_emp")) {
    d2 <- samp(d, y)
    add_fe_cols(d2)
    r <- run_did(d2, y, "conn:treat_year", "conn:placebo_year", fes_for("within", y), es_var = "conn")
    cat(sprintf("[%-6s] %-16s within: %s | pre: %s | ES pre-F p=%.3f | N=%d F=%d cells=%d\n",
        layer, y, fmt(r$main[1,1], r$main[1,2]), fmt(r$pre[1,1], r$pre[1,2]), r$esF, r$n, r$firms, r$cells))
    res[[paste(layer, y)]] <- data.table(layer = layer, outcome = y,
      b = r$main[1,1], se = r$main[1,2], b_pre = r$pre[1,1], se_pre = r$pre[1,2],
      esF = r$esF, n = r$n, firms = r$firms, cells = r$cells)
  }
}
saveRDS(rbindlist(res), file.path(OUT, "e3_partitions.rds"))
cat("Saved e3_partitions.rds\n")
