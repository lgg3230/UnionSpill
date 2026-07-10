## Why does the first half have a much smaller SE than the second half?
myskew <- function(x){x<-x[!is.na(x)]; m<-mean(x); mean((x-m)^3)/mean((x-m)^2)^1.5}
## Decompose: (a) cross-firm spread of the regressor, (b) how much the FEs/controls
## absorb it (residual spread), (c) tail/outliers, (d) iid vs clustered SE.
source("/Users/gui.neri/Library/CloudStorage/OneDrive-NorthwesternUniversity/Research Projects/Org_Econ BR/UnionSpillovers/Gui_coding/within firm/extensions/scripts/ext_common.R")

d <- load_layer("edu2")
k <- as.data.table(read_dta(file.path(DATA, "firm_layer_connectivity_edu2.dta"),
     col_select = c("identificad","layer_id", paste0("layer_treat_pw_", c("0708","0809","0910","1011")))))
setnames(k, paste0("layer_treat_pw_", c("0708","0809","0910","1011")), paste0("p",1:4))
e <- d[year %in% 2009:2011, .(E = mean(layer_emp, na.rm=TRUE)), by=.(identificad, layer_id)]
k <- merge(k, e, by=c("identificad","layer_id"))
k[, c_early := rowMeans(.SD, na.rm=TRUE), .SDcols=c("p1","p2")]
k[, c_late  := rowMeans(.SD, na.rm=TRUE), .SDcols=c("p3","p4")]
for(v in c("c_early","c_late")) k[is.nan(get(v)),(v):=NA_real_]
agg <- k[!is.na(E), .(cf_early=weighted.mean(c_early,E,na.rm=TRUE), cf_late=weighted.mean(c_late,E,na.rm=TRUE)), by=identificad]
for(v in c("cf_early","cf_late")) agg[is.nan(get(v)),(v):=NA_real_]

fp <- as.data.table(read_dta(file.path(DATA,"lagos_sample_sep24_pct_unionexp_ext_df2.dta"),
      col_select=c("identificad","year","treat_ultra","in_balanced_panel","lagos_sample_avg",
                   "industry1","mode_base_month","microregion","lr_remdezr_w","l_firm_emp","totaltreat_pw_n")))
for(v in names(fp)) if(inherits(fp[[v]],"haven_labelled")) fp[[v]] <- as.numeric(fp[[v]])
fp <- fp[year>=2009 & lagos_sample_avg==1]
tf <- fread(file.path(DATA,"totalflows_wide_2007_2011.csv"), colClasses=list(character=1)); setnames(tf,1,"identificad")
fp <- merge(fp, tf, by="identificad", all.x=TRUE)
fp <- merge(fp, agg, by="identificad", all.x=TRUE)
fp[, treat_year := as.integer(year>=2012)]
sB <- quote(treat_ultra==0 & in_balanced_panel==1)
P90e <- stata_pctile(unique(fp[eval(sB),.(identificad,cf_early)])$cf_early,90)
P90l <- stata_pctile(unique(fp[eval(sB),.(identificad,cf_late)])$cf_late,90)
fp[, ce := cf_early/P90e]; fp[, cl := cf_late/P90l]   # own-P90 scaled

## bins
mkbin <- function(dt,src,name){
  dt[, pt := {m<-mean(get(src)[year%in%2009:2011],na.rm=TRUE); if(is.nan(m))NA_real_ else m}, by=identificad]
  sel <- dt$year==2009 & dt$in_balanced_panel==1 & !is.na(dt$in_balanced_panel) & !is.na(dt$pt)
  br <- sapply(c(25,50,75), function(p) stata_pctile(dt$pt[sel],p))
  dt[, bt:=NA_integer_]; dt[sel, bt:=findInterval(pt,br)]
  dt[,(name):={b<-bt[!is.na(bt)]; if(length(b))b[1] else 0L}, by=identificad]; dt[,c("pt","bt"):=NULL]
}
fp[, tf_pre := rowMeans(.SD,na.rm=TRUE), .SDcols=c("totalflows_pw_07_08","totalflows_pw_08_09","totalflows_pw_09_10","totalflows_pw_10_11")]
fp[is.nan(tf_pre), tf_pre:=NA_real_]
for(v in c("lr_remdezr_w","l_firm_emp","tf_pre")) mkbin(fp,v,paste0(v,"_b"))

