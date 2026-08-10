source(file.path("/Users/gui.neri/Library/CloudStorage/OneDrive-NorthwesternUniversity/Research Projects/Org_Econ BR/UnionSpillovers/Gui_coding/within firm/gui_check/scripts", "prep_layer.R"))
d <- get_prepped("edu2", "/Users/gui.neri/Library/CloudStorage/OneDrive-NorthwesternUniversity/Research Projects/Org_Econ BR/UnionSpillovers/Gui_coding/within firm/gui_check/output")
p90g <- stata_pctile(d[s_base == TRUE & year == 2009, layer_treat_pw_n], 90)

## group connectivity (P90 units) + pre-period employment shares per firm
d[, c_no  := {v <- layer_treat_pw_n[layer_id=="no_hs"];  if(length(v) && !all(is.na(v))) v[!is.na(v)][1] else NA_real_}/p90g, by=identificad]
d[, c_has := {v <- layer_treat_pw_n[layer_id=="has_hs"]; if(length(v) && !all(is.na(v))) v[!is.na(v)][1] else NA_real_}/p90g, by=identificad]
emp <- d[year %in% 2009:2011, .(E = mean(layer_emp, na.rm=TRUE)), by=.(identificad, layer_id)]
emp <- dcast(emp, identificad ~ layer_id, value.var="E")
emp[, s_no := no_hs/(no_hs+has_hs)][, s_has := has_hs/(no_hs+has_hs)]

fp <- as.data.table(read_dta(file.path(DATA,"lagos_sample_sep24_pct_unionexp_ext_df2.dta"),
      col_select=c("identificad","year","totaltreat_pw_n")))
fx <- unique(d[s_base==TRUE & !is.na(c_no) & !is.na(c_has), .(identificad, c_no, c_has)])
fx <- merge(fx, emp[, .(identificad, s_no, s_has)], by="identificad")
fx <- merge(fx, fp[year==2009, .(identificad, c_firm = totaltreat_pw_n/p90g)], by="identificad")
fx <- fx[complete.cases(fx)]

## STEP 1: accounting identity  c_F = s_L*c_L + s_H*c_H
fx[, c_firm_hat := s_no*c_no + s_has*c_has]
m1 <- lm(c_firm ~ c_firm_hat, fx)
cat(sprintf("STEP 1  identity check: reg c_F on (s_L*c_L + s_H*c_H): slope=%.3f, R2=%.3f, N=%d firms\n",
    coef(m1)[2], summary(m1)$r.squared, nrow(fx)))
cat(sprintf("        mean shares: s_L=%.3f s_H=%.3f (sum=1 by construction)\n", mean(fx$s_no), mean(fx$s_has)))

## STEP 2: projection coefficients gamma_g of each group measure on the firm measure
g1 <- lm(c_no ~ c_firm, fx); g2 <- lm(c_has ~ c_firm, fx)
cat(sprintf("STEP 2  projections: c_L on c_F: gamma_L=%.3f | c_H on c_F: gamma_H=%.3f\n",
    coef(g1)[2], coef(g2)[2]))

## STEP 3: OVB reconstruction of the single-regressor estimate
bL <- 0.0029; bH <- 0.0022; delta <- 0.0039   # from run_a8_sum.R, same sample/FE/scale
cat(sprintf("STEP 3  gamma_L*b_L + gamma_H*b_H = %.4f  vs  actual single-regressor delta = %.4f\n",
    coef(g1)[2]*bL + coef(g2)[2]*bH, delta))
cat(sprintf("        plain sum b_L + b_H = %.4f  vs  Table 2 headline = 0.0051\n", bL+bH))
