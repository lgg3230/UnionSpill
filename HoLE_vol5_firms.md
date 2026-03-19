the | Chapter | 2   |     |     |     |
| ------- | --- | --- | --- | --- |
☆
| Firm    | wage    | effects |     |     |
| ------- | ------- | ------- | --- | --- |
| Patrick | Kline ⁎ |         |     |     |
UniversityofCalifornia,Berkeley,UnitedStates
⁎
Correspondingauthor.e-mailaddress:pkline@berkeley.edu
Chapter Outline
| 1 Background                    |     | 119 | 4.3Clusteringapproaches     | 156 |
| ------------------------------- | --- | --- | --------------------------- | --- |
| 2 Whatsortsoffirmspayhighwages? |     | 120 | 4.4Howvariableareworker     |     |
| 2.1Productivity,workerflows,    |     |     | andfirmeffects?             | 159 |
| andfirmsize                     |     | 121 | 5 Regressingfirmeffectson   |     |
| 2.2Entry,reallocation,and       |     |     | observables                 | 161 |
| dynamics                        |     | 122 | 5.1Onestepvstwo             | 162 |
| 2.3Sorting,outsourcing,and      |     |     | 5.2Varianceestimation       | 163 |
| displacement                    |     | 123 | 5.3Revisitingthefirmsize    |     |
| 2.4Industrystructureand         |     |     | wagepremium                 | 164 |
| amenities                       |     | 124 | 6 Hiringoriginsandstate     |     |
| 3 TheAKMmodel                   |     | 125 | dependence                  | 166 |
| 3.1Anedgyinterpretationof       |     |     | 6.1Structuralinterpretation | 167 |
| firmeffects                     |     | 127 | 6.2Testablerestrictions     | 168 |
| 3.2EvaluatingtheAKM             |     |     | 6.3Itain’twhereyou’refrom,  |     |
| restrictions                    |     | 135 | it’swhereyou’reat           | 169 |
| 3.3Causality                    |     | 140 | 6.4Informationandconduct    | 170 |
| 4 Variancedecomposition         |     | 146 | 7 Conclusion                | 171 |
| 4.1Limitedmobilitybias          |     | 147 | Appendix:Covariancebetween  |     |
| 4.2Cross-fittingandbias         |     |     | personandfirmeffects        | 172 |
| correction                      |     | 148 | References                  | 176 |
Nearly a century of empirical study supports the view that employers offer
different wages for identical work. Fueled by the dissemination of linked
employer-employee datasets, a rapidly advancing literature seeks to quantify
☆Thisisthefirstpartofalargerchapteronthetopicof“wagesettingpower”thatwasinitially
prepared for the Handbook of Labor Economics conference in Berlin, which was generously
fundedbytheRockwoolFoundationBerlin(RFBerlin).Basedondiscussionswiththeeditorsit
wasdeterminedtobebetterforpedagogicalreasonstopublishthetwopartsasseparatechapters.I
thank David Card, Raffaele Saggio, Ben Scuderi, Isaiah Andrews, and Sophie Sun for helpful
commentsonanearlierdraftthatsubstantiallyimprovedthepaper.JordanCammarotaprovided
outstandingresearchassistanceonthisproject.Manyoftheideasinthischaptergrewoutofpast
conversationswithcollaboratorsincludingDavidCard,RaffaeleSaggio,andMikkelSølvsten.
HandbookofLaborEconomics,Vol.5.https://doi.org/10.1016/bs.heslab.2024.11.005
Copyright©2024ElsevierB.V.Allrightsarereserved,includingthosefortextanddatamining,
| AItraining,andsimilartechnologies. |     |     |     | 115 |
| ---------------------------------- | --- | --- | --- | --- |

116 HandbookofLaborEconomics
the role of firms in generating wage inequality using high dimensional fixed
effects methods. This chapter provides an overview of the literature on firm
wage effects, summarizing the evidence base that has been accumulated on
which firms pay high wages, their contribution to inequality, and econometric
issues that arise in working with models of firm wage fixed effects.
The chapter begins with a survey of early empirical investigations of firm
and industry components of wage dispersion. Slichter (1950) and Stigler
(1962) pioneered the measurement of wage dispersion across employers,
providingestimatesofthevariabilityofpostedwageswithinnarrowlydefined
job categories and the variability of wage offers within the same worker.
Generations later, Krueger and Summers (1988) used the panel structure of
large surveys to study the wage changes accompanying worker mobility
between industries, concluding that substantial across industry dispersion is
presentinaveragepayforequivalentwork.Thesefindingsrenewedinterestin
deviations from competitive labor market models and foreshadowed many of
the economic and econometric debates surrounding the use of fixed effects
methodstoday(Katzetal.,1989;MurphyandTopel,1990;GibbonsandKatz,
1992). A related literature on firm size wage premia and intra-industry dis-
persion documented sizable wage differences across firms and plants in the
same industry (Brown and Medoff, 1989; Brown et al., 1990; Groshen, 1991;
CappelliandChauvin,1991).Abowdetal.(1999)’slandmarkstudyprovideda
unified framework for studying these phenomena by applying high dimen-
sional fixed effects methods to matched employer-employee data.
A large empirical literature has refined and extended many of the conclu-
sions from Abowd et al. (1999)’s paper. Five notable patterns stand out from
this literature. First, consistent with standard job ladder models, firm wage
fixed effects have been found to be positively related to proxies of firm pro-
ductivity, firm size, and revealed preference measures of firm desirability
(Card et al., 2016; Bloom et al., 2018; Sorkin, 2018; Crane et al., 2023).
Second,highwagefirmstendtoemployhighwageworkers,men,andworkers
withgreatereducationalattainment(Cardetal.,2013,2016).Third,firmwage
effectsarehighlytemporallypersistent(Lachowskaetal.,2023;Engbometal.,
2023),andahandfulofstudiessuggestchangesinlabormarketinstitutionscan
alterthemixoffirmeffectsinaneconomy(Cardetal.,2013;Dustmannetal.,
2022).Fourth,highwagefirmsaremorelikelyto“fissure”,oroutsourcejobs,
and to conduct mass layoffs, both of which may indicate that firms face hor-
izontal equity constraints in wage setting (Goldschmidt and Schmieder, 2017;
Bertheau et al., 2023). Fifth, the latest research suggests that the most pro-
ductivefirmsalsoprovidethebestamenities,aligningwithrevealedpreference
evidence that high wage firms tend to be more desirable than low wage firms
(Sorkin, 2018; Lamadon et al., 2022; Sockin, 2022; Roussille and Scuderi,
2023; Maestas et al., 2023; Lehmann, 2023; Caldwell et al., 2024b).
Delving into the econometric assumptions underlying many of these stu-
dies, we review “the AKM model”: a two-way fixed effects model of wage

Firmwageeffects Chapter | 2 117
determination allowing for unrestricted worker-firm sorting patterns. After
discussing the standard identification requirements of two-way fixed effects
estimatorsinmatchedemployer-employeedata,agraphtheoreticinterpretation
ofthemodelisintroducedwherefirmsserveasverticesandthewagechanges
between employers constitute directed edges. The restrictions that the AKM
modelplacesontheseedgesareexplained,highlightingthespecialroleplayed
bycyclesinthemobilitynetwork.Theserestrictionsyieldacomplexmapping
between wage changes and firm effects; however, pruning the mobility graph
toaspanningtreeyieldsajust-identifiedsetoffirmeffectswithaparticularly
simple structure. The plausibility of the AKM model restrictions is then
evaluatedempiricallyinabenchmarkdataset.Afteraccountingfornoiseinthe
edge specific wage changes, I find that the least squares estimates provide a
remarkably accurate (albeit imperfect) summary of the wage changes asso-
ciated with moving between particular pairs of firms.
Building on the graph theoretic interpretation, I introduce non-parametric
assumptionsthatendowthewagechangesaccompanyingworkermobilitywith
a causal interpretation. Difficulties arise with aggregating these causal effects
into a global ranking of firm wage levels. Least squares estimates of firm
effects are shown to rely on “indirect contrasts” involving mobility between
other firm pairs than those under consideration, a phenomenon that has been
found to also arise in other settings with multiple treatments (Goldsmith-
Pinkham et al., 2022). Indirect contrasts can be avoided when the network is
prunedtoatreebutleastsquaresestimatesoffirmeffectsdonotautomatically
allow global comparison of wage levels across firms without further assump-
tions. The section concludes by proposing an assumption that ensures a tran-
sitiverankingoffirmwagelevelsanddiscussinghowthisassumptionmightbe
usefully weakened in future research.
Abowd et al. (1999) proposed a now canonical variance decomposition of
log wages into components attributable to worker and firm heterogeneity and
sorting.Pluggingestimatedfixedeffectsintovariancedecompositionshaslong
been understood to generate important biases (Krueger and Summers, 1988;
Andrews et al., 2008). I review approaches to circumventing these biases,
including the cross-fitting based bias-correction of Kline et al. (2020) and
recently proposed clustering methods that assume the firm heterogeneity
possessesalowerdimensionalstructure(Bonhommeetal.,2019,2023).Cross-
fitting approaches require a substantial amount of worker mobility, which
researchers typically enforce by pruning to a set of “leave-out connected”
firms.Asimpleapproachtoboundingtheinfluenceofthispruningsteponthe
estimand is proposed and applied to a well known benchmark dataset. I also
discussimputationstrategiesthatcanbeusedtoaddressconcernsaboutbiases
arising either from pruning or neglected serial correlation. An empirical
investigation suggests that the selection biases associated with pruning and
serial correlation are likely minimal in large administrative datasets.

118 HandbookofLaborEconomics
Reviewingtheempiricalliteratureonbias-correctedvariancedecompositions,I
arguethatinterestoughttocenteronthemagnitudeofthesevariancecomponents
themselves rather than variance shares, which are difficult to compare across
datasets with different intrinsic noise levels. Bias-corrected estimates of the eco-
nomic magnitude of the variability in firm fixed effects are typically sizable,
relative both to the dispersion in person effects and to the effect sizes of human
capital interventions. A review of recent studies yields estimated standard devia-
tionsoffirmfixedeffectsrangingfrom15to60logpoints,withestimatesinthe
USandEuropeancountriesclusteringaround20logpoints.Inlinewithagrowing
literatureonlabormarketmisallocation(e.g.,HsiehandKlenow,2009),dispersion
in firm effects appears to be most pronounced in the least developed countries.
Investigating the factors driving this relationship between dispersion and devel-
opment is a fruitful area for future research.
Avirtueoffixedeffectsmethodsisthattheestimatescanbesharedwithother
research teams who can explore other hypotheses about the relationship between
thelatent effectsand observables.Ireviewthe logicof“two-step”regressionsof
estimated fixed effects on observables, contrasting it with one-step approaches
predicatedonstrongerrandomeffectsassumptions.Whilesecondstepregressions
of estimated firm fixed effects on firm and worker level covariates are unbiased,
inference is complicated by correlation across the fixed effects estimates, a pro-
blemthatiswellunderstoodtheoreticallybuthaslargelybeenignoredinapplied
work. Kline et al. (2020) proposed an approach to obtaining heteroscedasticity
robust standard errors reflecting the uncertainty stemming from the error under-
lyingthelinearfixedeffectsmodel.Iillustratethisapproachwithanapplicationto
the firm size wage premium, which is found to vary in complex ways across
Italian regions. Naive two-step standard errors, of the sort that currently pervade
the empirical literature, are shown to significantly understate the true uncertainty
present in averages of firm fixed effects in this example.
Finally, I discuss connections between the AKM model and the influential
classofsearchmodelspioneeredbyPostel-VinayandRobin(2002a,b).While
these “sequential auction” models have traditionally been assessed based on
their ability to jointly explain job mobility and wage dynamics within firm
matches, we discuss the theory’s implications for hiring wages. Di Addario
etal.(2023)showedthatasimplelinearspecificationallowingfixedeffectsfor
hiringoriginsneststhereducedformofhiringwagesinthesequentialauction
model of Bagger et al. (2014). Dispersion in these hiring origin fixed effects
can be viewed as capturing a contribution of search frictions (or equivalently,
“luck”) to wage inequality. While recent evidence suggests that hiring origins
are less influential than these models predict, bilateral competition between
firms undoubtedly plays an important role in wage determination for some
types of jobs. I discuss the importance for future work of allowing departures
from the full information benchmark underpinning canonical variants of this
competition framework and conclude with some directions for future research
on the econometrics and economics of firm wage setting.

Firmwageeffects Chapter | 2 119
1 Background
Economists have long been aware that employers differ in the pay offered to
equivalent workers. Slichter (1950) showed in survey data that the hourly
wagesofnarrowlydefinedmanualoccupationsvariedwidelyacrossemployers
in Boston. Studying industry data from the 1950 Economic Census, he found
that industry value added and profits were important drivers of average pay,
leading him to conclude that managerial practices were an important deter-
minantofindustrypaysetting.Adecadelater,Stigler(1962)collecteddataon
the job offers of business school graduates. In one of the earliest analyses of
matched employer-employee data, he documented that within occupational
categories, the dispersion of wage offers across companies was of the same
order of magnitude as dispersion of wage offers within individual. Moreover,
these company pay differences were found to be persistent across years. He
concluded from this evidence that wage dispersion for equivalent workers “is
of the order of magnitude of 5–10 percent even in so well organized a market
as that of college graduates at a single university” (Stigler, 1962, p. 96).
Generations later, Krueger and Summers (1988) examined the extent to
which industry differences in pay reflected the sorting of high ability workers
to high paying sectors. Using the 1984 Current Population Survey, they fit
linearmodelswithworkerqualitycontrolsandindustryfixedeffects,findinga
bias-corrected standard deviation across two-digit industries of industry fixed
effectsinwagesof14logpointsandastandarddeviationintotalcompensation
of roughly 18 log points. To account for unobserved differences in worker
quality, they fit longitudinal models to the 1984 displaced workers survey,
findingthatincludingworkerfixedeffectshadlittleimpactonestimatesofone
digit industry fixed effects, suggesting a limited role for selection on unob-
served worker quality. Corroborating this view, Gibbons and Katz (1992)
found sizable industry wage differentials even after restricting to transitions
induced by mass layoffs or plant closures. A large literature debated the
interpretation of these findings and whether they can be attributed to com-
pensating differentials, efficiency wages, or employer learning (Katz et al.,
1989; Murphy and Topel, 1990; Holzer et al., 1991; Gibbons et al., 2005).
Several authors also studied wage differences between establishments and
firmsofdifferentsize(OiandIdson,1999).BrownandMedoff(1989),Brown
et al. (1990), and Oi and Idson (1999) showed that larger firms, and larger
plants within large firms, paid higher wages. Studying worker switches
between establishments again confirmed that these differences were generally
not attributable to unobserved worker characteristics. Adjustments for work-
place amenities were also found to have little impact on the firm size wage
premium. Corroborating evidence from Groshen (1991) and Cappelli and
Chauvin (1991) documented large wage dispersion across establishments
withinindustrythatcouldnotbe explainedby differencesinmeasuredhuman

120 HandbookofLaborEconomics
capital. These intra-industry employer differentials were shown to be com-
parable in magnitude to inter-industry wage differences.
Seeking to unify these findings, Abowd et al. (1999) – henceforth, AKM
– studied employer wage differences in large administrative panels from
France and the United States featuring worker and firm identifiers. In what
mayhavebeenthefirsthighdimensionalregressioninlaboreconomics,they
fit linear models allowing a separate fixed effect for each worker and each
firm, along with firm specific trends intended to capture heterogeneity in
firm seniority trajectories. AKM found that estimated firm wage effects
varied substantially across firms and were correlated with observable mea-
suresoffirmproductivity.However,theestimatessuggestedthatworkerand
firm fixed effects were only modestly positively correlated and that industry
and firm size wage premia were largely accounted for by differences in
person effects. Unfortunately, shortly after their study was published, sub-
sequent work revealed that some of these empirical conclusions were arti-
factsofaninaccurateapproximationtothefullleastsquaressolution(Abowd
et al., 2002, 2003).
Despite theseearlystumbles, theworkofAbowd etal. (1999)heralded an
important transition in empirical labor economics towards interest in the
development of econometric methods for the study of matched employer-
employee data. While the literature on panel data econometrics traditionally
treated fixed effects as nuisance parameters (Chamberlain, 1984), AKM
viewed these effects as objects of direct interest. This perspective permeates
the literature today. Rather than focus attention on the relationship between
wages and a handful of observable firm characteristics such as size, sector, or
productivity, labor economists now routinely apply fixed effects estimators to
enormousadministrativedatasetsin anattemptto“letthedata speak”directly
about which employers offer high or low wages. The relationship between
employerwagefixedeffectsandlowdimensionalworkerandfirmobservables
can then be scrutinized in a second step, perhaps even by a different research
team. While similar transitions from structured to unstructured data analysis
haveoccurredinmanyotherareasofempiricaleconomics–seethechapterin
thisHandbookbyWalters(2024)forsomeexamples–thechangehasarguably
been most dramatic in the literature on wage determination, where it has long
been understood that wages vary meaningfully across employers in ways that
are difficult to capture with the worker and firm characteristics measured in
standard datasets.
2 What sorts of firms pay high wages?
Before delving into the econometrics of fixed effects models, it is useful to
provide an overview of what has been learned about the types of firms that
offer high wages from empirical research utilizing matched employer-
employee data. This body of work has refined our empirical understanding of

Firmwageeffects Chapter | 2 121
traditionalregularitiessuchasthefirmsizeandindustrywagepremiums,while
also offering new insights into how labor market institutions, outsourcing
practices, and job displacement contribute to wage inequality.
2.1 Productivity, worker flows, and firm size
Theempiricalliteraturefindsthatfirmwagefixedeffectsarestronglyassociated
both with observable measures of firm productivity and desirability. AKM’s
originalstudydocumentedthatfirmwageeffectswerepositivelycorrelatedwith
value added per worker and capital share. An updated analysis by Abowd et al.
(2012)utilizingexactleastsquaressolutionsfindsqualitativelysimilarpatternsin
morerecentpanelsofFrenchandUSadministrativedata.UsingPortuguesedata
on hourly wages merged to firm accounting data from Bureau Van Dijk, Card
et al. (2016) documented that firm wage effects exhibit a “hockey stick” like
relationship with log value added per worker, exhibiting a slope of essentially
zero at very low levels of value added followed by a nearly constant elasticity
relationshipathigherlevels.Subsequentworkdocumentssimilarnonlinearitiesin
Germany (Bruns, 2019), France (Coudin et al., 2018), Canada (Li et al., 2023),
Hungary (Boza and Reizer, 2024), and Italy (Di Addario et al., 2023). Possible
explanations for the hockey stick shape include the presence of binding wage
floorsthatprohibitverylowfirmeffects,theexistenceofa“competitivefringe”
of less productive firms that engage inessentially competitive wage setting, and
non-classical measurement error in value added per worker.
Sorkin (2018) devised a revealed preference measure of firm desirability
basedontheideathatadesirablefirmhiresworkersfromotherdesirablefirms.
The proposed measure, which is motivated by a wage posting model in the
spirit of Burdett and Mortensen (1998), involves applying the Google
PageRank algorithm (Page et al., 1999) to the network of job to job flows.
Sorkin(2018)reportsthathismeasureoffirmdesirabilityexhibitsacorrelation
of roughly 0.54 with firm wage effects derived from quarterly earnings in
LongitudinalEmployerHouseholdDynamics(LEHD)data.Craneetal.(2023)
alsouseLEHDdatatoshowthatfirmwagefixedeffectsarestronglypositively
related to the “poaching rank” index of Bagger and Lentz (2019), which
provides another revealed preference measure of firm desirability consistent
with a class of sequential auction models that will be discussed below.
Firm wage fixed effects have been shown to be positively related to firm
sizeandnegativelyrelatedtoquitrates(Cardetal.,2013;Bassieretal.,2022).
Bloom et al. (2018) study the changing nature of the firm size wage premium
by fitting separate fixed effects models to the US Social Security Adminis-
tration’s Master Earning File in each of three time periods: 1980–1986,
1994–2000, and 2007–2013. In the first period, firm wage fixed effects are
monotonically increasing in firm size, with an enormous 55 log point gap in
average firm effects between companies with 15,000 or more employees and
those with 1–10 employees. In later periods, the relationship between wages

122 HandbookofLaborEconomics
and firm size grows more concave. In the final 2007–2013 sample, mono-
tonicity appears to break down, with mean firm fixed effects estimated to be
slightly higher among firms with 1,000–2,500 employees than at the largest
firms. The pay gap between the largest and smallest firms falls to roughly
22 log points in this period. To date, little evidence is available regarding
whether similar transitions have occurred in other countries.
2.2 Entry, reallocation, and dynamics
Thedistributionoffirmeffectshasbeenshowntorespondtochangesinlabor
market institutions. Card et al. (2013) fit separate models to four overlapping
6–7 year intervals of German data spanning the period from 1985 to 2009.
They find that the variance of firm wage effects roughly doubles over the
courseoftheirstudy.Mostofthegrowthindispersionoffirmeffectsoccursin
the latter two intervals, a period that saw a rapid liberalization of the German
labor market. Analyzing cohorts of firms, they find that within cohort
inequalityinfirmwageeffectsisroughlystableovertimebutnewercohortsof
firms are more unequal.1 Tying these cohort trends to the breakdown of the
Germancollectivebargainingsystem,theydocumentthatfirmsnotcoveredby
bargaining agreements are more likely to exhibit very low wage fixed effects.
Songetal.(2019)conductasimilar“rollingAKM”analysismakinguseofUS
socialsecurityrecordsovertheperiod1978–2013.Whiletheyfindthatinequality
increased dramatically across firms over this period, firm effect variances were
surprisingly stable, suggesting the rise in between firm inequality was a con-
sequenceofincreasedworker-firmsorting.ThisdiscrepancybetweentheGerman
andUSresultsmayhavetodowithdifferencesintheinstitutionalenvironmentof
these labor markets. The US has enjoyed a relatively stable regulatory environ-
ment over the period studied by Song et al. (2019), while post-unification Ger-
many faced enormous pressure on its sectoral bargaining system that plausibly
paved the way for the entry of very low wage firms (Dustmann et al., 2014).
Dustmannetal.(2022)showthattheenactmentofaGermanminimumwageled
low wage workers to reallocate to firms with higher wage fixed effects, and that
Germanregionsdifferentiallyexposedtotheminimumwagehikeexperiencedan
increase in the average AKM fixed effect of surviving establishments.
The temporal stability of the firm effect variances among cohorts of
GermanfirmsdocumentedbyCardetal.(2013)suggeststhatfirmwageeffects
are persistent. Lachowska et al. (2023) used hourly wage data derived from
Washington state UI records to measure this persistence more carefully. They
estimateunrestrictedfirmfixedeffectsoverpairsofadjacentyears,yieldinga
sequence of fixed effects for each firm. Fitting an AR1 model to these esti-
mates, they find a bias-corrected autocorrelation of firm wage effects of 0.98.
1Sorkin and Wallskog (2023) find a similar pattern in US data, albeit without controlling for
personeffects.

Firmwageeffects Chapter | 2 123
Contemporaneous work by Engbom et al. (2023) finds that projecting firm
wage effects derived from 8 year intervals onto the effects derived from
pooling 32 years of Swedish wage data yields a slope of roughly 0.95, sug-
gesting that wage fixed effects are highly stable among long lived firms.
2.3 Sorting, outsourcing, and displacement
Highwagefirmsemployhighwageworkers.Thispatternhasbeenrepeatedly
documentedintheformofpositivebias-correctedcorrelationsbetweenworker
and firm fixed effects (Andrews et al., 2008; Kline et al., 2020; Bonhomme
et al., 2023). However, the pattern is usually evident (albeit attenuated) from
uncorrectedestimatesfittopopulationleveladministrativerecords.Cardetal.
(2013) and Song et al. (2019) both find that the uncorrected correlation
between worker and firm fixed effects has increased in recent decades.
Observableworkercharacteristicsarealsopredictiveoffirmeffects.Lowwage
firmstendtodisproportionatelyemploywomen(Cardetal.,2016),immigrants
(Dostie et al., 2023), minorities (Gerard et al., 2021), younger workers (Kline
etal.,2020),andworkerswithlowereducationalattainment(Cardetal.,2013).
Low wage firms are also typically intensive in jobs involving low wage
occupations(Cardetal.,2013;GoldschmidtandSchmieder,2017)andtendto
exhibit less complex job hierarchies (Huitfeldt et al., 2023).
GoldschmidtandSchmieder(2017)findthatGermanfirmswithhighwagefixed
effectsaremorelikelytooutsourceworkersinfoodservices,cleaning,security,and
logistics (FCSL) occupations. One interpretation of this pattern is that firms face
horizontalequityconstraintsmakingitdifficulttotailorwagestotheoutsideoptions
of individual workers. Consistent with this view, they estimate separate firm fixed
effectsforFCSLandnon-FCSLworkersateachemployerandfindthatfirmspaying
10 % higher wages to non-FCSL workers tend to pay FCSL worker roughly 8 %
higherwages(GoldschmidtandSchmieder,2017,FigureA-8).2Ratherthansharea
large wage premium with workers at all layers of the organization, firms tend to
spinoffjobslyingoutsidetheirareaofcorecompetencyinordertoeconomizeon
wage costs. In the wake of an outsourcing event, measured as a setting where
manyFCSLworkersmovefroma“mother”establishmenttothesame“daughter”
establishment specializing in FCSL services, the wage of outsourced workers
plummet. This drop turns out to be almost entirely explained by the low fixed
effects of establishments specializing in FCSL services. Goldschmidt and
Schmieder(2017)arguethatthegrowthoffirmsspecializinginFCSLservicesis
animportantdriverofGermaninequalityconsistentwiththefirmcohortpatterns
documented by Card et al. (2013).
In line with the German evidence on outsourcing, Lachowska et al. (2020)
document in Washington state UI records that firms in the top quintile of firm
2Conducting a similar exercise in Argentine data, Drenik et al. (2023) find that firms paying
regularworkers10%higherwagespaytemporaryworkersroughly5%higherwages.

