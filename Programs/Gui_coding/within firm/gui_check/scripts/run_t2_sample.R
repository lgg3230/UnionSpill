source(file.path("/Users/gui.neri/Library/CloudStorage/OneDrive-NorthwesternUniversity/Research Projects/Org_Econ BR/UnionSpillovers/Gui_coding/within firm/gui_check/scripts", "prep_layer.R"))
d <- get_prepped("edu2", "/Users/gui.neri/Library/CloudStorage/OneDrive-NorthwesternUniversity/Research Projects/Org_Econ BR/UnionSpillovers/Gui_coding/within firm/gui_check/output")

## A8-sample firm list: firms with BOTH group connectivities (02a construction)
d[, c_no_raw  := {v <- layer_treat_pw_n[layer_id=="no_hs"];  if(length(v) && !all(is.na(v))) v[!is.na(v)][1] else NA_real_}, by=identificad]
d[, c_has_raw := {v <- layer_treat_pw_n[layer_id=="has_hs"]; if(length(v) && !all(is.na(v))) v[!is.na(v)][1] else NA_real_}, by=identificad]
a8firms <- unique(d[!is.na(c_no_raw) & !is.na(c_has_raw), identificad])

## firm panel (full Lagos spillover universe, not via layer files)
fp <- as.data.table(read_dta(file.path(DATA,"lagos_sample_sep24_pct_unionexp_ext_df2.dta"),
      col_select=c("identificad","year","treat_ultra","in_balanced_panel","lagos_sample_avg",
                   "industry1","mode_base_month","microregion","lr_remdezr_w","l_firm_emp","totaltreat_pw_n")))
for (v in names(fp)) if (inherits(fp[[v]],"haven_labelled")) fp[[v]] <- as.numeric(fp[[v]])
fp <- fp[year >= 2009 & lagos_sample_avg == 1]
tf <- fread(file.path(DATA,"totalflows_wide_2007_2011.csv"), colClasses=list(character=1)); setnames(tf,1,"identificad")
fp <- merge(fp, tf, by="identificad", all.x=TRUE)
fp[, treat_year := as.integer(year>=2012)]
fp[, placebo_year := as.integer(year<2011)]

## firm connectivity scaled to full-spillover-sample P90 at 2009 (as in the paper)
p90f <- stata_pctile(fp[treat_ultra==0 & in_balanced_panel==1 & year==2009, totaltreat_pw_n], 90)
fp[, c_firm := totaltreat_pw_n / p90f]
cat(sprintf("firm-level P90 anchor (full spillover sample) = %.5f\n", p90f))

yp <- c("totalflows_pw_07_08","totalflows_pw_08_09","totalflows_pw_09_10","totalflows_pw_10_11")
fp[, tf_pre := rowMeans(.SD, na.rm=TRUE), .SDcols=yp]; fp[is.nan(tf_pre), tf_pre := NA_real_]
for (v in c("lr_remdezr_w","l_firm_emp")) {
  fp[, pre_tmp := {m<-mean(get(v)[year %in% 2009:2011], na.rm=TRUE); if(is.nan(m)) NA_real_ else m}, by=identificad]
  sel <- fp$year==2009 & fp$in_balanced_panel==1 & !is.na(fp$in_balanced_panel) & !is.na(fp$pre_tmp)
  br <- sapply(c(25,50,75), function(p) stata_pctile(fp$pre_tmp[sel], p))
  fp[, bin_tmp := NA_integer_]; fp[sel, bin_tmp := findInterval(pre_tmp, br)]
  fp[, (paste0(v,"_pre4")) := {b<-bin_tmp[!is.na(bin_tmp)]; if(length(b)) b[1] else 0L}, by=identificad]
  fp[, c("pre_tmp","bin_tmp") := NULL]
}
sel <- fp$year==2009 & fp$in_balanced_panel==1 & !is.na(fp$in_balanced_panel) & !is.na(fp$tf_pre)
br <- sapply(c(25,50,75), function(p) stata_pctile(fp$tf_pre[sel], p))
fp[, bin_tmp := NA_integer_]; fp[sel, bin_tmp := findInterval(tf_pre, br)]
fp[, totalflows_pw_pre4 := {b<-bin_tmp[!is.na(bin_tmp)]; if(length(b)) b[1] else 0L}, by=identificad]
fp[, bin_tmp := NULL]

run <- function(y, samp_label) {
  d2 <- fp[treat_ultra==0 & in_balanced_panel==1 & !is.na(get(y)) & !is.na(c_firm)]
  if (samp_label == "A8 sample") d2 <- d2[identificad %in% a8firms]
  d2[, b1y := paste(lr_remdezr_w_pre4,year)]; d2[, b2y := paste(l_firm_emp_pre4,year)]
  d2[, b3y := paste(totalflows_pw_pre4,year)]
  d2[, iy := paste(industry1,year)]; d2[, my := paste(mode_base_month,year)]; d2[, ry := paste(microregion,year)]
  bins <- if (y=="l_firm_emp") c("b2y","b3y") else c("b1y","b2y","b3y")
  fes <- c("identificad","year",bins,"iy","my","ry")
  dm <- drop_singletons(copy(d2), fes)
  ff <- paste(fes, collapse="+")
  e  <- coeftable(feols(as.formula(paste0(y," ~ c_firm:treat_year | ",ff)), dm, cluster=~identificad))
  dp <- drop_singletons(d2[year<=2011], fes)
  ep <- coeftable(feols(as.formula(paste0(y," ~ c_firm:placebo_year | ",ff)), dp, cluster=~identificad))
  cat(sprintf("%-14s %-12s b=%8.4f se=%6.4f | pre=%8.4f (%6.4f) | N=%6d F=%5d\n",
      y, samp_label, e[1,1], e[1,2], ep[1,1], ep[1,2], nrow(dm), uniqueN(dm$identificad)))
}
for (y in c("lr_remdezr_w","l_firm_emp")) for (s in c("full sample","A8 sample")) run(y, s)
cat("\nAnchors: Table 2 wages 0.0051** (0.0023) N=32,495 | emp 0.0004 (0.0081)\n")