dm <- fp[eval(sB) & !is.na(lr_remdezr_w) & !is.na(ce) & !is.na(cl)]
dm[, cet := ce*treat_year]; dm[, clt := cl*treat_year]
dm[, b_out:=paste(lr_remdezr_w_b,year)]; dm[, b_emp:=paste(l_firm_emp_b,year)]; dm[, b_flw:=paste(tf_pre_b,year)]
dm[, iy:=paste(industry1,year)]; dm[, my:=paste(mode_base_month,year)]; dm[, ry:=paste(microregion,year)]
fes <- c("identificad","year","b_out","b_emp","b_flw","iy","my","ry")
dm <- drop_singletons(copy(dm), fes)
ffe <- paste(fes, collapse=" + ")

## (a) raw cross-firm spread (one row per firm) of the own-P90 measures
fx <- unique(dm[,.(identificad,ce,cl)])
cat(sprintf("RAW cross-firm SD (own-P90 units): early=%.3f  late=%.3f  (ratio late/early=%.2f)\n",
    sd(fx$ce), sd(fx$cl), sd(fx$cl)/sd(fx$ce)))
cat(sprintf("RAW skew/max: early skew=%.1f max=%.2f p99=%.2f | late skew=%.1f max=%.2f p99=%.2f\n",
    myskew(fx$ce), max(fx$ce), quantile(fx$ce,.99), myskew(fx$cl), max(fx$cl), quantile(fx$cl,.99)))

## (b) residual spread of the regressor (cet, clt) after partialling out FEs
re <- feols(as.formula(paste0("cet ~ 1 | ", ffe)), dm)
rl <- feols(as.formula(paste0("clt ~ 1 | ", ffe)), dm)
cat(sprintf("RESIDUAL SD of regressor after FEs: early=%.4f  late=%.4f  (ratio late/early=%.2f)\n",
    sd(resid(re)), sd(resid(rl)), sd(resid(rl))/sd(resid(re))))
cat(sprintf("  -> share of regressor variance absorbed by FEs: early=%.1f%%  late=%.1f%%\n",
    100*(1-var(resid(re))/var(dm$cet)), 100*(1-var(resid(rl))/var(dm$clt))))

## (c) iid vs clustered SE for each
for(nm in c("early","late")){
  x <- if(nm=="early") "cet" else "clt"
  m_iid <- feols(as.formula(paste0("lr_remdezr_w ~ ",x," | ",ffe)), dm, se="iid")
  m_cl  <- feols(as.formula(paste0("lr_remdezr_w ~ ",x," | ",ffe)), dm, cluster=~identificad)
  cat(sprintf("%-6s: b=%.4f  SE(iid)=%.4f  SE(cluster)=%.4f  cluster/iid=%.2f\n",
      nm, coef(m_cl)[1], se(m_iid)[1], se(m_cl)[1], se(m_cl)[1]/se(m_iid)[1]))
}

## (d) winsorize connectivity at p99 (own-P90 units) and re-estimate — is early's
## precision an outlier artifact, or robust?
cat("\n-- winsorized (p99) robustness --\n")
for(nm in c("early","late")){
  x0 <- if(nm=="early") "ce" else "cl"
  cap <- quantile(unique(dm[,.(identificad, v=get(x0))])$v, .99, na.rm=TRUE)
  dm[, xw := pmin(get(x0), cap)*treat_year]
  m <- feols(as.formula(paste0("lr_remdezr_w ~ xw | ",ffe)), dm, cluster=~identificad)
  sdw <- sd(unique(dm[,.(identificad, w=pmin(get(x0),cap))])$w)
  cat(sprintf("%-6s winsor: b=%.4f SE=%.4f t=%.2f | cross-firm SD now %.3f\n",
      nm, coef(m)[1], se(m)[1], coef(m)[1]/se(m)[1], sdw))
}
## share of the early coefficient's identifying variation from the top 1% of firms
top <- quantile(unique(dm[,.(identificad,ce)])$ce, .99)
cat(sprintf("\ntop 1%% of early-connectivity firms: %d firms, hold %.0f%% of total cross-firm variance of early measure\n",
    uniqueN(dm[ce>top, identificad]),
    100*sum((unique(dm[ce>top,.(identificad,ce)])$ce - mean(unique(dm[,.(identificad,ce)])$ce))^2) /
        sum((unique(dm[,.(identificad,ce)])$ce - mean(unique(dm[,.(identificad,ce)])$ce))^2)))