124 HandbookofLaborEconomics
fixedeffectsaccountforadisproportionateshareofdisplacedworkers.However,
theyfindthat70%ofdisplacedworkersmovetoemployerswithsimilarorbetter
firmeffectsdespitesufferingwagelosses.Asaresult,theyestimatethatfirmfixed
effects account for only 17 % of the earnings losses associated with job dis-
placement;however,thissharerisestoroughlytwothirdsamongtheworkerswho
movetolowerwageemployersupondisplacement.Schmiederetal.(2023)findin
German administrative records that nearly all of the average daily wage losses
associatedwithdisplacementareexplainedbydifferencesinfirmeffects.Bertheau
etal.(2023)studyaharmonizedpanelofsevenEuropeancountriesandfindthat
between35%(inSpain)and100%(inPortugal)ofthedailywagelossesofjob
displacement after five years are explained by the loss of firm fixed effects. In a
longer working paper (Bertheau et al., 2022), they conjecture that this variation
acrosscountriesmaybeattributabletotheintensityofactivelabormarketpolicies,
which they show turns out to strongly predict the magnitude of country specific
wagelosses.LikeLachowskaetal.(2020),Bertheauetal.(2023)findinallseven
countriesthatjobdisplacementismostcommonamongfirmswithestimatedfirm
fixed effects in the top quintiles.
2.4 Industry structure and amenities
A headline finding of Abowd et al. (1999)’s original study was that industry
wage differentials are largely explained by person effects. This conclusion
turned out to have been driven by the computational method used in their
analysis to approximate the least squares solution in the largest samples of
firms(Abowdetal.,2002).SubsequentanalysisofearlyLEHDdatafromfour
states found substantial differences in average firm effects across sectors
(Abowd et al., 2003, Table 11). Sorkin (2018, Table V) finds in a broader
LEHDdatasetcomprisedoflargeemployersin27statesthatfourdigitindustry
codes account for roughly 45 % of the variation in firm fixed effects.
More recently, Card et al. (2024) analyze LEHD data covering all 50 states
fortheyears2010–2018.Theyfindthatroughlyonethirdofthevarianceinfirm
wageeffectsisexplainedbyfourdigitNAICSindustrycodes.Remarkably,the
averageindustrypremiumsarenearlyidenticalforworkerswhohave,andhave
not,obtainedacollegedegree.Theyestimatethatthehighestpayingindustryis
coal mining, while the lowest paying industry is drinking places. Perhaps sur-
prisingly, their industry wage premia estimates turn out to be positively corre-
lated with production function based estimates of industry wage markdowns
fromYehetal.(2022),whichmayindicatethatvariationinindustryaveragesof
firm wage effects reflect productivity more than market power.
Card et al. (2013) find in German data that between industry dispersion of
firm effects rose between 1985 and 2009 and that high wage workers
increasinglysorttohighwageindustries.Incontrast,Haltiwangeretal.(2024),
fitting AKM models to three intervals of LEHD data covering the period
1996–2018, find that the contribution of industry averages of firm wage fixed

Firmwageeffects Chapter | 2 125
effects to wage inequality has been relatively stable. Like Card et al. (2013),
however, they find that the sorting of high wage workers to high wage
industries increased substantially.
Sorkin(2018,TableV)reportsthatnearlyhalfofthevariationinhisflowsbased
measure of firm desirability is between 4 digit industries. He argues that elevated
wages in sectors such as mining primarily reflect compensating differentials.
Relatingthefirmwageeffectstomeasuresoffirmdesirability,heconcludesthatas
much as two thirds of the variation in firm wage fixed effects could reflect com-
pensating differentials. Subsequent work by Lamadon et al. (2022) concurs that
compensatingdifferentialsareanimportantdeterminantoffirmwagefixedeffects;
however,theyalsofindthathighwagefirmstendtohavethebestamenities.This
viewiscorroboratedbySockin(2022),whodocumentsthathigherwagefirmslist
morejobamenitiesinjobadvertisements.Likewise,Maestasetal.(2023)findthat
adjusting for valuations of observed amenities derived from stated preference
experiments actuallywidens inter-industry wage differentials.
An emerging consensus is that the most desirable firms tend to offer both the
highest wages and the best amenities, making firms with large wage fixed effects
highly desirable on average. Roussille and Scuderi (2023) provide revealed pre-
ferenceevidencefromanonlinejobboardforsoftwareengineersthathigherwage
firms offer better observed and unobserved amenities. Similar conclusions are
reachedbyLehmann(2023)andLagos(2019)utilizingadministrativerecordsfrom
Austria and Brazil, respectively. Caldwell et al. (2024b) provide survey evidence
from German workers that perceptions of the wages available at other firms are
stronglycorrelatedbothwithfirmeffectestimatesfromadministrativedataandwith
workers’perceptionsofthenon-wageamenitiesatthosefirms.SeeMas(2024)fora
comprehensive analysis oftherecent literature on compensatingdifferentials.
3 The AKM model
The fixed effects model considered by Abowd et al. (1999) can be written:
Y it = i + j(i,t) + X + it , (1)
where Y is the logarithm of worker i’s wages in year t and
it
j(i, t) {1,…,J} [J]isafunctionreturningtheidentityofthefirmemploying
worker i in year t.In their original application to an unbalanced panel of French
administrative data, J was on the order of five hundred thousand, two million
workerswerestudied,andthepanelconsistedofroughlyfivemillionperson-year
observations.Subsequentworkhasconsideredmuchlargersamples.Forinstance,
Song etal.(2019) fitmodelswith over 79millionperson effectsand 5.8million
firm effects to a five year panel with 220 million person-year observations. To
avoidnotationalclutter,itwillbeusefultorestrictattentiontothecasewherethe
panel is balanced in what follows such thatt {1,…,T} [T].
The person effect α is a portable component of wages that a worker can
i
takewiththemtootheremployers.Thisparametercancaptureskills,aswellas

126 HandbookofLaborEconomics
a worker’s reputation, bargaining prowess, or discrimination at the market
level. The firm effect ψ is a non-portable component of wages enjoyed only
j
whenaworkerisemployedatfirmj.Thiseffectcanbeafunctionofboththe
firm’s productivity, some of which is shared with the worker in the form of
higher wages, and its unobserved amenities, which may yield compensating
differentials. The firm effect may also reflect the degree to which effort is
monitorable at the firm, which can generate variation in efficiency wages
(ShapiroandStiglitz,1984;AkerlofandYellen,1990).ThevectorX includes
it
year fixed effects and measures of labor market experience.3
Thetimevaryingerrorε capturesinnovationstotheportablecomponentof
it
the worker’s wage along with any measurement errors. These errors are
assumed to obey a strict exogeneity restriction, requiring that
[ it j(i, s) = j, X is = x] = 0 for all workers i {1,…,N} [N], all time
periods(s, t) [T]2, and all possible firm assignments j [J] and covariate
values x . From a statistical perspective, ε provides the “noise” that
it
creates slippage between firm effect estimates and the true fixed effects.
Thinkingcarefullyabouthowtoaccountforthisnoiseisthecorecontribution
of much of the recent econometrics literature studying these models.
The strict exogeneity condition embeds both the requirement that worker
mobility between firms is not driven by time varying wage fluctuations (often
described as “exogenous mobility”) and that the mapping from worker and firm
heterogeneitytoexpectedlogwagesisadditivelyseparable.However,itdoesnot
restrict, in any way, the joint distribution of worker and firm effects. Therefore,
workersmaysorttofirmsbasedonanyfunctionoftheirownα andthevectorψ
i
of firm wage effects. The pairing of (1)with the strict exogeneity restriction has
cometobeknownas“theAKMmodel”andIwillfollowconventioninusingthis
eponym as a shorthand. It is worth noting, however, that closely related
assumptions are now employed in several literatures exploiting the switching of
units between groups (e.g., Finkelstein et al., 2016; Chetty and Hendren, 2018).
In the AKM model, movements between firms reveal differences in firm
wage setting. In the case where T=2, for any two firms j≠k between which
workers move, we have
[Y i2 Y i1 j(i, 1) = j, j(i, 2) = k, X i1 , X i2 ] = k j + (X i2 X i1 ) . (2)
AsAbowdetal.(2002)detail,thefirmeffectlevelsareonlyidentifieduptoa
constant within the largest “connected set” of employers: that is, the set of
firms connected, directly or indirectly, via worker moves. Intuitively, if there
aretwocollectionsoffirmsbetweenwhichworkersnevermove,thedifference
in their wage levels will not be identified. A single restriction on the firm
effects – typically a normalization that one of them is zero – within each
3SeeCardetal.(2018)fordiscussionofidentificationissuesposedbyintroducingageandyear
effects.Intheiroriginalstudy,Abowdetal.(1999)includedfirmspecificsenioritytrends,which
introducesadditionalidentificationchallengesthatIwillnotconsiderhere.

Firmwageeffects Chapter | 2 127
connectedsetisrequiredforthedesignmatrixofworkerandfirmdummiesto
have full rank, enabling least squares estimation of (1).
In the German social security records analyzed by Card et al. (2013), the
largest connected set captured around 97–98% of person year observations
depending on the period analyzed. These shares can be lower when studying
subpopulations. For example, fitting models separately by gender to Portuguese
data, Card et al. (2016) find that the largest connected set comprises 88% of
person-year observations for male workers and 91% of observations for female
workers.Inbothsettings,thewagedistributionsandworkercharacteristicsinthe
largest connected set tend to be similar to those in the broader population.
Ourdiscussionsofaroftheconnectednessandnormalizationrequirements
for estimation of the firm effects has been a bit vague. The next subsection
delves deeper into these subjects by providing a graph theoretic interpretation
of the AKM model. I focus there on the properties of the mobility network,
defined as a directed graph where vertices correspond to firms and edges
representworkermovesbetweenfirms.Atthecostofsomeadditionalnotation,
thisnetworkbasedlenswillallowustodevelopaninterpretationoftheAKM
model as a restricted model of “edge effects.” This interpretation motivates a
correspondingrepresentationoftheleastsquaresestimatoroffirmeffectsasa
linear combination of estimated edge effects. A closely related representation
was explored by Jochmans and Weidner (2019). My exposition differs from
theirs primarily in clarifying how the presence of cycles in the mobility net-
work influence the algebraic mapping between the wage changes of movers
and the firm fixed effects estimates. Section 3.2 investigates the extent to
which the restrictions motivating the firm fixed effects estimator are satisfied
inabenchmarkdataset.Section3.3discussescausalinterpretationsofedgeand
firm effects, concluding with some directions for future research.
3.1 An edgy interpretation of firm effects
We begin with some definitions. A graph is a collection of vertices and edges
joining those vertices. The graph we are considering is directed, which means
that each edge starts at one vertex and ends at another. Here, the vertices cor-
respond to the set of firms [J]. An edge is an ordered pair of vertices
(j, k) [J]2, with the first entry denoting an origin firm from which a worker
moved and the second entry denoting the destination of the move. To simplify
theanalysis,wewillcontinuetoassumeT=2,inwhichcasethesetofalledges
in the graph can be defined as:
E= (j,k) (j,k) [J]2, j k, 1{j(i, 1)= j,j(i,2)= k} > 0 .
i [N]
Denoting the total number of edges by E, I will index the edges by
{1,…, E } [E], referring to individual edges by{e } [E].

128 HandbookofLaborEconomics
FIG.1 Amobilitynetwork(J=4, E =6).
Awalkisasequenceofedgesthatjoinasetoffirms.Atrailisawalkwithno
repeated edges. A path is a trail with no repeated firms. The mobility graph is
connectedifthereisapathfromanyfirmtoanyotherfirm.Atreeisaconnected
graphforwhichthereisauniquepathbetweenanypairoffirms.Aspanningtree
is any subset of a connected graph that contains all firms and is a tree.
Fig. 1 depicts a connected graph with four firms and six edges. Arrows
indicatethedirectionsinwhichworkersmovebetweenfirms.Aspanningtree
of this network is given by the solid edges. The dashed edges depart from the
tree by generating alternative paths of moving between firms. These alternate
paths yield cycles: that is, trails that lead us back to where we started. For
example,usingaminussigntodenotetraversalofanedgeinreverse,thetrail
{e
1
, e
2
, e
3
, e
4
}isacycle.Afundamentalcycleisacycleformedbydeparting
fromthespanningtreeusingasingleedgenotinthetree.Thereare E J + 1
distinctfundamentalcyclesinaconnectedgraph.Theotherfundamentalcycles
in this graph are{e 2 , e 3 , e 6 }and{e 2 , e 3 , e 5 }.
TheincidencematrixBprovidesamathematicalrepresentationofthegraph’s
edges.4EveryrowofBrepresentsafirm,whileeverycolumnrepresentsanedge.
Asingleentryineachcolumnequals1,denotingthatedge’sdestinationfirm,and
asingleentryequals−1,capturingthatedge’soriginfirm.Theremainingentries
equal zero. In the graph above B takes the form:
4JochmansandWeidner(2019)workwithaweighteddefinitionoftheincidencematrix.Irely
hereonanunweighteddefinitioninordertohighlightconnectionstocyclesinthegraph.Weights
areintroducedbelowinSection3.1.2.

|     |     |     |     |     | Firmwageeffects |     | Chapter | |   | 2 129 |
| --- | --- | --- | --- | --- | --------------- | --- | ------- | --- | ----- |
An important property of B, to which we will return, is that its rows are
orthogonaltothegraph’scycles.Forinstance,thecycle{e , e , e , e }canbe
|     |     |     |     |     |     |     | 1 2 | 3 4 |     |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
represented by the vector c = [1, 1, 1, 1, 0, 0] . Likewise, the cycles
1
| {e , e ,     | e } and  | {e      | , e , e                                | } are     | captured |               | by  | the   | vectors |
| ------------ | -------- | ------- | -------------------------------------- | --------- | -------- | ------------- | --- | ----- | ------- |
| 2 3          | 6        |         | 2 3                                    | 5         |          |               |     |       |         |
| [0,          | 1, 1, 0, | 0, 1]   |                                        | [0, 1, 1, | 0, 1,    | 0]            |     |       |         |
| c 2 =        |          |         | andc 3 =                               |           |          | respectively. |     | It is | easy to |
| verifythatBc |          | =Bc =Bc | =0.Moregenerally,Bc=0forany|E|×1vector |           |          |               |     |       |         |
|              | 1        | 2       | 3                                      |           |          |               |     |       |         |
c in the linear span (also known as the “cycle space”) of the fundamental
cycles.Forexample,thetrail{e 5 , e 6 },whichcan berepresented byc −c , is
|     |     |     |     |     |     |     |     | 2   | 3   |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
in this graph’s cycle space. In a connected graph, the cycle space is the null-
spaceofB,meaningitcontainsthesetofallvectorsc E suchthatBc=0.
| 3.1.1 | Firm effects | as  | restricted | edge | effects |     |     |     |     |
| ----- | ------------ | --- | ---------- | ---- | ------- | --- | --- | --- | --- |
Returning to (2), we can now rewrite the AKM model in a notation directly
linked to the structure of the graph. To simplify the analysis, suppose that the
| vectorβisknownanddefineR |     |     | =   | Y Y | (X  | X ) | astheN×1vectorof |     |     |
| ------------------------ | --- | --- | --- | --- | --- | --- | ---------------- | --- | --- |
|                          |     |     |     | 2   | 1 2 | 1   |                  |     |     |
workerwagechangesadjustedforthechangeintimevaryingcovariates.LetF
t
denotethe N×J matrixof firmassignment indicators inperiod t, the i’throw
ofwhichcanbewritten(1{j(i, t) = 1}, 1{j(i, t) = 2},…,1{j(i, t) = J}).The
| AKM model | implies |       |        |      |        |         |       |         |     |
| --------- | ------- | ----- | ------ | ---- | ------ | ------- | ----- | ------- | --- |
|           |         |       | R =    | (F   | F) +   | ,       |       |         |     |
|           |         |       |        | 2    | 1      |         |       |         |     |
| where     | = (     | ,…, ) | is the | J ×1 | vector | of firm | fixed | effects | and |
1 J
| = (     | ,…, |            | )         | N×1 |        |                |     |         |        |
| ------- | --- | ---------- | --------- | --- | ------ | -------------- | --- | ------- | ------ |
| 12      | 11  | N2         | N1 is the |     | vector | of differences |     | in wage | errors |
| obeying | [ F | , F ] = 0. |           |     |        |                |     |         |        |
1 2
Wecanwritethematrixoffirstdifferencedfirmindicatorsintermsoftheedge
dummiesviatherelationF 2 F 1 = EB whereEisanN × E matrixof(directed)
edge indicators – i.e., dummies of the form1{j(i, 2) = k}1{j(i, 1) = j} for all
| origin-destinationfirmpairs(j, |     |     | k)  |     |     |     |     |     |     |
| ------------------------------ | --- | --- | --- | --- | --- | --- | --- | --- | --- |
traversedbymovers.Hence,theAKMmodelis
| equivalently | expressed | in  | terms ofthe | incidencematrix |     | as  |     |      |      |
| ------------ | --------- | --- | ----------- | --------------- | --- | --- | --- | ---- | ---- |
|              |           |     | R           | = EB            | + . |     |     |      |      |
|              |           |     |             |                 |     |     |     | [ E] | = 0. |
Here, strictexogeneity can be representedas therequirement that
It is instructive to contrast the AKM model with a model of unrestricted
| edge fixed | effects: |     |     |       |      |     |     |     |     |
| ---------- | -------- | --- | --- | ----- | ---- | --- | --- | --- | --- |
|            |          |     |     | R = E | + u, |     |     |     |     |
whereΔisan E × 1vectorofedgeeffectsandtheN×1errorvectoruobeys
[uE] = 0. Section 3.3 introduces assumptions giving these edge effects a
causal interpretation. The AKM model imposes = B , which entails
E J + 1linearrestrictionsontheedgeeffects.Whentheserestrictionshold,
the two error terms are identical (u = ). Hence, the AKM model can be
thought of as projecting the E J(J 1) edge effects down to only J − 1
| linearly | independent | firm | effects. |     |     |     |     |     |     |
| -------- | ----------- | ---- | -------- | --- | --- | --- | --- | --- | --- |

130 HandbookofLaborEconomics
To understand the nature of the edge restrictions entailed by the AKM
|             |      |         |        |          | c = cB =     | 0,    |
| ----------- | ---- | ------- | ------ | -------- | ------------ | ----- |
| model, note | that | for any | vector | c in the | cycle space, | which |
follows from the cyclic orthogonality properties of B discussed earlier. For
example, the AKM model imposes that wage changes should be symmetric
across origin firm - destination firm pairs, a property that was emphasized by
Card et al. (2013) and is reflected in our example of the cycle c − c .
2 3
However, the AKM restrictions go far beyond pairwise symmetry, restricting
networkdependenttuplesofedgeeffects.Forexample,thefundamentalcycle
c involves four edges. Though directly visualizing the restrictions pertaining
1
tosuch4-cyclesischallenging,theirlogicmirrorstherestrictionspertainingto
the2-cyclesstudiedbyCardetal.(2013):that“takingawalk”alongthegraph
should have no effect on wages so long as one ends up back at the same firm
| where the | walk | began. |     |     |     |     |
| --------- | ---- | ------ | --- | --- | --- | --- |
It may be helpful here to illustrate this reasoning with a simple thought
experiment. Consider two workers of the same age, both of whom are
employed at firm j in 2010, where they earn the same wage. In subsequent
years,eachworkerswitchesemployerstwicebeforereturningtofirmjin2020.
TheAKMmodelstipulatesthatweshouldexpectthesetwoworkerstoearnthe
same wages in 2020, regardless of the identity of their two intermediate
employers.Indeed,ifourtwotimeperiodswere2010and2020,theseworkers
would be viewed as “stayers” and equation (2) predicts their wage change
| depends | only on | the change | in  | time varying | covariates. |     |
| ------- | ------- | ---------- | --- | ------------ | ----------- | --- |
Mathematically, these cyclic restrictions exhaust the empirical restrictions
of the AKM modelon edge effects withina connected setof firms. That is, if
c = 0
for any cycle in the graph space, then there must exist a set of firm
effects capable of rationalizing the edges exactly. To understand why, recall
that B’s nullspace coincides with the cycle space of the graph, which implies
| we can | decompose | the | edge effects | as  |       |     |
| ------ | --------- | --- | ------------ | --- | ----- | --- |
|        |           |     |              | = B | + C , |     |
where is a vector of coefficients from a linear projection of Δ onto B′, C is
| E    | E   | J 1matrixcollectingthegraph’sfundamentalcycles,and |     |     |     |     |
| ---- | --- | -------------------------------------------------- | --- | --- | --- | --- |
| an × |     | +                                                  |     |     |     | is  |
an E J + 1vector of “cycle effects” that serve as residuals. Plugging this
| decomposition |     | into the | edge effects | model | yields,  |     |
| ------------- | --- | -------- | ------------ | ----- | -------- | --- |
|               |     |          | R =          | EB    | + C + u. |     |
The AKM model amounts to assuming that = 0, in which case = and
ε=u. When there are no cycle effects, then the true dimension of the edge
E
effectsismuchlowerthanitappears:theAKMmodelreducesthe edgesto
| J − 1 linearly |     | independent | firm | effects. |     |     |
| -------------- | --- | ----------- | ---- | -------- | --- | --- |
While E J + 1 = 3 in the graph depicted in Fig. 1,large scale empirical
applications can feature hundreds of thousands (or even millions) of restrictions.
As with any economic or statistical model, these restrictions are unlikely to be

|     |     |     | Firmwageeffects | Chapter | | 2 131 |
| --- | --- | --- | --------------- | --------- | ----- |
satisfiedexactly.Whentherestrictionsdonothold,thefirmeffectscanbethought
of as a linear projection that provides a lower dimensional summary of the edge
effects. We will examine the quality of this summary in Section 3.2.
3.1.2 Estimators
| ˆ = (EE) | 1ER    | E   | × 1vector    |               |     |
| -------- | ------ | --- | ------------ | ------------- | --- |
| Let      | denote | the | of estimated | edge effects. | The |
normal equations defining the least squares estimator of ψ can be written
|     |     | BWˆ | = L , |     |     |
| --- | --- | --- | ----- | --- | --- |
where W = EE is a diagonal weighting matrix recording the number of
workers moving along each edge and L = BWB = (F F ) (F F ) is a
|     |     |     |     | 2 1 2 | 1   |
| --- | --- | --- | --- | ----- | --- |
symmetricJ×JmatrixknowningraphtheoryastheLaplacian.TheLaplacian
encodes information about each’s firm’s role in the mobility network. The jth
row and kth column of L equals the negative of the total number of workers
moving (in either direction) between firms j and k when j≠k, while the jth
diagonalentryofLgivesthetotalnumberofworkersmovingtoorfromfirmj.
Lissingular,whichimpliesthereareaninfinitenumberofsolutionstothe
normal equations. Jochmans and Weidner (2019) study the properties of the
solutionL†BWˆ ,whereL†denotestheMoore-PenroseinverseofL.Iwilltake
a slightly different approach by studying the solution that results when one of
the firms is taken as the “reference firm” with zero firm effect. While both
solutions yield the same predicted edge effects, the reference firm solution is
typically used in practice and happens to also simplify the subsequent theo-
retical analysis. Bozzo (2013) provides some useful results on connections
| between the | two approaches. |     |     |     |     |
| ----------- | --------------- | --- | --- | --- | --- |
Define B as the submatrix leaving out the first row of B and let
(1)
L (11) = B (1) WB (1) denotethesubmatrixofLleavingoutitsfirstrowandcolumn.If
weimposetherestrictionψ =0,thenweobtaintheconstrainednormalequations
1
|     |     | Wˆ    | ,        |     |     |
| --- | --- | ----- | -------- | --- | --- |
|     |     | B (1) | = L (11) |     |     |
(1)
where isψomittingitsfirstentry.Aclassicresultingraphtheory,Kirchhoff’s
(1)
matrix tree theorem, states that any cofactor of the unweighted Laplacian matrix
gives the number of spanning trees in the graph. When the edges are weighted,
generalizationsofthetheorem(e.g.,Spielman,2019,Theorem13.4.1)establishthat
anycofactorofLgivesthetotaledgeweightofthegraph’sspanningtrees,where
the weight of each tree is given by the product of the edge weights it contains. A
connected graph must have at least one spanning tree. Hence, when the mobility
graphisconnected,itfollowsthatdet(L (11) ) > 0,implyingthatL (11) hasfullrank.
The least squares estimator that results from treating the first firm as the
| reference | can therefore | be written |           |     |     |
| --------- | ------------- | ---------- | --------- | --- | --- |
|           |               | ˆ = L      | 1 B Wˆ.   |     |     |
|           |               | (1)        | (11 ) (1) |     | (3) |

