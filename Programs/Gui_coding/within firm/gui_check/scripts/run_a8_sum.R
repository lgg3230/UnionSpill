source(file.path("/Users/gui.neri/Library/CloudStorage/OneDrive-NorthwesternUniversity/Research Projects/Org_Econ BR/UnionSpillovers/Gui_coding/within firm/gui_check/scripts", "prep_layer.R"))
d <- get_prepped("edu2", "/Users/gui.neri/Library/CloudStorage/OneDrive-NorthwesternUniversity/Research Projects/Org_Econ BR/UnionSpillovers/Gui_coding/within firm/gui_check/output")
p90g <- stata_pctile(d[s_base == TRUE & year == 2009, layer_treat_pw_n], 90)
d[, c_no  := {v <- layer_treat_pw_n[layer_id=="no_hs"];  if(length(v) && !all(is.na(v))) v[!is.na(v)][1] else NA_real_}/p90g, by=identificad]
d[, c_has := {v <- layer_treat_pw_n[layer_id=="has_hs"]; if(length(v) && !all(is.na(v))) v[!is.na(v)][1] else NA_real_}/p90g, by=identificad]

fp <- as.data.table(read_dta(file.path(DATA,"lagos_sample_sep24_pct_unionexp_ext_df2.dta"),
      col_select=c("identificad","year","lr_remdezr_w","l_firm_emp","totaltreat_pw_n")))
## firm-level P90 (own distribution, spillover sample, 2009) for scale comparison
fbase <- merge(unique(d[s_base==TRUE, .(identificad)]), fp[year==2009], by="identificad")
p90f <- stata_pctile(fbase$totaltreat_pw_n, 90)
cat(sprintf("P90 scale anchors: group-pooled = %.5f | firm-level = %.5f (ratio %.2f)\n", p90g, p90f, p90f/p90g))

## how much of firm connectivity is spanned by the two group measures?
fx <- unique(d[s_base==TRUE & !is.na(c_no) & !is.na(c_has), .(identificad, c_no, c_has)])
fx <- merge(fx, fp[year==2009, .(identificad, totaltreat_pw_n)], by="identificad")
fx[, c_firm := totaltreat_pw_n / p90g]  # same scale as the group measures
m <- lm(c_firm ~ c_no + c_has, fx)
cat(sprintf("c_firm on (c_no, c_has): weights %.3f / %.3f, R2=%.3f\n",
    coef(m)[2], coef(m)[3], summary(m)$r.squared))

## A8 firm-level sample & controls (corrected spec), single total-connectivity regressor
fw <- d[, .(c_no=c_no[1], c_has=c_has[1], treat_ultra=treat_ultra[1], in_balanced_panel=in_balanced_panel[1],
            industry1=industry1[1], mode_base_month=mode_base_month[1], microregion=microregion[1]), by=.(identificad,year)]
fw <- merge(fw, fp[, .(identificad,year,lr_remdezr_w,l_firm_emp,totaltreat_pw_n)], by=c("identificad","year"))
tf <- fread(file.path(DATA,"totalflows_wide_2007_2011.csv"), colClasses=list(character=1)); setnames(tf,1,"identificad")
fw <- merge(fw, tf, by="identificad", all.x=TRUE)
fw[, treat_year := as.integer(year>=2012)]
fw[, c_firm := totaltreat_pw_n / p90g]
yp <- c("totalflows_pw_07_08","totalflows_pw_08_09","totalflows_pw_09_10","totalflows_pw_10_11")
fw[, tf_pre := rowMeans(.SD, na.rm=TRUE), .SDcols=yp]; fw[is.nan(tf_pre), tf_pre := NA_real_]
for (v in c("lr_remdezr_w","l_firm_emp")) {
  fw[, pre_tmp := {m<-mean(get(v)[year %in% 2009:2011], na.rm=TRUE); if(is.nan(m)) NA_real_ else m}, by=identificad]
  sel <- fw$year==2009 & fw$in_balanced_panel==1 & !is.na(fw$in_balanced_panel) & !is.na(fw$pre_tmp)
  br <- sapply(c(25,50,75), function(p) stata_pctile(fw$pre_tmp[sel], p))
  fw[, bin_tmp := NA_integer_]; fw[sel, bin_tmp := findInterval(pre_tmp, br)]
  fw[, (paste0(v,"_pre4")) := {b<-bin_tmp[!is.na(bin_tmp)]; if(length(b)) b[1] else 0L}, by=identificad]
  fw[, c("pre_tmp","bin_tmp") := NULL]
}
sel <- fw$year==2009 & fw$in_balanced_panel==1 & !is.na(fw$in_balanced_panel) & !is.na(fw$tf_pre)
br <- sapply(c(25,50,75), function(p) stata_pctile(fw$tf_pre[sel], p))
fw[, bin_tmp := NA_integer_]; fw[sel, bin_tmp := findInterval(tf_pre, br)]
fw[, totalflows_pw_pre4 := {b<-bin_tmp[!is.na(bin_tmp)]; if(length(b)) b[1] else 0L}, by=identificad]
fw[, bin_tmp := NULL]
d2 <- fw[treat_ultra==0 & in_balanced_panel==1 & !is.na(lr_remdezr_w) & !is.na(c_no) & !is.na(c_has)]
d2[, b1y := paste(lr_remdezr_w_pre4,year)]; d2[, b2y := paste(l_firm_emp_pre4,year)]
d2[, b3y := paste(totalflows_pw_pre4,year)]
d2[, iy := paste(industry1,year)]; d2[, my := paste(mode_base_month,year)]; d2[, ry := paste(microregion,year)]
fes <- c("identificad","year","b1y","b2y","b3y","iy","my","ry")
dm <- drop_singletons(copy(d2), fes)
ff <- paste(fes, collapse="+")
e1 <- coeftable(feols(as.formula(paste0("lr_remdezr_w ~ c_firm:treat_year | ",ff)), dm, cluster=~identificad))
e2 <- coeftable(feols(as.formula(paste0("lr_remdezr_w ~ c_no:treat_year + c_has:treat_year | ",ff)), dm, cluster=~identificad))
cat(sprintf("\nA8 firm-level sample, corrected FE, same scale:\n  single total connectivity: b=%7.4f (%6.4f)\n  horse race: Low=%7.4f (%6.4f)  High=%7.4f (%6.4f)  SUM=%7.4f\n",
    e1[1,1], e1[1,2], e2[1,1], e2[1,2], e2[2,1], e2[2,2], e2[1,1]+e2[2,1]))