132 HandbookofLaborEconomics
Variants of this estimator are heavily used in applied research; however,
computation is typically implemented by iterative conjugate gradient (CG)
(11).5
methods rather than direct inversion of L CG routines are available in
most scientific computing packages including MATLAB and SciPy. The
efficiency of these routines is greatly aided by “preconditioning” the problem
withanapproximateCholeskyfactorizationofL (11).Intheempiricalexamples
below, I rely on the combinatorial multigrid solver package of Koutis et al.
| (2011) | as a preconditioner. |         |     |           |     |     |     |     |
| ------ | -------------------- | ------- | --- | --------- | --- | --- | --- | --- |
| 3.1.3  | Combination          | weights | and | smoothing |     |     |     |     |
Equation (3) reveals that the estimated firm effects are linear combinations of
the average wage changes associated with each edge. In general, the combi-
ˆ
nationweightsaresuchthateachfirmeffectcandependoneachelementof .
For example, when the edges in the graph depicted in Fig. 1 each represent a
| single     | mover, the firm | effect                                       | estimates | can   | be written: |     |     |     |
| ---------- | --------------- | -------------------------------------------- | --------- | ----- | ----------- | --- | --- | --- |
|            |                 |                                              |           | 7 1   | 1           | 5 1 | 1   |     |
|            |                 |                                              |           | 12 12 | 12 12       | 6   | 6   |     |
|            | ˆ               |                                              | ˆ         | 1 1   | 1           | 1   | ˆ.  |     |
|            | = (B            | B) 1B                                        | =         |       |             | 0   | 0   | (4) |
|            | (1) (1)         |                                              | (1)       | 2 2   | 2           | 2   |     |     |
|            |                 |                                              |           | 5 1   | 1           | 7 1 | 1   |     |
|            |                 |                                              |           | 12 12 | 12 12       | 6   | 6   |     |
|            | B c             | = 0                                          |           |       |             |     |     |     |
| Recallthat | (1)             | foranyvectorcinthegraph’scyclespace.Itiseasy |           |       |             |     |     |     |
ˆ
to verify in the above example that perturbing by adding to it any vector
c {c , c , c }yieldsnochangeintheestimatedfirmeffects ˆ .Thiscyclic
|     | 1 2 3 |     |     |     |     |     | (1) |     |
| --- | ----- | --- | --- | --- | --- | --- | --- | --- |
invariance property can be thought as offering a form of robustness to certain
types of confounding trends in the error ε. For example, a trend shared by the
movers traversing edges e 5 and e 6 (i.e., movers between Firms 2 and 4) will
ˆ
“differenceout.”Likewise, isunaffectedbyaddingaconstanttothewage
(1)
changes of the movers traversing each of the edges e , e , and e .6 Adding a
|     |     |     |     |     |     | 2 3 | 5   |     |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
constant to the wage changes of movers on edges e and e while subtracting
|      |                      |     |           |        | 2       | 3   |     |     |
| ---- | -------------------- | --- | --------- | ------ | ------- | --- | --- | --- |
| that | constant from movers |     | on e also | has no | effect. |     |     |     |
5
Whether confounding cyclic trends of this nature tend to be present in
economicdataisaninterestingquestionforfutureresearch.Mobilitycyclesare
commonamongemployersinthesameindustryandregion.Supposetheerrorε
5We have glossed over the issue of how to form R – and consequently ˆ – in the first place.
Typically,oneestimatesthecoefficientvectorβonthetimevaryingcovariatesX inafirststep
it
andsubtractsthemoff.ThisinitialadjustmentstepisalsogreatlyacceleratedwithCGmethods.
6Whenthenumberofmoversdiffersacrossedgesinacycle,thenthemagnitudeofatrendshared
acrossthecycle’sedgeswouldneedtobeinverselyproportionaltothenumberofmoversalong
eachedgeinordertodifferenceout.Thatis,thefirmeffectestimatesbecomeinvarianttoper-
turbing ˆ inthedirectionW−1cwherecisavectorinthecyclespace.However,fittingtheAKM
modeldirectlytotheedgeeffectsbyunweightedleastsquares(i.e.,settingW=Iinestimation)
restoresinvariancetocyclespecifictrends.

Firmwageeffects Chapter | 2 133
takes the form ε=Cη+u where η is a vector of cycle effects driven by
demand shocks to those industry-regions. Though this error structure violates
the AKM edge restrictions, unweighted firm effect estimates remain unbiased
because(B
(1)
B) 1B
(1)
ˆ = + (B
(1)
B) 1B
(1)
u.
An important simplification of (3) arises in the case where the mobility
graph is a tree. By definition, a tree has J vertices and J − 1 edges, which
implies the submatrix B (1) is square. Recall that L (11) = B (1) WB. Since L (11)
has full rank, B (1) must also have full rank. Hence, we can write:
ˆ = (B WB) 1B Wˆ = (B ) 1W 1B 1B Wˆ = (B ) 1ˆ.
(1) (1) (1) (1) (1) (1) (1)
The predicted edge effects implied by the estimated firm effects are given by
B ˆ = ˆ , indicating that the firm effects rationalize the adjusted wage
(1) (1)
ˆ
changes with no error. This phenomenon reflects that the firm effects are
just-identified by (i.e., “they saturate”) the edge specific wage changes.
Consider the spanning tree depicted in Fig. 1, which is comprised of the
graph’s first three edges. The B associated with this tree and its inverse are
(1)
depicted below:
1 0 0 1 0 0
B = 1 1 0 , (B ) 1 = 1 1 0 .
(1) (1)
0 1 1 1 1 1
In any spanning tree, one can always ensure that (B ) 1 is triangular by
(1)
ordering the edges of B (1) according to their distance from Firm 1. However,
some of the entries in such a triangle may possess a negative sign if reaching
the reference firm requires traversing an edge in reverse.7 The triangular
structure of (B ) 1 ensures that each firm effect is simply the sum of the
(1)
(oriented) edge effects on the path connecting it to the reference firm. Con-
sequently, the difference in firm effect estimates for any two firms j and k
connected by an edge must equal the average wage change of the workers
movingdirectlybetweenthem.Wewillreturntothispropertywhendiscussing
causal interpretations of firm effects.
A closely related property can be shown to hold when the graph is a
polytree, meaning that the undirected graph is a tree but some firm pairs may
be connected by edges in both directions. For example, adding an edge from
Firm4toFirm3tothespanningtreedepictedinFig.1yieldsapolytree.Any
polytreecanbetransformedintoasimpletreebytransferringtheweightfrom
one edge to the other in each pair of edges connecting the same firms. This
7For example, choosing Firm 3 as the reference in this spanning tree yields
1 1 0
(B (3) ) 1= 0 1 0 .
0 0 1

134 HandbookofLaborEconomics
transformation can be represented by an E × J 1matrix T that differences
the relevant edge pairs in the incidence matrix. For example,
|     | 1 0 | 0 0 1 | 0 0 | 1 0 | 0   |
| --- | --- | ----- | --- | --- | --- |
|     | 1 1 | 0 0 0 | 1 0 | 1 1 | 0   |
|     |     |       | =   |     | .   |
|     | 0 1 | 1 1 0 | 0 1 | 0 1 | 2   |
|     | 0 0 | 1 1 0 | 0 1 | 0 0 | 2   |
|     | B   |       | T   |     |     |
Remarkably, the firm effect estimates are invariant to such transformations.
Specifically, when B represents a polytree, the least squares weights for the
| transformed | graph | (B WTT WB | ) 1B WTT W | equal | the weights |
| ----------- | ----- | --------- | ---------- | ----- | ----------- |
|             |       | (1)       | (1) (1)    |       |             |
L 1 B W for the untransformed graph.8 Since B WT is a square invertible
| (11 ) (1) |     |     | (1) |     |     |
| --------- | --- | --- | --- | --- | --- |
matrix representing a simple tree, the firm effects derived from fitting the
|           |               |                  |            | (TWB | ) 1T Wˆ |
| --------- | ------------- | ---------------- | ---------- | ---- | ------- |
| AKM model | to a polytree | can equivalently | be written |      | (1) .   |
Consequently,inanypolytree,thedifferenceinestimatedfirmeffectsbetween
anypairoffirmsjoinedbyapairofedgeswillequalamoverweightedaverage
of the two oriented edge effects connecting them. As in a simple tree, the
difference in firm effects for any pair of firms joined by a single edge will
| depend only | on that estimated | edge | effect. |     |     |
| ----------- | ----------------- | ---- | ------- | --- | --- |
When the graph is not a tree, the firm effects become over-identified and
|            |              |              | ˜   | B ˆ     | = Hˆ, |
| ---------- | ------------ | ------------ | --- | ------- | ----- |
| the vector | of predicted | wage changes | is  | (1) (1) | where |
1
H = B L B W isan E × E weightedprojectionmatrixthatisinvariant
| (1) | (11 ) (1) |     |     |     |     |
| --- | --------- | --- | --- | --- | --- |
to the choice of reference firm. Like the usual “hat” matrix (Hoaglin and
Welsch, 1978), H’s diagonal entries {h } [E] give the leverage of each
observation (in this case each edge effect) on the predicted value. One can
| write the | ℓ’th leverage: |     |           |     |     |
| --------- | -------------- | --- | --------- | --- | --- |
|           |                | h = | bL 1b n , |     |     |
(11)
where b is the ℓ’th column of B and n is the ℓ’th diagonal entry of W. In
| ℓ   |     | (1) | ℓ   |     |     |
| --- | --- | --- | --- | --- | --- |
large systems, costly inversion of L (11) can be avoided by breaking compu-
tation into a CG step that solves a linear system and a subsequent matrix
|     | step.9 |     |     | [0, 1], |     |
| --- | ------ | --- | --- | ------- | --- |
multiplication Leverages lie in the interval with larger values
indicatingthatdroppingthatedgefromthedatawouldleadtoagreaterchange
in the estimated firm effects. Any edge that is part of a cycle has h < 1. An
ℓℓ
8The transformation T maps the edges back into the span of the weighted incidence matrix,
implying the weighted orthogonality condition TW(I B L 1 B W)=0. Expanding this
|     |     |     | (1) | (11 ) (1) |     |
| --- | --- | --- | --- | --------- | --- |
condition yields TW=TWB L 1 B W. Premultiplying by B WT gives
|     |     | (1) (11 ) | (1) |     | (1) |
| --- | --- | --------- | --- | --- | --- |
B WTTW=B WTTWB L 1 B W. Dividing both sides by B WTTWB yields the
| (1) | (1) | (1) (11 ) (1) |     | (1) | (1) |
| --- | --- | ------------- | --- | --- | --- |
result.
9Notethatwecanrewritetheℓ’thleverageh =bz ,wherez =L 1 b n .Thefirststepsolves
(11 )
the equation L z =b n for the vector z via CG methods. The second step computes
|     | (11) |     | ℓ   |     |     |
| --- | ---- | --- | --- | --- | --- |
h =bz byvectormultiplication.Thisprocesscanbeparallelizedacrossedgestorecoverallof
theleverages.

|     |     |     | Firmwageeffects | Chapter | | 2 135 |
| --- | --- | --- | --------------- | --------- | ----- |
edgewithh =1isknownasabridge.Droppingabridgebreaksthegraphinto
ℓℓ
twoormoreconnectedcomponents,in whichcaseatleastonefirmeffectcan
| no longer | be estimated. |     |     |     |     |
| --------- | ------------- | --- | --- | --- | --- |
Whenthegraphisatree,alledgesarebridgesandHistheidentitymatrix.
However, when the graph exhibits cycles, H departs from identity and some
“smoothing” across edges takes place. The rows of H give the smoothing
weightsusedtoformthepredictionforeachedge.Eachrow’sweightssumto
onebuttheentriescanbenegative.Forexample,ifweassumeasinglemover
traverseseachedgeofthegraphdepictedinFig.1thenthehatmatrixtakesthe
| following | form: |       |         |     |     |
| --------- | ----- | ----- | ------- | --- | --- |
|           |       | 7     | 1 1 5   | 1 1 |     |
|           |       | 12 12 | 12 12   | 6 6 |     |
|           |       | 1 7   | 5 1 1   | 1   |     |
|           |       | 12 12 | 12 12 6 | 6   |     |
|           |       | 1     | 5 7 1 1 | 1   |     |
|           |       | 12 12 | 12 12 6 | 6   |     |
H =
|     |     | 5 1   | 1 7 1   | 1   |     |
| --- | --- | ----- | ------- | --- | --- |
|     |     | 12 12 | 12 12 6 | 6   |     |
|     |     | 1 1   | 1 1 1   | 1   |     |
|     |     | 6 6   | 6 6 3   | 3   |     |
|     |     | 1     | 1 1 1   | 1 1 |     |
|     |     | 6     | 6 6 6   | 3 3 |     |
InheritingthepropertiesofB (1),thesesmoothingweightsareorthogonalto
any vector in the cycle space but are otherwise widely dispersed across the
edges. Placing weight on edges throughout the network is efficient when the
˜
AKMmodelrestrictionshold.Otherwise, mayprovideapoorestimateofΔ.
| 3.2 Evaluating | the | AKM restrictions |     |     |     |
| -------------- | --- | ---------------- | --- | --- | --- |
To evaluate whether the AKM model provides an accurate summary of the
wage changes associated with (directed) moves between firm pairs, we study
two years of the Veneto Workers History (VHW) data. This dataset has
emerged as a popular benchmark in the literature due to the low barriers
associatedwithobtainingaccesstoit.10Weworkwithanextractof1,859,459
person-year observations from the years 1999 and 2001 that was studied pre-
viouslybyKlineetal.(2020).Thelargestconnectedsetcontains73,933firms
and 747, 205 workers, 197, 572 of whom switch employers between the two
years. These 197, 572 “movers” are spread across 150, 417 edges. Hence, the
| AKM model | implies | 76, 485 restrictions | on the edge | effects. |     |
| --------- | ------- | -------------------- | ----------- | -------- | --- |
TheAKMmodelisfittothelogdailywagechangesofworkersbysolving
the normal equations using MATLAB’s preconditioned conjugate gradient
routine. The only time varying covariate included is an indicator for the year
10The data can be requested at https://www.frdb.org/en/dati/dati-inps-carriere-lavorative-in-
veneto/.

136 HandbookofLaborEconomics
being 2001. Job stayers contribute to the firm effect estimates only indirectly
ˆ
viaestimationoftheyearfixedeffect .Weusethissameyeareffectestimate
ˆ
topreadjustwagechangesbeforecollapsingthemtoestimatededgeeffects .
3.2.1 Visualizing goodness of fit
Fig. 2 summarizes how the conditional distribution of estimated edge effects
varieswiththeAKMpredictions.Eachdotdepictsthemeanedgeeffectwithin
a bin of predicted edge
effects(˜).
The bands around the dots give a sense of
dispersion within each bin: the upper limit of each band gives the 75th per-
centileofestimatededgeeffectsinthatbin,whilethelowerlimitgivesthe25th
percentile.
TheAKMmodelstipulatesthat,intheabsenceofnoise,thedotsshouldall
lie on the dashed 45 degree line. On average, the edge effects do tend to lie
remarkably close to the 45 degree line. Moreover, the bands around the dots
revealonlymodestdispersionaroundtheaverages.However,theAKMmodel
was fit to the same data as the edge effects, which induces a mechanical
dependencebetweenthetwosetsofestimates.Indeed,ifthegraphhadbeena
tree, the edge predictions would all lie exactly on the 45 degree line.
Loopingoveredgestocomputethe leverages{h } [E] revealsthat about
22%oftheedgesarebridgesthatmustmechanicallylieonthe45degreeline.
Roughly 44% of the firm effects are just-identified by one of these bridges.
Dropping the bridges leaves 117,657 edges with h < 1 that connect 41,195
ℓℓ
firms. The x’s in Fig. 2 depict the mean predictions in this subpopulation,
whichstilltrackthe45degreelineclosely.However,theinterquartilerangeof
deviationsisamplified.Toevaluatewhetherthesedeviationsarelargerthanwe
should expect under the AKM model requires accounting for noise in the
estimated edge effects.
3.2.2 Accounting for noise
Thenoiseintheedgeeffectsthatconcernsusderivesfromthevectoruofwage
change errors. One can think of these errors as capturing the idea that if a
different worker happened to traverse the same edge, a different wage change
would likely result. In what follows, I will use the expectation and variance
operators u [] and u [] to convey that integration is ultimately being con-
ducted with respect to the edge effects error u introduced in Section 3.1.1.
Hence, the expected value of the AKM prediction is [˜] = H
u
and the variance matrix of the estimated edge effects is
u
[ˆ] = (EE) 1E [uu]E(EE) 1.
Denote the vector of differences between the predicted and estimated
edge fixed effects by ˆ ˜ = Mˆ , where M = (I H) is the “residual
ˆ ˆ ˜ ˜
maker” matrix.Let denote the ℓ’th entryof and theℓ’th entryof .
A standard goodness of fit statistic is the sum of squared residuals.
We will work with a mover-weighted version of this statistic:

|     |     |     |     | Firmwageeffects |     | Chapter | | 2 137 |
| --- | --- | --- | --- | --------------- | --- | ------- | ------- |
FIG.2 Logdailywagechangeofedge(ˆ)versusAKMprediction(˜).Notes:Theverticalaxis
ˆ
depicts binned averages of the elements of : the average adjusted log daily wage changes
associatedwitheachorigin-destinationfirmedge.Thehorizontalaxisgivesbinsof ˜:thewage
changepredictedbytheleastsquaresestimatesoffirmeffects.Panelcomprisedofthe1999and
2001 waves of the Veneto Work Histories dataset developed by the Economics Department in
UniversitaCa’FoscariVeneziaunderthesupervisionofGiuseppeTattara.
| n (ˆ | ˜ )2 = (ˆ | ˜) W(ˆ | ˜)  | = ˆ M | WMˆ | .11 So long | as the |
| ---- | --------- | ------ | --- | ----- | --- | ----------- | ------ |
wagechangeerrorshavefinitevariance,wecanwritetheexpectationofthis
sum as
|     | [ˆ M WMˆ] | =   | M WM | + trace(M |     | WM [ˆ]). |     |
| --- | --------- | --- | ---- | --------- | --- | -------- | --- |
|     | u         |     |      |           |     | u        |     |
squared bias
noise
| The AKM | model | stipulates |     | that | MΔ=0, | which | implies |
| ------- | ----- | ---------- | --- | ---- | ----- | ----- | ------- |
[˜
| M WM | = n ( |     | ])2 = | 0. However, |     | the model | doesn’t |
| ---- | ----- | --- | ----- | ----------- | --- | --------- | ------- |
u
restrictthe traceterm,whichcapturestheexpectedcontribution ofnoise.If
[ˆ]
the wage change errors are independent across movers, then is a
u
| diagonal | matrix and the | trace | expression | simplifies |     | to   |     |
| -------- | -------------- | ----- | ---------- | ---------- | --- | ---- | --- |
|          |                | [ˆ])  |            |            |     | [ˆ   |     |
|          | trace(M        | WM    | =          | n (1       | h   | ) ], |     |
|          |                | u     |            |            |     | u    |     |
[E]
where [ˆ ]is the ℓth diagonal entry of [ˆ]. This formula captures the
| u   |     |     |     | u   |     |     |     |
| --- | --- | --- | --- | --- | --- | --- | --- |
intuition that high leverage edges are expected to yield smaller residuals
11Theresidualmakermatrixwillnot,ingeneral,besymmetricwhenthenumberofmoversvaries
across edges. Fortunately, MWM=WM for any distribution of mover weights, which sig-
nificantlysimplifiesthecalculationsbelow.

138 HandbookofLaborEconomics
[ˆ ]
because of overfitting. Conversely, edges with higher noise levels u
| should yield | larger | squared | residuals. |     |     |     |     |
| ------------ | ------ | ------- | ---------- | --- | --- | --- | --- |
For edges with more than a single mover, a simple unbiased estimator of
| [ˆ ]is |            |             |          |        | [ˆ ] = | 1s2, |                  |
| ------ | ---------- | ----------- | -------- | ------ | ------ | ---- | ---------------- |
| u      | available: | the squared | standard | error, | u      |      | where s ℓ is the |
n
standard deviation of adjusted wage changes along edge ℓ. Reflecting the
sparsity of the mobility network, only 9,459 of the edges that are not bridges
have 2 or more movers. Denote this set of edges by 2+ . Combining the
leverages with the edge specific standard errors yields an expected sum of
squared residuals under the null hypothesis that the AKM model holds of
[ˆ
| n                                       | (1 h | )   | ] = 207.58. |     |     |      |              |
| --------------------------------------- | ---- | --- | ----------- | --- | --- | ---- | ------------ |
| 2 +                                     |      | u   |             |     |     |      |              |
| E m pirically,theresidualsumofsquaresis |      |     |             |     | n   | (ˆ ˜ | )2 = 360.51. |
2+
Thedifference,360.51–207.58=152.92,betweentheactualandexpectedsum
ofsquaresprovidesanunbiasedestimateofthesumofsquaredapproximation
|         | n   | (   | [˜ ])2. |                   |     |           |            |
| ------- | --- | --- | ------- | ----------------- | --- | --------- | ---------- |
| errors: |     |     | u A     | natural benchmark |     | for these | approxima- |
|         | 2+  |     |         |                   |     |           | 2,         |
tion errors is the (mover-weighted) sum of squared edge effects n
2+
|                             |     |     |     | (ˆ2 | [ˆ  |                   |     |
| --------------------------- | --- | --- | --- | --- | --- | ----------------- | --- |
| anunbiasedestimateofwhichis |     |     |     | n   | ])  | = 978.67.Theratio |     |
|                             |     |     |     | 2+  | u   |                   |     |
ofthesetwonumberscanbethoughtofasoneminusthe(uncentered)R2from
an infeasible mover-weighted regression of the true edge effects in{ }
2+
ontothematrixoffirstdifferencedfirmdummies.12Hence,thedatasuggestthe
AKM approximation captures roughly (1 152.92/978.67) × 100 84% of
the variation in true edge effects. Equivalently, the estimated correlation
| between | the edge | effects | and the AKM | predictions | is 0.92. |     |     |
| ------- | -------- | ------- | ----------- | ----------- | -------- | --- | --- |
Of course, this R2 estimate is itself subject to sampling uncertainty and
applies only to a particularpopulation ofedges. Table1 repeats this goodness
R2
of fit exercise restricting to edges with more movers. The estimates are
remarkably stable, suggesting that these findings are unlikely to be an artifact
ofnoise.Thefinalcolumnofthetablereportsthesquarerootofthenoiselevel
within edges due to irreducible uncertainty across movers. Depending on the
sampleofedgesconsidered,theaveragenoiselevelisfourtofivetimesgreater
| than the | average | squared | model error. |     |     |     |     |
| -------- | ------- | ------- | ------------ | --- | --- | --- | --- |
ThetworowsinthesecondpanelofTable1imputethenoiselevelsofthe
edgeswithasinglemoverandrecomputetherelevantquadraticformsoverall
edges that are not bridges. The first of these rows sets the noise level of the
singleton edges equal to twice the average noise level of edges with exactly 2
movers,animputationthatwouldbevalidunderhomoscedasticity.Thesecond
row relaxes the homoscedasticity assumption by allowing an arbitrary linear
relationship between the log of the average noise level and the log of the
numberofmovers.Thislinearrelationship,estimatesofwhicharedepictedin
Appendix Fig. A.1, fits the data well and suggests slightly higher noise levels
12ThecenteredR2isnearlyidenticalbecausethemeanedgeeffectinthe 2+sampleis0.01and
themeanAKMpredictioninthissampleis0.01.Inthebroadersampleof117,657edgesthatare
notbridges,themeanedgeeffectis0.001andthemeanAKMpredictionis0.005.

ssorcasrevomforebmuneht ybnevigsi”stceffeegdederauqsnaemtooR“.}] worehT.] yltcaxehtiwsegdefororredradnatsderauqsegarevaehteciwtsarevomelgnisahtiwegdehcaerof] gnomanoissergerraenilanopudesabrevomelgnisahtiwsegdefolevelesionehtetupmi”noissergergol-golaivdetupmiesionnotelgniS“delebalsworehT.srevomowt -nondnasegdirbrofyletarapesdetcudnocsnoitatupmI.srevomforebmunehtfogolehtdnatpecretninatsniagalevelesionegarevaehtfogolehtfosrevom01-2htiwsegde
naemtooR levelesion
| 421.0 290.0 670.0 | 591.0 402.0 | 002.0 |
| ----------------- | ----------- | ----- |
ˆ[u
n
| 73.48 85.78 59.78 | 58.17 68.37 | 83.18 |
| ----------------- | ----------- | ----- |
1
2R fotoorerauqsehtseviglevelesionnaemtooR.seititnauqowtesehtfooitarehtfoerauqsehtsi2RehT.)]
n
=
| egdederauqs |     | dnanoitaredisnocrednusegdefotesehtetoned |
| ----------- | --- | ---------------------------------------- |
naemtooR
| tceffe 041.0 711.0 901.0 | 522.0 912.0 | 232.0 |
| ------------------------ | ----------- | ----- |
ˆ[u
)
h
1(
2)
| ledomderauqs |     | ˜   |
| ------------ | --- | --- |
naemtooR
ˆ({
| rorre 550.0 140.0 830.0 | 911.0 211.0 | 001.0 |
| ----------------------- | ----------- | ----- |
n
1
fotoorerauqsehtsadetupmocsi”rorreledomderauqsnaemtoor“eht,segdehcus
gnitteL.segdirbtoneratahtsegdefodesirpmoceratsalehttubselpmasllA:setoN
rebmuN segdefo
|                | 756,711 756,711 | 714,051 |
| -------------- | --------------- | ------- |
| 9549 6583 7842 |                 | ˆ[u     |
setupmi”srevom2/wsegdeeciwtlevelesionnotelgniS“delebal
.elpmasegde
srevomfo
| rebmuN               | 254,851 254,851 | 275,791 |
| -------------------- | --------------- | ------- |
| 452,05 840,93 149,43 |                 |         |
ybtiffo ˆ[u
2ˆ(
srevom2/wsegdeeciwt
| ssendooG | detupmiesionnotelgniS | detupmiesionnotelgniS |
| -------- | --------------------- | --------------------- |
n
|                                              | levelesionnotelgniS noissergergol-golaiv | noissergergol-golaiv |
| -------------------------------------------- | ---------------------------------------- | -------------------- |
| srevom2tsaeltA srevom3tsaeltA srevom4tsaeltA |                                          | segdirbgnidulcnI     |
revom1tsaeltA 1
fotoorerauqseht
1ELBAT
elpmaS
.segdirb

140 HandbookofLaborEconomics
for the singleton edges. Under both imputations, the R2 falls modestly to just
above 70%.
Finally, recall that nearly half of the firm effects are just-identified by a
bridge, contributing no model error at all to the edge predictions. Applying a
corresponding linear imputation of singleton noise levels to the bridges
(depicted in Appendix Fig. A.1) yields an estimated sum of squared edge
effects across all edges 15 = 0 1 ,417n (ˆ2 u [ˆ ]) of roughly 10, 671. Hence,
the estimated R2 from an infeasible regressionof all edge effects(inclusive of
bridges) onto the first differenced firm dummies evaluates to
[1 (0.112)2 × 158, 452/10, 671] × 100 81%.
In sum, the AKM model provides a highly informative (albeit imperfect)
summary of the expected wage effects of worker mobility. If we were using firm
effect estimates to predict the wage changes associated with worker moves, these
findings suggest that noise would be a greater hindrance than model error. The
model errors that are present result from cycles in the mobility network among a
highly concentrated subset of firms. One interpretation of these errors is that they
reflectheterogeneityinthefirmeffectsfacedbydifferentsortsofworkers.Wenow
turntothinkingabouttheconditionsunderwhichtheestimatedAKMfirmeffects
retain a causal interpretationin thepresence ofsuch heterogeneous effects.
3.3 Causality
The AKM model bears a strong resemblance to a difference in differences
specification with J treatment arms where firm effect differences ψ −ψ
j k
represent average treatment effects and the exogenous mobility assumption
ensures “parallel trends.” It is natural then to ask whether least squares esti-
mation of (1) can identify causal effects under non-parametric restrictions on
potential outcomes and worker firm assignments. I will begin with the ante-
cedent task of finding conditions under which the edge effects introduced in
Section3.1.1 can begiven a causalinterpretation. Toeaseexposition, we will
again confine attention to the case where T=2 and ignore time varying cov-
ariates,whichcanbethoughtofashavingbeenadjustedforinapreviousstep.
Let Y it (d 1 , d 2 ) denote the potential log wage of worker i in year t who
works at firm d 1 [J] in period 1 and d 2 [J] in period 2. To mimic
conventionaltreatmenteffectsnotation,IwillusethesymbolD
it
= j(i, t)to
denote the firm employing worker i in period t. We now state three
assumptions that endow the average wage changes of workers switching
employers between the two periods with a causal interpretation. Our first
assumption is an exclusion restriction:
Assumption 1. (Exclusion).Y it (d 1 , d 2 ) = Y it (d t ) fort {1, 2}.
This assumption rules out the possibility that past or future firm assign-
ments affect wages. Assumption 1 is violated in sequential auction models
(Postel-Vinay and Robin, 2002b; Cahuc et al., 2006), which posit that hiring

|     |     |     |     | Firmwageeffects |     | Chapter | | 2 141 |
| --- | --- | --- | --- | --------------- | --- | ------- | ------- |
wagesareinfluencedbythefirmfromwhichaworkerwaspoached.However,
Di Addario et al. (2023) find in Italian data that past employers exhibit a
negligible influence on hiring wages outside of the law and banking sectors,
suggestingthisassumptionislikelytoprovideareasonableapproximationfor
most workers. When Assumption 1 holds, we can link observed wages to
| potential | wages via | the relationY | =   | Y (D ). |     |     |     |
| --------- | --------- | ------------- | --- | ------- | --- | --- | --- |
it it it
The next assumption mimics the parallel trends assumption of standard
| difference | in differences | models:  |     |     |           |           |       |
| ---------- | -------------- | -------- | --- | --- | --------- | --------- | ----- |
|            |                |          | [Y  | (j) | Y (j) D = | j, D = k] | = 0 k |
| Assumption | 2 (Parallel    | trends). |     | i2  | i1 i1     | i2        |       |
j [J]2.
Assumption 2 states that, among workers switching between any pair of
firms,theaveragepotentialwagesattheiroriginfirmswouldnothavechanged
between periods. As noted earlier, we should think of Y here as pre-adjusted
it
foryearandage/experienceeffects,inwhichcasethisamountstoarestriction
thatpotentialoriginanddestinationwagesexhibitacommontimetrend.Card
et al. (2013) reported event study plots of the average earnings trajectories of
workerswhotransitionedbetweengroupsoffirmscharacterizedbytheirleave-
out wage quartile. These plots, which are now a standard diagnostic, indicate
thatworkersmovingtohighwagefirmsdonotexperiencefasterwagegrowth
before moving, nordoes theirwage trendchange upon moving to a new firm,
suggesting that Assumption 2 provides a reasonable approximation.
Finally, we make a stationarity assumption on average treatment effects
| among | firm switchers: |     |     |     |     |     |     |
| ----- | --------------- | --- | --- | --- | --- | --- | --- |
Assumption 3 (Stationarity). [Y (k) Y (j) D = j, D = k] = [Y (k)
|     |     |     | i1  | i1  | i1  | i2  | i2  |
| --- | --- | --- | --- | --- | --- | --- | --- |
[J]2.
| Y i2 (j) D | i1 = j, D i2 | = k] jk | , k | j   |     |     |     |
| ---------- | ------------ | ------- | --- | --- | --- | --- | --- |
In a mild abuse of our earlier notation for edge effects, this last condition
Δ
simply ensures that the average treatment effect jk of moving from firm j to
firm k among those who make this transition is not time dependent. The
plausibilityofAssumption3will,ofcourse,dependonthenatureandlengthof
the sample period under consideration. Lachowska et al. (2023) and Engbom
et al. (2023) provide empirical evidence that firm effects are quite stable over
the five to seven year horizons typically studied in the literature.
The following proposition establishes that when these conditions are
satisfied worker moves between pairs of firms identify average treatment
| effects on | the wages | of movers. |     |     |     |     |     |
| ---------- | --------- | ---------- | --- | --- | --- | --- | --- |
Proposition 1 (Firm switches identify average treatment effects on movers).
| If Assumptions | 1,  | 2, and 3 hold, | then, |        |        |     |     |
| -------------- | --- | -------------- | ----- | ------ | ------ | --- | --- |
|                |     | [Y             | Y D   | = j, D | = k] = | .   |     |
|                |     | i2             | i1 i1 | i2     |        | jk  |     |

142 HandbookofLaborEconomics
Proof. The assumptions used in each step of the below proof are listed above
the equals sign:
A1
[Y Y D =j, D =k] = [Y (k) Y (j) D =j, D =k]
i2 i1 i1 i2 i2 i1 i1 i2
= [Y (k) Y (j)+ Y (j) Y (j) D =j, D =k]
i2 i2 i2 i1 i1 i2
A2
= [Y (k) Y (j) D =j,D =k]
i2 i2 i1 i2
A3
= jk . □
Hence, contrasts of the form in (2) can identify causal estimands under
plausible assumptions even if firm effects are heterogeneous. In particular,
onedoesnotneedtheprocessdeterminingwagestobeadditivelyseparable
in unobserved worker and firm heterogeneity for these assumptions to
hold.
While Proposition 1 endows the mean wage changes accompanying firm
switches with a causal interpretation, these average causal effects are not
sufficient to order firms in terms of their average wage levels. The Δ
jk
represent average treatment effects for a potentially highly selected group of
movers between firm j and firm k. Without further assumptions, this hetero-
geneity undermines our ability to rank the potential wages offered by firms
because wage changes may be intransitive. For example, with three firms, we
could have Δ > 0, Δ > 0, Δ < 0 because the workers who move
12 23 13
betweenFirm1andFirm3aredifferentfromthosewhomovebetweenFirm2
and Firm 3 or Firm 1 and Firm 2.13 Proposition 1 does not even rule out the
possibility that wage changes between firm pairs are asymmetric – i.e., that
sign( jk ) = sign( kj ) – which is also a form of intransitivity.
3.3.1 Indirect contrasts and spanning trees
The AKM model enforces transitivity by imposing that Δ =ψ −ψ. We
jk k j
discussed in Section 3.1 how this assumption implies restrictions on edges
formingacycle.Forexample,ifworkersmovefromFirm1toFirm2,Firm2to
Firm 3, and Firm 3 to Firm 1, then the AKM model requires that Δ +Δ
12 23
+Δ =0. When cyclic restrictions of this nature are violated, least squares
31
estimation of (1) is not guaranteed to provide firm effect estimates that, when
contrasted,yieldaconvexweightedaverageoftreatmenteffects.Thisdifficulty
is familiar from both the difference in differences literature and recent work on
least squares estimation in environments with multiple treatment arms
(Goldsmith-Pinkhametal.,2022).Asinthosesettings,theproblememerges,in
part, from imposing over-identifying restrictions that are violated empirically.
Unlike in randomized experiments, however, interpretation problems persist
13Patterns of thisnature are familiar from the social choice literature, where pairwise elections
have long been observed to exhibit intransitivities in the form of Condorcet (1785) cycles.
Young(1995)providesanaccessibleintroductiontothegraphtheoreticinterpretationofthese
cycles.

|     |     |     |     |     | Firmwageeffects |     | Chapter | |   | 2 143 |
| --- | --- | --- | --- | --- | --------------- | --- | ------- | --- | ----- |
evenwhenwesaturatethemodelbecausethecausalcontrastsunderstudy(i.e.,
the “edge effects”) pertain to potentially non-comparable populations.
ItwasalreadymentionedinSection3.1.3thatthefirmeffectestimatesare,
in general, a linear combination of all of the edge specific wage changes. The
combination weights need not sum to one in each row and can be negative.
Thesenegativeentriesdonotimmediatelyundermineacausalinterpretationof
thefirmeffectestimatesbecausetheedgeeffectsaredirected.Returningtothe
graphdepictedinFig.1,inthecasewhereasinglemoverispresentalongeach
edge, equation (4) implies that Firm 2′s fixed effect estimate can be written:
|     | 7      |     | 3   | 1     |          |       | 2       |     |      |
| --- | ------ | --- | --- | ----- | -------- | ----- | ------- | --- | ---- |
|     | ˆ =    | ˆ + | ˆ   | + (2ˆ | ˆ        | ˆ ) + | (ˆ      | ˆ ) |      |
|     | 2      | 12  | 14  | 14    | 23       | 34    | 42      | 24  |      |
|     | 12     |     | 12  | 12    |          | 12    |         |     |      |
|     | direct |     |     |       | indirect |       |         |     |      |
|     |        | 5   |     |       |          | 2     |         |     |      |
|     | = ˆ    | +   | (ˆ  | ˆ ˆ   | ˆ ) +    | (2ˆ   | +2ˆ     | + ˆ | ˆ ). |
|     | 12     |     | 14  | 12 23 | 34       | 23    | 34      | 42  | 24   |
|     |        | 12  |     |       |          | 12    |         |     |      |
|     | direct |     |     | cˆ    |          |       | (c2+c3) | ˆ   |      |
ˆ
With the first firm effect normalized to zero, it is natural for to place
2
substantialweighton ˆ 12,whichoffersadirectcontrastofthewagesatFirm1
andFirm2forawell-definedsubpopulationofmovers.Fromthefirstline,we
ˆ
see a weight of 7/12 is placed on 12. However, indirect contrasts measuring
the effects of moving between other pairs of firms also contribute to ˆ , an
2
example of what Goldsmith-Pinkham et al. (2022) term “contamination.” The
combination weights in this representation sum to 13/12, revealing that ˆ
2
cannotbewrittenasaconvexweightedaverageofdirectandindirectcontrasts.
Under the AKM model, the indirect contrasts contain additional information
aboutΔ .Toseethis,notefromthesecondlinethatbyrearrangingterms,wecan
12
ˆ
write thefirmeffect asthedirectcontrast 12 plustwo termsthat havemeanzero
under the AKM model because they correspond to cycles. With independent and
ˆ
identically distributed errors, adding these terms cuts the variance of 2 in half,
whichcanbeverifiedbysummingthesquaresofthecoefficientsmultiplyingeach
edge effect in the first line. However, with unrestricted selection into edges and
treatmenteffectheterogeneity,theseindirectcontrastsneednotbeinformativeabout
any individual’scausal effect ofmoving from Firm 1 to Firm 2.
Indirect contrasts can be avoided by pruning the mobility network to a
polytree. As discussed in Section 3.1.3, pruning the graph in Fig. 1 to its first
| three | edges | yields | estimates | taking | the form |     |     |     |     |
| ----- | ----- | ------ | --------- | ------ | -------- | --- | --- | --- | --- |
ˆ
ˆ
|     |     |     |     | 2   | 1 0 0 | 12  |     |     |     |
| --- | --- | --- | --- | --- | ----- | --- | --- | --- | --- |
|     |     |     |     | ˆ = | 1 1 0 | ˆ . |     |     |     |
|     |     |     |     | 3   |       | 23  |     |     |     |
|     |     |     |     | ˆ   | 1 1 1 | ˆ   |     |     |     |
34
4
|     |     |     |     |     | B 1 |     |     |     |     |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
(1)
Importantly, this representation holds no matter how many workers traverse
ˆ
each edge. Here, each firm effect is a simple sum of contrasts jk, which
provides a causal interpretation to the difference in estimated firm effects

144 HandbookofLaborEconomics
between any two firms that share an edge. For example ˆ
3
ˆ
2
= ˆ 23.
However, the interpretation of differences in estimated firm effects between
firms that do not share in edge is murky.
For example, the estimator ˆ 4 = ˆ 12 + ˆ 23 + ˆ 34 is not guaranteed to
reveal anything about the relative wage levels of Firm 4 and Firm 1.
Fundamentally,withoutmovesfromFirm4toFirm1(whichwouldintroduce
a cycle into the graph) there is no information in the data directly revealing
these firms’ relative wage levels for any given individual. For the wage
changes of the workers moving between Firms 1 and 2 to even reveal the
expectedsignofthewagechangeassociatedwithmovingfromFirm1toFirm
4, we need a transitivity restriction: e.g., that for any three firms
(j, k, m) [J]3, Δ > 0, Δ > 0 ⇒ Δ > 0.
jk km jm
Ensuring transitivity requires either restricting the treatment effect hetero-
geneity or restricting selection. We will follow the tradition in the treatment
effectsliteratureofavoidingrestrictionsontheoutcomeequationandexamine
a restriction on selection that not only ensures a stable ordering of firms but
allows cardinal comparison of firm wage levels.
3.3.2 Restricting selection
The following exogeneity assumption ensures comparability of firm wage
levels based upon moves by assuming away selection on treatment effects:
Assumption 4 (No selection on treatment effects). Y i2 (k) Y i2 (j) D i1 , D i2
k j [J]2.
Importantly,Assumption4permitsmobilitydecisionstoberelatedtoaverage
treatmenteffects [Y i2 (k) Y i2 (j)].Forexample,workerscangravitatetowards
high wage firms as in the Burdett and Mortensen (1998) model. However, this
assumptionprohibitsselectionon“match”componentsofwagesasarisesinmany
models with comparative advantage (e.g., Gibbons et al., 2005; Eeckhout and
Kircher, 2011; Haanwinckel, 2023; Gottfries and Jarosch, 2023).
When Assumption 4 does hold, worker mobility identifies unconditional
average treatment effects. These average treatment effects necessarily obey
transitivity because they pertain to the same population, allowing firm wage
levels to be ranked on a common scale. Hence, we can write
jk = [Y i2 (k) Y i2 (j)] = k j , in which case least squares estimation of
(1) identifies pairwise average treatment effects within the connected set of
firms. We summarize this logic in the following result.
Proposition 2. If Assumptions 1–4 hold then jk = [Y i2 (k) Y i2 (j)]
k j [J]2. Let = ( 2 ,…, J ) , where j = [Y i2 (j)] [Y i2 (1)]
for j [2,…,J], and define the J − 1×1 vector F it = (1{D it = 2}
,…,1{D it = J}). If the worker mobility network is connected and ψ 1 =0,
then [ˆ k ˆ j {F i2 , F i1 } i [N] ] = [Y i2 (k) Y i2 (j)] k j [J]2, where

|     |     |     |     |     | Firmwageeffects |     | Chapter | |   | 2 145 |
| --- | --- | --- | --- | --- | --------------- | --- | ------- | --- | ----- |
| ˆ   |     |     |     |     | 1               |     |         | (ˆ  | ˆ     |
= i [N] (F i2 F i1 )(F i2 F i1 ) i [N] (F i2 F i1 )(Y i2 Y i1 ) = ,…, ) .
2 J
Proof. = [Y (k) Y (j)] follows directly from Assumption 4. Using
|     | jk  |     | i2  | i2  |     |     |     |     |     |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
|     |     |     |     | ψ,  |     |     | ψ   | =0, |     |
Proposition 1, the definition of and the assumption that 1 we have
|     | [Y  | Y D   | , D ] = |     | (   | )(1{D | = k} | 1{D | = j}) |
| --- | --- | ----- | ------- | --- | --- | ----- | ---- | --- | ----- |
|     | i2  | i1 i2 | i1      |     | k   | j     | i2   | i1  |       |
(j,k) {2,…,J}2
|     |     |     | =   | (F F | ) . |     |     |     |     |
| --- | --- | --- | --- | ---- | --- | --- | --- | --- | --- |
|     |     |     |     | i2   | i1  |     |     |     |     |
ˆ
Connectednessofthemobilitynetworkensurestheestimator iswelldefined.
|     |     |     | [ˆ {F , | }   | ]   |     |     |     |     |
| --- | --- | --- | ------- | --- | --- | --- | --- | --- | --- |
It follows that i2 F i1 i [N] = . The definition of ψ and assumption
|      |      |       | [ˆ  | ˆ     |                  |     |     | [J]2. |     |
| ---- | ---- | ----- | --- | ----- | ---------------- | --- | --- | ----- | --- |
| that | ψ =0 | imply |     | {F i2 | , F i1 } i [N] ] | =   | k   | j     | □   |
|      | 1    |       | k   | j     |                  | k   | j   |       |     |
This proposition implies that, in the absence of selection on treatment
effects, the cyclic restrictions discussed in Section 3.1.1 should hold. While
these restrictions offer a reasonable approximation to the edge effects, the
empiricalanalysisinSection3.2indicatedtheyareunlikelytoholdexactly.Of
course, the same could be said of most empirical work relying on quasi-
experimental variation. Nonetheless, future researchers may find it fruitful to
| entertain | some | weakenings |     | of Assumption | 4.  |     |     |     |     |
| --------- | ---- | ---------- | --- | ------------- | --- | --- | --- | --- | --- |
One approach is to find richer time varying covariates that plausibly
accountforselection.RecentworkbyVafaetal.(2022)demonstratesthatlow
dimensional embeddings of employment histories can capture significant
information about both potential wages and mobility, potentially restoring
independence of adjusted wages. Similarly, conditioning on worker mobility
patternsless likelyto be plaguedby selectioncould improve thecredibility of
firm effect estimates. For example, Di Addario et al. (2023) show that the
sequentialauctionmodelofBaggeretal.(2014)predictsthattheAKMmodel
restrictions should hold for the subpopulation of workers displaced from their
twopreviousjobs andprovideevidencesupportingthishypothesis.Thescope
for selection may also be diminished among subpopulations whose transitions
are prompted by plant closures or mass layoffs (Gibbons and Katz, 1992).
A second approach involves imposing a priori bounds on the maximal
selection present in the network. For example, one could constrain
| max |            |     | [Y  | (k) Y | (j)] and | seek | estimation | and inference |     |
| --- | ---------- | --- | --- | ----- | -------- | ---- | ---------- | ------------- | --- |
|     | (j,k) [J]2 | kj  | i2  | i2    |          |      |            |               |     |
procedures that perform well subject to this bound, utilizing extensions of the
methods discussed in Armstrong and Kolesár (2018), Armstrong and Kolesár
(2023).14
(2021), and Rambachan and Roth In some contexts it might be rea-
sonable to consider asymmetric bounds on selection. For example, a static Roy
(1951) selection model would posit that [Y (k) Y (j)] for voluntary
|     |     |     |     |     | jk  | i2  | i2  |     |     |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
14Amajortechnicalhurdleinthissettingrelativetoconventionaldifferenceindifferencespro-
blemsisthatmostedgeshaveveryfewmovers,implyingthatnormalityoftheestimatededge
effectsisnotassured.

146 HandbookofLaborEconomics
moves. While this sort of condition can be violated in sequential auction models
andmodelswithcompensatingdifferentials,itseemsreasonabletoexpectpositive
| selection on | wage | gains more | often | than negative | selection. |     |     |     |
| ------------ | ---- | ---------- | ----- | ------------- | ---------- | --- | --- | --- |
A third approach is to develop network formation models that deliver
dynamicpropensityscoresformobilitybetweenfirmsthatcanbeusedtomake
semi-parametric adjustments to wage changes. While some early progress has
been made in this direction (Abowd et al., 2019), particularly with the use of
stochasticblockmodels(Nimczik,2017;Jaroschetal.,2024),thisliteratureis
still in its infancy. A challenge for future work in this area is evaluating the
quality of propensity score models in networks that are extremely sparse.
Finally, a number of authors depart from “design based” assumptions on
selection and work with interactive factor models of wage outcomes
(Bonhomme et al., 2019; Lei and Ross, 2023). These models rationalize
intransitivities in edge effects in terms of latent heterogeneity in the sorts of
workers that transition between different edges. To date, however, most
researchinthisveinhasworkedwithlowerdimensionalrepresentationsofthe
mobility network, typically by clustering firms into a small set of groups, in
order to circumvent the incidental parameter biases that emerge from fitting
nonlinear models to sparse networks (Chen et al., 2021). An interesting
question for future research is whether the clustering step can be skipped and
the structure of the underlying (uncoarsened) edge effects more fully rationa-
| lized with factor | models        | of  | this nature. |     |     |     |     |     |
| ----------------- | ------------- | --- | ------------ | --- | --- | --- | --- | --- |
| 4 Variance        | decomposition |     |              |     |     |     |     |     |
Abowdetal.(1999)proposedsummarizingtheinfluenceoffirmsoncovariate-
adjusted wage inequality via the finite sample variance decomposition
| [Y X | ] =                    | [   | ] + | [                    | ]   | + 2 [ , | ] +    | [ ],  |
| ---- | ---------------------- | --- | --- | -------------------- | --- | ------- | ------ | ----- |
| n it |                        | n i |     | n j(i,t)             |     | n i     | j(i,t) | n it  |
|      | person effect variance |     |     | firm effect variance |     | sorting |        | noise |
[x ]
where n is the number of person-year observations in the sample, n it =
| n 1 (x | [x  | ])2, | [x ] = | n 1 x | it, and | [ , | ] =    | n 1 |
| ------ | --- | ---- | ------ | ----- | ------- | --- | ------ | --- |
| i,t it | n   | it   | n it   | i,t   |         | n i | j(i,t) | i,t |
( [ ]). Attention usually focuses on the firm effect variance
| i j(i,t) | n j(i,t) |     |     |     |     |     |     |     |
| -------- | -------- | --- | --- | --- | --- | --- | --- | --- |
[ ],whichgivesafirstpassmeasureoftheimportanceoffirmsinwage
n j(i,t)
determination.Notethatthisquantityisperson-yearweighted,sothatthefirm
effects of larger firms make a greater contribution to wage inequality. The
covariance component [ , ], which is often converted into a correla-
|     |     | n   | i j(i,t) |     |     |     |     |     |
| --- | --- | --- | -------- | --- | --- | --- | --- | --- |
tion coefficient, measures the assortativeness of worker-firm matching.
Ithasbecomecommontoscalethevarianceandcovariancecomponentsby
n [Y it X ] in order to give each component a share interpretation. While
suchexercisesallowacompletedecompositionofresidualwageinequality,the
|     |     |     |     |     |     | [ ], |     |     |
| --- | --- | --- | --- | --- | --- | ---- | --- | --- |
variance shares depend critically on the noise level n it which can vary
dependingonthevolatilityofearningsinthecountrybeingstudied,thenature

|     |     |     |     |     | Firmwageeffects |     | Chapter | | 2 147 |
| --- | --- | --- | --- | --- | --------------- | --- | ------- | ------- |
of the earnings measure (hourly, monthly, quarterly, or annual), and the
demographics of the workers under study. As discussed below, cross-fitting
and clustering methods both provide approaches to consistently estimating
[ ]. To maximize comparability across studies then, it is advisable to scale
n it
|               |     |           |     |             |           |     | [Y     | ] [ ], |
| ------------- | --- | --------- | --- | ----------- | --------- | --- | ------ | ------ |
| decomposition |     | exercises | by  | the “signal | variance” |     | n it X | n it   |
which captures the variability of long run expected wages of the worker-firm
| pairings | observed | in  | the data. |     |     |     |     |     |
| -------- | -------- | --- | --------- | --- | --- | --- | --- | --- |
Variance shares measure the relative importance of variance components but
say nothing about the absolute magnitude of variability present. Variance com-
ponents are also difficult to interpret because they are measured in squared log
points. Standard deviations allow a more direct assessment of the magnitude of
worker and firm heterogeneity because they are measured in log points. For
]1/2
example, a finding that n [ = 0.25 implies that moving to a standard
j(i,t)
deviation higher paying firm yields a roughly [exp(.25) 1] × 100 28%
higher wage. Moreover, by Chebyshev’s inequality, we know that the (employ-
ment-weighted) share of firms with firm effects more than k standard deviations
above the mean is at most 1/k2. Hence, in this example, no more than 6.25% of
personyearobservationscanbeatfirmswithwages100logpointsormoreabove
the mean.
| 4.1 | Limited | mobility | bias |     |     |     |     |     |
| --- | ------- | -------- | ---- | --- | --- | --- | --- | --- |
Theexogenousmobilityassumptionguaranteesthatleastsquareswillproduce
unbiasedestimatesofeachfixedeffect.Itisthereforetemptingtoplugtheleast
squares estimates {ˆ } N and {ˆ }J into the and operators to form
|     |     |     | i i =1 | j j=1 |     | n   | n   |     |
| --- | --- | --- | ------ | ----- | --- | --- | --- | --- |
estimates of the relevant variance components. Unfortunately, doing so will
produce biased estimates because these operators are quadratic functions. To
understand the problem, observe that for any unbiased estimator ˆ of ψ, we
j j
can write
|     | [ˆ2] | [    |     | ]   | [    |     |        | 2]  |
| --- | ---- | ---- | --- | --- | ---- | --- | ------ | --- |
|     |      | = (ˆ | +   | )2  | = (ˆ | )2  | + 2 (ˆ | ) + |
|     | j    | j    | j   | j   | j    | j   | j j    | j j |
[ˆ]
|     |     | =   | + 2 > | 2,  |     |     |     |     |
| --- | --- | --- | ----- | --- | --- | --- | --- | --- |
|     |     | j   | j     | j   |     |     |     |     |
where [] denotes expectation with respect to the mean zero noise terms
{ } in (1) and [] gives the corresponding variance. Hence, esti-
| it  | i [N],t [T] |     |     |     |     |     |     |     |
| --- | ----------- | --- | --- | --- | --- | --- | --- | --- |
mation noise leads the square of the estimator to provide an upwardly biased
estimateofthesquareoftheparameter.Asimilarargumentrevealsthatforany
unbiasedpersoneffectestimator ˆ ofα andanyunbiasedfirmeffectestimator
|     |        |     |     | i   | i             |     |               |              |
| --- | ------ | --- | --- | --- | ------------- | --- | ------------- | ------------ |
| ˆ   |        | ˆ   |     |     | ˆ             |     |               |              |
| of  | ψ that | [ˆ  | ] = | +   | [ˆ , ]. Abowd |     | et al. (2002) | termed these |
| j   | j      | i j | i   | j   | i j           |     |               |              |
biases in the context of fixed effects estimation (1) “limited mobility bias” on
account of the observation that if the number of movers between each firm
weretogrowinfinitelylarge,thenoisewoulddisappearandthebiasalongwith
it. Andrews et al. (2008) derived the nature of the bias in plugin estimates of

148 HandbookofLaborEconomics
the variance components in the AKM decomposition more formally and
ˆ
established that the covariance [ˆ , ] between person and firm effects
n i j(i,t)
| must | be biased | down.      |           |     |          |        |          |        |     |
| ---- | --------- | ---------- | --------- | --- | -------- | ------ | -------- | ------ | --- |
|      |           |            |           |     | ˆ [ˆ]1/2 |        |          | [ˆ]1/2 |     |
|      | When a    | consistent | estimator |     |          | of the | standard | error  | is  |
|      |           |            |           |     | j        |        |          | ˆ2     | j   |
available,onecanformabias-corrected estimateofeach 2 with ˆ [ˆ];
|     |     |     |     |     |     |     | j   | j   | j   |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
that is, by subtracting off the squared standard error from the plugin estimate.
Likewise, an unbiased estimate of the variance of firm wage effects
|     | = [      | ] = | [ 2     | ]   | [ ]2   |        |          |                   |     |
| --- | -------- | --- | ------- | --- | ------ | ------ | -------- | ----------------- | --- |
|     | n j(i,t) |     | n (i,t) | n   | j(i,t) | can be | obtained | from its debiased |     |
j
analogue
|     | ˆ   | [ˆ 2    | ˆ [ˆ | ]]     | {   | [ˆ ]2  | ˆ [ | [ˆ ]]} |       |
| --- | --- | ------- | ---- | ------ | --- | ------ | --- | ------ | ----- |
|     | =   | n       |      |        |     | n      |     | n      | . (5) |
|     |     | j (i,t) |      | j(i,t) |     | j(i,t) |     | j(i,t) |       |
KruegerandSummers(1988)implementedabiascorrectionofthisformwhen
ˆ
computingthevarianceofindustrywagefixedeffects.Replacing with ˆ
|     |     |     |     |     |     |     |     | j(i,t) | i   |
| --- | --- | --- | --- | --- | --- | --- | --- | ------ | --- |
intheaboveformulayieldsabias-correctedvarianceofpersoneffects ˆ .The
bias-corrected covariance between person and firm effects can be obtained
|      |             |     | ˆ   | ˆ          | ˆ   | ˆ        |     |     |     |
| ---- | ----------- | --- | --- | ---------- | --- | -------- | --- | --- | --- |
| from | the formula |     | =   | [ˆ         |     | [ˆ ,     | ]]. |     |     |
|      |             |     | ,   | n i j(i,t) |     | i j(i,t) |     |     |     |
Andrews et al. (2008) proposed a correction for the AKM variance and
covariance components under the assumption that the ε are iid. However,
it
these corrections yielded small changes in the variance components, cor-
rectionsthatappearedtobetoosmallgiventhemagnitudeofthebiasesfound
in the subsampling exercises reported in Andrews et al. (2012). Card et al.
(2013,OnlineAppendix3)conjecturedthatthisunder-correctionwaslikelya
result of unmodeled heteroscedasticity and serial correlation in wage inno-
vations, properties that had been well documented in the literature on earn-
ings dynamics (e.g., MaCurdy, 1982; Abowd and Card, 1989; Meghir and
| Pistaferri, | 2004). |     |     |     |     |     |     |     |     |
| ----------- | ------ | --- | --- | --- | --- | --- | --- | --- | --- |
It is tempting to use conventional heteroscedasticity-consistent standard
errors to estimate and remove the bias. However, these “standard standard
errors” and their bootstrap analogues are known to exhibit bias when the
number of parameters being estimated is proportional to the number of
observations (Bickel and Freedman, 1981; MacKinnon and White, 1985;
Mammen, 1993; Cattaneo et al., 2018; El Karoui and Purdom, 2018). Kline
et al. (2020) proposed replacing the usual heteroscedasticity consistent stan-
dard errors (e.g., White, 1980; MacKinnon and White, 1985) with hetero-
scedasticity unbiased variance estimates derived from cross-fitting that are
| robust | to arbitrary  |     | heteroscedasticity. |            |     |     |     |     |     |
| ------ | ------------- | --- | ------------------- | ---------- | --- | --- | --- | --- | --- |
| 4.2    | Cross-fitting |     | and bias            | correction |     |     |     |     |     |
Cross-fitting can be thought of as a version of sample splitting designed to
remove overfitting biases while making maximally efficient use of the data

|     |     |     |     |     | Firmwageeffects |     | Chapter | | 2 149 |
| --- | --- | --- | --- | --- | --------------- | --- | ------- | ------- |
(Newey and Robins, 2018).15 To understandthe logic behind this approach, it
| is useful | to rewrite | (1)      | in the notation |        |     |          |             |       |
| --------- | ---------- | -------- | --------------- | ------ | --- | -------- | ----------- | ----- |
|           |            |          | Y =             | D +    | F   | + ,      |             | (6)   |
|           |            |          | m               | m      | m   | m        |             |       |
| where     | Y is       | a vector | of              | all of | the | wages in | worker-firm | match |
m
| m {1,…,M} |     | [M]. |              |     |          |        |             |           |
| --------- | --- | ---- | ------------ | --- | -------- | ------ | ----------- | --------- |
|           |     |      | For example, | if  | a worker | spends | three years | at a job, |
thenthatmatchyieldsa3×1vectorofwages.ThematrixD iscomprisedof
m
workerdummies;ithasasmanyrowsastherearetimeperiodsinmatchmand
Ncolumns,oneforeachworkerinthesample.Thevectorαcollectstheperson
effects. The matrix F is comprised of firm dummies. We assume one firm
m
hasJ−1columnsandthevector
| effecthasbeennormalizedtozerosothatF |     |     |     |     | m   |     |     |     |
| ------------------------------------ | --- | --- | --- | --- | --- | --- | --- | --- |
ψ collects J − 1 firm effects. I have again abstracted from the time varying
covariates, which can be partialled out in a first stage. Throughout this dis-
cussion,wewilltreatthe{D , } [M],alongwith( , )asfixed,leavingε
|     |     |     | m F | m m |     |     |     |     |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
m
| asthe onlysourceofrandomnessin |     |     |     | themodel.The{ |     |     | } areassumedto |     |
| ------------------------------ | --- | --- | --- | ------------- | --- | --- | -------------- | --- |
m m [M]
| be mutually | independent |     | and to | exhibit | mean | zero. |     |     |
| ----------- | ----------- | --- | ------ | ------- | ---- | ----- | --- | --- |
We will write [ ] = which conveys both that the noise level may
|     |     |     | m m |     |     |     |     |     |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
vary from match to match and that arbitrary within match correlation of the
errors ε is permitted. The variance of least squares estimates of firm effects
m
| takes the | usual | “sandwich” | form  |     |     |     |       |     |
| --------- | ----- | ---------- | ----- | --- | --- | --- | ----- | --- |
|           |       |            |       | 1   |     |     |       | 1   |
|           | [ˆ]   |            | F˜ F˜ |     | F˜  | F˜  | F˜ F˜ |     |
|           |       | =          | m m   |     | m   | m m | m m   | ,   |
|           |       | m          | [M]   | m   | [M] | m   | [M]   |     |
F˜
where m is the matrix of firm dummies that results after partialling out the
worker dummies – i.e., after deviating the firm indicators from their worker
|     |     |     |     | the{ | }   |     |     |     |
| --- | --- | --- | --- | ---- | --- | --- | --- | --- |
specific means. Hence, if we knew m m [M], we could compute “match
clustered” standard errors that allow us to biascorrect the square of each firm
| effect by | subtracting | off | its squared | standard |     | error. |     |     |
| --------- | ----------- | --- | ----------- | -------- | --- | ------ | --- | --- |
ˆ
Let m denotethevectoroffirmeffectsderivedfromfitting(1)byleastsquares
whenleavingouttheobservationsformatchmand ˆ thecorrespondingvectorof
m
personeffects.For ˆ toexist,weneedthateveryworkerhasatleasttwoworker-
m
firmmatches.Assumeforthemomentthenthatthesamplehasbeenrestrictedtojob
switcherssothat ˆ exists.Thisassumptioniswithoutlossofgeneralitysincejob
m
stayersdonotcontributetoestimationofthefirmeffectsbutonlytothefirmweights
usedtodefinethevarianceofinterest.Anotheroptionistoconsiderlongdifferences
– i.e., toomit all butthefirst andlast periods– and totreat thefirst andlast wage
errorofjobstayersasindependent,which maybeplausibleinlongerpanels.
15Sorkin(2018),Dreniketal.(2023),andCardetal.(2024)estimatevectorsoffirmeffectsusing
twoindependenthalfsamplesofworkers.Thecovariancebetweenthetwosamplesprovidedan
unbiased(andtransparent)estimateofthevarianceofthelatentfirmeffects.Unfortunately,the
connectedsetcangrowmuchsmallerwhenthesampleissplitandrandomnessinhowthesplit
waschosencontributestothevariabilityoftheestimator.

150 HandbookofLaborEconomics
| Define | the | cross-fit | residual | as  |     |     |     |     |     |
| ------ | --- | --------- | -------- | --- | --- | --- | --- | --- | --- |
ˆ
|       |     | ˆ     | = Y | D ˆ     | F   | =           | + ,  |        |          |
| ----- | --- | ----- | --- | ------- | --- | ----------- | ---- | ------ | -------- |
|       |     | m     | m   | m m     | m   | m m         | m    |        |          |
|       |     |       | ˆ   |         | ˆ   |             |      |        |          |
| where |     | D m ( | m ) | + F m ( |     | ) is a mean | zero | vector | of noise |
|       | m   |       |     |         | m   |             |      |        |          |
ˆ
arising from estimation error in the coefficients (ˆ m , ). Note that
m
| [   | ] = | 0   |     |     |     |     |     |     |     |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
m because the noise is independent across matches. Hence, unlike
m
traditionalregressionresiduals,whichtendtobetoosmallduetooverfitting,the
|           |           |     |           |            |     | [ˆ ˆ | ] = | + [ | ].  |
| --------- | --------- | --- | --------- | ---------- | --- | ---- | --- | --- | --- |
| cross-fit | residuals | are | generally | too large, | as  | m m  | m   |     | m   |
m
Kline et al. (2020) propose multiplying the cross-fit residual by the out-
| come, | which | yields the | unbiased | estimator |     |      |     |     |     |
| ----- | ----- | ---------- | -------- | --------- | --- | ---- | --- | --- | --- |
|       |       | ˆ =        | Y ˆ =    | (D        | + F | + )( | +   | ) . |     |
|       |       | m          | m m      | m         | m   | m    | m m |     |     |
ˆ
| Unbiasednessof |     | mfor |     | followsfromtheobservationthatD |     |     |     | α+F | ψisa |
| -------------- | --- | ---- | --- | ------------------------------ | --- | --- | --- | --- | ---- |
|                |     |      | m   |                                |     |     |     | m   | m    |
matrix of constants and the presumed independence of ε from ξ .16 Hence,
|     |     |     |     |     |     |     | m   | −m  |     |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
[ˆ]is
| an unbiased |     | estimator | of  |     |     |       |       |       |     |
| ----------- | --- | --------- | --- | --- | --- | ----- | ----- | ----- | --- |
|             |     |           |     | 1   |     |       |       | 1     |     |
|             | ˆ   | [ˆ]       | F˜  | F˜  | F˜  | ˆ F˜  | F˜    | F˜    |     |
|             |     | =         | m   | m   |     | m m m |       | m m . | (7) |
|             |     | m         | [M] | m   | [M] |       | m [M] |       |     |
NotethatunliketheclassicHC2andHC3estimatorsofMacKinnonandWhite
(1985), the cross-fit variance estimator is unbiased for any sample size. A
corresponding formula for the covariance between person and firm effects is
| provided | in  | the appendix. |     |     |     |     |     |     |     |
| -------- | --- | ------------- | --- | --- | --- | --- | --- | --- | --- |
Unbiasedness does not guarantee that the variance estimate for any particular
firmeffectwillbeaccurate.Infact,anecessaryconsequenceofunbiasednessisthat
there must be some probability that the realized variance estimate for each of the
diagonalterms ˆ [ˆ]isnegative.However,Klineetal.(2020)showthatweighted
j
averages of the estimated variances, such as the average estimated noise level
| [ˆ  | [ˆ     |                   |     |             |     | [ˆ  |        |            |      |
| --- | ------ | ----------------- | --- | ----------- | --- | --- | ------ | ---------- | ---- |
|     |        | ]] are guaranteed |     | to converge | to  | [   | ]] as  | the sample | size |
| n   | j(i,t) |                   |     |             |     | n   | j(i,t) |            |      |
grows large. If we have restricted estimation to the firm movers, we can also
computetheweightedaverage noise level,which reweightsthefirms according to
theirshareofallperson-yearobservationsincludingthefirmstayers.Consequently,
unbiasedestimationofthevarianceoffirmeffectsdoesnotrequiretakingastandon
the serial correlation of the stayer wage errors. Bias-corrected estimates of firm
variancecomponentsareoftenquiteprecise.Forinstance,Klineetal.(2020)obtain
abias-correctedpointestimateoftheperson-yearweightedvarianceoffirmeffects
16Asmentionedearlier,onetypicallypreadjustslogwagesfortimevaryingcovariatesinafirst
step,whichintroducesasmallhigherorderbiasduetoestimationerror ˆ influencingboth
y and ˆ m.Evenso,itisoftenwisetoensurey hasmeanzerobeforeapplyingcross-fittingin
| m   |     |     |     |     | m   |     |     |     |     |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
ordertoreducethevariabilityof ˆ andwewilldosoinourempiricalexamplebelow.
m

|     |     |     |     | Firmwageeffects |     | Chapter | |   | 2 151 |
| --- | --- | --- | --- | --------------- | --- | ------- | --- | ----- |
of 0.024 (which we will replicate shortly) with a corresponding standard error of
only 0.0006.
| 4.2.1 | Leave-out connectedness |     |     |     |     |     |     |     |
| ----- | ----------------------- | --- | --- | --- | --- | --- | --- | --- |
An important requirement of cross-fitting methods is that the model must be
estimable after leaving out any particular observation. Within a given connected
set,manyfirmsmaybeconnectedbyonlyasinglemove,implyingtheirψ would
j
not be estimable if that worker’s wage observations were dropped. Kline et al.
(2020) find when using only two periods of data that 43% of the firms in the
largestconnectedsetare“just-connected”inthismanner.Workerswhomovetoor
fromsuchfirmshavenoresidualassociatedwiththeirwagechange,prohibitingan
assessmentofthelevelofnoiseintheirwagesandconsequentlyabiascorrection.
Fundamentallythen,thevarianceoffirmeffectsisonlyidentifiedwithintheleave-
| out connected | set that prunes |     | the just-connected |     | firms. |     |     |     |
| ------------- | --------------- | --- | ------------------ | --- | ------ | --- | --- | --- |
Toassesshowthispruningmightchangeestimands,Klineetal.(2020,Table
IV) report the results of further restricting the set of firms under study to be
connected when any two matches are left out. Requiring that each firm effect be
estimable when any two matches are left out further reduces the number of
estimablefirmeffectsby43%.Surprisingly,theeffectofthisrestrictionturnsout
to be negligible, nudging the point estimate of the variance of firm effects from
0.240 to 0.238. Similar insensitivity to these leave-out requirements is found for
subsamplesofolderandyoungerworkers.Onereasonforthisinsensitivityisthat
weakly connected firms typically employ few workers and hence make a small
contribution to the overall (person-year weighted) variance of firm effects.
Another is that in finite samples, there is a large degree of randomness in which
firms happen to be connected, a phenomenon consistent with standard random
| search models | exhibiting   | Poisson    | arrival | of mobility | events. |     |     |     |
| ------------- | ------------ | ---------- | ------- | ----------- | ------- | --- | --- | --- |
| 4.2.2         | Bounding and | imputation |         |             |         |     |     |     |
Existing applications of the cross-fitting correction report variance compo-
nents describing heterogeneity within theleave-out connectedset ofworkers
and firms. Moving the goalposts to estimate whatever target parameter is
identified by a research design is standard fare in empirical economics
(Crump et al., 2009; Imbens, 2010). It is nonetheless prudent to examine the
extent to which the leave-out connected set might differ from the broader
population of workers and firms. Fortunately, it is relatively straightforward
tocomputeboundsonvariancecomponentsdescribingthebroaderconnected
set of firms.
The key insight that allows the construction of bounds is to note that the
| noise level | in any       | match     | must obey | the   | bound: 0 |     | [Y  | Y ]. The |
| ----------- | ------------ | --------- | --------- | ----- | -------- | --- | --- | -------- |
|             | m            |           |           |       |          | m   | m   |          |
| upper bound | follows from | observing |           | that  |          |     |     |          |
|             | [Y Y         | ] = (D    | +         | F )(D | + F      | ) + | .   |          |
|             | m m          |           | m         | m     | m m      |     | m   |          |

152 HandbookofLaborEconomics
Thefirstterminthissumistheouterproductofavectorandthereforemustbe
positive semi-definite. Consequently, the upper bound is sharp, arising when
| D   | α+F | ψ equals | a vector | of zeros. |     |     |     |     |
| --- | --- | -------- | -------- | --------- | --- | --- | --- | --- |
m m
Intuitively,thewagesassociatedwithajust-connectedmatchcouldbepure
|     |     |     |     | [Y  | ],  |     |     |     |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
noise, in which case m = m Y m or they could be entirely noiseless, in
[ˆ]
which case = 0. This observation suggests estimating bounds on
m
|       | ˆ   | = Y Y |       |             |     | ˆ = 0 |               |        |
| ----- | --- | ----- | ----- | ----------- | --- | ----- | ------------- | ------ |
| using | m   | m m   | as an | upper bound | and | m as  | a lower bound | on the |
noise contribution of just-connected matches. As before, we use the leave-out
estimator ˆ = Y ˆ for leave-out connected matches. Denote the resulting
|     |     | m m | m   |     |           |                            |     |     |
| --- | --- | --- | --- | --- | --------- | -------------------------- | --- | --- |
|     |     |     |     |     | ˆ+ [ˆ]and | ˆ [ˆ]respectively.Plugging |     |     |
estimatedupperandlowerboundsby
these bounds on the noise level into (5) yields a corresponding lower bound
ˆ+
estimate ˆ and upper bound estimate on the variance of firm effects
|     | = n [ | ]:  |     |     |     |     |     |     |
| --- | ----- | --- | --- | --- | --- | --- | --- | --- |
j(i,t)
|     |     | [ˆ2      | ˆ+[ˆ | ]]     | { [ˆ | ]2     | ˆ+[ [ˆ   | ]]} |
| --- | --- | -------- | ---- | ------ | ---- | ------ | -------- | --- |
|     | ˆ = |          |      |        |      |        |          | ,   |
|     |     | n j(i,t) |      | j(i,t) | n    | j(i,t) | n j(i,t) |     |
|     | ˆ+  | [ˆ2      |      | ]]     | {    |        | [        | ]]} |
|     | =   |          | ˆ    | [ˆ     | [ˆ   | ]2     | ˆ [ˆ     | .   |
|     |     | n j(i,t) |      | j(i,t) | n    | j(i,t) | n j(i,t) |     |
These bounds, which are consistent for the corresponding population bounds
under conditions that parallel the case where all observations are leave-out
connected, may be especially useful in thin samples or environments char-
acterized by low mobility. A corresponding approach to bounding the covar-
|       |     | = (       | ,        | )           |        |           |     |     |
| ----- | --- | --------- | -------- | ----------- | ------ | --------- | --- | --- |
| iance | ,   | n         | i j(i,t) | is detailed | in the | appendix. |     |     |
| 4.2.3 | An  | empirical | example  |             |        |           |     |     |
To illustrate these ideas, we now return to the benchmark VHW sample
introducedinSection3.2.Withtwoyearsofdata,estimatingthefirmeffectsin
levelsandfirstdifferencesisnumericallyequivalent,whichimpliesthatwecan
thinkofY m asascalarmeasuringwagechangeswithoutlossofgenerality.As
shown in the top panel of Table 2, roughly 83% of movers in the largest
connected set are also in the leave-out connected set. These leave-out con-
nected workers exhibit mildly higher average wages that are slightly less
dispersed.ThelowerpanelsofthetablereportestimatesoftheAKMvariance
| decomposition |     | in each | sample. |     |     |     |     |     |
| ------------- | --- | ------- | ------- | --- | --- | --- | --- | --- |
Squaring the plug-in and bias-corrected standard deviations of firm effects
reported inthe second columnof Table2 reproduces the firmeffect variances
reportedinTableIIofKlineetal.(2020).Thecross-fittingbiascorrectionhas
substantial bite in the leave-out sample, cutting the estimated standard devia-
tionoffirmeffectsfrom18.9to15.5logpoints.Itisnaturaltoworry,however,
that this bias reduction constitutes a pyrrhic victory, as the roughly 40% of
connectedfirmsthatarenotleave-outconnectedmaydifferfromthosethatare
connected.Howlargeofabiascorrectionwouldwehaveobtainedifweknew
| the | error | variances | in the | original connected |     | set? |     |     |
| --- | ----- | --------- | ------ | ------------------ | --- | ---- | --- | --- |

|     | Firmwageeffects | Chapter | | 2 153 |
| --- | --------------- | --------- | ----- |
TABLE2 SamplecompositionandvariancecomponentsinVeneto,Italy.
|     | Connectedset | Leave-out |     |
| --- | ------------ | --------- | --- |
connectedset
| NumberofPerson-YearObservations | 1,859,459 | 1,319,972 |     |
| ------------------------------- | --------- | --------- | --- |
| NumberofMovers                  | 197,572   | 164,203   |     |
| NumberofFirms                   | 73,933    | 42,489    |     |
| MeanLogWage                     | 4.7507    | 4.8066    |     |
| StandardDeviationofLogWage      | 0.4455    | 0.4293    |     |
StandardDeviationofFirmEffects
| Plug-in           | 0.2161          | 0.1892 |     |
| ----------------- | --------------- | ------ | --- |
| Bias-Corrected    | [0.1421,0.1847] | 0.1549 |     |
| ConnectedatRandom | 0.1643          |        |     |
StandardDeviationofPersonEffects
| Plug-in                | 0.3712          | 0.3634 |     |
| ---------------------- | --------------- | ------ | --- |
| Bias-Corrected         | [0.3216,0.3423] | 0.3345 |     |
| ConnectedatRandom      | 0.3320          |        |     |
| ImputeStayerNoiseLevel | [0.3138,0.3353] | 0.3267 |     |
| CAR(ImputeStayerNoise) | 0.3245          |        |     |
CovarianceofFirmandWorkerEffects
| Plug-in           | −0.0053         | 0.0039 |     |
| ----------------- | --------------- | ------ | --- |
| Bias-Corrected    | [0.0063,0.0188] | 0.0146 |     |
| ConnectedatRandom | 0.0128          |        |     |
Notes:Thistablereportspropertiesoftheconnectedandleave-outconnectedsetsinapanelcomprisedof
the1999and2001wavesoftheVenetoWorkHistoriesdatasetdevelopedbytheEconomicsDepartmentin
UniversitaCa’FoscariVeneziaunderthesupervisionofGiuseppeTattara.Thestandarddeviationoffirm
effectsreferstotheperson-yearweightedstandarddeviationoffirmeffectsinaregressionoflogdailywages
onworkerfixedeffects,firmfixedeffects,andayearfixedeffect.“Plug-in”referstotheOLSestimates.“Bias-
corrected” estimate uses the cross-fit bias correction. Intervals correspond to bounds on the variance
componentinquestionresultingfromtheassumptionthatthenoiselevelsofjust-connectedmoversequal
eitherzeroorthatmover’ssquaredwagechange.“Connectedatrandom”biascorrectsbyimputingthe
average error variance of leave-out connected movers to just-connected movers. “Impute Stayer Noise
Level”biascorrectsassumingthatworkerswhodon’tswitchjobshavetheaveragenoiselevelofleave-out
connectedmovers.Intervalsagaincorrespondtoboundsonthevariancecomponentinquestionresulting
fromtheassumptionthatthenoiselevelsofjust-connectedmoversequaleitherzeroorthatmover’ssquared
wagechange.“CAR(ImputeStayerNoise)”biascorrectsassumingthatbothjust-connectedmoversandjob
stayersexhibittheaveragenoiselevelofleave-outconnectedmovers.

154 HandbookofLaborEconomics
The first column of the bottom panel of Table 2 sheds light on this
question. The upper bound on the variance of firm effects assumes that the
matches at just-connected firms have error variance zero, yielding an upper
bound on the standard deviation of firm effects of 18.5log points. Coin-
cidentally, this upper bound is very near the plug-in estimate of the standard
deviationoffirmeffectsintheleave-outconnectedsample.Conversely,ifwe
assume matches at each just-connected firm have error variance equal to the
squared wage change involving that firm, then we attain a lower bound
standard deviation of 14.2log points. Finally, if the just-connected matches
exhibit a noise level equal to the average of the leave-out connected
matches – an assumption that I will term “connected at random” (CAR) –
then we can form a bias correction by imputing for every just-connected
match the average cross-fit noise level of wage changes of movers in the
leave-out connected set.17 The CAR imputation yields an estimated standard
deviation of firm effects of 16.4log points.
Evidently, the bias-corrected standard deviation estimate in the leave-out
connected sample is almost exactly halfway between the lower bound and
CAR estimates in the broader connected sample. Moreover, the range of
estimatesisrelativelynarrow.Littleseemstohavebeenlostherebyrestricting
to the leave-out connected set. If the CAR estimate had been very different
from the bias-corrected estimate, however, we might have come away more
concerned about selection bias. Hence, the CAR estimate seems like a useful
diagnostic to report in addition to the standard bias-corrected estimates
describing the leave-out connected set.
Anequivalentexercisecanbeconductedwiththevarianceofpersoneffects
and the covariance between person and firm effects. Bias correcting the
standard deviation of person effects in the leave-out connected set reduces its
magnitude by about 3log points, which is comparable to the effects of bias
correction on the standard deviation of firm effects. In the broader sample of
connected workers, the bounds on the standard deviation are quite narrow,
ranging from 32.2 to 34.2log points. Like the bias-corrected estimate in the
leave-out connectedset,the CARestimate ofthe standarddeviation of person
effects in the broader connected set is 33log points.
As was noted earlier, it is possible that the noise level of job stayers has
been underestimated by neglecting serial correlation.While job stayers do not
contributetoestimationoffirmeffects,theyareessentialfortheestimationof
person effects. Underestimationof job stayer noise levels could thereforelead
to overestimation of the variance of person effects. To assess this possibility,
we also report the person effect standard deviation that would result if
job stayers had the same average noise level as job movers. Doing so in the
17One could argue that this assumption should be termed “connected completely at random”
(CCAR)astheimputationisnotconditionedonanycovariates.

Firmwageeffects Chapter | 2 155
leave-out connected set yields a marginally smaller person effect standard
deviation of 32.7log points. In the broader connected sample, this imputation
lowersboththeupperandlowerboundsonthepersoneffectstandarddeviation
byslightlyless thanalog point.Likewise,the CARestimateinthe connected
samplefallsbynearlyalogpointandisessentiallyindistinguishable fromthe
estimate in the leave-out connected sample.
Finally, bias correcting the covariance between worker and firm effects
in the leave-out connected set yields small increases. Fortunately, bias cor-
recting the covariance does not require recovering the noise level of stayers
because the bias stems from estimation error in firm effects, which depend
entirely on movers. In the broader connected sample, the bounds are again
fairly narrow. Moreover, the CAR estimate of covariance is close to the bias-
corrected covariance in the leave-out connected set.
Usingthebias-correctedestimatesintheleave-outconnectedsampleyields
a correlation coefficient of 0.28. If we ascribe to the stayers the noise level of
the movers, the correlation rises negligibly to 0.29 because the person effect
variance falls. In the broader connected set the correlation is an increasing
function of the unknown noise level of the just-connected movers.
Consequently,wecanobtainlowerboundundertheassumptionthatthenoise
level is zero and an upper bound under the assumption that the noise level is
given by the squared wage change. It turns out that this yields a non-trivial
range of possible correlation coefficients [0.09, 0.40]. However, these bounds
entertain the implausible possibility that the wage changes of just-connected
movers are either all noise or all signal. The CAR estimate of correlation is
0.23 and imputing the mover noise level to the stayers raises this correlation
negligibly to 0.24. These estimates are quite close to our bias-corrected esti-
mate in the leave-out connected sample, suggesting that selection is probably
not a major concern here.
In sum, we can be relatively confident that trimming has little effect on
theperson-yearweightedvarianceofworkerorfirmeffects.Theinfluenceof
trimming on the correlation between worker and firm effects is less clear;
however, the agreement between the CAR estimates and the bias-corrected
estimates in the leave-out connected set suggests selection bias in the cor-
relation is also likely to be mild. Future research in this area could consider
more sophisticated imputation schemes that allow the noise levels of just-
connected workers to depend upon features of the worker-firm mobility
network. Finally, our imputation experiments suggest that person effect
variances are unlikely to be dramatically overstated by cross-fitting approa-
ches neglecting the serial correlation of job stayers. In settings where serial
correlationisaknownconcern,imputingthenoiselevelsofjobstayersbased
on the average estimated noise level of movers offers a potentially attractive
way of mitigating this bias.

156 HandbookofLaborEconomics
4.3 Clustering approaches
Bonhomme et al. (2019) analyze a version of the AKM model in which firm
heterogeneity is restricted to be discrete. They assume the firm effects can be
represented in a lower dimensional space via the relation
K
j = T jk ¯ k , (8)
k=1
where the {T jk } k K =1 are indicators for the latent type of the j’th firm effect
obeying k K =1 T jk = 1and the{¯ k } k K =1 are the wage effects of those firm types.
In their baseline specification, they work with K =10 types, a choice that has
been focal in the subsequent literature.
Directlyimposing(8)andoptimizingjointlyovertheindicatorsT andthe
jk
¯
locations via nonlinear least squares is a non-convex and often intractable
k
computational problem. To circumvent this obstacle, Bonhomme et al. (2019)
proposeatwostepapproach.First,theyapplyavariantofK-meansclustering
(Forgy, 1965; Lloyd, 1982) to firm wage distributions to obtain firm type
assignments
Tˆ
jk. These type assignments are then treated as regressors in
second step estimation of the model
K
Y = + Tˆ ¯ + X + .
it i j(i,t)k k it
k=1
RatherthanestimatethisequationbyOLS,theytreattheα asnormalmixtures
i
withmeansthatdependonTˆ
jk,whichfurtherreducesthenumberofparameters
tobeestimated,andmaximizethelikelihoodviatheEMalgorithm(Dempster
et al., 1977). Once the type specific parameters have been estimated, the type
estimates can (in principle) be updated, yielding reclassified firm and worker
typeassignmentsthatprovideapproximationstoonestepmaximumlikelihood
estimates of the full model.
In some respects, the clustering approach mirrors the earlier literature on
industry wage differentials (e.g., Krueger and Summers, 1988). Rather than
usingasregressorsindicatorsfor20orso2-digitindustries,the“industries”are
treated as latent random variables to be reconstructed via clustering of firm
wagedistributions.ByreducingthehighdimensionalAKMspecificationdown
to a low dimensional model, the clustering approach sidesteps the usual inci-
dental parameters problem, substantially reducing the biases associated with
squaringestimatedparameters.Clusteringalsocircumventstherequirementto
limit the analysis to the largest connected set of firms, as one only needs the
estimated firm
typesTˆ
jk, rather than each individual firm, to be connected by
worker mobility for the second step model to be estimable. Interactions
between estimated worker and firm types can also be treated as regressors,
allowingestimationofnon-separablemodels.Theseinteractionsturnouttobe
negligible in Swedish data, however, raising the estimated R2 of the model

Firmwageeffects Chapter | 2 157
from 74.8% to 75.8%, leading Bonhomme et al. (2019) to conclude that
“complementarities explain only a small part of the variance of log-earn-
ings.”18
The advantages of the clustering approach come at the cost of strong
assumptionsonthedatageneratingprocess.Foronething,itseemsimplausible
that there exist large groups of firms that offer exactly the same wage pre-
miums. The restriction in (8) is at best an approximation and one that inevi-
tablyleadstounderstatementoffirmeffectvariancesbyneglectingwithin-type
variability. Neglected covariances between any within firm type employer
heterogeneityandworkerheterogeneitycanalsoleadtobiasintheestimatesof
worker-firm sorting. Card et al. (2023) note both of these problems when
revisiting the industry wage differential literature, where they find substantial
variation in employer wage premiums within industry along with significant
worker-firm sorting. It seems unlikely that any partition of firms into 10 or
even 10,000 groups would entirely resolve these problems.
Evenif(8)weretoholdexactly,thetypeassignmentsTˆ
jk willbenoisyfor
small firms, which can generate bias in the estimated locations parameters
{¯ˆ }K . Indeed, the formal assumptions used by Bonhomme et al. (2019) to
k k=1
establish consistency of the two step clustering approach require that the
number of wage observations at the smallest firm grow with the number of
firms. This potential for bias that arises with finite sized firms is a cost of
having to estimate a regressor instead of relying on a predetermined grouping
such as industry, firm size, or geography. Another cost concerns interpret-
ability. While some judgement calls are involved in choosing industry and
geographic categories,variationacrossthemissubstantially easierto interpret
than variation across firm groups determined via K-means clustering of wage
distributions.
A related conceptual difficulty is that the type assignments are determined
based on cross-sectional wage distributions rather than worker mobility.
However,anycross-sectionaldistributionofwagescouldbedrivenbyworker
sorting rather than firm heterogeneity. The ability to separate the two comes
only from the assumption that the economy possesses a finite number of well
separated firm types. Parametric identification of this nature is contrary to the
ethos of the AKM approach, which relies entirely on worker mobility to
separate worker and firm heterogeneity.
The robustness exercises reported in Bonhomme et al. (2019, Table III)
revealthattheestimatedvarianceoffirmeffectscan,infact,bequitesensitive
to the details of the procedure used to form the type assignments. They find
18Infact,theirestimatedinteractionsaresmallerthanthosereportedbyCardetal.(2013,Table
III)forGermandata,whofindthatallowingforunrestrictedworker-firmmatcheffectsraisesthe
adjusted R2 by roughly 2% points. In a recent analysis of US earnings data, Lamadon et al.
(2022,TableA6)reportthataddingworker-firminteractionstoanadditivegroupfixedeffects
modelraisestheR2bylessthanonepercentagepoint.

158 HandbookofLaborEconomics
that clustering firms into ten groups based on their cross-sectional wage dis-
tributionsyieldsavarianceoffirmeffectsthataccountsfor2.6%oftheoverall
varianceof earnings in Swedish administrative data. Splittingthose groupsby
firmvalueaddedraisestheshareofwagevarianceexplainedbyfirmsto3.4%.
Reclassifying the firm types – which can be thought of as choosing the firm
groups to directly approximate the firm effects of the movers – raises the
estimated contribution of firm effects to 4.1% of the variance.
A recent paper by Bonhomme et al. (2023) relaxes (8) by assuming
K
= T (¯ + ),
j jk k k (9)
k=1
where each{ k } k K =1 is a mean zero normally distributed random effect with a
different variance.Byallowing forwithin firmtypedispersion, thiscorrelated
random effects (CRE) approach generally picks up a greater degree of firm
dispersion.Forinstance,Lamadonetal.(2022,TableA6)findthatfirmeffects
explain only 3.2% of annualearnings variance in US tax data when using the
two-step estimator imposing (8), whereas Bonhomme et al. (2023, Table F2)
estimatethatshareat6.2%inasixyearpanelofthesamedatausingtheCRE
estimator predicated on (9). However, the CRE estimator still relies on func-
tional form assumptions to separate worker and firm types. In particular, the
estimator is predicated on moment conditions imposing that i [ i T jk ] is
independent of υ , which implies there is no worker firm sorting within firm
k
types, while the type assignments
Tˆ
jk are still based on a first step clustering
routine applied to the cross-sectional wages of job stayers.
Bonhomme et al. (2023) find in both Monte Carlo exercises and real
datasets that both their CRE estimator and the cross-fitting estimator of Kline
et al. (2020) successfully address limited mobility bias. On average the para-
metric CRE estimator yields modestly smaller firm effect estimates than the
bias-correctedestimatorbasedoncross-fitting.Itisdifficulttoassesstheextent
to which these differences arise from violations of the functional form
assumptions baked into the CRE model. A traditional justification for CRE
methods is that, by exploiting additional restrictions, they can offer more
efficient(albeitlessrobust)estimates(Chamberlain,1982;AngristandNewey,
1991). Monte Carlo evidence suggests that the CRE estimates of variance
components are indeed likely to be more efficient than the cross-fitting esti-
mator when the CRE assumptions hold. Hence, the CRE approach may be
useful in small samples where precision is a practical concern. Another
potentiallyimportantusecasefortheCREestimatorissettingswithextremely
limitedmobility,whererestrictingtotheleave-outconnectedsetwoulddropan
unacceptably large share of the units under study (e.g., Fenizia, 2022). When
using such approaches, it may be worthwhile to pursue iteratively updated
versions of the estimator, which have been found to yield improved perfor-
mance in some settings (Bonhomme et al., 2019; Lentz et al., 2022).

Firmwageeffects Chapter | 2 159
4.4 How variable are worker and firm effects?
Bias-corrected estimates of worker and firm contributions to wage inequality
have now been reported in many countries. The figure below depicts bias-
corrected estimates of worker and firm effect variability drawn from nine
recentstudiesutilizingthecross-fittingcorrectionofKlineetal.(2020).Rather
thanfocusonvariancesorvarianceshares,Icomparethestandarddeviationof
person effects to the standard deviation of firm effects, the units of which are
directlyinterpretableinlogpoints.Whenreported,multiplespecificationsfrom
the same study are included to illustrate the sensitivity of estimates to the
sample period and population. The list of studies depicted is provided in
Appendix Table A.1. Some studies that used bias corrections could not be
included because they failed to report the magnitude of the variance compo-
nents, relying on variance shares without reporting the marginal variance.
The45degreelinethroughtheoriginofFig.3giveswhatoneshouldexpectif
workerandfirmcomponentsareequallyimportantandscalewiththeoveralllevel
ofinequalityinaneconomy.Perhapssurprisingly,manyoftheestimateslievery
near this line. As expected, the scale of inequality appears most pronounced in
middleincomecountriessuchasMexico,SouthAfrica,andBrazil,whileItaly,the
US, and Sweden are relatively more equal in both dimensions. The estimates
fallingbelowthe45degreelinecomepredominantlyfromhighincomecountries
and from Brazil. Interestingly, these studies all find comparable standard devia-
tionsoffirmeffectsnear0.25.However,thestandarddeviationsofworkereffects
vary widely from sample to sample.
Tosomeextent,thisvariabilityofpersoneffectvariancesistobeexpected
giventhatmanyoftheestimatespartitionbyraceorsex,groupswithinwhich
FIG.3 Bias-correctedstandarddeviationsoffirmandworkerfixedeffectsbycountry.

160 HandbookofLaborEconomics
we expect person effects to be less dispersed. For example, four of the
Brazilian estimates are from Gerard et al. (2021), who report estimates sepa-
rately by race and sex using a 12 year panel, which accounts for some of the
lowest worker effect standard deviations in that country. However, person
effectvariancesalsoseemtovarywithotherfeaturesofthedataincludingthe
time horizon studied.
AbowdandMcKinney(2023),forexample,findanearlyidenticalstandard
deviation offirm effects in 3 year and 24 year extracts of annualized earnings
records from the LEHD. However, in the 3 year panel, the bias-corrected
standard deviation of person effects is roughly 50% larger than the standard
deviationoffirmeffects,whileinthe24yearpanel,thepersoneffectsexhibita
standard deviation roughly 33% below that of the firm effects. Likewise,
Lachowska et al. (2023) find using hourly wage data from Washington state
thatpersoneffectsaresubstantiallymoredispersedina2yearpanelthana12
year panel. While it is tempting to conclude that this sensitivity to time scale
reflects drift in the person effects, Lachowska et al. (2023) demonstrate that
person effect estimates remain strongly correlated across decades.
Recall that the variance of person effects among firm stayers cannot be
estimated by cross-fitting at the match level. A majority of the studies con-
sidered include firm stayers and it is reasonable to assume that these studies
treat the errors of firm stayers as serially independent, as this is the default
option provided in the most widely used software package used to implement
the cross-fitting correction.19 The estimated person effect variances may
therefore be subject to an upward bias stemming from neglected serial corre-
lation, albeit a smaller one than if no correction were implemented. It seems
likely then that the tendency for shorter panels to yield larger person effect
variances reflects this tendency to under-correct, as adjacent observations are
more strongly correlated. If the person effect variances are in fact upwardly
biased due to serial correlation, then it is even more surprising that so many
studies yield estimates near the 45 degree line.
Thoughtheestimatedpersoneffectvariancesappearsensitivetosample
composition, the firm effect standard deviations are remarkably resilient.
Among the estimates depicted here, the firm effect standard deviations all
exceed 0.15 and for high income countries cluster around 0.20. A poten-
tially useful comparison comes from Bonhomme et al. (2023), who esti-
mated decompositions using the CRE clustering method in harmonized
datasets of annualized earnings from five high income countries (Austria,
Italy,Norway,Sweden,andtheU.S.)Whiletheydonotreportpersoneffect
variances, averaging their estimates of the standard deviation of firm
effects across countries and samples yields a mean value of roughly 0.14,
which is a bit below the estimates reported for rich countries in the figure
19Seehttps://github.com/rsaggio87/LeaveOutTwoWayfordetails.

Firmwageeffects Chapter | 2 161
above.20 Some of this discrepancy is likely attributable to their procedure
for harmonizingsamplesacrosscountrieswith differentearnings measures.
In the U.S., data limitations require them to study annual earnings.
Bonhommeetal(2023, AppendixFigureF10)showinNorwegiandatathat
usingannualratherthanhourlyearningssubstantiallylowersestimatedfirm
effect variances. To facilitate comparisons between the U.S. and European
countries,theyimposeonallsamplesaminimumannualearningsthreshold
of 32.5% of thenational average, whichin theU.S. approximatesthefull time
earnings of minimum wage workers. However, selecting on the dependent
variablereducesitsvariabilityandBonhommeetal(2023,AppendixFigureF2)
documentinU.S.datathatimposinghigherminimumearningsthresholdsyields
lower firm effect variances.
A reasonably informed guess then, is that across a wide range of high
income countries, the standard deviation of firm effects in daily or hourly
wages typically ranges between 15 and 20log points. For middle income
countries, the standard deviation of firm effects appears to be higher, perhaps
ashighas0.4insomecases.Itisplausiblethatfirmeffectsaremoreimportant
in developing countries, where search frictions and misallocation have been
argued to be more prevalent (Hsieh and Klenow, 2009). However, many of
these studies are very recent and have yet to clear peer review. It will be
important to see estimates from more countries and research teams before
drawing strong conclusions about the relationship between economic devel-
opment and the dispersion in firm pay components.
The median firm effect standard deviation estimate among all those pic-
tured in Fig. 3 is 0.26 and an unweighted average of them is 0.30. If, in high
income countries, the standard deviation of firm wage effects is somewhere
between 15 and 20log points, then switching to a standard deviation higher
firm yields wages 16–22% higher – a very substantial effect size. For com-
parison, Chetty et al. (2011) estimate that a standard deviation increase in
kindergarten classroom quality in the Project STAR experiment raises adult
earningsby13%points.Thesefindingssuggestworkplaceheterogeneityisan
important contributor to wage inequality.
5 Regressing firm effects on observables
Examininghowfixedeffectscovarywithobservablescanhelptodemystify
the nature of these fundamentally unobservable objects. Many of the
empirical findings summarized in Section 2 were derived from regressing
estimated firm fixed effects on observed features of workers and firms.
Besides greater robustness to modeling assumptions, an important advan-
tage of fixed effects methods over more structured random effects
20Bonhomme et al. (2023) report the match-weighted variance of firm effects rather than the
person-yearweightedvariance.

162 HandbookofLaborEconomics
approaches (e.g. Hanushek, 1974; Amemiya, 1978) is that fixed effect
estimates can be shared with different research teams, who can subse-
quently use them to examine different downstream hypotheses via “second
step” regressions. I will now review the logic of these downstream
regressionsanddiscussthesubtletiesofinferenceonsecondstepprojection
coefficients. These ideas will be illustrated with the example of estimating
| the | firm | size wage | premium | in  | the VHW | data. |     |     |
| --- | ---- | --------- | ------- | --- | ------- | ----- | --- | --- |
| 5.1 | One  | step      | vs two  |     |         |       |     |     |
Supposeweareinterestedintherelationshipbetweenthevectorofpopulation
firm effects ψ and a set of firm covariates such as firm size and the average
educationlevelofthefirm’semployees.Descriptiverelationshipsofthisnature
| are | often | summarized | with | linear | projections | of   | the form |     |
| --- | ----- | ---------- | ---- | ------ | ----------- | ---- | -------- | --- |
|     |       |            |      |        | = Z         | + v, |          |     |
where Z is a matrix of firm covariates and the parameter of interest is
|          | (ZZ) | 1Z                |                  |          |         |            |               | 0.   |
| -------- | ---- | ----------------- | ---------------- | -------- | ------- | ---------- | ------------- | ---- |
| =        |      | .                 | By construction, |          | the     | projection | error v obeys | Zv = |
| Plugging |      | this relationship |                  | into (6) | yields: |            |               |      |
|          |      |                   | Y                | = D      | + F     | Z + F      | v + .         |      |
|          |      |                   | m                | m        | m       |            | m m           |      |
SincetheprojectionerrorvisorthogonaltoZ,onemightbetemptedby
this representation to estimate θ from a least squares regression of Y on
m
(D , F Z) – i.e., on person dummies plus the firm characteristics.
m m
There are two difficulties with this logic. The first objection, which is
largely pedantic, has to do with weighting. The cross product
|     | (F  | Z) F v | =     | ZF  | F v willnot,in |     | general, equalzerounless |     |
| --- | --- | ------ | ----- | --- | -------------- | --- | ------------------------ | --- |
| m   | [M] | m m    | m [M] |     | m m            |     |                          |     |
all firms are the same size. Hence, orthogonality need not hold in the
microdata even if it holds across firms. Of course, if we had initially
θ
defined the estimand as the firm size weighted projection, then the
| relevant |     | v would | satisfy | orthogonality |     | in the | microdata. |     |
| -------- | --- | ------- | ------- | ------------- | --- | ------ | ---------- | --- |
AmoresignificantobjectionisthatevenifF visuncorrelatedwithF Z,it
|     |     |     |     |     |     |     | m   | m   |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
isstilllikelytobecorrelatedwithD m .Thefactthathigherwageworkerstend
to work at higher wage firms suggests D F v > 0, which violates the
|     |     |     |     |     |     | m [M] | m m |     |
| --- | --- | --- | --- | --- | --- | ----- | --- | --- |
exogeneity requirements of least squares. This violation will not only tend to
generatebiasintheestimatedpersoneffectsbutalsoinestimatesofθbecause
F Z is correlated with D . Hence, unless one has a strong reason to suspect
| m   |     |     |     | m   |     |     |     |     |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
that the elements of Z account for all of the correlation between worker and
firmwageeffects,droppingthefirmdummiesascontrols(i.e.,treatingvasan
| uncorrelated |     | random | effect) | will | tend to | generate | bias. |     |
| ------------ | --- | ------ | ------- | ---- | ------- | -------- | ----- | --- |
ˆ
The two step approach is to first compute the fixed effects and then
|     |     |     |     |     |     |     | ˆ   | ˆ   |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
regress them on Z to obtain the projection coefficient = (ZZ) 1Z . Under
strict exogeneity, the firm effects are unbiased. The projection coefficient,
which is just a linear combination of the estimated firm effects, inherits this

Firmwageeffects Chapter | 2 163
property, obeying
[ˆ]
= . Hence, the two step estimator provides robust
estimates of the projection regardless of the dependence between worker and
firm effects.
Another advantage of the two step estimator is that it can foster scientific
ˆ
cooperation: the research team that produces need not be the team that has
access to Z. Fixed effects estimates are often computed once on population
microdatabyexpertresearchersandthenmadeavailabletooutsideteamswho
may not have access to the same microdata files (e.g., Bellmann et al., 2020).
Thesesortsofdatasharingarrangementsenableabroaderrangeofhypotheses
and external data sources to be brought to bear on questions of scientific
interest.
5.2 Variance estimation
The variance of the estimated projection coefficient is
[ˆ] = (ZZ) 1Z [ˆ]Z(ZZ) 1.
While second step regressions will yield unbiased estimates of linear pro-
jection coefficients, the standard errors produced by conventional software
ˆ
packages will mistakenly assume that the noise is independent across
firms – i.e., that
[ˆ]
is diagonal. Neglecting correlation between the esti-
matedfirmeffectscanleadtosevereunderstatement(oroverstatement)ofthe
uncertainty in second step regression coefficients.
The sign of this bias in the estimated standard errors is theoretically
ambiguous because the residuals from the second step regression will tend to
overstate the intrinsic noise level of each estimated fixed effect. To take an
extremeexample,supposethatthewagedisturbancesε in(1)areexactlyzero.
it
In such a case, the first step regression will fit perfectly, yielding ˆ = .
However, a second step regression of firm fixed effects on observed firm
characteristicswillnonethelessyieldresidualscapturingunexplainedvariation
in the vector ψ of true firm effects. Consequently, conventional software
packages will produce a positive standard error estimate despite the fact that
the true firm effects are fixed and exhibit no uncertainty.
Standard errors reflecting only the uncertainty associated with the ε are
it
easilycomputedbyusingthecross-fitvarianceestimatesintroducedin(7).For
example, Kline et al. (2020) considered a second step regression wherein Z
included a constant, the share of workers over age 35, firm size, and their
interaction. Note that, as in our earlier discussion of cross-fitting, interest
centers on the finite population of J firms actually measured in our dataset
ratherthananabstract“super-population”fromwhichthosefirmsweredrawn.
Replacing the unknown
[ˆ]
with
ˆ [ˆ]
yields an unbiased estimate of the
variance of the second step regression coefficient that can be used for

164 HandbookofLaborEconomics
inference. Fortunately, computation does not require that the entire
ˆ [ˆ]
matrix be computed or stored.21
Whileitisstraightforwardforresearchagenciestoreleasefixedeffectestimates
tothe public alongwith their (squared)standarderrors,it is not feasibleto release
entire variance matrices. In principle, one could conduct inference relying only on
the fixed effect standard errors by considering worst case correlation patterns.
However,doingsocouldleadtoextremelyconservativeinferences.Aninteresting
areaforfutureworkisunderstandingwhatlowdimensionalfeaturesof
ˆ [ˆ]canbe
reported that would enable accurate inference on projection coefficients without
knowledge of theZ under consideration by theresearch team.22
5.3 Revisiting the firm size wage premium
Fig. 4 illustrates the use of these methods by studying how the relationship
between firm effects and firm size varies by province in Veneto. Returning to
the firm effect estimates studied in Table 2, the matrix Z is chosen to include
indicatorsforthefirmsizecategoriesutilizedbyBloometal.(2018)interacted
with indicators for which of Veneto’s seven provinces contains the firm in
question. As a normalization, the smallest firm size category of 1–10
employees has been set to zero in each province, so that each of the included
estimatesrepresentsawithinprovincefirmsize“premium.”Toreduceclutter,
we have dropped the province of Rovigo which is so small that it lacks any
firms in the largest two size categories. By contrast, more than one thousand
firms are present in each size category of the pictured provinces.
Confidence intervals based on naive heteroscedasticity-robust standard errors
computed via a second step regression are shown alongside those based on the
cross-fit variance matrix
ˆ [ˆ].
The cross-fit standard errors reflecting uncertainty
attributable to ε turn out to be about 75% larger than the naive standard errorson
average. As a result the 95% confidence intervals based on cross-fitting bracket
thosebasedonnaivestandarderrors.Evidently,thedownwardbiasinnaivestandard
errors attributable to neglecting correlation among the estimated firm effects out-
weighs the upward bias attributable to treating the firm effects as random draws
from a broader population.
In all six pictured provinces, firm effects tend to increase with firm size.
However, the size profiles differ substantially across provinces and in some
cases appear non-monotone. In Verona and Padova the largest firms exhibit
fixed effects averaging approximately 40log points more than the smallest
firms,whileinVenicethecorrespondinggapinfirmwageeffectsisonlyabout
9log points. These orderings reverse, however, in the next largest firm size
21A computationally efficient approach to estimation of [ˆ]is automated and detailed in the
LeaveOutTwowaypackageavailableathttps://github.com/rsaggio87/LeaveOutTwoWay.
22Forexample,inalowerdimensionalcontext,FirthandDeMenezes(2004)proposereporting
“quasi-variances”thatcanbeusedforinferenceonunknowncontrasts.

|     |     |     | Firmwageeffects | Chapter | | 2 165 |
| --- | --- | --- | --------------- | --------- | ----- |
FIG.4 Meanfirmeffectsbyfirmsizeandprovince.Notes:Samplecomprisedoffirmsinleave-
outconnectedsetdescribedinTable2.Barheightgivescoefficientfromsecondstepregressionof
firm effects onto province indicators plus interactions with indicators for firm size category.
Omitted firm size category in each province is 1–10. Both confidence intervals derived by
adding± 1.96standarderrorstothepointestimate.Outerconfidenceinterval(depictedinblack)
ˆ [ˆ]Z(ZZ)
relies on (ZZ) 1Z 1 as estimator of the asymptotic variance. Inner confidence
|     |     | J   | ˆ)}2Z(ZZ) |     |     |
| --- | --- | --- | --------- | --- | --- |
interval (depicted in red) relies on (ZZ) 1Z{diag(M Z 1 as estimator of the
J k
| asymptoticvariance,whereM | Z   | =I Z(ZZ) 1Z. |     |     |     |
| ------------------------- | --- | ------------ | --- | --- | --- |
category. In Venice, for example, firms with 1,000–2,500 employees are
estimated to pay roughly 22log points more than firms with 1–10 employees,
| while in Verona | the premium | is only 13log | points. |     |     |
| --------------- | ----------- | ------------- | ------- | --- | --- |
While the premiums relative to the base firm size category are precisely
estimated in each province, it is not completely obvious which of these pre-
miums differ from one another given that the estimates are all correlated. A
useful rule of thumb is that we can conclude that the estimands are different
from one another if their confidence intervals do not overlap.23 Based on this
heuristic, we can safely infer that in both Venice and Treviso the firm size
premium in the 1,000–2,500 employee category exceeds the premium in the
2,500–10,000 employee category, indicating that the firm size premiums are
| not monotone | in these regions. |     |     |     |     |
| ------------ | ----------------- | --- | --- | --- | --- |
23For any two estimators ˆ and ˆ 2, we have (ˆ ˆ )= (ˆ )+ (ˆ ) 2 (ˆ , ˆ )
|     | 1   |     | 1 2 | 1 2 | 1 2 |
| --- | --- | --- | --- | --- | --- |
{ (ˆ )1/2+ (ˆ )1/2}2, where the upper bound binds with equality when the two estimators are
| 1   | 2   |     |     |     |     |
| --- | --- | --- | --- | --- | --- |
perfectlynegativelycorrelated.Consequently, (ˆ )1/2+ (ˆ )1/2 providesaconservativestandard
|     |     |     | 1 2 |     |     |
| --- | --- | --- | --- | --- | --- |
error on the difference between the estimators. A test that evaluates whether
ˆ ˆ >c[ (ˆ )1/2+ (ˆ )1/2] forsomecriticalvaluec(e.g.,1.96asinFig.4)amountsto
| 1 2 | 1   | 2   |     |     |     |
| --- | --- | --- | --- | --- | --- |
evaluatingwhether[ˆ c (ˆ )1/2, ˆ +c (ˆ )1/2] [ˆ c (ˆ )1/2, ˆ +c (ˆ )1/2]= .
|     | 1 1 | 1 1 | 2 2 | 2 2 |     |
| --- | --- | --- | --- | --- | --- |

166 HandbookofLaborEconomics
We can also infer that size premiums tend to differ by region, though our
visual rule of thumb becomes less decisive in smaller firm size categories. To
obtain a more accurate assessment of regional differences in the average pre-
mium for firms with 10–50 employees, I reparameterize Z to include inter-
actionsbetweenprovinceandfirmsizecategories.Theresultingstandarderror
estimatesrevealthatitispossibletorejectatthe5%levelthenullhypothesis
that the premiums in the 10–50 employee category are equal in Venice and
Vicenza. By contrast, the premiums in Vicenza and Treviso cannot be dis-
tinguished from each other even at the 10% level.
6 Hiring origins and state dependence
The basic AKM specification views wage determination as fundamentally
static: the expected wage arising from a match between a worker and firm
depends only on their underlying (time-invariant) types. Search theoretic
models, by contrast, often predict that wages should be influenced by the
circumstances surrounding how the match was formed – e.g., whether the
worker was “poached” from another firm or hired from unemployment, as
unemployedworkerstypicallyhaveworseoutsideoptionsthantheiremployed
counterparts.Consistentwiththisview,Fabermanetal.(2022)providesurvey
based evidence that job offers received by currently employed workers pay
higher wages than those received by unemployed workers with similar char-
acteristics.
An influential framework for modeling such state dependence comes from
the class of sequential auction models pioneered by Postel-Vinay and Robin
(2002a,b), where on the job search gives rise to a series of bilateral competi-
tions between firms for workers. These competitions mirror second-price
auctions,withfirmstailoringtheirwagebidsbaseduponthewillingnesstopay
of the rival they face. Consequently, the wages offered to new hires differ
basedonwhereaworkerishiredfromandwhichfirmishiringthem.Tailoring
of this nature can, in principle, contribute greatly to cross-sectional inequality
by amplifying the role of luck: an early job displacement can lower wages
throughout a worker’s career by persistently degrading their outside options.
Di Addario et al. (2023) study the empirical predictions of sequential
auction models for hiring wages using an extension of the AKM model, in
which a separate fixed effect is allowed for each possible hiring origin. These
hiring origin fixed effects are meant to proxy for the worker’s outside option.
LettingY denotetheloghiringwageoftheithworkerattheirm’thjob,they
im
consider a linear model taking the form:
Y = + + + X + , fori [n], m [M].
im i j(i,m) h(i,m) im i (10)
destination effect origin effect

Firmwageeffects Chapter | 2 167
Here, the function j: [n] × [M i ] [J] returns the identity of the firm hiring
the worker at their m’th job. The function h: [n] × [M i ] [J] {U}returns
theoriginofthenewhire,whichcaneitherbetheidentityofaprioremployer
from which the worker was “poached” or unemployment (denoted as “U”).
Thus, each firm j has a pair( j , j ) of fixed effects.
DiAddarioetal.(2023)termthespecificationin(10)a“dualwageladder”
(DWL) model because hiring wages depend on two dimensions of firm het-
erogeneity.AsintheAKMmodel,α isapersonfixedeffectthatcanbeported
i
from employer to employer, while the vector X includes time varying cov-
im
ariates, including work experience and indicators for the year that the match
was formed. The term is a destination firm fixed effect that, like the
j(i,m)
traditional AKM firm effect, must be forfeited upon separating from the
employer. The distinctive feature of the DWL specification is the origin firm
fixedeffect, h(i,m),whichcapturesaformofstatedependenceinwagesetting.
AccordingtotheDWLmodel,twoworkerswiththesameα,hiredbythesame
i
firm from two different origins – e.g., non-employment and the most pro-
ductive firm in the economy – will be paid different wages.
Theerrorε measuresomittedfactorsthatvaryacrossmatchesatthetime
im
ofhiring.Eachoftheseerrorsisassumedtohavemeanzero,whichisaversion
of the traditional exogenous mobility assumption used to justify least squares
estimation. An important feature of standard sequential auction models is that
bilateral competitions are presumed to be efficient: i.e., the more productive
firm always wins the auction. If firm productivity is time invariant, then
conditioning on j(i, m) and h(i, m) is equivalent to conditioning on the pro-
ductivity of the origin and destination firm, which given log-linear wage
contracts implies the errors{ im } i [n],m [M] are strictly exogenous.
i
6.1 Structural interpretation
DiAddarioetal.(2023)showformallythatthemodelofBaggeretal.(2014),
which nests the seminal model of Postel-Vinay and Robin (2002b) when
consumption utility is assumed to be logarithmic, yields (10) as the reduced
form for hiring wages. It is useful to review this argument both to understand
the structural interpretation of the origin and destination fixed effects and the
justificationfortheexogenousmobilityassumptiononthereducedformerrors.
The Bagger et al. (2014) model implies that the log hiring wage offered by a
firm of productivity level p, to a worker of productivity type ϵ, with labor
marketexperience ,whoiscurrentlyemployedatafirmofproductivityqcan
be written as the generalized linear function
( ) + g( ) + (p) + (q) + .
Hires from unemployment follow the same equation with the productivity of
theincumbentfirmqsetequaltotheflowvalueofleisureb,whichisassumed
to be common for all workers.

168 HandbookofLaborEconomics
The term ( ) is a worker fixed effect capturing general human capital,
which is rewarded equally by all employers. Likewise, g( ) captures the
returnstoexperience,whiletheerrorterm capturesidiosyncraticinnovations
to the worker’s general human capital. By assumption, neither of these terms
influence worker mobility, which depends solely on the firm productivities p
and q. The destination firm effect, (p), equals lnp + I(p, ), while the
hiringorigineffect, (q),isgivenby(1 )lnq I(q, ),where [0, 1]
indexesworkerbargainingstrength.Thefunction I(p, ),whichisdecreasing
in both its arguments and obeys I(p, 1) = 0, captures the expected utility of
thewagegrowthassociatedwithmovingfromafirmwithproductivityptothe
mostproductivefirmintheeconomy.Hence,thedifferenceI(p, ) I(q, )
captures the expected utility of the wage growth associatedwith moving from
an incumbent firmwith productivity q to a poaching firm with productivityp.
Inspection of these equations reveals that when β is small, the destination
effect (p)willbedecreasinginp,whichcanbeinterpretedasacompensating
differential for the anticipated wage growth associated with moving. By con-
trast,foranyvalueofβ < 1, (q)willbeincreasinginq,whichreflectsthatit
ismoredifficulttopoachworkersfromfirmsthatcanaffordtopaythemmore.
When β=1, the term (q) becomes zero and the model reduces to a version
of the AKM model with only destination firm effects. Remarkably,
(p) + (p) = lnp foranyvalueofβ,implyingthatafirm’sproductivitycan
berecoveredbysummingitsoriginanddestinationeffects.Sinceworkersview
more productive firms as fundamentally more desirable than less productive
firms,thissumrecoverstheorderingoftheunderlying“jobladder”inexpected
utility governing worker flows.
6.2 Testable restrictions
IntheBaggeretal.(2014)model,firmsaredifferentiatedonlybyproductivity.
Consequently, the origin and destination effects are deterministic functions of
one another. Di Addario et al. (2023) show that it is possible to exploit this
featureofthemodeltoboundthebargainingpowerofworkersusingtheexcess
varianceofthedestinationeffectsovertheorigineffects.Letting p denotethe
variance across firms, the following bound on β is obtained by exploiting the
fact that I(p, ) [ (1 )2/ , 0]:
lnp
[ (p)] [ (p)]
p p
1/2 + .
(11)
2 [ (p) + (p)]
p
As discussed earlier, if β were very close to 1, we should expect the origin
effectstobenegligibleandfordestinationeffectstobelargeasworkersextract
from firms the greatest wage they can afford: lnp. This bound formalizes the
converse idea that when destination effects are large relative to origin effects,
worker bargaining power must be strong. When β > 1/2, the following lower

Firmwageeffects Chapter | 2 169
boundcanbeshowntoholdonthecorrelationbetweenthetwodimensionsof
firm heterogeneity:
[ (p)] 3 [ (p)]
p p
corr( (p), (p)) 1 .
[ (p) + (p)] 10 [ (p) + (p)]
p p
Intuitively, when β is large, both the origin and destination effects must be
strongly increasing in productivity, yielding a high correlation. However, a
large β also yields relatively larger destination effects than origin effects. The
correlation bound formalizes this link, effectively providing a test of the pre-
sence of a unidimensional firm hierarchy.24
6.3 It ain’t where you’re from, it’s where you’re at
DiAddarioetal.(2023)fit(10)toItaliansocialsecuritydatausingtheaveragedaily
wageofeachworkerintheirfirstyearofemploymentwithafirmasaproxyfortheir
hiringwage.Apoachingeventispresumedtohavetakenplacewheneveraworker
resignsfromtheirjobasopposedtobeinglaidofforfiredforcause.Iftheworkerdid
not resign from their previous job, they are assumed to have been hired from
unemployment.Whiletherearereasonstosuspectthatstatedresignationsprovidean
imperfect proxy of when bilateral competition between firm pairs is taking place
(McLaughlin, 1991; Postel-Vinay and Turon, 2014), Italian workers poached
according to this criterion turn out to have much shorter durations of non-employ-
mentbetweenjobsthanworkersinvolvedinothersortsofseparations.
DiAddarioetal.(2023)findaroughly3.5logpointgapbetweentheestimated
valueofλ (theorigineffectassociatedwithunemployment)andtheaverageorigin
U
effectofpoachedworkers, n [ h(i,m) h(i, m) U],implyingamodestpenaltyfor
being hired from unemployment. The bias-corrected variance of origin effects,
n [ h(i,m) ], turns out to be extremely small, accounting for less than 1% of the
varianceofhiringwagesacrossjobmovers.Bycontrast,thevarianceofdestination
effects, n [ j(i,m) ],explains24%ofthevarianceofhiringwages.
AsmentionedinSection4,variancesharescanbesomewhatdifficulttointerpret
given that noise levels vary across samples. The estimated standard deviation of
destination effects in their sample of job movers is roughly 0.26, which is only
slightly above the typical bias-corrected standard deviation of AKM firm effects
reportedfortheUSandItalyinFig.3.Bycontrast,theorigineffectshaveastandard
deviationamongalljobmoversof0.04andastandarddeviationof0.08amongthe
roughly1/3ofjobtransitionsthatinvolvepoachinga workerfromanotherfirm.
While an 8% wage change is not negligible, this standard deviation of origin
effects turns out to be far less thanwould be predicted by the Bagger et al. (2014)
24Roussille and Scuderi (2023) reject a unidimensional model of firm valuations in favor of a
mixturemodelwiththreedistincthierarchiesusingdatafromanonlinejobboardforsoftware
engineers.

170 HandbookofLaborEconomics
model.Thestandarddeviationacrossfirmsofthedestinationeffects, p [ (p)]1/2,is
0.26 (the same as was found across workers), while the corresponding standard
deviation of origin effects, p [ (p)]1/2, is only 0.07. Applying the formula in (11)
implies that β≥0.88. In addition to being intuitively implausible, this value of β
would require an extremely high correlation between the origin and destination
effectsof0.84.Inpractice,thebias-correctedcorrelationisonly0.25,indicatingthat
the model cannot rationalize the covariance structure of the origin and destination
effectsunderanydistributionoffirmproductivities.
6.4 Information and conduct
The order of magnitude difference in scale between firm origin and destination
effects suggests either that the identity of one’s current employer doesn’t convey
much information about outside options at the time of a poaching attempt or that
firmsareunable(orunwilling)totailorofferstothoseoutsideoptions.Toassessthe
former hypothesis, one could collect more granular proxies of outside options.
Perhapsinteractingtheidentityoftheincumbentfirmwithdetailedjobtitlesortenure
wouldbemorepredictiveofhiringwages?Thesecondpossibility,thatfirmsarenot
ableorwillingtotailorwageoffers,ismoredifficulttoevaluate.Firmsoftenreport
having some latitude to tailor wages to worker circumstances and Caldwell et al.
(2024a)provideevidencethatwagesarestronglyrelatedtopreviousfirmpayamong
thosefirmsthatengageinbargaining.Ontheotherhand,surveyevidencesuggests
offer matching is rare empirically (Faberman et al., 2022; Caldwell et al., 2024a).
Moreover,receivinganoutsideofferdoesnotseemtobeassociatedwithlargewage
gainsonaverage(Guo,2023).
Eveniffirmstypicallydohavetheabilitytotailorwages,theinformational
requirements of tying wage offers to best predictors of outside options are
formidable. Sequential auctionmodelsare predicatedon a perfectinformation
benchmarkwhereeach firmknows thewillingness topayof therivalfirmfor
the worker in question, leading them to offer a rival dependent wage.25 By
contrast,thefamousBurdettandMortensen(1998)modeleffectivelyassumes
that firms know nothing about workers’ outside options, which is why they
offerthesamewagestounemployedworkersandworkerssearchingonthejob.
As Postel-Vinay and Robin (2002a) acknowledge “reality lies somewhere in
between our complete information story and Burdett’s and Mortensen’s
incomplete information assumption.”
How to think about this middle ground between wage posting and
sequentialauctionmodelsremainsafrontierareaofresearch.Oneapproachis
to view the economy as comprised of a mixture of wage posting firms ala
Burdett and Mortensen (1998) and tailoring firms ala Postel-Vinay and Robin
25Workersarealsoassumedtobefullyinformedaboutthematchsurplusavailableatthetworival
firms.Jägeretal.(2024)provideevidencesuggestingthatworkersatlowwagefirmstendto
underestimatetheiroutsideoptions.

Firmwageeffects Chapter | 2 171
(2002b). While coherent models of this nature have been proposed (Postel-
Vinayand Robin,2004; FlinnandMullins, 2017), empiricalevidence onhow
wage setting conduct varies across employers remains in its infancy. A
recurrent finding from estimation of these models is that counter offers and
negotiation are more common among higher skilled workers (Caldwell and
Harmon, 2019; Flinnand Mullins, 2021). This finding likely resonates among
academic economists, many of whom have experienced the majority of their
salary growth by receiving outside offers. Indeed, the sequential auction
paradigm of bilateral competition appears to be a good one for academia,
whichisahierarchicalindustrywhereemployershavegoodinformationabout
the ability of rival institutions to compete for talent. It is unclear how many
other labor markets are characterized by this sort of competition.
Breaking their variance decompositions down by industry, Di Addario et al.
(2023)findthatdestinationeffectsareordersofmagnitudemorevariablethanorigin
effects in most sectors of the Italian economy. The key exceptions are finance/
bankingandthelegalsector,whereoriginanddestinationeffectsexhibitcomparable
variability. Both of these sectors are hierarchical and plausibly exhibit more infor-
mationregardingtheabilityoffirmstopaytoretainworkersthanothersectors.The
finance/banking industry is the only sector where the correlation bound is satisfied,
suggesting perhaps that it too exhibits the sort of unidimensional competition
describedinsequentialauctionmodels.Inlessskilledsectors,bycontrast,employers
arelikelymoredifficulttorank.Asaresult,lessinformationmaybeconveyedbythe
identity of one’s previous employer. In these settings, worker outside options seem
more likely to be private information, an idea that is central to the idea of mono-
psonisticmodelsofwagesetting.
7 Conclusion
While much has been learned about which firms pay high wages and their
contribution to wage inequality, plenty of work remains. Some questions this
review has touched upon that appear particularly ripe for exploration include:
1. DispersionandDevelopment:Whyarefirmwageeffectsmoredispersed
in less developed countries? One possibility is that labor market frictions
are more pronounced in these economies, leading to greater misallocation.
Another is that measurement differences, especially the prevalence of
informal work, play a confounding role.
2. AccountingforCycles:Whataccountsforthecycliccomponentofedgeeffects?
Cyclescouldreflecteithereconomicshockssharedbycloselyconnectedfirmsor
differences in the sorts of workers moving along different parts of the mobility
network. The former view has difficulty explaining the documented stability of
firm effects. The latter interpretation suggests something important may have
been missed by existing models of non-separable wages, estimates of which
typicallyexhibitsmalldeparturesfromlinearity.

172 HandbookofLaborEconomics
3. Intransitive Firms: To what extent do firm rankings, in both wages and
desirability, vary with worker and job characteristics? Does accounting for this
heterogeneityamplifyormutethetotalcontributionoffirmstoinequality?
4. Hiring Origins and Conduct: When and where do hiring origins matter
forwagedetermination?Domarketswherethedispersionoforigineffects
islargerexhibitgreaterwageeffectsofreceivingoutsideoffers?Howdoes
the reason for separation (e.g., ostensible quits vs layoffs) influence the
degree of state dependence in wages?
5. Worker Mobility Post-Layoff: Why do mass layoffs sometimes lead
workers to move to higher-wage firms? Does the prevalence of this
behavior vary with labor market institutions?
6. Understanding Network Structure: What network formation models produce
realisticmobilitypatterns?Howeffectivearethesemodelsatpredictingthenext
firm that will employ a worker? How do network-based definitions of labor
marketsalign withworkers’perceptionsasmeasuredinsurveys?
7. Reproducibility: How can fixed effect estimates be shared most effec-
tively? Transparency and replicability are crucial components of the data
sciencerevolution(Donoho,2024).Futureworkcouldenablewideraccess
notonlytopointestimatesbutalsotomeasuresofuncertainty,loweringthe
barriers to downstream inference and prediction.
Appendix: Covariance between person and firm effects
Here, I detail how to construct an unbiased estimator of [ˆ i , ˆ j ] for each (i,j) pair in
[N]×[J 1]thatcanbeusedtobiascorrectthecovariance.Ithendiscusshowboundscan
beformedonthecovariance.
From(6),wecanwritetheOLSestimators
1
ˆ = + D˜ D˜ D˜ ,
m m m m
m [M] m [M]
1
ˆ= + F˜ F˜ F˜ ,
m m m m
m [M] m [M]
where D˜ m is the matrix of worker indicators after having partialled out the matrix of firm
indicators.Hence,
1 1
(ˆ )(ˆ ) = D˜ D˜ D˜ F˜ F˜ F˜
m m m m m m m m
m [M] m [M] m [M] m [M]
1 1
= D˜ D˜ D˜ ˜ F˜ F˜ F˜
m m m m m m m m
m [M] m [M] m [M]
1 1
+ D˜ D˜ D˜ F˜ F˜ F˜ .
m m m m l m m
m [M] m [M] l m m [M]

|     |     |     | Firmwageeffects |     | Chapter | |   | 2 173 |
| --- | --- | --- | --------------- | --- | ------- | --- | ----- |
Independenceacrossmatchesimpliesthatthefinallinehasexpectationzero,allowingusto
write
|         |      |     | 1   |     |     |       | 1   |
| ------- | ---- | --- | --- | --- | --- | ----- | --- |
| [(ˆ )(ˆ | ) ]= | D˜  | D˜  | D˜  | F˜  | F˜ F˜ | .   |
|         |      | m   | m   | m m | m   | m m   |     |
|         | m    | [M] | m   | [M] | m   | [M]   |     |
Wecanestimatethiscovariancematrixwith
|       |      |     | 1   |      |     |       | 1   |
| ----- | ---- | --- | --- | ---- | --- | ----- | --- |
| ˆ )(ˆ |      | D˜  | D˜  | D˜ ˆ | F˜  | F˜ F˜ |     |
| [(ˆ   | ) ]= | m   | m   | m m  | m   | m m   | .   |
|       | m    | [M] | m   | [M]  | m   | [M]   |     |
The lower triangle of this estimated matrix gives the relevant unbiased estimators
ˆ [ˆ , ˆ ] of [ˆ , ˆ ]. The debiased estimator of covariance between person and firm
| i j i | j   |     |     |     |     |     |     |
| ----- | --- | --- | --- | --- | --- | --- | --- |
effectsis:
|     | ˆ   | [ˆ ˆ       | ˆ   | [ˆ, ˆ        |     |     |     |
| --- | --- | ---------- | --- | ------------ | --- | --- | --- |
|     | , = | n i j(i,t) |     | i j(i,t) ]]. |     |     |     |
Toboundthiscovarianceinthebroaderconnectedsamplethatisnotleaveoutconnected,we
canagainapplythebound0 [Y Y ].Upwardlyanddownwardlybiasedestimatorsof
|     | m   | m   |     |     |     |     |     |
| --- | --- | --- | --- | --- | --- | --- | --- |
|     | [(ˆ | )(ˆ |     |     | ˆ   |     |     |
therelevantcovariances ) ]areobtainedbyreplacing mwithY m Y m orzero,
|     |     |     |     | ˆ   | )(ˆ |     |     |
| --- | --- | --- | --- | --- | --- | --- | --- |
respectively,injust-connectedmatchescontributingto [(ˆ ) ].Onethenapplies
ˆ
the bias correction formula above replacing ˆ [ˆ , ] with either its upwardly or down-
|     |     |     | i   | j(i,t) |     |     |     |
| --- | --- | --- | --- | ------ | --- | --- | --- |
wardlybiasedestimate(Fig.A.1)and(TableA.1).
FIG.A.1
Noiselevelbynumberofmoversperedge.Notes:Theverticalaxisdepictsthenatural
ˆ[ˆ ]
logarithm of the average of among edges with a given number of movers. Number of
moversconsideredrangesfrom2to10.Thelineofbestfit(depictedabove)hasintercept−3.325
andslope−1.118whenfitonedgesthatarebridgesandaninterceptof−3.126andslope−1.087
when fit on edges that are not bridges. Using these lines of best fit to impute the variance of
singleton edges, the imputed noise level of singleton bridges is exp( 3.325) 0.036 and the
imputednoiselevelforsingletonedgesthatarenotbridgesisexp( 3.12) 0.044.

voC*2
| 920.0      | 570.0 420.0 | 250.0 021.0 | 070.0 890.0 790.0 | 500.0 601.0 340.0 | 420.0 201.0 |
| ---------- | ----------- | ----------- | ----------------- | ----------------- | ----------- |
| mriF 420.0 | 340.0 230.0 | 520.0 781.0 | 270.0 611.0 650.0 | 230.0 073.0 920.0 | 140.0 370.0 |
raV
rekroW
| 211.0 | 052.0 582.0 | 333.0 671.0 | 451.0 914.0 483.0 | 970.0 884.0 070.0 | 740.0 361.0 |
| ----- | ----------- | ----------- | ----------------- | ----------------- | ----------- |
raV
| latoT 481.0 | 704.0 063.0 | 624.0 907.0 | 444.0 886.0 775.0 | 862.0 023.1 671.0 | 061.0 944.0 |
| ----------- | ----------- | ----------- | ----------------- | ----------------- | ----------- |
raV
| 1002,9991 | 4102–2002 3002–2002 | 4102–3102 8991–4991 | 8102–4102 1002–8991 3102–1102 | 6102–5891 6102–1102 5102–5991 | 5102–5991 4102–2002 |
| --------- | ------------------- | ------------------- | ----------------------------- | ----------------------------- | ------------------- |
sraeY
nemetihW,lizarB
etatSnotgnihsaW etatSnotgnihsaW etatSnotgnihsaW
nemoW,ylatI
| ylatI,oteneV |     |     |     | acirfAhtuoS |     |
| ------------ | --- | --- | --- | ----------- | --- |
/yrtnuoC
neM,ylatI
nedewS
noigeR
|     |     | lizarB | lizarB lizarB lizarB |     |     |
| --- | --- | ------ | -------------------- | --- | --- |
.3 .giF
| ecruoS 2elbaT     | 3elbaT 2elbaT | 2elbaT 2elbaT | 1elbaT | 3elbaT 2elbaT | 2elbaT |
| ----------------- | ------------- | ------------- | ------ | ------------- | ------ |
| nidedulcniseidutS |               |               |        | elbaT         |        |
2.D
)3202(.lateakswohcaL
oiznattaLdnaocirasaC
|     |     |                | )3202(lekcniwnaaH | )3202(.latemobgnE |                   |
| --- | --- | -------------- | ----------------- | ----------------- | ----------------- |
|     |     | resoMdnamobgnE |                   |                   | )1202(.latedrareG |
)0202(.lateenilK
)3202(reissaB
1.AELBAT
| ydutS |     | )2202( |     |     | )3202( |
| ----- | --- | ------ | --- | --- | ------ |

| 850.0 321.0 060.0                 | 740.0 350.0 990.0             | 111.0 121.0 320.0             | 810.0 450.0 180.0             |
| --------------------------------- | ----------------------------- | ----------------------------- | ----------------------------- |
| 450.0 570.0 540.0                 | 660.0 171.0 391.0             | 622.0 432.0 730.0             | 830.0 521.0 402.0             |
| 001.0 912.0 441.0                 | 380.0 651.0 252.0             | 432.0 022.0 680.0             | 710.0 912.0 541.0             |
| 233.0 894.0 423.0                 | 972.0 595.0 695.0             | 726.0 826.0 033.3             | 324.3 035.0 275.0             |
| 4102–2002 4102–2002 4102–2002     | 5102–5002 0202–0002 8002–4002 | 3102–9002 8102–4102 4102–2102 | 7102–4991 4102–6002 4102–6002 |
| etihW-non,lizarB etihW-non,lizarB |                               |                               |                               |
evitaN,anihC tnargiM,anihC
etihW,lizarB
ainauhtiL
| nemow | nemow ocixeM     | ocixeM ocixeM |        |
| ----- | ---------------- | ------------- | ------ |
|       |                  | DHEL          | DHEL   |
| nem   | ylatI            |               |        |
|       | /3elbaT 4.AelbaT |               |        |
|       | 2elbaT           | 4elbaT        | 2elbaT |
3.A
)3202(.lateoiraddAiD
yenniKcMdnadwobA
amsedeL-onuNzereP
dnaoazuoL-aicraG
)4202(.lateouG
)3202(ireigguR
)2202( )3202(

176 HandbookofLaborEconomics
References
Abowd, J.M., Card, D., 1989. On the covariance structure of earnings and hours changes.
Econometrica57(2),411–445.
Abowd,J.M.,Creecy,R.H.,Kramarz,F.,etal.,2002.Computingpersonandfirmeffectsusing
linkedlongitudinalemployer-employeedata.TechnicalReports,CenterforEconomicStudies
(USCensusBureau).
Abowd, J.M., Kramarz, F., Lengermann, P., McKinney, K.L., Roux, S., 2012. Persistent inter-
industry wage differences: rent sharing and opportunity costs. IZA Journal of Labor
Economics1,1–25.
Abowd, J.M., Kramarz, F., Margolis, D.N., 1999. High wage workers and high wage firms.
Econometrica67(2),251–333.
Abowd,J.M.,Lengermann,P.,McKinney,K.L.,2003.Themeasurementofhumancapitalinthe
USeconomy.Tech.rep.,Citeseer.
Abowd, J.M.,McKinney,K.L.,2023.Mixed-effectsmethodsfor searchand matchingresearch.
arXivpreprintarXiv:2308.15445.
Abowd,J.M.,McKinney,K.L.,Schmutte,I.M.,2019.Modelingendogenousmobilityinearnings
determination.JournalofBusiness&EconomicStatistics37(3),405–418.
Akerlof, G.A., Yellen, J.L., 1990. The fair wage-effort hypothesis and unemployment. The
QuarterlyJournalofEconomics105(2),255–283.
Amemiya, T., 1978. A note on a random coefficients model. International Economic Review
793–796.
Andrews,M.J.,Gill,L.,Schank,T.,Upward,R.,2008.Highwageworkersandlowwagefirms:
negativeassortativematchingorlimitedmobilitybias?JournaloftheRoyalStatisticalSociety:
SeriesA(StatisticsinSociety)171(3),673–697.
Andrews,M.J.,Gill,L.,Schank,T.,Upward,R.,2012.Highwageworkersmatchwithhighwage
firms: clear evidence of the effects of limited mobility bias. Economics Letters 117 (3),
824–827.
Angrist, J.D., Newey, W.K., 1991. Over-identification tests in earnings functions with fixed
effects.JournalofBusiness&EconomicStatistics9(3),317–323.
Armstrong, T.B., Kolesár, M., 2018. Optimal inference in a class of regression models.
Econometrica86(2),655–683.
Armstrong,T.B.,Kolesár,M.,2021.Finite-sampleoptimalestimationandinferenceonaverage
treatmenteffectsunderunconfoundedness.Econometrica89(3),1141–1177.
Bagger,J.,Fontaine,F.,Postel-Vinay,F.,Robin,J.-M.,2014.Tenure,experience,humancapital,
and wages: a tractable equilibrium search model of wage dynamics. American Economic
Review104(6),1551–1596.
Bagger,J.,Lentz,R.,2019.Anempiricalmodelofwagedispersionwithsorting.TheReviewof
EconomicStudies86(1),153–190.
Bassier,I.,Dube,A.,Naidu,S.,2022.Monopsonyinmovers:theelasticityoflaborsupplytofirm
wagepolicies.JournalofHumanResources57(S),S50–s86.
Bassier, I., 2023. Firms and inequality when unemployment is high. Journal of Development
Economics,161,103029.Chicago.
Bellmann, L., Lochner, B., Seth, S., Wolter, S., 2020. Institut für Arbeitsmarkt-und
Berufsforschung(IAB),Nürnberg[Institutefor….].
Bertheau,A.,Acabbi,E.M.,Barcelo,C.,Gulyas,A.,Lombardi,S.,Saggio,R.,2022.Theunequal
costofjoblossacrosscountries.Tech.rep.,IZADPNo.15033.

Firmwageeffects Chapter | 2 177
Bertheau,A.,Acabbi,E.M.,Barceló,C.,Gulyas,A.,Lombardi,S.,Saggio,R.,2023.Theunequal
consequences of job loss across countries. American Economic Review: Insights 5 (3),
393–408.
Bickel, P.J., Freedman, D.A., 1981. Some asymptotic theory for the bootstrap. The Annals of
Statistics1196–1217.
Bloom,N.,Guvenen,F.,Smith,B.S.,Song,J.,vonWachter,T.,2018.Thedisappearinglarge-firm
wagepremium.In:AEAPapersandProceedings,volume108,317–322.
Bonhomme, S., Holzheu, K., Lamadon, T., Manresa, E., Mogstad, M., Setzler, B., 2023. How
much should we trust estimates of firm effects and worker sorting? Journal of Labor
Economics41(2),291–322.
Bonhomme, S., Lamadon, T., Manresa, E., 2019. A distributional framework for matched
employeremployeedata.Econometrica87(3),699–739.
Boza,I.,Reizer,B.,2024.Theroleofflexiblewagecomponentsingenderwagedifference.
Bozzo,E.,2013.Themoore–penroseinverseofthenormalizedgraphlaplacian.LinearAlgebra
andItsApplications439(10),3038–3043.
Brown, C., Hamilton, J., Medoff, J.L., 1990. Employers Large and Small. Harvard University
Press.
Brown,C.,Medoff,J.,1989.Theemployersize-wageeffect.JournalofPoliticalEconomy97(5),
1027–1059.
Bruns,B.,2019.Changesinworkplaceheterogeneityandhowtheywidenthegenderwagegap.
AmericanEconomicJournal:AppliedEconomics11(2),74–113.
Burdett, K., Mortensen, D.T., 1998. Wage differentials, employer size, and unemployment.
InternationalEconomicReview257–273.
Cahuc,P.,Postel-Vinay,F.,Robin,J.-M.,2006.Wagebargainingwithon-the-jobsearch:Theory
andevidence.Econometrica74(2),323–364.
Caldwell,S.,Haegele,I.,Heining,J.,2024a.Bargaininginthelabormarket.
Caldwell,S.,Haegele,I.,Heining,J.,2024b.Firmpayandworkersearch.
Caldwell,S.,Harmon,N.,2019.Outsideoptions,bargaining,andwages:Evidencefromcoworker
networks.Unpublishedmanuscript,Univ.Copenhagen.
Cappelli,P.,Chauvin,K.,1991.Aninterplanttestoftheefficiencywagehypothesis.TheQuarterly
JournalofEconomics106(3),769–787.
Card,D.,Cardoso,A.R.,Heining,J.,Kline,P.,2018.Firmsandlabormarketinequality:evidence
andsometheory.JournalofLaborEconomics36(S1),S13–S70.
Card,D.,Cardoso,A.R.,Kline,P.,2016.Bargaining,sorting,andthegenderwagegap:quanti-
fyingtheimpactoffirmsontherelativepayofwomen.TheQuarterlyJournalofEconomics
131(2),633–686.
Card,D.,Heining,J.,Kline,P.,2013.WorkplaceheterogeneityandtheriseofwestGermanwage
inequality.TheQuarterlyJournalofEconomics128(3),967–1015.
Card,D.,Rothstein,J.,Yi,M.,2023.Industrywagedifferentials:Afirm-basedapproach.Tech.
rep.,NationalBureauofEconomicResearch.
Card,D.,Rothstein,J.,Yi,M.,2024.Industrywagedifferentials:afirm-basedapproach.Journalof
LaborEconomics42(S1),S11–S59.
Casarico, A., & Lattanzio, S., 2024. What firms do: Gender inequality in linked employer-
employeedata.JournalofLaborEconomics,42(2),325–355.
Cattaneo,M.D.,Jansson,M.,Newey,W.K.,2018.Inferenceinlinearregressionmodelswithmany
covariatesandheteroscedasticity.JournaloftheAmericanStatisticalAssociation113(523),
1350–1361.

178 HandbookofLaborEconomics
Chamberlain,G.,1982.Multivariateregressionmodelsforpaneldata.JournalofEconometrics18
(1),5–46.
Chamberlain,G.,1984.Paneldata.HandbookofEconometrics2,1247–1318.
Chen,M.,Fernández-Val,I.,Weidner,M.,2021.Nonlinearfactormodelsfornetworkandpanel
data.JournalofEconometrics220(2),296–324.
Chetty,R.,Friedman,J.N.,Hilger,N.,Saez,E.,Schanzenbach,D.W.,Yagan,D.,2011.Howdoes
yourkindergartenclassroomaffectyourearnings?Evidencefromprojectstar.TheQuarterly
JournalofEconomics126(4),1593–1660.
Chetty, R., Hendren, N., 2018. The impacts of neighborhoods on intergenerational mobility I:
Childhoodexposureeffects.TheQuarterlyJournalofEconomics133(3),1107–1162.
Condorcet, M.d., 1785. Essay on the Application of Analysis to the Probability of Majority
Decisions.ImprimerieRoyale,Paris.
Coudin,E.,Maillard,S.,Tô,M.,2018.Family,firmsandthegenderwagegapinfrance.Tech.
rep.,IFSWorkingPapers.
Crane, L.D., Hyatt, H.R., Murray, S.M., 2023. Cyclical labor market sorting. Journal of
Econometrics233(2),524–543.
Crump, R.K., Hotz, V.J., Imbens, G.W., Mitnik, O.A., 2009. Dealing with limited overlap in
estimationofaveragetreatmenteffects.Biometrika96(1),187–199.
Dempster,A.P.,Laird,N.M.,Rubin,D.B.,1977.Maximumlikelihoodfromincompletedatavia
theemalgorithm.JournaloftheRoyalStatisticalSociety:SeriesB(methodological)39(1),
1–22.
DiAddario,S.,Kline,P.,Saggio,R.,Sølvsten,M.,2023.Itain’twhereyou’refrom,it’swhere
you’re at: hiring origins, firm heterogeneity, and wages. Journal of Econometrics 233 (2),
340–374.
Donoho,D.,2024.Datascienceatthesingularity.HarvardDataScienceReview6,1.
Dostie,B.,Li,J.,Card,D.,Parent,D.,2023.Employerpoliciesandtheimmigrant–nativeearnings
gap.JournalofEconometrics233(2),544–567.
Drenik,A.,Jäger,S.,Plotkin,P.,Schoefer,B.,2023.Payingoutsourcedlabor:directevidencefrom
linkedtempagency-worker-clientdata.ReviewofEconomicsandStatistics105(1),206–216.
Dustmann,C.,Fitzenberger,B.,Schönberg,U.,Spitz-Oener,A.,2014.Fromsickmanofeuropeto
economicsuperstar:Germany’sresurgenteconomy.JournalofEconomicPerspectives28(1),
167–188.
Dustmann, C., Lindner, A., Schönberg, U., Umkehrer, M., VomBerge, P., 2022. Reallocation
effectsoftheminimumwage.TheQuarterlyJournalofEconomics137(1),267–328.
Eeckhout,J.,Kircher,P.,2011.Identifyingsorting—intheory.TheReviewofEconomicStudies
78(3),872–906.
ElKaroui,N.,Purdom,E.,2018.Canwetrustthebootstrapinhigh-dimensions?Thecaseoflinear
models.TheJournalofMachineLearningResearch19(1),170–235.
Engbom, N., & Moser, C., 2022. Earnings inequality and the minimum wage: Evidence from
Brazil.AmericanEconomicReview,112(12),3803–3847.
Engbom,N.,Moser,C.,Sauermann,J.,2023.Firmpaydynamics.JournalofEconometrics233(2),
396–423.
Faberman,R.J.,Mueller,A.I.,Şahin,A.,Topa,G.,2022.Jobsearchbehavioramongtheemployed
andnon-employed.Econometrica90(4),1743–1779.
Fenizia, A., 2022. Managers and productivity in the public sector. Econometrica 90 (3),
1063–1084.
Finkelstein,A.,Gentzkow,M.,Williams,H.,2016.Sourcesofgeographicvariationinhealthcare:
evidencefrompatientmigration.TheQuarterlyJournalofEconomics131(4),1681–1726.

Firmwageeffects Chapter | 2 179
Firth,D.,DeMenezes,R.X.,2004.Quasi-variances.Biometrika91(1),65–80.
Flinn,C.,Mullins,J.,2017.Firms’choicesofwage-settingprotocolsinthepresenceofminimum
wages.TechnicalReports,Discussionpaper.NewYorkUniversity.
Flinn, C., Mullins, J., 2021. Firms’ choices of wage-setting protocols. Technical Reports,
Discussionpaper.NewYorkUniversity.
Forgy, E.W., 1965. Cluster analysis of multivariate data: efficiency versus interpretability of
classifications.biometrics21,768–769.
Garcia-Louzao,J.,&Ruggieri,A.,2023.Labormarketcompetitionandinequality.Workingpaper.
Gerard,F.,Lagos,L.,Severnini,E.,Card,D.,2021.Assortativematchingorexclusionaryhiring?
TheimpactofemploymentandpaypoliciesonracialwagedifferencesinBrazil.American
EconomicReview111(10),3418–3457.
Gibbons,R., Katz, L.,1992.Does unmeasuredabilityexplain inter-industrywagedifferentials?
TheReviewofEconomicStudies59(3),515–535.
Gibbons, R., Katz, L.F., Lemieux, T., Parent, D., 2005. Comparative advantage, learning, and
sectoralwagedetermination.JournalofLaborEconomics23(4),681–724.
Goldschmidt,D.,Schmieder,J.F.,2017.Theriseofdomesticoutsourcingandtheevolutionofthe
Germanwagestructure.TheQuarterlyJournalofEconomicsqjx008.
Goldsmith-Pinkham, P., Hull, P., Kolesár, M., 2022. Contamination bias in linear regressions.
Tech.rep.,NationalBureauofEconomicResearch.
Gottfries,A.,Jarosch,G.,2023.Dynamicmonopsonywithlargefirmsandanapplicationtonon-
competes.
Groshen,E.L.,1991.Sourcesofintra-industrywagedispersion:howmuchdoemployersmatter?
TheQuarterlyJournalofEconomics106(3),869–884.
Guo,J.,2023.Theresponseofwagestorejectedoffers.
Guo,N.,Zhang,L.,Zhang,R.,&Zou,B.,2024.MigrationRestrictionsandtheMigrant-Native
WageGap:TheRoleofWageSettingandSorting.
Haanwinckel,D.,2023.Supply,demand,institutions,andfirms:atheoryoflabormarketsorting
andthewagedistribution.TechnicalReports,NationalBureauofEconomicResearch.
Haltiwanger,J.,Hyatt,H.R.,Spletzer,J.R.,2024.Risingtop,fallingbottom:industriesandrising
wageinequality.AmericanEconomicReview114(10),3250–3283.
Hanushek,E.A.,1974.Efficientestimatorsforregressingregressioncoefficients.TheAmerican
Statistician28(2),66–67.
Hoaglin, D.C., Welsch, R.E., 1978. The hat matrix in regression and anova. The American
Statistician32(1),17–22.
Holzer, H.J., Katz, L.F., Krueger, A.B., 1991. Job queues and wages. Quarterly Journal of
Economics106(3),739–768.
Hsieh,C.-T.,Klenow,P.J.,2009.MisallocationandmanufacturingTFPinChinaandIndia.The
QuarterlyJournalofEconomics124(4),1403–1448.
Huitfeldt,I.,Kostøl,A.R.,Nimczik,J.,Weber, A.,2023.Internallabormarkets:aworkerflow
approach.JournalofEconometrics233(2),661–688.
Imbens,G.W.,2010.Betterlatethannothing:somecommentsonDeaton(2009)andHeckmanand
Urzua(2009).JournalofEconomicliterature48(2),399–423.
Jäger,S.,Roth,C.,Roussille,N.,Schoefer,B.,2024.Workerbeliefsaboutoutsideoptions.The
QuarterlyJournalofEconomicsqjae001.
Jarosch,G.,Nimczik,J.S.,Sorkin,I.,2024.Granularsearch,marketstructure,andwages.Review
ofEconomicStudiesrdae004.
Jochmans,K.,Weidner,M.,2019.Fixed-effectregressionsonnetworkdata.Econometrica87(5),
1543–1560.

180 HandbookofLaborEconomics
Katz,L.F.,Summers,L.H.,Hall,R.E.,Schultze,C.L.,Topel,R.H.,1989.Industryrents:evidence
andimplications.BrookingsPapersonEconomicActivity.Microeconomics1989,209–290.
Kline, P., Saggio, R., Sølvsten, M., 2020. Leave-out estimation of variance components.
Econometrica88(5),1859–1898.
Koutis,I.,Miller,G.L.,Tolliver,D.,2011.Combinatorialpreconditionersandmultilevelsolvers
for problems in computer vision and image processing. Computer Vision and Image
Understanding115(12),1638–1646.
Krueger, A.B., Summers, L.H., 1988. Efficiency wages and the inter-industry wage structure.
Econometrica:JournaloftheEconometricSociety259–293.
Lachowska,M.,Mas,A.,Saggio,R.,Woodbury,S.A.,2023.Dofirmeffectsdrift?Evidencefrom
Washingtonadministrativedata.JournalofEconometrics233(2),375–395.
Lachowska,M.,Mas,A.,Woodbury,S.A.,2020.Sourcesofdisplacedworkers’long-termearnings
losses.AmericanEconomicReview110(10),3231–3266.
Lagos,L.,2019.Labormarketinstitutionsandthecompositionoffirmcompensation:evidence
fromBraziliancollectivebargaining.
Lamadon,T.,Mogstad,M.,Setzler,B.,2022.Imperfectcompetition,compensatingdifferentials,
andrentsharingintheUSlabormarket.AmericanEconomicReview112(1),169–212.
Lehmann, T., 2023. Non-wage job values and implications for inequality. Available at SSRN
4373816.
Lei, L., Ross, B., 2023. Estimating counterfactual matrix means with short panel data. arXiv
preprintarXiv:2312.07520.
Lentz,R.,Piyapromdee,S.,Robin,J.-M.,2022.Theanatomyofsorting-evidencefromdanishdata.
Li,J.,Dostie,B.,Simard-Duplain,G.,2023.Firmpaypoliciesandthegenderearningsgap:the
mediatingroleofmaritalandfamilystatus.ILRReview76(1),160–188.
Lloyd,S.,1982.Leastsquaresquantizationinpcm.IEEETransactionsonInformationTheory28
(2),129–137.
MacKinnon, J.G., White, H., 1985. Some heteroskedasticity-consistent covariance matrix esti-
matorswithimprovedfinitesampleproperties.JournalofEconometrics29(3),305–325.
MaCurdy,T.E.,1982.Theuseoftimeseriesprocessestomodeltheerrorstructureofearningsina
longitudinaldataanalysis.JournalofEconometrics18(1),83–114.
Maestas,N.,Mullen,K.J.,Powell,D.,VonWachter,T.,Wenger,J.B.,2023.Thevalueofworking
conditions in the United States and implications for the structure of wages. American
EconomicReview113(7),2007–2047.
Mammen,E.,1993.Bootstrapandwildbootstrapforhighdimensionallinearmodels.TheAnnals
ofStatistics255–285.
Mas,A.,2024.Compensatingdifferentials.HandbookofLaborEconomics.
McLaughlin,K.J.,1991.Atheoryofquitsandlayoffswithefficientturnover.JournalofPolitical
Economy99(1),1–29.
Meghir, C.,Pistaferri,L.,2004.Incomevariancedynamics andheterogeneity.Econometrica72
(1),1–32.
Murphy,K.M.,Topel,R.H.,1990.Efficiencywagesreconsidered:theoryandevidence.Advances
intheTheoryandMeasurementofUnemployment.Springer,pp.204–240.
Newey,W.K.,Robins,J.R.,2018.Cross-fittingandfastremainderratesforsemiparametricesti-
mation.arXivpreprintarXiv:1801.09138.
Nimczik,J.S.,2017.Jobmobilitynetworksandendogenouslabormarkets.
Oi,W.Y.,Idson,T.L.,1999.Firmsizeandwages.HandbookofLaborEconomics3,2165–2214.
Page,L.,Brin,S.,Motwani,R.,Winograd,T.,etal.,1999.Thepagerankcitationranking:bringing
ordertotheweb.

Firmwageeffects Chapter | 2 181
PérezPérez,J.,&Nuño-Ledesma,J.G.,2022.Workers,workplaces,sorting,andwagedispersion
inMexico.WorkingPaper.
Postel-Vinay,F.,Robin,J.-M.,2002a.Thedistributionofearningsinanequilibriumsearchmodel
with state-dependent offers and counteroffers. International Economic Review 43 (4),
989–1016.
Postel-Vinay, F., Robin, J.-M., 2002b. Equilibrium wage dispersion with worker and employer
heterogeneity.Econometrica70(6),2295–2350.
Postel-Vinay, F., Robin, J.-M., 2004. To match or not to match?: Optimal wage policy with
endogenousworkersearchintensity.ReviewofEconomicDynamics7(2),297–330.
Postel-Vinay,F.,Turon,H.,2014.Theimpactoffiringrestrictionsonlabourmarketequilibriumin
thepresenceofon-the-jobsearch.TheEconomicJournal124(575),31–61.
Rambachan,A.,Roth,J.,2023.Amorecredibleapproachtoparalleltrends.ReviewofEconomic
Studies90(5),2555–2591.
Roussille,N.,Scuderi,B.,2023.Biddingfortalent:atestofconductinahigh-wagelabormarket.
Roy,A.D.,1951.Somethoughtsonthedistributionofearnings.OxfordEconomicPapers3(2),
135–146.
Schmieder, J.F., VonWachter, T., Heining, J., 2023. The costs of job displacement over the
businesscycleanditssources:evidencefromGermany.AmericanEconomicReview113(5),
1208–1254.
Shapiro, C., Stiglitz, J.E., 1984. Equilibrium unemployment as a worker discipline device. The
AmericanEconomicReview74(3),433–444.
Slichter,S.H.,1950.Notesonthestructureofwages.TheReviewofEconomicsandStatistics32
(1),80–91.
Sockin,J.,2022.Showmetheamenity:arehigher-payingfirmsbetterallaround?
Song,J.,Price,D.J.,Guvenen,F.,Bloom,N.,VonWachter,T.,2019.Firmingupinequality.The
QuarterlyJournalofEconomics134(1),1–50.
Sorkin,I.,2018. Rankingfirms usingrevealed preference.TheQuarterly Journal ofEconomics
133(3),1331–1393.
Sorkin, I., Wallskog, M., 2023. The slow diffusion of earnings inequality. Journal of Labor
Economics41(S1),S95–S127.
Spielman,D.,2019.Spectralandalgebraicgraphtheory.
Stigler,G.J.,1962.Informationinthelabormarket.JournalofPoliticalEconomy70(5,Part2),
94–105.
Vafa,K.,Palikot,E.,Du,T.,Kanodia,A.,Athey,S.,Blei,D.M.,2022.Career:afoundationmodel
forlaborsequencedata.arXivpreprintarXiv:2202.08370.
Walters,C.R.,2024.Empiricalbayesmethodsinlaboreconomics.HandbookofLaborEconomics.
White,H.,1980.Aheteroskedasticity-consistentcovariancematrixestimatorandadirecttestfor
heteroskedasticity.Econometrica:JournaloftheEconometricSociety817–838.
Yeh, C., Macaluso, C., Hershbein, B., 2022. Monopsony in the US labor market. American
EconomicReview112(7),2099–2138.
Young,P.,1995.Optimalvotingrules.JournalofEconomicPerspectives9(1),51–64.
