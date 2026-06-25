ReviewofEconomicStudies(2023)90,2555–2591 doi:10.1093/restud/rdad018
©TheAuthor(s)2023.PublishedbyOxfordUniversityPressonbehalfofTheReviewofEconomicStudiesLimited.
Advanceaccesspublication15February2023
A More Credible Approach to
Parallel Trends
ASHESHRAMBACHAN
MicrosoftResearchNewEnglandandMIT
and
JONATHANROTH
BrownUniversity
FirstversionreceivedJuly2021;EditorialdecisionOctober2022;AcceptedJanuary2023(Eds.)
Thispaperproposestoolsforrobustinferenceindifference-in-differencesandevent-studydesigns
where the parallel trends assumption may be violated. Instead of requiring that parallel trends holds
exactly,weimposerestrictionsonhowdifferentthepost-treatmentviolationsofparalleltrendscanbe
fromthepre-treatmentdifferencesintrends(“pre-trends”).Thecausalparameterofinterestispartially
identifiedundertheserestrictions.Weintroducetwoapproachesthatguaranteeuniformlyvalidinfer-
enceundertheimposedrestrictions,andwederivenovelresultsshowingthattheyhavedesirablepower
propertiesinourcontext.Weillustratehoweconomicknowledgecaninformtherestrictionsonthepos-
sibleviolationsofparalleltrendsintwoeconomicapplications.Wealsohighlighthowourapproachcan
beusedtoconductsensitivityanalysesshowingwhatcausalconclusionscanbedrawnundervarious
restrictionsonthepossibleviolationsoftheparalleltrendsassumption.
Keywords:Difference-in-differences,Event-study,Paralleltrends,Robustinference,Sensitivityanalysis,
Partialidentification
JELcodes:C1
1. INTRODUCTION
Researchers using difference-in-differences (DiD) and related methods are often unsure about
thevalidityoftheparalleltrendsassumptionneededforpointidentificationofthecausalparam-
eterofinterest.Ithasthereforebecomecommonpracticetoassesstheplausibilityoftheparallel
trends assumption by testing for pre-treatment differences in trends (“pre-trends”). Although
pre-trends tests are intuitive, recent research has shown that they may suffer from low power
(Freyaldenhoven et al., 2019; Bilinski and Hatfield, 2020; Kahn-Lang and Lang, 2020; Roth,
2022),andthatconditioningtheanalysisonpassingpre-trendstestsintroducesstatisticalissues
relatedtopre-testing(Roth,2022).Howthenshouldresearchersproceedwhentheyareunsure
aboutthevalidityoftheparalleltrendsassumption?
This paper proposes methods for robust inference and sensitivity analysis in empirical set-
tings where the parallel trends assumption may not hold. Building on work by Manski and
Pepper(2018),weshowthatthecausalparameterofinterestcanbe(partially)identifiedunder
TheeditorinchargeofthispaperwasFrancescaMolinari.
2555
Downloaded
from
https://academic.oup.com/restud/article/90/5/2555/7039335
by
Northwestern
University
Libraries
user
on
20
June
2026

2556 REVIEWOFECONOMICSTUDIES
alargeclassofrestrictionsthatimposethatthepost-treatmentviolationsofparalleltrendscan-
notbe“toodifferent”fromthepre-trends.Wethenintroducemethodsthatyielduniformlyvalid
inferenceforthetreatmenteffectundertheimposedrestrictions.Intuitively,ourinferencemeth-
odsaccountforbothstatisticaluncertainty(wecanonlynoisilyestimatethetruepre-trend)as
well as “identification uncertainty” (even if the true pre-trend were known, we may not know
exactlyhowtoextrapolateit).Ourapproachthusformalizestheintuitionmotivatingpre-trends
testingwhileavoidingthestatisticalissuesdescribedabove.
Moreconcretely,weconsiderasettinginwhichtheresearcherestimatesavectorof“event-
study” coefficients βˆ =(βˆ(cid:2) pre ,βˆ(cid:2) post )(cid:2) ∈RT ¯ +T¯ , where βˆ pre and βˆ post respectively correspond
with estimates for T pre-treatment periods and T
¯
post-treatment periods. We assume that
βˆ
is
¯
consistentforthereduced-formparameterβ,whichcanbedecomposedas
(cid:2) (cid:3) (cid:2) (cid:3)
0 δ
β = + pre , (1)
τ δ
(cid:4) (cid:5)po(cid:6)st (cid:7) (cid:4) (cid:5)po(cid:6)st (cid:7)
=:τ =:δ
whereτ isacausalparameterofinterestthatisassumedtobe0inthepre-treatmentperiodand
δisabiasfromadifferenceintrends.Forinstance,inthecanonical(non-staggered)DiDframe-
work,βˆ maybethecoefficientsfroman“event-studyregression”specification,τ thevectorof
period-specific average treatment effects on the treated (ATT) for some policy of interest, and
δ the difference in trends of untreated potential outcomes between the treated and comparison
groups. As we discuss in Section 2, this framework also applies to more complicated empiri-
calsettings,suchasthosewithstaggeredtreatmenttiming(e.g.CallawayandSant’Anna,2020;
Sun and Abraham, 2020). The usual parallel trends assumption used to point identify τ is
post
that δ =0, and researchers frequently assess the plausibility of this assumption by testing
post
thenullhypothesisδ =0(a“pre-trends”test).
pre
Insteadofimposingthattheparalleltrendsassumptionholdsexactly,weplacerestrictionson
thepossiblepost-treatmentdifferencesintrendsδ giventhepointidentifiedpre-trendsδ .
post pre
Suchrestrictionsformalizetheintuitionmotivatingpre-trendstests,namelythatpre-trendsare
informativeaboutcounterfactualpost-treatmentdifferencesintrends.Formally,weassumethat
δ ∈(cid:5)forsomeresearcher-specifiedset(cid:5),andshowthatthecausalparameterτ ispartially
post
identifiedundersuchrestrictions.
Restrictionsofthisformcanbeusedtoformalizeawidevarietyofintuitionsaboutpossible
violationsoftheparalleltrendsassumptionthatarecommonlyexpressedinappliedwork.For
example,asdiscussedinManskiandPepper(2018),researchersmaybewillingtoassumethat
the confounding factors that create post-treatment violations of parallel trends are similar in
magnitudetothoseinthepre-treatmentperiod.Thisintuitioncanbeformalizedbyspecifyinga
(cid:5)thatboundsthemaximalpost-treatmentviolationofparalleltrendsbyaparameterM ¯ timesthe
maximalpre-treatmentviolationofparalleltrends.Inothercontexts,researchersareconcerned
aboutviolationsofparalleltrendsfromseculartrendsthatareassumedtoevolvesmoothlyover
time.Thisintuitioncanbeformalizedbyboundingtheextenttowhichtheslopeoftheviolation
ofparalleltrendscanchangeovertime.Weadoptaflexibleframeworkthatallowsresearchers
tocapturetheseintuitions,aswellasmanyotherrestrictionsthatareimpliedbycontext-specific
knowledgeaboutpossibleconfoundingfactors.
We then introduce methods to conduct uniformly valid inference on a scalar parameter of
theformθ =l(cid:2)τ undertherestrictionδ ∈(cid:5).Asemphasizedintherecentliteratureonpre-
post
trends testing, the pre-treatment coefficients βˆ are often imprecise estimates of δ . It is
pre pre
therefore important to introduce inference methods that account for the statistical uncertainty
Downloaded
from
https://academic.oup.com/restud/article/90/5/2555/7039335
by
Northwestern
University
Libraries
user
on
20
June
2026

RAMBACHANANDROTH AMORECREDIBLEAPPROACHTOPARALLELTRENDS 2557
intheestimationoftheevent-studycoefficients.Weintroducetwomaininferenceapproaches,
withdifferentdesirablepropertiesdependingontheshapeof(cid:5).
Wefirstintroduceageneralinferenceapproachthatcanaccommodatealargeclassofchoices
for(cid:5).Thisapproachisbasedontheobservationthatconductinginferenceonθcanbecastasthe
problemoftestingasystemofmomentinequalities,allowingustoleveragealargeeconomet-
ricsliteratureonmomentinequalitytesting(CanayandShaikh,2017providearecentreview).
The moments have a potentially large number of nuisance parameters that enter linearly, and
wethereforeconsideranimplementationofthisapproachbasedontheconditionalandhybrid
approachesofAndrewsetal.(forthcoming,henceforthARP),whoconsideredmomentinequal-
ities with this structure. Uniform size control for these tests follows nearly immediately from
resultsinARP.
WethenprovethatthetestsproposedbyARPhavesomedesirablepowerpropertiesinour
context.First,theconditionalandhybridtestsareconsistent,inthesensethattheyhavepower
approaching 1 against fixed alternatives outside of the identified set. Second, we prove that
theconditionaltesthasoptimallocalasymptoticpowerunderalinearindependenceconstraint
qualification (LICQ) assumption. As described in Kaido et al. (2021), LICQ and related con-
straintqualificationshavebeenusedwidelyinthepartialidentificationliterature,andareoften
imposed to ensure size control. By contrast, we show that the ARP conditional test is asymp-
totically valid even when LICQ fails, but has optimal local asymptotic power when LICQ is
satisfied.Intuitively,thisresultimpliesthattheconditionaltestwillperformwellwhenthebind-
ingandnon-bindingmomentsare“farapart”relativetothesamplingvariationinthedata.We
provideseveralintuitiveexamplestoillustratewhenthisresultwillandwillnotbeapplicable.
OurresultalsoimpliesthattheARPhybridtestwillhavenear-optimallocalasymptoticpower
under LICQ. These power results are new, and exploit additional structure in our context not
containedinARP.
Our second approach to inference is based on fixed length confidence intervals (FLCIs)
(Donoho,1994).FLCIshavedesirablefinite-sampleguaranteesforparticular(cid:5)sofinterest.In
particular,resultsfromArmstrongandKolesa´r(2018,2020b)implythatwhen(cid:5)isconvexand
centrosymmetric,FLCIshavenear-optimalexpectedlengthinthefinite-samplenormalmodel.
Theseresultsareapplicableforoneofourleadingexamples,(cid:5)SD,whichrestrictsthesmooth-
nessofthedifferenceintrends.InMonteCarlosimulations,wefindthattheuseofsuchFLCIs
can lead to substantial power gains over the conditional/hybrid approaches for (cid:5)SD when the
lengthoftheidentifiedsetisshortrelativetothesamplingvariationinthedata.Thisisintuitive
sincetheasymptoticpowerguaranteesfortheconditional/hybridapproachesareintheasymp-
totic regime where sampling uncertainty is small relative to the length of the identified set, in
contrasttothefinite-sampleguaranteesforFLCIs.Ontheotherhand,FLCIsareapplicablefor
a much smaller class of (cid:5)s: indeed, we show that for many other choices of (cid:5), they will be
inconsistentinthestrongsensethatpoweragainstfixedpointsoutsidetheidentifiedsetneednot
convergetooneasymptotically.
Based on our theoretical results and Monte Carlo simulations, we recommend the ARP
hybrid approach for general forms of (cid:5), but prefer the FLCI approach in special cases (such
asfor(cid:5)SD)wheretheconditionsforconsistencyandfinite-samplenear-optimalityaremet.
Werecommendthatappliedresearchersuseourmethodstoconstructrobustconfidencesets
undereconomically-motivatedrestrictionsonhowthepre-trendsrelatetothepost-treatmentvio-
lationsofparalleltrends.Ourtoolscanalsobeusedtotoconductsensitivityanalysesinwhich
the researcher reports confidence sets under varying restrictions on the possible differences in
trends.Forexample,iftheresearchersuspectsthattheconfoundingfactorsinthepost-treatment
periodsaresimilarinmagnitudetothoseinthepre-treatmentperiods,thenitmaybereasonable
to impose that the post-treatment violations of parallel trends are no larger than the maximum
Downloaded
from
https://academic.oup.com/restud/article/90/5/2555/7039335
by
Northwestern
University
Libraries
user
on
20
June
2026

2558 REVIEWOFECONOMICSTUDIES
pre-treatment violation of parallel trends. As a sensitivity analysis, the researcher might also
reportconfidencesetsthatallowthemaximumpost-treatmentviolationofparalleltrendstobe
¯ ¯
upto M timeslargerthanthemaximumpre-treatmentviolationfordifferentvaluesof M.The
proposedsensitivityanalysisthusfollowsthe“top-down”approachdescribedbyTamer(2010),
inwhich theresearcher reports what can be learned under a sequence of progressively weaker
assumptions.Performingsuchsensitivityanalysesmakesclearwhatmustbeassumedaboutthe
possibledifferencesintrendsinordertodrawspecificcausalconclusions,inlinewiththepar-
tialidentificationparadigminitiatedbyCharlesManskiandco-authorsinavarietyofcontexts
(Manski,1989,1990,2003,2008).WeprovidetheHonestDiDRandStatapackagestoimple-
mentourmethods.1 Weillustrateourrecommendedapproachwithapplicationstotworecently
publishedpapers,inwhichweshowhowthechoiceoftherestrictions(cid:5)canbetailoredtothe
economiccontext.
1.1. Relatedliterature
TheapproachinthispaperbuildsonthefoundationalpartialidentificationanalysisforDiDin
ManskiandPepper(2018).ManskiandPepperconsideridentificationunderresearcher-specified
boundsonthemagnitudeofδ (whattheycall“boundedDiDvariation”),andcalibratethese
post
bounds usingthemaximalpre-treatmentviolationofparalleltrendsintheirempiricalapplica-
tionontheeffectsofright-to-carrygunlaws.2 Oneofourleadingclassesofrestrictions,(cid:5)RM,
formalizesthiscalibrationapproachbyboundingthemagnitudeofpost-treatmentviolationsof
¯
paralleltrendsby M timesthemaximalpre-treatmentviolation.Ourframeworkalsoallowsfor
manyotherintuitiverestrictions—suchasboundsonhowfarδ candeviatefromlinearity—and
it can be applied to a variety of DiD estimators, including recent proposals for settings with
staggeredtreatmenttiming.Mostimportantly,whileManskiandPepper(2018)provideaframe-
work for identification, we provide inference methods to construct uniformly valid confidence
sets for the treatment effect of interest. This allows applied researchers to account for statisti-
caluncertaintyintheiranalyses,whichcanbeimportantsinceevent-studycoefficientsareoften
impreciselyestimatedinpractice.
Several other recent papers consider various relaxations of the parallel trends assumption.
Keeleetal.(2019)developtechniquesfortestingthesensitivityofDiDdesignstoviolationsof
theparalleltrendsassumption,buttheydonotincorporateinformationfromtheobservedpre-
trendsintheirsensitivityanalysis.Empiricalresearcherscommonlyadjustfortheextrapolation
ofalineartrendfromthepre-treatmentperiodswhenthereareconcernsaboutviolationsofthe
paralleltrendsassumption,whichisvalidifthedifferenceintrendsisexactlylinear(e.g.Bhuller
etal.,2013;Dobkinetal.,2018;Goodman-Bacon,2018,2021).Ourmethodsnestthisapproach
asaspecialcase,butallowforvalidinferenceunderlessrestrictiveassumptionsabouttheclass
ofpossibledifferencesintrends(suchaswhenδisonlyapproximatelylinear).Freyaldenhoven
et al. (2019) propose a method that allows for violations of the parallel trends assumption but
requiresanadditionalcovariatethatisaffectedbythesameconfoundingfactorsastheoutcome
butnotbythetreatmentofinterest.Yeetal.(2020)considerpartialidentificationoftreatment
effectswhenthereexisttwocontrolgroupswhoseoutcomeshaveabracketingrelationshipwith
1. The latest version of the R and Stata packages are respectively available at
https://github.com/asheshrambachan/HonestDiDandhttps://github.com/mcaceresb/stata-honestdid/.
2. ManskiandPepper(2018)alsoconsider“boundedtime”and“boundedstate”restrictionsthatboundhow
muchthemeanofY(0)candiffereitheracrosstreatmentgroupsorwithin-groupsovertime.Suchrestrictionscouldalso
beincorporatedintoourframeworkbyaugmentingthevectorβˆ
toincludegroup-specificsampleaverages.
Downloaded
from
https://academic.oup.com/restud/article/90/5/2555/7039335
by
Northwestern
University
Libraries
user
on
20
June
2026

RAMBACHANANDROTH AMORECREDIBLEAPPROACHTOPARALLELTRENDS 2559
the outcome of the treated group. Leavitt (2020) proposes an empirical Bayes approach cali-
brated to pre-treatment differences in trends, and Bilinski and Hatfield (2020) and Dette and
Schumann (2020) propose non-inferiority approaches based on pre-tests for the magnitude of
thepre-treatmentviolationsofparalleltrends.
OurmethodsaddressseveralconcernsrelatedtocurrentempiricalpracticeinDiDandevent-
study designs. First, pre-trends tests may be underpowered against meaningful violations of
parallel trends, potentially leading to severe undercoverage of conventional confidence inter-
vals (Freyaldenhoven et al., 2019; Bilinski and Hatfield, 2020; Kahn-Lang and Lang, 2020;
Roth,2022).Second,statisticaldistortionsfrompre-trendstestsmayfurtherunderminetheper-
formance of conventional inference procedures (Roth, 2022). Third, parametric approaches to
controlling for pre-existing trends may be sensitive to functional form assumptions (Wolfers,
2006; Lee and Solon, 2011). We address these issues by providing tools for inference that
do not rely on an exact parallel trends assumption, incorporate statistical uncertainty about
the estimated event-study coefficients, and make clear the mapping between the researcher’s
assumptionsaboutthepotentialdifferencesintrendsandthestrengthoftheircausalconclusions.
Our work complements a growing literature on the causal interpretation of event-study
coefficients in two-way fixed effects models in the presence of staggered treatment timing
and heterogeneous treatment effects (Borusyak and Jaravel, 2016; Callaway and Sant’Anna,
2020;deChaisemartinandD’Haultfæuille,2020;SunandAbraham,2020;AtheyandImbens,
2021; Goodman-Bacon, 2021). A key finding is that regression coefficients from conventional
approaches may not produce convex weighted averages of treatment effects even if parallel
trendsholds.Severalalternativeestimatorshavebeenproposedthatconsistentlyestimateinter-
pretablecausalestimandsunderasuitableparalleltrendsassumption.Ourmethodologycanbe
used in conjunction with these alternative estimators to assess their sensitivity to violations of
thecorrespondingparalleltrendsassumption;seeSection2.1foradditionaldetails.
More broadly, our work contributes to a larger econometric literature that uses partial
identification to provide empirical researchers with tractable tools to conduct inference under
assumptions that may be more credible in empirical practice; see, for example, Manski (2003,
2007,2013),Tamer(2010),HoandRosen(2017),andMolinari(2020)forreviews.
2. MODELSET-UP
2.1. Event-studycoefficients
Wesupposethattheresearcherhasestimatedavectorof“event-studycoefficients”βˆ n ∈RT ¯ +T¯ ,
which can be partitioned into vectors of coefficients corresponding with the pre-treatment
andpost-treatmentperiods,βˆ n =(βˆ(cid:2) n,pre ,βˆ(cid:2) n,post ),whereβˆ n,pre ∈RT ¯ andβˆ n,post ∈RT¯ .Event-
study estimates of this form arise from non-staggered DiD as well as a variety of related
estimators,asweillustratewithseveralexamples
Example1(Non-staggeredDiD). ConsiderthecanonicalDiDsettinginwhichwehaveabal-
anced panel of units from period t =−T,...,T ¯ , and units with D =1 receive a treatment
¯ i
beginninginperiodt =1,whileunitswith D =0neverreceivethetreatment.Itiscommonto
i
reportDiDestimatesoftheform
βˆ =(Y ¯ −Y ¯ )−(Y ¯ −Y ¯ ),
s s1 s0 01 00
whereY ¯ isthesamplemeanoftheoutcomeforunitswith D =d inperiodt =s.Intuitively,
sd i
βˆ
compares the change in the mean outcome between period 0 and period s for the treated
s
and comparison units. In this setting, the estimates
βˆ
are numerically equivalent to the OLS
s
Downloaded
from
https://academic.oup.com/restud/article/90/5/2555/7039335
by
Northwestern
University
Libraries
user
on
20
June
2026

2560 REVIEWOFECONOMICSTUDIES
coefficientsfromtheregression
(cid:8)
| =λ  | +φ + | β   | ×1[t =s]×D | +(cid:9) . |     |
| --- | ---- | --- | ---------- | ---------- | --- |
| Y   |      |     |            |            | (2) |
| it  | i t  | s   |            | i it       |     |
s(cid:4)=0
Downloaded from https://academic.oup.com/restud/article/90/5/2555/7039335 by Northwestern University Libraries user on 20 June 2026
βˆ
In this case, collects the estimated coefficients corresponding with treated periods,
post
(βˆ ,...,βˆ ),whileβˆ
1 T¯ pre collectstheestimatedcoefficientscorrespondingwithperiodsbefore
treatment(βˆ ,...βˆ ).
−T −1
¯
Example2(StaggeredDiD). Event-studycoefficientscanalsobeobtainedfrommorecompli-
catedDiDprocedures.Forexample,insettingswithstaggeredtreatmenttiming,Callawayand
Sant’Anna(2020)proposeevent-studyestimatesoftheform
(cid:8)
|     | βˆ = | w A (cid:2) | TT(g,g+r), |     |     |
| --- | ---- | ----------- | ---------- | --- | --- |
|     | r    | g           |            |     |     |
g
where A (cid:2) TT(g,t) is a DiD estimate that compares the evolution of the outcome for units first
g−1
treated at period g to units first-treated after period t between time periods and t, and
βˆ
the w are weights that sum to one (e.g. proportional to sample size). In this case, col-
g post
| βˆ  |     |     |     |     | βˆ  |
| --- | --- | --- | --- | --- | --- |
lects the values of for r ≥0 (i.e. estimates where one of the groups is treated), and
| r   |     |     |     |     | pre |
| --- | --- | --- | --- | --- | --- |
| βˆ  |     | <0. |     |     |     |
collects the values of for values of r Several other related procedures have been pro-
r
posedforconstructingevent-studycoefficientsincontextswithstaggeredtreatmenttiming;see
deChaisemartinandD’Haultfæuille(2021)andRothetal.(2022)forreviews.
Example3(Otherrelatedestimators). Otherexamplesofestimatorsthatcanbeusedtoproduce
event-studiescoefficientsoftheformconsideredhereincludetheGMMprocedureproposedby
Freyaldenhovenetal.(2019),instrumentalvariablesevent-studies(Hudsonetal.,2017),aswell
estimators that flexibly control for differences in covariates between treated and comparison
groups(e.g.Heckmanetal.,1998;Abadie,2005;Sant’AnnaandZhao,2020).
2.2. Causaldecomposition
Under mild regularity conditions√, all of the estimators described above will be asymptotically
|     | n(βˆ | −β)→N | (0, (cid:10)∗) |     | β.  |
| --- | ---- | ----- | -------------- | --- | --- |
normally distributed, satisfying for some parameter vector We
n
assumetheparametervectorβ satisfiesthefollowingcausaldecomposition.
Theparametervectorβ
Assumption1. canbedecomposedas
|     | (cid:2) (cid:3)                    | (cid:2)                    | (cid:3) |     |     |
| --- | ---------------------------------- | -------------------------- | ------- | --- | --- |
|     | τ                                  | δ                          |         |     |     |
| β = | pre                                | + pre                      | withτ   | =0. | (3) |
|     | τ                                  | δ                          |         | pre |     |
|     | (cid:4) (cid:5)po(cid:6)st (cid:7) | (cid:4) (cid:5)po(cid:6)st | (cid:7) |     |     |
|     | =:τ                                | =:δ                        |         |     |     |
The first term, τ, represents the treatment effects of interest. We assume the treatment has
τ =0. δ,
no causal effect prior to its implementation, so pre The second term, represents the
differenceintrendsbetweenthetreatedandcomparisongroupsthatwouldhaveoccurredabsent
|     |     |     | δ   | =0, β | =τ  |
| --- | --- | --- | --- | ----- | --- |
treatment. The parallel trends assumption imposes that post and therefore post post
underparalleltrends.3
3. AlthoughourfocusisongeneralizedDiDsettings,ourresultsapplytoanysettingwheretheresearcherhasan
asymptoticallynormallydistributedestimatorβˆ ofareducedformparameterβthatsatisfies(3).Forexample,βˆ
could

|     | RAMBACHANANDROTH |     | AMORECREDIBLEAPPROACHTOPARALLELTRENDS |     |     |     |     |     | 2561 |
| --- | ---------------- | --- | ------------------------------------- | --- | --- | --- | --- | --- | ---- |
2.2.1. Example:non-staggeredDiD(continued). Supposetheobservedoutcomesatisfies
Y = D Y (1)+(1−D )Y (0), where Y (1) and Y (0) are, respectively, the potential out-
| it  | i it | i   | it  | it  |     | it  |     |     |     |
| --- | ---- | --- | --- | --- | --- | --- | --- | --- | --- |
comeswhenunitiisultimatelytreated/nottreated.Assumefurtherthatthereisnoanticipationof
treatment,sothatY (1)=Y (0)forallt <1.Then,foranys,undermildregularityconditions
it it Downloaded from https://academic.oup.com/restud/article/90/5/2555/7039335 by Northwestern University Libraries user on 20 June 2026
βˆ
willbeconsistentfor
s
|     | β =τ   | +E            | [Y (0)−Y | (0)|D | =1]                  | − E[Y (0)−Y        | (0)|D | =0 ],   |     |
| --- | ------ | ------------- | -------- | ----- | -------------------- | ------------------ | ----- | ------- | --- |
|     | s      | ATT,s (cid:4) | is       | i0    | i                    | (cid:5) (cid:6) is | i0 i  | (cid:7) |     |
|     |        |               |          |       | differentialtrend=:δ | s                  |       |         |     |
|     | τ =E[Y | (1)−Y         | (0)|D    | =1]   |                      |                    |       |         |     |
where ATT,s is the average treatment effect on the treated in
|     |     | is  | is  | i   |     |     |     |     |     |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
period s, and δ is the difference in trends in potential outcomes between period 0 and period
s
| s.4 |     |     |     |     |     | τ =0 | <0, |     |     |
| --- | --- | --- | --- | --- | --- | ---- | --- | --- | --- |
Since the no-anticipation assumption implies that ATT,s for s this yields the
decomposition(3).
2.2.2. Example: staggered DiD (continued). Likewise, in the staggered DiD context,
define Y (g) to be the potential outcome for unit i in period t if they are first treated
it
|     |     | (∞) |     |     |     |     |     | βˆ  |     |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
at period g and Y to be the never-treated po(cid:9)tential outcome. Then will be con-
|     |     | it  |     |     |     |     |     | r   |     |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
sistent for the parameter β =τ +δ , where τ = w ATT(g,g+r) and ATT(g,g+
|     | (cid:10) |     | r r | r(cid:11) | r   | g g |     |     |     |
| --- | -------- | --- | --- | --------- | --- | --- | --- | --- | --- |
r)=E Y i,g+r (g)−Y i,g+r(cid:9) (∞)|G =g is the ATT in p(cid:10)eriod g+r for units first treated(cid:11)at
i
pe(cid:10)riod g. Likewise, δ = w δ , w(cid:11) here δ =E Y (∞)−Y (∞)|G =g −
|     |       | r     | g g,g+r |     | g,g+r | i,g+r | i,g−1 |     | i   |
| --- | ----- | ----- | ------- | --- | ----- | ----- | ----- | --- | --- |
| E   | (∞)−Y | (∞)|G | >g+r    |     |       |       |       |     |     |
Y i,g+r i,g−1 is the difference in trends in never-treated potential
i
outcomesbetweenunitsfirsttreatedatperiodgandunitsfirsttreatedafterperiodg+r.Under
ano-anticipationassumption,τ =0forr <0,whichagainyieldsthedecomposition(3).
r
Wecandecomposeβ
|     | 2.2.3. Example:otherrelatedestimators(continued). |     |     |     |     |     |     | asin(3)for |     |
| --- | ------------------------------------------------- | --- | --- | --- | --- | --- | --- | ---------- | --- |
other estimators as well. For example, for event-study IVs (with non-staggered timing), τ
post
is a vector containing the local average treatment effect for each period, and δ represents the
asymptoticbiasoftheIVestimator(e.g.fromviolationsofindependenceorexclusion)foreach
period.Formethodsthatflexiblycontrolforcovariatedifferencesbetweentreatedandcompar-
|     | τ   |     |     |     | δ   |     |     |     |     |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
ison groups, post is again a vector of ATTs, and post represents a weighted average (across
covariates)oftheviolationoftheconditionalparalleltrendsassumption.
2.3. Targetparameterandidentification
We suppose the target parameter is a linear combination of the post-treatment causal effects,
θ :=l(cid:2)τ for some known T ¯ -vector l. For example, θ equals the tth period causal effect τ
|     | post |     |     |     |     |     |     |     | t   |
| --- | ---- | --- | --- | --- | --- | --- | --- | --- | --- |
θ
when the vector l equals the tth standard basis vector. Similarly, equals the average causal
|                                           |     |     |     |     |       | ¯,...,1/T ¯)(cid:2). |     |     |     |
| ----------------------------------------- | --- | --- | --- | --- | ----- | -------------------- | --- | --- | --- |
| effectacrossallpost-treatmentperiodswhenl |     |     |     |     | =(1/T |                      |     |     |     |
|                                           |     |     |     | θ   |       | δ                    |     |     |     |
We obtain partial identification of by assuming that lies in a researcher-specified set
| ofpossibledifferencesintrends(cid:5)⊆RT |     |            |     | +T¯  |                                              |     |     |     |     |
| --------------------------------------- | --- | ---------- | --- | ---- | -------------------------------------------- | --- | --- | --- | --- |
|                                         |     |            |     | ¯    | .Thisneststheusualparalleltrendsassumptionas |     |     |     |     |
|                                         |     | (cid:5)={δ | :δ  | =0}. | δ                                            | =β  |     |     |     |
the special case with Since is identified, the assumption that
|     |     |     | post |     | pre | pre |     |     |     |
| --- | --- | --- | ---- | --- | --- | --- | --- | --- | --- |
correspondwithavectoroffirst-differencesortriple-differencesestimators,andδtheviolationofthecorresponding
identifyingassumption.
4. WefocusontheATTasthetargetparameter,asinmostoftheDiDliterature.Ifoneisinterestedinthe
population-wideaveragetreatmenteffect(ATE),onecouldobtainboundsontheATEunderrestrictionsontreatment
effectheterogeneity,orotherassumptionsthatallowonetoboundthetreatmenteffectsforuntreatedunits;seeManski
andPepper(2013)foraninsightfuldiscussion.

2562 REVIEWOFECONOMICSTUDIES
δ =(δ(cid:2) ,δ(cid:2) )(cid:2) ∈(cid:5)restrictsthepossiblevaluesofδ giventheidentifiedvalueofthepre-
| pre post |     |     |     |     | post |     |     |     |
| -------- | --- | --- | --- | --- | ---- | --- | --- | --- |
treatmentdifferenceintrendsδ .
pre
δ δ
It is natural to place restrictions on the relationship between and , since applied
|     |     |     |     |     |     | pre | post |     |
| --- | --- | --- | --- | --- | --- | --- | ---- | --- |
researchersfrequentlytestthenullhypothesisδ =0inordertoassesstheplausibilityofthe
pre Downloaded from https://academic.oup.com/restud/article/90/5/2555/7039335 by Northwestern University Libraries user on 20 June 2026
assumptionthatδ =0.Ouridentificationframework,whichgeneralizesthepartialidentifi-
post
cation framework in Manski and Pepper (2018), thus helps formalize the intuition motivating
pre-trendstesting.
|     |     | δ ∈(cid:5)(cid:4)={δ |     | :δ  | =0}, |     | θ   |     |
| --- | --- | -------------------- | --- | --- | ---- | --- | --- | --- |
Under the assumption that the parameter will typically be set-
post
identified.Theidentifiedsetisthesetofvaluesforθ thatareconsistentwithagivenvalueofβ
undertherestrictionδ ∈(cid:5),
|                | (cid:12) |                |      |       |               |     | (cid:2) (cid:3)(cid:13) |     |
| -------------- | -------- | -------------- | ---- | ----- | ------------- | --- | ----------------------- | --- |
| S(β,(cid:5)):= | θ        | :∃δ ∈(cid:5),τ | ∈RT¯ |       | (cid:2)τ =θ,β | =δ+ | 0 .                     |     |
|                |          |                |      | s.t.l |               |     |                         | (4) |
|                |          |                | post |       | post          |     | τ                       |     |
post
When(cid:5)isaclosedandconvexset,theidentifiedsethasasimplecharacterization.5
Lemma 2.1. If (cid:5) is closed and convex, then S(β,(cid:5)) is an interval in R, S(β,(cid:5))=
[θlb(β,(cid:5)),θub(β,(cid:5))],where
|                   |     |          | (cid:2) |          |                    |           | (cid:3) |     |
| ----------------- | --- | -------- | ------- | -------- | ------------------ | --------- | ------- | --- |
|                   |     | (cid:2)β |         | (cid:2)δ |                    |           |         |     |
| θlb(β,(cid:5)):=l |     |          | − maxl  |          | , s.t.δ ∈(cid:5),δ | =β        | ,       | (5) |
|                   |     | post     | δ       | post     |                    | pre       | pre     |     |
|                   |     |          | (cid:4) |          | (cid:5)(cid:6)     |           | (cid:7) |     |
|                   |     |          |         |          | =:bmax(β           | ,(cid:5)) |         |     |
pre
|                   |     |          | (cid:2)   |          |                    |           | (cid:3) |     |
| ----------------- | --- | -------- | --------- | -------- | ------------------ | --------- | ------- | --- |
|                   |     | (cid:2)β |           | (cid:2)δ |                    |           |         |     |
| θub(β,(cid:5)):=l |     |          | − minl    |          | , s.t.δ ∈(cid:5),δ | =β        | .       | (6) |
|                   |     | post     |           | post     |                    | pre       | pre     |     |
|                   |     |          | (cid:4) δ |          | (cid:5)(cid:6)     |           | (cid:7) |     |
|                   |     |          |           |          | =:bmin(β           | ,(cid:5)) |         |     |
pre
S(β,(cid:5))=
Proof. Re-arranging terms in (4), the identified set can be equivalently written as
{θ :∃δ ∈(cid:5)s.t.δ =β ,θ =l(cid:2)β −l(cid:2)δ }.Theresultisthenimmediate.
| pre | pre |     | post | post |     |     |     |     |
| --- | --- | --- | ---- | ---- | --- | --- | --- | --- |
2.3.1. Example: non-staggered DiD (continued). In the three-period DiD model
=T ¯ =1),
(T the ATT in period 1 is point identified if we assume that the counterfactual
¯
post-treatment difference in trends δ is exactly zero (parallel trends). Instead, we assume
1
δ =(δ ,δ )(cid:2) ∈(cid:5)forsomeset(cid:5).When(cid:5)isclosedandconvex,theidentifiedsetfortheATT
−1 1
inperiod1is[β −bmax,β −bmin],wherebmax =maxδ δ s.t(δ ,δ )(cid:2) ∈(cid:5)isthemaximum
| 1   |     | 1   |     |     | 1   | −1  | 1   |     |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
possiblebiasofβˆ
| givenδ |     | =β  | andbmin | isdefinedanalogously. |     |     |     |     |
| ------ | --- | --- | ------- | --------------------- | --- | --- | --- | --- |
| 1      | −1  | −1  |         |                       |     |     |     |     |
(cid:5)
Additionally, it is imm(cid:14)ediate from the definition of the identified set in (4) that if is the
finiteunionofsets,(cid:5)= K (cid:5)
,thentheidentifiedsetistheunionoftheidentifiedsetsfor
k=1 k
itssubcomponents,
(cid:15)K
|     |     |     | S(β,(cid:5))= |     | S(β,(cid:5) ). |     |     | (7) |
| --- | --- | --- | ------------- | --- | -------------- | --- | --- | --- |
k
k=1
This fact will be useful, since several empirically relevant choices of (cid:5) can be written as the
finiteunionofconvexsets,aswewillseebelow.
5. Ourfocusisoninferenceonθ.Ifonewereinsteadinterestedinestimatingtheendpointsoftheidentified,a
naturalestimatorwhen(cid:5)isclosedandconvexwouldbe[θlb(βˆ,(cid:5)),θub(βˆ,(cid:5))],whichisthesampleanaloguetothe
boundsderivedinLemma2.1;seeSupplementaryMaterial,AppendixCforadditionaldiscussion.

| RAMBACHANANDROTH |     |     | AMORECREDIBLEAPPROACHTOPARALLELTRENDS |     |     |     |     |     |     | 2563 |
| ---------------- | --- | --- | ------------------------------------- | --- | --- | --- | --- | --- | --- | ---- |
2.4. Possiblechoicesof(cid:5)
Theclassofpossibledifferencesintrends(cid:5)mustbespecifiedbytheresearcher,andthechoice
of(cid:5)willdependontheeconomiccontext.Wehighlightseveralpossiblechoicesof(cid:5)thatmay
be reasonable in empirical applications and formalize intuitive arguments that are commonly Downloaded from https://academic.oup.com/restud/article/90/5/2555/7039335 by Northwestern University Libraries user on 20 June 2026
made by applied researchers regarding possible violations of parallel trends. Throughout our
discussion,wewriteδ =(δ ,...δ )(cid:2) andδ =(δ ,...δ )(cid:2),withδ normalizedtozero.
|     |     | pre | −T                                                      | −1  | post | 1   | T¯  |     | 0   |     |
| --- | --- | --- | ------------------------------------------------------- | --- | ---- | --- | --- | --- | --- | --- |
|     |     |     | ¯ mple1,whereδcorrespondstothedifferenceintrendsbetween |     |      |     |     |     |     |     |
ThisalignsthenotationwithExa
| treatedandcomparisongroups,andδ |     |     |     | isnormalizedtozero. |     |     |     |     |     |     |
| ------------------------------- | --- | --- | --- | ------------------- | --- | --- | --- | --- | --- | --- |
0
2.4.1. Boundingrelativemagnitudes. Inempiricalapplications,researchersmaybewill-
ing to assume that the confounding factors which produce non-parallel trends in the post-
treatment periods are not too much larger in magnitude than the confounding factors in the
pre-treatmentperiods.Intheirempiricalapplicationtoright-to-carrygunlaws,ManskiandPep-
|     |     |     |     |     |     |     |     | |δ | |     |     |
| --- | --- | --- | --- | --- | --- | --- | --- | ---- | --- | --- |
per (2018) operationalize this intuition by calibrating bounds on 1 to the largest violations
of parallel trends in the pre-treatment period (see their Table 3).6 Such a restriction can be
formalizedinourframeworkbyimposingthatδ ∈(cid:5)RM(M ¯)for M ¯ ≥0,where
|     | (cid:5)RM(M | ¯)={δ | :∀t | ≥0, | |δ −δ | |≤ ¯ ·max|δ |     | −δ  | |}. |     |
| --- | ----------- | ----- | --- | --- | ----- | ----------- | --- | --- | --- | --- |
|     |             |       |     |     | t+1   | M           |     | s+1 |     |     |
|     |             |       |     |     | t     |             | s<0 |     | s   |     |
(cid:5)RM(M ¯)boundsthemaximumpost-treatmentviolationofparalleltrendsbetweenconsecutive
¯
periodsby M timesthemaximumpre-treatmentviolationofparalleltrends.Weusetheabbre-
¯)maybereasonableiftheresearcher
viationRMfor“relativemagnitudes.”Thechoice(cid:5)RM(M
suspectsthatpossibleviolationsofparalleltrendsaredrivenbyconfoundingeconomicshocks
that are of a similar magnitude to confounding economics shocks in the pre-period. When
the number of pre-treatment and post-treatment periods is similar, a natural benchmark may
¯ =1,
be M which bounds the worst-case post-treatment difference in trends by the equivalent
maximuminthepre-treatmentperiod.7
2.4.2. Example: non-staggered DiD (continued). In the three-period DiD model
| (T =T ¯ =1), |          | δ   | ∈(cid:5)RM(M | ¯)={(δ | ,δ )(cid:2) | :|δ |≤ | M ¯|δ | |}     |               |     |
| ------------ | -------- | --- | ------------ | ------ | ----------- | ------ | ----- | ------ | ------------- | --- |
|              | assuming |     |              |        | −1 1        | 1      | −1    | bounds | the magnitude | of  |
| δ ¯          |          |     | δ            |        |             |        |       |        |               |     |
based on the magnitude of −1 . The larger the magnitude of the pre-treatment violation
1
in parallel trends, |δ |, the wider the range of possible post-treatment violations of parallel
−1
trends.(cid:2)
2.4.3. Smoothness restrictions. In other empirical settings, researchers may be worried
aboutconfoundingfromseculartrends(e.g.long-runchangesinlaboursupply)thattheysuspect
evolve smoothly over time. In such settings, it is common for empirical researchers to control
foralineargroup-specifictimetrend.8Thisapproachisvalidifthedifferenceintrendsislinear,
6. Intheirapplication,ManskiandPepper(2018)observetheoutcomefortheentirepopulationofinterest,and
preratherthanβˆ
| thustheirobservedpre-treatmentdatacorrespondswithδ |     |     |     |     |     | pre. |     |     |     |     |
| -------------------------------------------------- | --- | --- | --- | --- | --- | ---- | --- | --- | --- | --- |
7. Insettingswherelaterpre-periodsarethoughttobemoreinformative,theresearchercoulduseadifferentvalue
¯ fordifferentpre-periods,e.g.imposingthat|δ −δ |≤max{|δ −δ−1 |,2·|δ−1 −δ−2 |}.Likewise,although
| ofM |     |     |     |     | t+1 t | 0   |     |     |     |     |
| --- | --- | --- | --- | --- | ----- | --- | --- | --- | --- | --- |
we’veconsideredboundsonchangesacrossconsecutiveperiods,theresearchercouldalsoimposeboundsonchanges
| acrossmultipleperiods,e.g.|δ |     |     | −δ |≤M | ¯ ·maxs<−1 | |δ −δ | |.  |     |     |     |     |
| ---------------------------- | --- | --- | ------ | ---------- | ----- | --- | --- | --- | --- | --- |
|                              |     | t+2 | t      |            | s+2   | s   |     |     |     |     |
8. Specifically,researchersoftenaugmentspecification(2)withgroup-specificlineartrends,anapproachDobkin
etal.(2018)refertoasa“parametricevent-study.”Ananalogousapproachistoestimatealineartrendusingonly
observationspriortotreatment,andthensubtractouttheestimatedlineartrendfromtheobservationsaftertreatment
(Bhulleretal.,2013;Goodman-Bacon,2018,2021).

2564 REVIEWOFECONOMICSTUDIES
i.e.(cid:5)={δ: δ =γ ·t,γ ∈R}.Thereareoftenconcerns,however,thatthelinearspecification
t
is not exactly correct (Wolfers, 2006; Lee and Solon, 2011). A natural relaxation is therefore
toimposeonlythatthedifferentialtrendsevolvesmoothlyovertimebyboundingtheextentto
whichitsslopemaychangeacrossconsecutiveperiods.Sucharestrictioncanbeformalizedin
ourframeworkbyimposingthatδ ∈(cid:5)SD(M)for M ≥0,where
(cid:5)SD(M):={δ :|(δ t+1 −δ t )−(δ t −δ t−1 )|≤ M, ∀t}. (8)
The parameter M ≥0 governs the amount by which the slope of δ can change between con-
secutive periods, and thus bounds the discrete analogue of the second derivative. We use the
abbreviation SD for “second differences” or “second derivative.”9 In the special case where
M =0,(cid:5)SD(0)requiresthatthedifferenceintrendsbeexactlylinear,whichcorrespondswith
theassumptionunderlyingtheparametriclinearspecificationcommoninappliedwork.
2.4.4. Example:non-staggeredDiD(continued). Inthethree-periodDiDmodel,assum-
ing the differential trend is exactly linear is equivalent to assuming (cid:5)={δ :δ 1 =−δ −1 }.
Assuming δ ∈(cid:5)SD(M) requires only that the linear extrapolation be approximately correct,
δ
1
∈[−δ
−1
−M,−δ
−1
+M].
2.4.5. Combining smoothness and relative magnitudes bounds. In some contexts,
researchers may be willing to assume that the difference in trends evolves relatively smoothly
over time but may be unsure about the smoothness bound M ≥0 introduced above. In such
cases,itmaybereasonabletoassumethatthepossiblenon-linearitiesinthepost-treatmentdif-
ferenceintrendsareboundedbytheobservednon-linearitiesinthepre-treatmentdifferencein
trends.Thiscanbeformalizedwiththerestriction
(cid:5)SDRM(M ¯)={δ :∀t ≥0, |(δ t+1 −δ t )−(δ t −δ t−1 )|≤ M ¯ ·max|(δ s+1 −δ s )−(δ s −δ s−1 )|},
s<0
whichboundsthemaximumdeviationfromalineartrendinthepost-treatmentperiodbyM ¯ ≥0
timestheequivalentmaximuminthepre-treatmentperiod.Theset(cid:5)SDRM(M ¯)isthussimilar
to (cid:5)SD(M) introduced above, except it allows the magnitude of the possible non-linearity to
explicitlydependontheobservedpre-trends.
2.4.6. Sign and monotonicity restrictions. Context-specific knowledge may sometimes
also suggest sign or monotonicity restrictions on the differential trend. For instance, if the
policy of interest occurs at the same time as a confounding policy change that we expect to
have a positive effect on the outcome, we might restrict the post-treatment bias to be positive,
δ ∈(cid:5)PB :={δ :δ ≥0 ∀ t ≥0}. Likewise, there may be secular pre-existing trends that we
t
expectwouldhavecontinuedfollowingthetreatmentdate.10 Wemaythenwishtoimposethat
the differential trend be increasing, δ ∈(cid:5)I :={δ :δ t ≥δ t−1 ∀ t}, or monotone with unknown
sign,δ ∈(cid:5)Mon :=(cid:5)I ∪(−(cid:5)I).Signandmonotonicityrestrictionsmaybecombinedwiththe
9. Restrictionsonthesecondderivativeoftheconditionalexpectationfunctionordensityhavebeenusedin
regression discontinuity settings (Kolesa´r and Rothe, 2018; Frandsen, 2016; Noack and Rothe, 2020). Smoothness
restrictionsarealsousedtoobtainpartialidentificationine.g.Manski(1997);Kimetal.(2018).
10. Monotoneviolationsofparalleltrendsareoftendiscussedinappliedwork.Forexample,Lovenheimand
Willen(2019a)arguethatviolationsofparalleltrendscannotexplaintheirresultsbecause“pre-[treatment]trendsare
eitherzeroorinthewrongdirection(i.e.oppositetothedirectionofthetreatmenteffect).”GreenstoneandHanna(2014)
estimateupward-slopingpre-existingtrendsandarguethat“ifthepre-trendshadcontinued”theirestimateswouldbe
upwardbiased.
Downloaded
from
https://academic.oup.com/restud/article/90/5/2555/7039335
by
Northwestern
University
Libraries
user
on
20
June
2026

|     | RAMBACHANANDROTH |     | AMORECREDIBLEAPPROACHTOPARALLELTRENDS |     |     | 2565 |
| --- | ---------------- | --- | ------------------------------------- | --- | --- | ---- |
previously discussed restrictions, such as (cid:5)SDPB(M):=(cid:5)SD(M)∩(cid:5)PB, (cid:5)SDI(M):=(cid:5)SD
| (M)∩(cid:5)I,and(cid:5)RMI(M |     | ¯):=(cid:5)RM(M | ¯)∩(cid:5)I. |     |     |     |
| ---------------------------- | --- | --------------- | ------------ | --- | --- | --- |
2.4.7. Polyhedral restrictions. Although the restrictions described above will be sensi-
Downloaded from https://academic.oup.com/restud/article/90/5/2555/7039335 by Northwestern University Libraries user on 20 June 2026
ble in many empirical contexts, researchers will often have context-specific knowledge that
motivatesalternativerestrictionsthanwhatweintroducedabove.Toaccommodatesuchcases,
(cid:5)s
we consider the broad class of that can be written as polyhedra (sets defined by linear
inequalities),orthefiniteunionofpolyhedra.
|     |     |     |     | (cid:5) |     | (cid:5)={δ : |
| --- | --- | --- | --- | ------- | --- | ------------ |
Definition 1 (Polyhedral restriction). The class is polyhedral if it takes the form
| Aδ ≤d}forsomeknownmatrix |     |     | Aandvectord. |     |     |     |
| ------------------------ | --- | --- | ------------ | --- | --- | --- |
Alloftheexamplesdescribedabovecanbewritteneitheraspolyhedralrestrictionsorfinite
unions of such restrictions. For instance, (cid:5)SD(M) and (cid:5)SDPB(M) can be written directly as
polyhedra.11Likewise,(cid:5)RM(M ¯)and(cid:5)SDRM(M ¯)canbewrittenasthefiniteunionofpolyhedra,
where each polyhedron corresponds with a different location for the maximum pre-treatment
violation.12
The class of (finite unions of) polyhedra is quite broad, and allows for a variety of other
restrictions that may be relevant in empirical work. For example, researchers studying labour
market training and related programs may be concerned about Ashenfelter’s dip (Ashenfelter,
1978),inwhichearningsforthetreatedgrouptrenddownwards(relativetocontrol)beforetreat-
mentandupwardsafterwards.Inthistypeofsetting,researchersmightnaturallyuseapolyhedral
(cid:5)toimpose(i)restrictionsonthesignsofthepre-treatmentandpost-treatmentbiases,aswell
as(ii)restrictionsonthemagnitudeofthereboundeffectrelativetothepre-treatmentshock.
2.5. Inferentialgoal
√
|     |     |     |     | βˆ  | n(βˆ −β)→ | N (0, (cid:10)∗) |
| --- | --- | --- | --- | --- | --------- | ---------------- |
As discussed above, the event study coefficients n will satisfy d
n
for a wide variety of commonly used estimators. This suggests the finite-sample normal
approximation
|     |     |     | βˆ ≈ N | (β, (cid:10) ), |     |     |
| --- | --- | --- | ------ | --------------- | --- | --- |
(9)
|     |     |     | n d | n   |                        |     |
| --- | --- | --- | --- | --- | ---------------------- | --- |
|     | ≈   |     |     |     | (cid:10) =(cid:10)∗/n. |     |
where d denotes approximate equality in distribution and n We will construct
θ
confidence sets that are uniformly valid for all parameter values in the identified set when
the approximation in (9) holds exactly with (cid:10) known. That is, we construct confidence sets
n
| C (βˆ | ,(cid:10) )satisfying |     |     |     |     |     |
| ----- | --------------------- | --- | --- | --- | --- | --- |
n n
n
|     |     |                   |                                  | (cid:16) | (cid:17)          |      |
| --- | --- | ----------------- | -------------------------------- | -------- | ----------------- | ---- |
|     |     |                   | P                                | θ ∈C (βˆ | ,(cid:10) ) ≥1−α. |      |
|     |     | in f              | i n f βˆ                         |          |                   | (10) |
|     |     | δ∈ (cid:5) ,τθ∈S( | δ + τ,(cid:5)) n ∼N(δ+τ,(cid:10) | n ) n n  | n                 |      |
InSection3.3,wewillshowthatfinite-samplesizecontrolinthenormalmodelinthesenseof
(10)translatestouniformasymptoticsizecontroloveralargeclassofdata-generatingprocesses
(cid:10)ˆ
when (cid:10) is replaced by a consistent estimate . That is, we will show that the constructed
|     | n   |     |     | n   |     |     |
| --- | --- | --- | --- | --- | --- | --- |
confidencesetsfurthersatisfy
(cid:16) (cid:17)
11. Inourongoingthree-periodDiDexample,(cid:5)SD(M)={δ: ASDδ≤dSD}forASD= 1 1 anddSD=
− 1− 1
(M,M)(cid:2)
.Thisgeneralizesnaturallywhentherearemultiplepre-periodsandmultiplepost-periods.
|     |     |     | R M(M ¯)={δ |     | ¯(δ | R M |
| --- | --- | --- | ----------- | --- | --- | --- |
12. Forexample,definethepolyhedra(cid:5) ,+ :∀t≥0,|δ t+1 −δ t |≤M s+1 −δ s )}and(cid:5) ,− ={δ:
|     |     |     | s   | (cid:14) |     | s   |
| --- | --- | --- | --- | -------- | --- | --- |
∀t≥0, |δ −δ |≤−M ¯(δ −δ )}.Then(cid:5)RM(M ¯)= ((cid:5) R M(M ¯)∪(cid:5) R M(M ¯)).
|     | t+1 | t s+1 | s   | s<0 s ,+ | s ,− |     |
| --- | --- | ----- | --- | -------- | ---- | --- |

| 2566 |     |        |          | REVIEWOFECONOMICSTUDIES |              |          |                |          |     |     |      |     |
| ---- | --- | ------ | -------- | ----------------------- | ------------ | -------- | -------------- | -------- | --- | --- | ---- | --- |
|      |     |        |          |                         |              | (cid:16) |                | (cid:17) |     |     |      |     |
|      |     | liminf | inf      |                         | inf P        | θ ∈C     | (βˆ ,(cid:10)ˆ | ) ≥1−α.  |     |     | (11) |     |
|      |     |        |          |                         |              | P        | n n            | n        |     |     |      |     |
|      |     | n→∞    | P∈Pθ∈S(δ |                         | +τ ,(cid:5)) |          |                |          |     |     |      |     |
P P
| foralargeclassofdistributionsP |     |     |     | suchthatδ |     | ∈(cid:5)forall |     | ∈P. |     |     |     |                                                                                                                                     |
| ------------------------------ | --- | --- | --- | --------- | --- | -------------- | --- | --- | --- | --- | --- | ----------------------------------------------------------------------------------------------------------------------------------- |
|                                |     |     |     |           |     | P              | P   |     |     |     |     | Downloaded from https://academic.oup.com/restud/article/90/5/2555/7039335 by Northwestern University Libraries user on 20 June 2026 |
Wewillfocusonconstructingconfidencesetsforthecasewhere(cid:5)isapolyhedron.Forthe
casewhere(cid:5)isthefiniteunionofpolyhedra,avalidconfidencesetcanbeconstructedbytaking
theunionoftheconfidencesetsforeachofitscomponents.
Lemma 2.2. Suppose that for each k =1,...,K, the c(cid:14)onfidence set C (βˆ ,(cid:10) ) satisfies
|     |     |     |     |     |     |     |     |     | n,k | n n |     |     |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
ith(cid:5)=(cid:5) .ThentheconfidencesetC (βˆ ,(cid:10) )= K C (βˆ ,(cid:10) )satisfies(10)with
| (10)w    |          |         |     |     |     |       |     | n,k |     |     |     |     |
| -------- | -------- | ------- | --- | --- | --- | ----- | --- | --- | --- | --- | --- | --- |
|          | (cid:14) | k       |     |     |     | n n n | k   | =1  | n n |     |     |     |
| (cid:5)= | K        | (cid:5) |     |     |     |       |     |     |     |     |     |     |
|          | k=1      | k .     |     |     |     |       |     |     |     |     |     |     |
In the next two sections, we introduce two approaches to obtain confidence sets satisfying
(10),withdifferentdesirablepropertiesdependingontheformof(cid:5).Thefirstapproach,based
(cid:5)
on moment inequalities, accommodates a wide range of restrictions and has some desirable
asymptoticpowerguarantees.Thesecondapproach,basedonFLCIs,canpotentiallyofferfinite-
samplepowerimprovementsforcertainspecialclassesof(cid:5)ofinterest,suchas(cid:5)SD(M).
3. INFERENCEUSINGMOMENTINEQUALITIES
Inthissection,weintroduceageneralapproachforinferencethathasgoodasymptoticproperties
over a large class of possible restrictions (cid:5). We show that inference on the partially identified
parameter θ =l(cid:2)τ in this setting is equivalent to testing a system of moment inequalities
post
with a potentially large number of nuisance parameters that enter the moments linearly. We
consideranimplementationbasedontheconditionalapproachdevelopedinARP,whichallows
ustoobtaincomputationallytractableconfidencesetswithdesirablepowerpropertiesformany
parameterconfigurations.
3.1. Representationasamomentinequalityproblemwithlinearnuisanceparameters
|     |     |     |     |     |     | θ   | =l(cid:2)τ |     | (cid:5) |     |     |     |
| --- | --- | --- | --- | --- | --- | --- | ---------- | --- | ------- | --- | --- | --- |
Consider the problem of conducting inference on post when takes the polyhedral
form (cid:5)={δ : Aδ ≤d}. We will develop tests that control size under the null hypothesis
H :θ =θ¯,δ ∈(cid:5)whenthenormalapproximation(9)holdsexactlywithknownvariancematrix
0
(cid:10)
.InSection3.3,wewillprovideconditionsunderwhichsizecontrolinthefinitesamplenor-
n
mal model translates to uniform asymptotic size control over a large class of data-generating
processes.
Asafirststep,weshowthattesting H isequivalenttotestingasystemofmomentinequali-
0
tieswithlinearnuisanceparametersinthenormalmodel.Observethatifβˆ ∼N (β, (cid:10) )forβ
|     |     |     |     |     |     |     |     |     | n   |     | n   |     |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
satisfying(3),thenE [βˆ −τ]=δ.Itfollowsthatδ ∈(cid:5)={δ : Aδ ≤d}ifandonlyif
βˆ
|                 |     |        | n ∼N(β,(cid:10) | n ) n     |     |            |     |                                |     |     |     |     |
| --------------- | --- | ------ | --------------- | --------- | --- | ---------- | --- | ------------------------------ | --- | --- | --- | --- |
| E               |     | [Aβˆ − | τ]≤d.           |           | =   | Aβˆ −dandL |     | =[0,I](cid:2)tobethematrixsuch |     |     |     |     |
| βˆ              |     | A      |                 | DefiningY |     |            |     |                                |     |     |     |     |
| n ∼N(β,(cid:10) | n   | ) n    |                 |           | n   | n          |     | post                           |     |     |     |     |
tha t τ = L τ , it is immediate that the null hypothesis H is equivalent to the composite
|     |     | post post |     |     |     |     |     | 0   |     |     |     |     |
| --- | --- | --------- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
null
|     |     |          |       |          |     |               |     | (cid:10) |      | (cid:11) |      |     |
| --- | --- | -------- | ----- | -------- | --- | ------------- | --- | -------- | ---- | -------- | ---- | --- |
|     |     | :∃τ ∈RT¯ |       | (cid:2)τ | =θ¯ | E             |     | −        | τ    | ≤0.      |      |     |
|     | H   |          | s.t.l |          | and | βˆ            |     | Y AL     |      |          | (12) |     |
|     | 0   | post     |       | post     |     | ∼N(β,(cid:10) | n ) | n        | post | post     |      |     |
n
Testing the null hypothesis H is therefore equivalent to testing that the moment inequalities
0
| E                |     | [Y −   | τ         | ]≤0holdforsomevalueofτ |     |     |      | satisfyingl(cid:2)τ |     | =θ.  |     |     |
| ---------------- | --- | ------ | --------- | ---------------------- | --- | --- | ---- | ------------------- | --- | ---- | --- | --- |
| βˆ ∼N(β,(cid:10) |     | ) n AL | post post |                        |     |     | post |                     |     | post |     |     |
| n                | n   |        |           |                        |     |     |      |                     |     |      |     |     |

RAMBACHANANDROTH AMORECREDIBLEAPPROACHTOPARALLELTRENDS 2567
Forthepurposesofdevelopingtests,itwillbeusefultore-castthisnullhypothesisinterms
ofmomentsinvolvinganunrestrictednuisanceparameterτ˜ ofdimensionT ¯ −1.Byapplyinga
change of basis to the matrix AL , we can re-write the expression AL τ as A ˜(θ,τ˜(cid:2))(cid:2)
post post post
forτ˜ ∈RT¯−1.13Thenull H isthenequivalentto 0
(cid:18) (cid:19)
H :∃τ˜ ∈RT¯−1s.t.E Y ˜ (θ¯)−X ˜τ˜ ≤0, (13)
0 n
whereY ˜(θ¯)=Y n − A ˜ (·,1) θ¯ and X ˜ = A ˜ (·,−1).14 SinceY ˜ n (θ¯)isnormallydistributedwithcovari-
ance matrix (cid:10)˜ = A(cid:10) A(cid:2) under the finite-sample normal model, testing H :θ =θ¯,δ ∈(cid:5) is
n n 0
equivalenttotestingasystemofmomentinequalitieswithlinearnuisanceparameters.
The testing problem (13) is a special case of the problem studied in ARP, which focuses
on testing null hypotheses of the form H :∃τ s.t.E[Y(θ)−Xτ|X]≤0 (a.s.). Our setting is
0
a special case of this framework in which: i) the variable X takes the degenerate distribution
X = X ˜ ,andii)Y(θ)=Y ˜(θ)islinearinθ.Thisadditionalstructurewillplayanimportantrole
inthedevelopmentofourasymptoticpowerresultsbelow.
3.2. Constructingconditionalandhybridconfidencesets
Weconsidertestsforthesystemofmomentinequalitiesdescribedaboveusingtheconditional
and hybrid methods proposed by ARP. This is for both computational and efficiency reasons.
Fromthecomputational perspective,apracticalchallenge totestingthehypothesis (13)inour
settingisthatthedimensionofthenuisanceparameterτ˜ isT ¯ −1,andthuswillbelargeifthere
are many post-treatment periods. For example, 5 of the 12 recent event-study papers reviewed
in Roth (2022) have T ¯ >10. This renders many moment inequality methods, especially those
whichrelyontestinversionoveragridforthefullparametervector,computationallyinfeasible.
To tractably deal with the nuisance parameter, we consider tests based on the conditional and
hybrid approaches of ARP, which directly exploit the linear structure of the hypothesis (13)
¯
to deliver computationally tractable tests even when the number of post-treatment periods T
is large.15 From the perspective of power, we will show that the tests proposed by ARP have
(near-)optimallocalasymptoticpowerinoursettingwhenanLICQconditionissatisfied.
Webrieflysketchtheconstructionoftheconditionaltestingapproachinoursetting,andrefer
the reader to ARP for full details. These tests are implemented in the HonestDiD R and Stata
packagesthataccompanythepaper.
13. Let(cid:13)beasquarematrixwiththevectorl (cid:2) inthefirst(cid:20)rowandremain(cid:21)ingrowschosensothat(cid:13)hasfullrank.
θ
DefineA ˜:= ALpost (cid:13)−1.ThenALpost τ post =A ˜(cid:13)τ post =A ˜ (cid:13) (cid:4) (−1, (cid:5) · (cid:6) )τ pos(cid:7)t .IfT ¯ =1,thenτ˜is0-dimensionaland
:=τ˜
shouldbeinterpretedas0.
14. WeusethenotationV(·,1)todenotethefirstcolumnofamatrixV,andV(·,−1)todenotethematrixcontaining
allbutthefirstcolumnofV.
15. Othermomentinequalitymethodshavebeenproposedforsubvectorinference,buttypicallydonotexploit
the linear structure of our setting—see, e.g. Romano and Shaikh (2008), Chernozhukov et al. (2015), Bugni et al.
(2017)andChenetal.(2018)andKaidoetal.(2019).ChoandRussell(2019),Gafarov(2019),andFlynn(2019)also
providemethodsforsubvectorinferencewithlinearmomentinequalities,butincontrasttoourapproachrequirealinear
independenceconstraintqualification(LICQ)assumptionforsizecontrol.Morerecently,CoxandShi(2022)introduced
newtestsforthelinearmomentinequalitysettinginARP;seeSection3.5belowforfurtherdiscussion.
Downloaded
from
https://academic.oup.com/restud/article/90/5/2555/7039335
by
Northwestern
University
Libraries
user
on
20
June
2026

| 2568 |     |     | REVIEWOFECONOMICSTUDIES |     |     |     |     |     |     |     |     |     |
| ---- | --- | --- | ----------------------- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
θ¯
3.2.1. Conditional confidence sets. Suppose we wish to test (13) for some fixed . The
conditionaltestingapproachconsiderstestsbasedontheprofiledteststatistic
|     |     |     | ηˆ  | :=minηs.t.Y | ˜ (θ¯)−X | ˜τ˜ | ≤σ˜ ·η, |     |     |     | (14) |                                                                                                                                     |
| --- | --- | --- | --- | ----------- | -------- | --- | ------- | --- | --- | --- | ---- | ----------------------------------------------------------------------------------------------------------------------------------- |
|     |     |     |     |             | n        |     | n       |     |     |     |      | Downloaded from https://academic.oup.com/restud/article/90/5/2555/7039335 by Northwestern University Libraries user on 20 June 2026 |
η,τ˜
(cid:22)
|     | σ˜ = diag((cid:10)˜ | ).  |     |     |     |     |     |     |     |     |     |     |
| --- | ------------------- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
where n n This linear program selects the value of the nuisance parameters
τ˜ ∈RT¯−1
that minimizes the maximum studentized moment. Duality results from linear pro-
gramming (e.g. Schrijver (1986), Section 7.4) imply that the value ηˆ obtained from the primal
program(14)equalstheoptimalvalueofthedualprogram16
|     |     | ηˆ =maxγ(cid:2) |     | Y ˜ (θ¯)s.t.γ(cid:2) | X ˜ | =0,γ(cid:2)σ˜ | =1, | γ ≥0. |     |     | (15) |     |
| --- | --- | --------------- | --- | -------------------- | --- | ------------- | --- | ----- | --- | --- | ---- | --- |
|     |     |                 |     | n                    |     |               | n   |       |     |     |      |     |
γ
Ifavectorγ ∗isoptimalinthedualproblemabove,thenitisavectorofLagrangemultipliersfor
the primal problem. Standard results in linear programming imply that the optimum is always
obtained at one of the finite set of vertices, V((cid:10) ) (also known as the set of basic feasible
|     |     |     | ˆ   |     |     | n   |     |     |     |     |     |     |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
solutions).WedenotebyV ⊂ V((cid:10) )thesetofoptimalverticesofthedualprogram.17
|     |     |     | n   | n   |     |     |     |     |     |     |     |     |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
Toconstructcriticalvalues,ARPusethefactthatthedistributionofηˆhasatruncatednormal
distributionconditionalontheeventthatγ ∗isoptimalinthedualproblem.Specifically,
ˆ
|     |     |     | ηˆ|{γ | ∗ ∈ V | ,S =s}∼ξ|ξ | ∈[vlo,vup], |     |     |     |     |     |     |
| --- | --- | --- | ----- | ----- | ---------- | ----------- | --- | --- | --- | --- | --- | --- |
|     |     |     |       | n     | n          |             |     |     |     |     |     |     |
ξ ∼N(γ (cid:2)μ˜(θ¯), γ (cid:2)(cid:10)˜ γ ), μ˜(θ¯)=E[Y ˜ (θ¯)], =(I −((cid:10)˜ γ /γ (cid:2)(cid:10)˜ γ )γ (cid:2))Y ˜ (θ¯),
| where   |                                |     | ∗   |      |                     | S   |     | ∗                           |     | ∗   | and |     |
| ------- | ------------------------------ | --- | --- | ---- | ------------------- | --- | --- | --------------------------- | --- | --- | --- | --- |
|         | areknownfunctionsof(cid:10)˜ ∗ |     | ∗ n |      | n                   | n   |     | n                           | ∗ n | ∗ n |     |     |
| vlo,vup |                                |     |     | ,s,γ | (seeLemma1inARP).18 |     |     | Intuitively,thedistribution |     |     |     |     |
|         |                                |     |     | n    | ∗                   |     |     |                             |     |     |     |     |
ofηˆdependsonthevectorμ˜(θ¯),andsotoeliminatethedependenceonthecomponentsofμ˜(θ¯)
otherthanγ(cid:2)μ˜(θ¯),weconditiononS ,whichisasufficientstatisticforthecomponentsofμ˜(θ¯)
n
thatareorthogonaltoγ(cid:2)μ˜(θ¯).
∗
ηˆ
ARP show that all quantiles of the conditional distribution of in the previous display are
|     | γ(cid:2)μ˜(θ¯). |     |     |     |     |     |     | γ(cid:2)μ˜(θ¯)≤0. |     |     |     |     |
| --- | --------------- | --- | --- | --- | --- | --- | --- | ----------------- | --- | --- | --- | --- |
increasing in Moreover, the null hypothesis (13) implies To see why this
|     | ∗   |     |     |     |     |     |     | ∗   |      |     |                |     |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | ---- | --- | -------------- | --- |
|     |     |     |     |     |     |     |     |     | γ ≥0 | γ   | (cid:2)X ˜ =0, |     |
is the case, note that the definition of the dual problem (15) implies that ∗ and
∗
whereas the null hypothesis implies that there exists τ˜ such that μ˜(θ¯)−X ˜τ˜ ≤0. It follows
|      | γ(cid:2)μ˜(θ¯)=γ(cid:2)(μ˜(θ¯)−X |     | ˜τ˜)≤0 |       |           |     |     |             |      |           |      |     |
| ---- | -------------------------------- | --- | ------ | ----- | --------- | --- | --- | ----------- | ---- | --------- | ---- | --- |
| that |                                  |     |        | under | the null. | The | ARP | conditional | test | therefore | uses |     |
|      | ∗ ∗                              |     |        |       |           |     |     |             |      |           |      |     |
the critical value max{0,c }, where c is the 1−α quantile of the truncated normal dis-
|     |                |     | C,α |     | C,α |     |     |                     |     |     |     |     |
| --- | -------------- | --- | --- | --- | --- | --- | --- | ------------------- | --- | --- | --- | --- |
|     | ξ|ξ ∈[vlo,vup] |     |     |     |     |     |     | γ(cid:2)μ˜(θ¯)=0.19 |     |     |     |     |
tribution under the worst-case assumption that ∗ We denote by
Technically,thedualityresultsrequirethatηˆbefinite.However,onecanshowthatηˆisfinitewithprobability
16.
˜ containsavectorwithallnegativeentries,inwhichcasetheidentifiedsetforθistherealline.
1,unlessthespanofX
Wethereforetriviallydefineourtestnevertorejectifηˆ=−∞.
17. Ingeneral,theremaynotbeauniquesolutiontothedualprogram.ARPshowthatinthecontextofthefinite
samplenormal,conditionalonanyonevertexofthedualprogram’sfeasiblesetbeingoptimal,everyothervertexis
optimalwitheitherprobability0or1.Inthefinitesamplenormalmodel,itthussufficestoconditionontheeventthat
avectorγ∗∈V ˆ .Ourconditionsforasymptoticvalidityoftheconditionaltestbelow,however,ensurethattheoptimal
vertexwillbeuniquew.p.a.1.
18. The cut-offs vlo and vup are the maximum and minimum of the set {x:x=maxγ∈Fn γ(cid:2)(s+
((cid:10)˜ γ∗/γ (cid:2)(cid:10)˜ γ∗)x)}whenγ (cid:2)(cid:10)˜ γ∗(cid:4)=0,whereFnisthefeasiblesetofthedualprogram(15).Whenγ (cid:2)(cid:10)˜ γ∗=0,we
| n   | ∗ n | ∗   | n   |     |     |     |     |     |     | ∗ n |     |     |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
definevlo=−∞andvup=∞,sotheconditionaltestrejectsifandonlyifηˆ>0.
19. AsnotedinARP,thetruncationat0isnotnecessaryfortheconditionaltesttocontrolsizeinthefinite
samplenormalmodel,butitsimplifiesasymptoticarguments.Italsopreventsthetestfromrejectingwhenallmoments
aresatisfiedinsample.

| RAMBACHANANDROTH       |     | AMORECREDIBLEAPPROACHTOPARALLELTRENDS |     |     |     |     | 2569 |
| ---------------------- | --- | ------------------------------------- | --- | --- | --- | --- | ---- |
| ψC(βˆ ,A,d,θ¯,(cid:10) |     |                                       |     |     |     |     | =θ¯  |
)anindicatorforwhethertheconditionaltestrejectsthenullthatθ for
| α n | n   |     |     |     |     |     |     |
| --- | --- | --- | --- | --- | --- | --- | --- |
(cid:5)={δ : Aδ ≤d}.
|                       |      |              |     | θ      |                 | CC (βˆ ,(cid:10) ):={θ¯ | :ψC(βˆ , |
| --------------------- | ---- | ------------ | --- | ------ | --------------- | ----------------------- | -------- |
| We can then           | form | a confidence | set | for by | test inversion, |                         |          |
|                       |      |              |     |        |                 | α,n n n                 | α n      |
| A,d,θ¯,(cid:10) )=0}. |      |              |     |        |                 |                         | E        |
n The construction of the conditional test implies that βˆ ∼N(δ+τ,(cid:10) ) Downloaded from https://academic.oup.com/restud/article/90/5/2555/7039335 by Northwestern University Libraries user on 20 June 2026
n n
[ψC(βˆ ,A,d,l(cid:2)τ ,(cid:10) )]≤α δ ∈(cid:5). CC (βˆ ,(cid:10) )
α n post n for any It therefore follows that α,n n n satisfie s
thefinite-samplecoveragerequirement(10).InSection3.3below,weshowthatcoverageinthe
normalmodeltranslatestouniformasymptoticcoverageoveralargeclassofDGPs.
¯
Example4. AninstructiveexampleiswhenT =1(sothattherearenonuisanceparameters),
| (cid:10)˜ |     | ˜   |     |     |     | ˜   | ˜   |
| --------- | --- | --- | --- | --- | --- | --- | --- |
and = I. Then ηˆ =max Y is the maximum component of Y , vlo =max j(cid:4)=jˆY is the
| n   |     | j n,j |     |     |     | n   | n,j |
| --- | --- | ----- | --- | --- | --- | --- | --- |
|     |     | ˜     | ˆ   |     |     |     |     |
second-largestelementofY (where j denotestheindexofthemax),andvup =∞.Thus,the
n
|     |     | ηˆ  |     | 1−α |     |     |     |
| --- | --- | --- | --- | --- | --- | --- | --- |
conditional test rejects when exceeds the quantile of the standard normal distribution
truncated to [vlo,∞). Intuitively, this means that the conditional test will tend to reject when
themaximumsamplemomentisfarenoughawayfromthesecond-largestsamplemoment.Two
special cases are worth special consideration. First, consider the case where in population one
moment is violated and the remaining moments are very slack, e.g. μ˜ >0 while μ˜ (cid:19)0 for
|     |     |     |     |     |     | 1   | j   |
| --- | --- | --- | --- | --- | --- | --- | --- |
(cid:4)=1.ThenwithhighprobabilityηˆwillequalY ˜ andvlowillbeverynegative.Thus,thecon-
| j   |     |     |     |     | n,1 |     |     |
| --- | --- | --- | --- | --- | --- | --- | --- |
˜
ditional test will behave similarly to a one-sided t-test using Y , which can be shown to be
n,1
the most powerful test in the finite-sample normal model in this example. On the other hand,
ifμ ≈μ >0,thenthemaximumandsecond-largestsamplemoments(i.e.ηˆ andvlo)willbe
1 2
closetogetherwithhighprobability,sotheconditionaltestmaynotrejectwithsubstantialprob-
| abilityevenifbothμ |     | andμ |     |     |     |     |     |
| ------------------ | --- | ---- | --- | --- | --- | --- | --- |
arelarge,andthustheconditionaltestmayhavepoorpower.To
|     |     | 1 2 |     |     |     |     |     |
| --- | --- | --- | --- | --- | --- | --- | --- |
improvepowerinthesesettingswherethebindingandnon-bindingmomentsareclosetogether
(relativetosamplingvariation),ARPintroducea“hybrid”test,whichwedescribenext.
3.2.2. Hybridconfidence sets. ARPproposea“hybrid”testthatcombinesthecondition-
μ˜(θ¯)=0.
ing approach above with a test based on the “least-favourable” assumption that In
particular, ARP show that the distribution of ηˆ under the null is bounded above (in the sense
|     |     |     |     |     | ηˆ  | μ˜(θ¯)=0 |     |
| --- | --- | --- | --- | --- | --- | -------- | --- |
of first-order stochastic dominance) by the distribution of when (see Section 3.2
of ARP). One can therefore construct a size-κ least-favourable (LF) test in the finite-sample
normal model that rejects whenever ηˆ exceeds the 1−κ quantile of maxγ∈V((cid:10)) γ(cid:2)ξ, where
(cid:10)˜
ξ ∼N(0, ).Thiscriticalvalue,whichwewilldenotebyc LF,κ,caneasilybecalculatedby
n
simulation. For 0<κ <α, the ARP conditional-LF hybrid test is defined to reject if a first-
size-κ
stage, LF test rejects. If this first-stage test does not reject, then in the second stage the
hybridtestconductsamodifiedversionofthesize-((α−κ)/(1−κ))conditionaltestthatalso
conditionsontheeventthatthefirst-stageLFtestdidnotreject.Inparticular,bysimilarlogicas
fortheconditionaltest,wehavethat
ˆ
|     | ηˆ|{γ | ∈ V | ,S =s, | ηˆ ≤c | }∼ξ|ξ | ∈[vlo,vu p], |     |
| --- | ----- | --- | ------ | ----- | ----- | ------------ | --- |
|     |       | ∗ n | n      |       | LF,κ  | H            |     |
where vu p =min{vlo,c } (see Section 3.4 of ARP). The second-stage of the hybrid test
| H   |     | LF,κ |     |     |     |     |     |
| --- | --- | ---- | --- | --- | --- | --- | --- |
rejectsifηˆexceedsthecriticalvalueforthesize-((α−κ)/(1−κ))conditionaltestthatusesvup
H
instead of vup. We will denote by ψC-LF(βˆ ,A,d,θ¯,(cid:10) ) an indicator for whether the hybrid
|                                 |     |     | κ,α                  | n   | n         |                               |     |
| ------------------------------- | --- | --- | -------------------- | --- | --------- | ----------------------------- | --- |
| testrejectsataparticularvalueθ¯ |     |     | ,anddenotebyCC-LF(βˆ |     |           |                               |     |
|                                 |     |     |                      |     | ,(cid:10) | )theconfidencesetthatcollects |     |
|                                 |     |     |                      |     | κ,α,n n   | n                             |     |
thevaluesofθ¯
forwhichthehybridtestdoesnotreject.Aswiththeconditionaltest,byconstruc-
tion the hybrid confidence set satisfies that coverage criterion (10) in the finite-sample normal
| model.Inourimplementationbelow,weuseκ |     |     |     | =α/10,followingARP. |     |     |     |
| ------------------------------------- | --- | --- | --- | ------------------- | --- | --- | --- |

| 2570 |     |     |     | REVIEWOFECONOMICSTUDIES |     |     |     |     |     |
| ---- | --- | --- | --- | ----------------------- | --- | --- | --- | --- | --- |
3.3. Uniformasymptoticsizecontrol
We now provide conditions under which size control in the finite sample normal model trans-
latestouniformasymptoticsizecontroloveralargeclassofdata-generatingprocessesP under
whichβˆ isasymptoticallynormallydistributedand(cid:10) isreplacedwithaconsistentestimator Downloaded from https://academic.oup.com/restud/article/90/5/2555/7039335 by Northwestern University Libraries user on 20 June 2026
|     | n   |     |     |     |     |     | n   |     |     |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
(cid:10)ˆ .Inparticular,weprovidesufficientconditionsonβˆ ,(cid:10)ˆ ,and(cid:5)suchthatthehigher-level
| n   |     |     |     |     |     |     | n   | n   |     |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
conditionsforsizecontrolinARParesatisfied(Proposition2inARP).
|     |     |     |     |     | (cid:5)={Aδ | ≤d} |     |     |     |
| --- | --- | --- | --- | --- | ----------- | --- | --- | --- | --- |
Throughout this section, we fix for some A with all non-zero rows, and
assume that (cid:5) is non√-empty. We consider a class of data-generating processes, indexed by
P ∈P, under which n(βˆ −β ) is asymptotically normal, where β satisfies the causal
|     |     |     | n   | P     |     |     |            |     | P   |
| --- | --- | --- | --- | ----- | --- | --- | ---------- | --- | --- |
|     |     |     | β   | =δ +L | τ   |     | δ ∈(cid:5) | τ   | ∈RT |
decomposition in (3), i.e. P,post for and P,post ¯ . The parame-
|     |     |     | P   | P   | post |     | P   |     |     |
| --- | --- | --- | --- | --- | ---- | --- | --- | --- | --- |
ter of interest is θ :=l(cid:2)τ , for some fixed l (cid:4)=0. Our first assumption imposes uniform
|     |     | P   | P,post |     |     |     |     |     |     |
| --- | --- | --- | ------ | --- | --- | --- | --- | --- | --- |
asymptoticnormalityofβˆ
.
n
Assumption2. LetBL denotethesetofLipschitzfunctionswhichareboundedby1inabsolute
1
valueandhaveLipschitzconstantboundedby1.Weassume
|        |     |              |           | (cid:23)      |            |        |          |                   | (cid:23)    |
| ------ | --- | ------------ | --------- | ------------- | ---------- | ------ | -------- | ----------------- | ----------- |
|        |     |              |           |               | (cid:18) √ |        | (cid:19) | (cid:10) (cid:11) |             |
|        |     |              |           | (cid:23)      | n(βˆ       |        |          |                   | (cid:23)    |
|        |     | lim          | sup       | sup (cid:23)E | f(         | −β     | )) −E    | f(ξ )             | (cid:23)=0, |
|        |     | n→∞          |           | P             |            | n      | P        | P                 |             |
|        |     |              | P∈P f∈BL1 |               |            |        |          |                   |             |
| whereξ | ∼N  | (0, (cid:10) | ),andβ    | =δ            | +L         | τ      | forδ     | ∈(cid:5)andτ      | ∈RT¯        |
|        |     |              |           |               |            | P,post |          |                   | P,post .    |
|        | P   | P            |           | P P           | post       |        | P        |                   |             |
Convergence in distribution is equivalent to convergence in bounded Lipschitz metric (see
Theorem1.12.4invanderVaartandW√ellner,1996),soAssumption2formalizesthenotionof
n(βˆ
uniformconvergenceindistributionof −β )toaN (0, (cid:10) )variableunder P.
|     |     |     |     |     |     | n P |     | P   |     |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
βˆ
Our next two assumptions require that the eigenvalues of the asymptotic variance of be
n
bounded above and away from zero, and that there exists a uniformly consistent estimator for
| thevarianceofβˆ |     | .   |     |     |     |     |     |     |     |
| --------------- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
n
Assumption3. LetSdenotethesetofmatriceswitheigenvaluesboundedbelowbyλ>0and
¯
| abovebyλ¯ |     | ≥λ.Forall | P ∈P,(cid:10) | ∈S. |     |     |     |     |     |
| --------- | --- | --------- | ------------- | --- | --- | --- | --- | --- | --- |
P
¯
Wehaveanestimator(cid:10)ˆ
| Assumption4. |     |     |     |     | thatisuniformlyconsistentfor(cid:10) |     |     |          | ,   |
| ------------ | --- | --- | --- | --- | ------------------------------------ | --- | --- | -------- | --- |
|              |     |     |     |     | n                                    |     |     |          | P   |
|              |     |     |     |     | (cid:16)                             |     |     | (cid:17) |     |
(cid:20)(cid:10)ˆ
|     |     |     |     | lim supP |     | −(cid:10) | (cid:20)>(cid:9) | =0, |     |
| --- | --- | --- | --- | -------- | --- | --------- | ---------------- | --- | --- |
|     |     |     |     |          | P   | n         | P                |     |     |
n→∞ P∈P
forall(cid:9) >0.
|              | Finally,weimposesomeregularityconditionsonthematrix |                                |     |     |     |     |     | A.  |     |
| ------------ | --------------------------------------------------- | ------------------------------ | --- | --- | --- | --- | --- | --- | --- |
| Assumption5. |                                                     | Atleastoneofthefollowingholds. |     |     |     |     |     |     |     |
(A)Fork 1(cid:2) +k = (cid:3)dim(δ),thematrix Acanbewrittenas TQ,where Q hasfullrow-rank
2
|     |     | Ik 0 |     |     |     |     |     |     |     |
| --- | --- | ---- | --- | --- | --- | --- | --- | --- | --- |
= − 1
and T I k1 0 . (We allow for the case where one of k 1 or k 2 is 0, in which case the
Ik2
0
zero-dimensionalblockscanbeignored).
Let γ¯ ,...,γ¯ be the elements of V(I). Then for all k, either γ¯(cid:2)A=0 or
|     | (B)     | 1              | K    |                      |     |     |     |     |     |
| --- | ------- | -------------- | ---- | -------------------- | --- | --- | --- | --- | --- |
|     |         | (cid:20)(γ¯    | −aγ¯ | )(cid:2)A(cid:20)>0. |     |     |     |     | k   |
|     | inf a≥0 | inf j(cid:4)=k |      |                      |     |     |     |     |     |
|     |         | k              | j    |                      |     |     |     |     |     |
Part (A) of Assumption 5 imposes that the only source of degeneracy in the rows of A is
matching inequalities of opposite signs. This is the case for many restrictions of interest, such
¯).
as (cid:5)SD(M) and the polyhedra that form (cid:5)RM(M Part (B) provides an alternative, higher-
levelconditionthatensuresthatfordistinctverticesγ¯ ,γ¯ ,therandomvariablesγ¯(cid:2)Y ˜ andγ¯(cid:2)Y ˜
|     |     |     |     |     |     |     | k j |     | n n |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
j k

|     | RAMBACHANANDROTH |     |     |     | AMORECREDIBLEAPPROACHTOPARALLELTRENDS |     |     |     |     | 2571 |
| --- | ---------------- | --- | --- | --- | ------------------------------------- | --- | --- | --- | --- | ---- |
are not perfectly positively correlated with each other. Assumption 5 is used to guarantee that
degeneracyintheasymptoticdistributionofγ(cid:2)Y ˜ arisesonlyfromknowndegeneraciesin A.We
n
note, however, that Assumption 5 does not rule out settings where the solutions to the bounds
of the identified set given in equation (5) and (6) are non-unique or degenerate (i.e. where the
Downloaded from https://academic.oup.com/restud/article/90/5/2555/7039335 by Northwestern University Libraries user on 20 June 2026
θ
extreme points for occur at “flat faces” of the identified set). If A is full-rank, for example,
μ˜(θ¯)
then Assumption 5(A) holds trivially with T = I, and thus the mean of the moments is
completelyunrestricted.20
TheassumptionsstatedabovearesufficientfortheconditionsinProposition2inARP,which
establishesuniformsizecontrolfortheconditionalandhybridtests.
Proposition 3.1. Suppose Assumptions 2–5 hold. Then the conditional and LF-hybrid tests
| uniformlycontrolsize.Thatis,foranyα |     |     |     |     |          | <0.5,   |     |     |                 |     |
| ----------------------------------- | --- | --- | --- | --- | -------- | ------- | --- | --- | --------------- | --- |
|                                     |     |     |     |     | (cid:24) | (cid:2) |     |     | (cid:3)(cid:25) |     |
1
|     |     |     | limsupsupE |     | ψC       | βˆ ,A,d,θ |     | , (cid:10)ˆ | ≤α.             |     |
| --- | --- | --- | ---------- | --- | -------- | --------- | --- | ----------- | --------------- | --- |
|     |     |     |            |     | P        | α         |     | P           | n               |     |
|     |     |     | n→∞        |     |          | n         |     | n           |                 |     |
|     |     |     |            | P∈P | (cid:24) | (cid:2)   |     |             | (cid:3)(cid:25) |     |
1
|     |     |     | limsupsupE |     | ψC-LF |     | βˆ ,A,d,θ | ,   | (cid:10)ˆ ≤α. |     |
| --- | --- | --- | ---------- | --- | ----- | --- | --------- | --- | ------------- | --- |
|     |     |     |            |     | P     | κ,α | n         | P   | n             |     |
|     |     |     | n→∞        | P∈P |       |     |           |     | n             |     |
3.4. Uniformasymptoticconsistency
Wenextprovideconditionsunderwhichtheconditionalandhybridtestsareuniformlyasymp-
totically consistent, in the sense that power against fixed alternatives outside the identified set
convergesuniformlyto1.Toestablishuniformconsistencyoftheconditionalandhybridtests,
westrengthenAssumptions2and3asfollows.
|              |     |      |     | =((βˆ | −β )(cid:2),(vec((cid:10)ˆ |     | )−vec((cid:10) | ))(cid:2))(cid:2),wherevec((cid:10))isthevectorof |     |     |
| ------------ | --- | ---- | --- | ----- | -------------------------- | --- | -------------- | ------------------------------------------------- | --- | --- |
| Assumption6. |     | LetW |     |       |                            |     |                |                                                   |     |     |
|              |     |      | n   | n     | P                          |     | n              | P                                                 |     |     |
theelementsofthematrix(cid:10).Weassume
|     |     |     |     |     | (cid:23)(cid:23)  | (cid:10) √ | (cid:11) | (cid:10) | (cid:11)(cid:23)(cid:23) |     |
| --- | --- | --- | --- | --- | ----------------- | ---------- | -------- | -------- | ------------------------ | --- |
|     |     |     |     |     | (cid:23)(cid:23)E | f(         | )        | −E f(ξ+) | (cid:23)(cid:23)=0,      |     |
|     |     |     | lim | sup | sup               | P          | nW n     |          |                          |     |
|     |     |     | n→∞ |     |                   |            |          |          | P                        |     |
P∈P f∈BL1
|     |     |     |     | (cid:16) |     | (cid:17) |     |     |     |     |
| --- | --- | --- | --- | -------- | --- | -------- | --- | --- | --- | --- |
(cid:10)
| whereξ+ | ∼N  | (0, | V ),V | =   | P VP,β(cid:10)           | .   |     |     |     |     |
| ------- | --- | --- | ----- | --- | ------------------------ | --- | --- | --- | --- | --- |
|         | P   |     | P     | P   | VP,(cid:10)β VP,(cid:10) |     |     |     |     |     |
Assumption 7. For all P ∈P, (cid:10) ∈S and the matrix V defined in Assumption 6 lies in a
|     |     |     |     |     | P   |     |     | P   |     |     |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
compactsetV.Additionally,((cid:10) −V † )haseigenvaluesboundedbelowbyλ˜ >0,
|     |     |     |     |     | P,β(cid:10)V | V           | P,(cid:10)β |     |     |     |
| --- | --- | --- | --- | --- | ------------ | ----------- | ----------- | --- | --- | --- |
|     |     |     |     |     | P            | P ,(cid:10) |             |     |     |     |
where†denotestheMoore–Penroseinverse.
|     |     |     |     |     |     |     |     |     | βˆ (cid:10)ˆ |     |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | ------------ | --- |
Assumption 6 strengthens Assumption 2 to require that and have a joint normal
|     |     |     |     |     |     |     |     |     | n n |     |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
asymptotic distribution. Although somewhat more restrictive, event-study estimates are often
estimated via OLS, and standard covariance estimators for OLS, including cluster-robust vari-
anceestimators,produceasymptoticallynormalestimatesasthenumberofclustersgrowslarge
(Hansen, 2007; Stock and Watson, 2008; Hansen and Lee, 2019). We do not impose that the
|     |     |     |     | βˆ  | (cid:10)ˆ |     |     |     |     |     |
| --- | --- | --- | --- | --- | --------- | --- | --- | --- | --- | --- |
asymptotic distributions of and n are independent, as would occur in linear models if
n
thelinearmodeliscorrectlyspecified.Assumption7strengthensAssumption3torequirethat
theasymptoticdistributionofβˆ isnotperfectlyasymptoticallycolinearwith(cid:10)ˆ
|     |     |     |     |     | n   |     |     |     | n . |     |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
20. Somevaluesof AsatisfyingAssumption5mayimplythatcertainpairsofmomentscannotsimultaneously
bebinding.Forexample,therestrictionthat|δ |≤1canberepresentedasδ ≤1and−δ ≤1,whichsatisfiesAssump-
|     |     |     |     |     | 1   |     |     | 1   | 1   |     |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
tion5(A),butclearlybothmomentscannotsimultaneouslybind.NeverthelessAssumption5(A)iscompatiblewith“flat
faces”evenwhenAisnotfullrank.Forexample,if(cid:5)correspondswiththerestrictions|δ |≤1and|δ |≤1,thenthe
|                   |     |     |                                          |     |     |     |     |       | 1 2 |     |
| ----------------- | --- | --- | ---------------------------------------- | --- | --- | --- | --- | ----- | --- | --- |
| extremepointsforθ |     | =τ  | 2occuratflatfacesoftheidentifiedsetfor(τ |     |     |     |     | ,τ ). |     |     |
1 2

2572 REVIEWOFECONOMICSTUDIES
Undertheimposedassumptions,weobtainuniformconsistencyoftheconditionalandhybrid
tests.
Proposition3.2. SupposeAssumptions4–7hold.Thenforanyx >0andα <0.5,
(cid:24) (cid:2) (cid:3)(cid:25)
lim inf E ψC βˆ ,A,d,θub+x, 1 (cid:10)ˆ =1
n→∞P∈P P
(cid:24)
α
(cid:2)
n P n n
(cid:3)(cid:25)
lim inf E ψC-LF βˆ ,A,d,θub+x, 1 (cid:10)ˆ =1,
n→∞P∈P P κ,α n P n n
whereθub =supS(β ,(cid:5))istheupperboundoftheidentifiedset.Theanalogousresultholds
P P
replacingθub+x withθlb−x forθlb =infS(β ,(cid:5)).
P P P P
3.5. Optimallocalasymptoticpower
We next provide conditions under which the conditional test has optimal local asymptotic
power. We first state the conditions and our formal results, and then provide several examples
highlightingwhentheassumptionswillandwillnothold.
3.5.1. Main results. We begin by defining LICQ. Recall that the upper bound of the
identifiedsetisgivenby
(cid:2) (cid:3)
θub(β,(cid:5))=l (cid:2)β − minl (cid:2)δ , s.t. Aδ ≤d,δ =β .
post post pre pre
δ
Sinceδ =β −τ ,wecanre-writetheupperboundasamaximizationoverτ ,
post post post post
θub(β,(cid:5))=maxl (cid:2)τ
post
, s.t. − A(·,post) τ
post
≤d− Aβ, (16)
τ
post
where A(·,post)containsthecolumnsof Acorrespondingwithδ
post
.Letτ
p
∗
ost
denoteasolutionto
theoptimizationforθub(β,(cid:5))in(16),andlet B∗ denotetheindicesofthebindingconstraints,
sothat−A(B∗,post) τ p ∗ ost =d B∗ − A(B∗,·) β and−A(−B∗,post) τ p ∗ ost <d−B∗ − A(−B∗,·) β.
Definition 2 (LICQ). We say that LICQ holds in direction l if there exists a solution τ∗ to
post
(16)suchthatthegradientofthebindingconstraintswithrespecttoτ
post
,−A(B∗,post),hasfull
rowrank.21 WedefineLICQinthedirection−l analogouslyfortheoptimizationthatreplaces
maxwithminin(16).
For (cid:9) >0, we define P (cid:9) to be the set of distributions P ∈P such that LICQ holds in the
directionl andthenon-bindingconstraintsareslackbyatleast(cid:9),i.e.−A(−B∗,post) τ
p
∗
ost
<d−
Aβ −(cid:9).
P
Our next result states that for P ∈P (cid:9), the local power of the conditional test converges to
the power envelope for tests that control size in the finite sample normal model. To state this
resultformally,wedefineI
α
((cid:5),(cid:10)
n
)tobethecollectionofconfidencesetsthatcontrolsizein
thefinitesamplenormalmodel,i.e.confidencesetssatisfying(10).
21.
ThedefinitionofLICQinKaidoetal.(2021)wouldrequirethatthisconditionholdsforallsolutionsτ∗
.
post
Forourresults,however,itissufficientfortheconditiontoholdforsomesolutionτ∗
.
post
Downloaded
from
https://academic.oup.com/restud/article/90/5/2555/7039335
by
Northwestern
University
Libraries
user
on
20
June
2026

RAMBACHANANDROTH AMORECREDIBLEAPPROACHTOPARALLELTRENDS 2573
Proposition3.3. SupposeAssumptions2–4hold.Letθub =supS(β ,(cid:5)).Thenforany(cid:9) >0,
P P
x >0,andα <0.5,
(cid:23) (cid:24) (cid:2) (cid:3)(cid:25) (cid:23)
(cid:23) (cid:23)
n l → im ∞ P s ∈ u P p (cid:9) (cid:23) (cid:23) E P ψ α C βˆ n ,A,d,θ P ub+ √ 1 n x, n 1 (cid:10)ˆ n −ρ α ∗(P,x)(cid:23) (cid:23) =0,
where (cid:2)(cid:2) (cid:3) (cid:3)
1
ρ α ∗(P,x)= n l → im ∞ C
α,n
∈I s
α
u ((cid:5) p ,
n
1(cid:10)
P
) P βˆ n ∼N (β P , n 1(cid:10) P ) θ P ub+ √ n x (cid:4)∈C α,n
is the optimal local asymptotic power of a size-α test in the finite sample normal model. An
analogousresultholdsforthelowerboundundertheclassofdistributionswhereLICQholdsin
direction−l.
Since the LF-hybrid test rejects whenever the conditional test with size (α−κ)/(1−κ)
rejects,itisimmediatethatthelocalasymptoticpoweroftheLF-hybridtestisatleastasgood
asthepoweroftheoptimalsize-((α−κ)/(1−κ))test.
Corollary3.1. UndertheconditionsofProposition3.3,
(cid:2) (cid:24) (cid:2) (cid:3)(cid:25) (cid:3)
liminf inf E ψC-LF βˆ ,A,d,θub+ √ 1 x, 1 (cid:10)ˆ −ρ∗ (P,x) ≥0.
n→∞ P∈P
(cid:9)
P κ,α n P n n n (α−κ)/(1−κ)
We emphasize that Proposition 3.3 and Corollary 3.1 are new, and exploit structure in our
contextnotcontainedinthemoregeneralsettingconsideredinARP.
3.5.2. Discussion and examples. As discussed in Kaido et al. (2021), LICQ and related
constraint qualifications have been used frequently in the partial identification literature. Intu-
itively,LICQensuresthattheboundsoftheidentifiedsetaredifferentiablewithrespecttothe
meansofthemoments(μ˜(θ¯)),andthusavoidschallengesrelatedtoestimationandinferencefor
non-differentiable parameters (Hirano and Porter, 2012). Uniform LICQ conditions have been
invokedrecentlybyGafarov(2019)andChoandRussell(2019),andarelatedSlaterconstraint
qualificationisusedinKaidoandSantos(2014).Oneimportantdistinctionbetweenourresults
and previous results using LICQ is that we do not require LICQ for our size control results
(Proposition 3.1). Thus, our tests control size even when LICQ fails (and so the bounds may
be non-differentiable), but Proposition 3.3 shows that this does not come at the cost of power
asymptoticallywhenindeedLICQholds.22
Figure1providesgeometricintuitionforwhenLICQwillandwillnotholdinthecasewhere
T ¯ =2andthetargetparameteristheaverageofthepost-treatmenteffects,θ = 1(τ +τ ).In
2 1 2
panel(a),thereisaunique τ∗ (colouredinred)atwhichtwolinearlyindependent moments
post
bind,soLICQissatisfied.LICQislikewisesatisfiedinpanel(b),wheretheoptimalτ∗ isnot
post unique(aso-called“flat-face”problem).Thisisbecauseattheindicatedvaluesτ∗ (coloured
post
inred),thereiseitheroneortwolinearlyindependent bindingmoments.AfailureofLICQis
showninpanel(c).Inthisexample,therearethreebindingmomentsatτ∗ (colouredinred),
post
sothebindingconstraintscannotbelinearlyindependentinR2.Suchasituationmayarisewhen
there are both smoothness restrictions and sign or shape restrictions that are simultaneously
bindingattheboundaryoftheidentifiedset.
22. Weviewthisresultaslooselyparalleltoresultsintheweakidentificationliteratureshowingthatcertain
procedurescontrolsizeunderweakidentificationbutareefficientunderstrongidentification(e.g.Moreira,2003).
Downloaded
from
https://academic.oup.com/restud/article/90/5/2555/7039335
by
Northwestern
University
Libraries
user
on
20
June
2026

2574 REVIEWOFECONOMICSTUDIES
(a) (b) (c)
FIGURE1
DiagramillustratingwhenLICQ(Assumption2)willandwillnotholdinthecasewhereT ¯ =2.
Note:Ineachpanel,weassumethattherowsassociatedwithbindingmomentsareorderedfirstinthematrixAforeaseofnotation.The
s b a lu ti e sfi s e h d ad s i i n n g ce d t e h n e o re te i s s t a h u e n i i d q e u n e ti τ fi p ∗ e o d st se ( t co fo lo r u ( r τ e 1 d , i τ n 2 r ) e a d n ) d at th w e h d ic a h sh tw ed o r l e in d ea a r r l r y ow ind p e o p in e t n s d i e n nt th m e o d m ir e e n c t t s io a n re l b = in ( di 1 2 n , g 1 2 .I ) n (cid:2). p I a n n p el an (b e ) l , ( e a v ) e , n L t I h C o Q ug i h s
τ p ∗ ostisnotunique,LICQissatisfiedasthereiseitheroneortwolinearlyindependentbindingmomentsatthevaluesofτ p ∗ ostcoloured
inred.Inpanel(c),therearethreebindingmomentsatτ p ∗ ost(colouredinred),andsoLICQisviolated.
InthethreeperiodDiDmodel(wheretherearenonuisanceparameters,sinceT ¯ =1),LICQ
issatisfiedwhentheboundsoftheidentifiedsetareeachdeterminedbyonemoment.Thisholds
everywherefor(cid:5)SD(M)whenM >0.Itholdsalmosteverywherefor(cid:5)SDPB(M)whenM >0,
althoughitfailswhenboththesignrestrictionsandsmoothnessrestrictionsaresimultaneously
binding.(ForLICQtoholdwithnon-bindingmomentsslackbyatleast(cid:9),i.e. P ∈P (cid:9),δ
P
must
notbelocaltoapointatwhichLICQfails.)When M =0,boththeupperandlowerboundsfor
(cid:5)SD(M)and(cid:5)SDPB(M)arebinding,soLICQfails.
Moregenerally,theresultinProposition3.3isundertheasymptoticregimewherethesam-
plingvariationgrowssmallrelativetothelengthoftheidentifiedset,andthusthebindingand
non-bindingmomentsare“far”apartrelativetosamplingvariation.Importantly,itcanbeshown
that the LICQ condition rules out settings where θ is point identified. Thus, the asymptotics
considered in Proposition 3.3 may not provide a good approximation to the finite-sample per-
formanceoftheconditionaltestinsettingswhereθ ispoint-identified,orwhenthelengthofthe
identifiedsetis“small”relativetosamplingvariation.
WearenotawareofresultsanalogoustoProposition3.3foranytestthatcontrolssizeinthe
finite-samplenormalmodel.KaidoandSantos(2014)provideanefficiencyresultunderarelated
Slaterconstraintqualificationcondition,buttheirtestdoesnotcontrolsizewhentheconstraint
qualification fails. It is worth highlighting that if LICQ holds for a particular set of moments,
then it also holds if one adds moments that are slack at the optimal τ∗ . Proposition 3.3 thus
post
requiresthattheasymptoticpowerofthetestisnotaffectedbytheinclusionofslackmoments.
Theonlyothernon-trivialteststhatweareawareofthatcontrolsizeinthefinite-samplenormal
model and have this formof insensitivity to slack moments are the tests proposed byCox and
Shi(2022). Aninterestingopen question iswhether the testsproposed by Cox and Shi(2022)
alsoconvergetothepowerenvelopeunderLICQ.23
3.5.3. Extensions. Proposition 3.3 is stated for(cid:14)the case when (cid:5) is a single polyhedron.
Animmediatecorollary,however,isthatwhen(cid:5)= K (cid:5) ,theconditionaltestbasedonthe
k=1 k
union of confidence sets has optimal local asymptotic power when the (cid:5) that determines the
k
identified set bounds is unique and satisfies the conditions of Proposition 3.3. This implies,
23. ExtendingtheresultstotheCoxandShitestsisnon-trivialgiventhattheyuseadifferentteststatisticand
constructcriticalvaluesinadifferentway.
Downloaded
from
https://academic.oup.com/restud/article/90/5/2555/7039335
by
Northwestern
University
Libraries
user
on
20
June
2026

| RAMBACHANANDROTH |     |     |     | AMORECREDIBLEAPPROACHTOPARALLELTRENDS |     |     |     |     |     | 2575 |
| ---------------- | --- | --- | --- | ------------------------------------- | --- | --- | --- | --- | --- | ---- |
¯),
for example, that when (cid:5)=(cid:5)RM(M the power of the conditional test converges to the
powerenvelopewhenthereisaunique(non-zero)pre-treatmentmaximumviolation,i.e.when
| |δ  | −δ  | |>0 |     |     |     |     |     |     |     |     |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
max s<0 s+1 and has a unique solution.24 Likewise, the conditional test has optimal
|     |     | s   |     |     | ¯)  |     |     |     |     |     |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
local asymptotic power for (cid:5)SDRM(M when there is a unique maximum non-linearity in the
Downloaded from https://academic.oup.com/restud/article/90/5/2555/7039335 by Northwestern University Libraries user on 20 June 2026
pre-treatment period. Intuitively, this is because the upper bound of the identified set is deter-
mined by a single (cid:5) satisfying LICQ, so the conditional test for this (cid:5) has optimal local
|     |     | k∗  |     |     |     |     |     |     | k∗  |     |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
asymptoticpower,whereasourconsistencyresultsimplythatthetestsfortheremaining(cid:5) that
k
do not determine the identified set bound reject with probability approaching 1. See Corollary
4.1 in the working paper version of this paper for a formal derivation (Rambachan and Roth,
2021).
Proposition 3.3 shows that under LICQ the local asymptotic power of the conditional test
converges to the power envelope for tests controlling size in the finite-sample normal model.
In the working paper version of this paper, we showed that the power envelope from the
finite-samplenormalmodelcorrespondswiththepower-envelopeamongteststhatcontrolsize
asymptoticallyandhavecertaininvariancepropertiesusingresultsinMu¨ller(2011)(Proposition
E.4inRambachanandRoth,2021).
4. INFERENCEUSINGFIXEDLENGTHCONFIDENCEINTERVALS
WenextconsiderFLCIsbasedonaffineestimators.Whiletheconditionalandhybridconfidence
setsofferattractiveasymptoticpowerguaranteesunderasymptoticsinwhichsamplingvariation
grows small relative to the length of the identified set, FLCIs offer finite-sample power guar-
antees (in the normal model) for certain classes (cid:5) of interest. In certain special cases, FLCIs
may thus outperform the ARP tests when sampling variation is large relative to the length of
the identified set. For brevity of exposition, we focus on the properties of FLCIs in the case
wherethefinite-samplenormalapproximation(9)holdsexactlywith(cid:10)
n known;Armstrongand
Kolesa´r(2020b)provideuniformasymptoticresultsforFLCIsunderconditionssimilartothose
inSection3.3.
4.1. ConstructingFLCIs
FollowingDonoho(1994)andArmstrongandKolesa´r(2018,2020a),weconsiderFLCIsbased
|              |           |     | θ,  |         | C      | (a,v,χ):=(a+v(cid:2)βˆ |     | )±χ, |         | χ       |
| ------------ | --------- | --- | --- | ------- | ------ | ---------------------- | --- | ---- | ------- | ------- |
| on an affine | estimator |     | for | denoted | by α,n |                        |     |      | where a | and are |
n
scalarsandv ∈RT +T¯ .Weminimizethehalf-lengthoftheconfidenceinterval,χ,subjecttothe
¯
constraintthatC α,n (a,v,χ)satisfiesthecoveragerequirement(10)inthefinite-samplenormal
model.
|     |     |     |     |     |     |     | (cid:26) |     | (cid:27) |     |
| --- | --- | --- | --- | --- | --- | --- | -------- | --- | -------- | --- |
βˆ ∼N (β, (cid:10) ), a+v(cid:2)βˆ ∼N a+v(cid:2)β, v(cid:2)(cid:10) v |a+
| Observe | that | (cid:26) if | (cid:27) | n   | then |     |     |     | n , and hence |     |
| ------- | ---- | ----------- | -------- | --- | ---- | --- | --- | --- | ------------- | --- |
|         |      | n           |          |     |      |     | n   |     |               |     |
v(cid:2)βˆ −θ|∼|N b, v(cid:2)(cid:10) v |, b=a+v(cid:2)β−θ θ.
| n   |     |     | n   | where |     |     | is the | affine | estimator’s bias | for |
| --- | --- | --- | --- | ----- | --- | --- | ------ | ------ | ---------------- | --- |
(a,v,χ)ifandonlyif|a+v(cid:2)βˆ
Observefurtherthatθ ∈C −θ|≤χ.Forfixedv(cid:26)aluesa an(cid:27)d
|     |     |     | α,n |     |     |     | n   |     |     |     |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
v,thesmallestvalueofχ thatsatisfies(10)isthereforethe1−αquantileofthe|N ¯, v(cid:2)(cid:10) v |
|                                                         |     |          |     |             |            |          |      |             | b         | n    |
| ------------------------------------------------------- | --- | -------- | --- | ----------- | ---------- | -------- | ---- | ----------- | --------- | ---- |
| distribution,wherebistheaffineestimator’sworst-casebias |     | ¯        |     |             |            |          |      |             |           |      |
|                                                         |     |          |     |             | (cid:23)   | (cid:26) |      | (cid:27)    | (cid:23)  |      |
|                                                         |     | ¯(a,v):= |     |             | (cid:23)   |          |      |             | (cid:23). |      |
|                                                         |     | b        |     | sup         | a+v(cid:2) | δ+L      | τ    | −l (cid:2)τ |           | (17) |
|                                                         |     |          |     |             |            |          | post | post        | post      |      |
|                                                         |     |          |     | δ∈(cid:5),τ | ∈RT¯       |          |      |             |           |      |
post
24. Forthisconvergencetoholduniformly,thenon-bindingmomentsmustbeslackby(cid:9),sowewouldneedthat
| maxs<0 |δ | −δ  | |isatleast(cid:9)greaterthanthesecondlargestdifference. |     |     |     |     |     |     |     |     |
| --------- | --- | ------------------------------------------------------- | --- | --- | --- | --- | --- | --- | --- | --- |
|           | s+1 | s                                                       |     |     |     |     |     |     |     |     |

| 2576 |     |     | REVIEWOFECONOMICSTUDIES |     |     |     |     |     |
| ---- | --- | --- | ----------------------- | --- | --- | --- | --- | --- |
Letcv (t)denotethe1−α quantileofthefoldednormaldistribution|N (t, 1)|.25 Forfixeda
α
andv,thesmallestvalueofχ satisfyingthecoveragerequirement(10)isthus
|     |     | χ   | (a,v;α)=σ |     | ·cv (b ¯(a,v)/σ | ),  |     |      |
| --- | --- | --- | --------- | --- | --------------- | --- | --- | ---- |
|     |     |     |           | v,n | α               | v,n |     | (18) |
n Downloaded from https://academic.oup.com/restud/article/90/5/2555/7039335 by Northwestern University Libraries user on 20 June 2026
√
where σ := v(cid:2)(cid:10) v. The optimal (i.e. minimum-length) FLCI is constructed by choosing
| v,n | n   |     |     |     |         |     |     |     |
| --- | --- | --- | --- | --- | ------- | --- | --- | --- |
|     | v   |     |     |     | (cid:5) |     |     |     |
the values of a and to minimize (18). When is convex, this minimization can be solved
as a nested optimization problem, where both the inner and outer minimizations are convex
(Low,1995;ArmstrongandKolesa´r,2018,2020a).Wedenotethe1−αlevel,optimalFLCIby
C LCI(βˆ ,(cid:10) ):=(a +v (cid:2)βˆ )±χ ,whereχ :=inf χ (a,v;α)anda ,v
| F        |     |     |     |     |     | a,v | aretheoptimal |     |
| -------- | --- | --- | --- | --- | --- | --- | ------------- | --- |
| α ,n n n | n   | n n | n   |     | n   | n   | n n           |     |
valuesintheminimization.
4.1.1. Example:(cid:2)SD(M). Supposeθ =τ .(cid:9)For(cid:5)SD(M),theaffineestimatorusedbythe
1
optimalFLCItakestheforma+v(cid:2)βˆ =βˆ − 0 w (βˆ −βˆ ),wheretheweights
|     |     |     |     | n,1 | s=−T+1 | s n,s | n,s−1 |     |
| --- | --- | --- | --- | --- | ------ | ----- | ----- | --- |
n
w sumtoone(butmaybenegative).Thisestimatorad¯juststheevent-studycoefficientfort =1
s
by an estimate of the differential trend between t =0 and t =1 formed by taking a weighted
averageofthedifferentialtrendsinperiodspriortotreatment.Theworst-casebiaswillbesmaller
ifmoreweightisplacedonpre-treatmentperiodsclosertothetreatmentdate,butitmayreduce
w
variance to place more weight on earlier pre-periods. The weights s are optimally chosen to
balancethistrade-off.
4.2. Finite-samplenearoptimality
Inparticularcasesofinterest,suchaswhen(cid:5)=(cid:5)SD(M),theoptimalFLCIsintroducedabove
have near-optimal expected length in the finite-sample normal model. The following result,
whichisanimmediateconsequenceofresultsinArmstrongandKolesa´r(2018,2020a),bounds
the ratio of the expected length of the shortest possible confidence interval that controls size
relativetothelengthoftheoptimalFLCI.
Assume(i)(cid:5)isconvexandcentrosymmetric(i.e.δ˜ ∈(cid:5)implies−δ˜ ∈(cid:5)),and
Assumption8.
∈(cid:5)issuchthat(δ˜−δ)∈(cid:5)forallδ˜
| ii)δ |     |     |         | ∈(cid:5). |     |                     |     |     |
| ---- | --- | --- | ------- | --------- | --- | ------------------- | --- | --- |
|      |     | δ   | (cid:5) |           |     | I ((cid:5),(cid:10) | )   |     |
Proposition 4.1. Suppose and satisfy Assumption 8. Let α denote the class of
n
confidencesetsthatsatisfythecoveragecriterion(10)atthe1−α level.Then,foranyτ with
τ =0and(cid:10)
| pre  | n positivedefinite, |     |          |          |            |                   |        |     |
| ---- | ------------------- | --- | -------- | -------- | ---------- | ----------------- | ------ | --- |
|      |                     |     | (cid:10) | (cid:11) |            |                   |        |     |
| infC | E                   |     | λ(C      | )        | z (1−α)−z˜ | (cid:21)(z˜ )+φ(z | )−φ(z˜ | )   |
α,n ∈I α ((cid:5),(cid:10) n ) βˆ ∼N(δ+τ,(cid:10) ) α,n ≥ 1−α α α 1−α α ,
|     | n   |     | n   |     |     |       |     |     |
| --- | --- | --- | --- | --- | --- | ----- | --- | --- |
|     | 2χ  |     |     |     |     | z     |     |     |
|     |     | n   |     |     |     | 1−α/2 |     |     |
whereλ(·)denotesthelength(Lebesguemeasure)ofasetandz˜ =z −z .
|     |     |     |     |     |     | α 1−α | 1−α/2 |     |
| --- | --- | --- | --- | --- | --- | ----- | ----- | --- |
Part(i)ofAssumption8issatisfiedfor(cid:5)SD(M)butnotforourotherongoingexamples.For
example, (cid:5)SDPB(M) is convex but not centrosymmetric, and (cid:5)RM(M ¯) is neither convex nor
centrosymmetric.Partii)ofAssumption8issatisfiedwheneverparalleltrendsholdsinboththe
pre-treatmentandpost-treatmentperiods(δ =0)andwheneverδisalineartrendforthecaseof
(cid:5)SD(M).
FLCIs thus offer attractive guarantees for the case of (cid:5)SD(M). When α =0.05, the lower
bound in Proposition 4.1 evaluates to 0.72, meaning that the expected length of the shortest
25. Ift=∞,wedefinecvα=∞.

| RAMBACHANANDROTH |     | AMORECREDIBLEAPPROACHTOPARALLELTRENDS |     |     |     |     | 2577 |
| ---------------- | --- | ------------------------------------- | --- | --- | --- | --- | ---- |
possibleconfidencesetthatsatisfiesthecoveragerequirement(10)isatmost28%shorterthan
thelengthoftheoptimalFLCIwhentheconditionsofthepropositionhold.
Downloaded from https://academic.oup.com/restud/article/90/5/2555/7039335 by Northwestern University Libraries user on 20 June 2026
4.3. (In)ConsistencyofFLCIs
As discussed above, these finite-sample guarantees do not apply for several types of restric-
tions(cid:5)ofimportance,includingthosethatconstructboundsusingthemaximumpre-treatment
violationorincorporate signandshaperestrictions.Wenow showthattheFLCIs canperform
poorlyundersuchrestrictions.Wefirstprovidetwoillustrativeexamples,andthenstateaformal
inconsistencyresult.
4.3.1. Example: (cid:2)SDPB(M) and (cid:2)SDI(M). Suppose θ =τ . It can be shown that the
1
|     |     |     | (cid:5)SDPB(M) |     | (cid:5)SDI(M) |     |     |
| --- | --- | --- | -------------- | --- | ------------- | --- | --- |
worst-case bias of an affine estimator over or is the same as the worst-
casebiasforthatestimatorover(cid:5)SD(M).26SincetheconstructionoftheoptimalFLCIdepends
onlyontheworst-casebiasandvarianceoftheaffineestimator,itfollowsthattheoptimalFLCI
|     | (cid:5)SDPB(M) | (cid:5)SDI(M) |     |     |     |     | (cid:5)SD(M). |
| --- | -------------- | ------------- | --- | --- | --- | --- | ------------- |
constructed using or is the same as the one constructed using
Therefore,theoptimalFLCIdoesnotadapttoadditionalsignormonotonicityrestrictions.
|        | (cid:2)RM(M | ¯).     | θ =τ | (cid:5)=(cid:5)RM(M | ¯)  | ¯ >0, |                 |
| ------ | ----------- | ------- | ---- | ------------------- | --- | ----- | --------------- |
| 4.3.2. | Example:    | Suppose | 1    | . If                | and | M     | then all affine |
¯)canhave|δ
estimatorsforτ haveinfiniteworst-casebias,sinceδ ∈(cid:5)RM(M |arbitrarilylarge
|     | 1   |     |     |     |     | 1   |     |
| --- | --- | --- | --- | --- | --- | --- | --- |
if|δ |isalsosufficientlylarge.Thus,theonlyvalidFLCIistheentirerealline.
−1
We next provide a formal result on the (in)consistency of the FLCIs. Specifically, we will
showthatevenasthesamplingvariation(cid:10) convergesto0,theoptimalFLCIwillincludefixed
n
pointsoutsideoftheidentifiedsetwithpositiveprobabilityunlesscertainspecialconditionsare
met.27 RecallfromLemma2.1thattheidentifiedsetS(β,(cid:5))isanintervalwhen(cid:5)isconvex,
withlengthequaltoθub(β,(cid:5))−θlb(β,(cid:5))=bmax(β ,(cid:5))−bmin(β ,(cid:5)).Sincethelength
|     |     |     |            | pre | pre   |            |     |
| --- | --- | --- | ---------- | --- | ----- | ---------- | --- |
|     |     |     | β (cid:5), |     | LID(β | ,(cid:5)). |     |
of the identified set only depends on pre and denote it by pre Our next result
shows that CFLCI(βˆ ,(cid:10) ) is consistent if and only if LID(β ,(cid:5)) is its maximum possible
|     | α,n n n |     |     |     | pre |     |     |
| --- | ------- | --- | --- | --- | --- | --- | --- |
value,providedthattheidentifiedsetisnottheentirerealline(inwhichcaseanyprocedureis
triviallyconsistent).
δ ∈(cid:5)
Assumption 9 (Identified set maximal length and finite). Suppose is such
LID(δ˜
that LID(δ ,(cid:5))=sup ,(cid:5))<∞, where (cid:5) ={δ ∈RT :
|                  | pre                            | δ˜ ∈(cid:5)                      | pre |     |     | pre | pre |
| ---------------- | ------------------------------ | -------------------------------- | --- | --- | --- | --- | --- |
| ∃δ s.t.(δ(cid:2) | ,δ(cid:2) )(cid:2) ∈(cid:5)}is | p r e p re tofpossiblevaluesforδ |     |     |     |     |     |
|                  |                                | t h es e                         |     |     | .   |     |     |
| post             | pre post                       |                                  |     |     | pre |     |     |
Proposition4.2. Suppose(cid:5)isconvexandα <0.5.Fixδ ∈(cid:5)andτ withτ =0,andsuppose
pre
S(δ+τ,(cid:5))(cid:4)=R.Then(δ,(cid:5))satisfyAssumption9ifandonlyifCFLCI(βˆ
,(cid:10) )isconsistent,
|                        |               |     |     |     | α,n | n n |     |
| ---------------------- | ------------- | --- | --- | --- | --- | --- | --- |
| meaningthatfor(cid:10) | =(cid:10)∗/n, |     |     |     |     |     |     |
n
|     |     | (cid:16) |     | (cid:17) |     |     |     |
| --- | --- | -------- | --- | -------- | --- | --- | --- |
l im P θout ∈C F LCI(βˆ ,(cid:10) ) =0 forallθout (cid:4)∈S(δ+τ,(cid:5)).
|     | βˆ ∼N(δ+τ,(cid:10) | )   | α ,n n | n   |     |     |     |
| --- | ------------------ | --- | ------ | --- | --- | --- | --- |
| n → | ∞ n                | n   |        |     |     |     |     |
Supposethevectorδ¯ maximizesthebiasforanaffineestimator(a,v)over(cid:5)SD(M).Thevectorthatadds
26.
|     | δ¯ δ˜ = | δ¯ + · (− ,. . | . , ¯ )(cid:2) | (cid:5) S D | (M ) |     | δ˜  |
| --- | ------- | -------------- | -------------- | ----------- | ---- | --- | --- |
a c o n st an ts lo p e t o , s a y c c T T , a ls o lie s in , a n d fo r c s uf fi c ie n tl y l ar g e, c w i ll l i e i n
| (cid:5) S D P B (M ) |     | ¯   |     | δa  | δ˜ ( a, v | )   |     |
| -------------------- | --- | --- | --- | --- | --------- | --- | --- |
. M o r eo v e r , th e w or se -c as e bi as w i l l b e th e s am e fo r n d c , s in c e if h a s fi n it e w o rs t- ca s e b i a s i t
mustsubtractoutaweightedaverageofthepre-treatmentslopes.
27. For ease of exposition, we present a result using “small-(cid:10)” asymptotics in the normal model, as in e.g.
Kadane(1971)andMoreiraandRidder(2019).

2578 REVIEWOFECONOMICSTUDIES
Thus, if Assumption 9 fails, then CFLCI(βˆ ,(cid:10) ) is inconsistent in the strong sense that it
α,n n n
includesfixedpointsoutsideoftheidentifiedsetwithnon-vanishingprobability.Itfollowsthat
therewillbesomeδ ∈(cid:5)suchthattheFLCIisinconsistentunderδ unlesstheidentifiedsetis
alwaysthesamelength.Proposition4.2isnew,andmayberelevantforothersettingsinwhich
FLCIsareused.
The intuition for the possible inconsistency of FLCIs is as follows: to ensure that an FLCI
satisfies the coverage requirement (10), its length must be at least sup δ˜ ∈(cid:5) LID(δ˜ pre ,(cid:5)).
pre pre
However,thisimpliesthatifinfact LID(δ pre ,(cid:5))<sup δ˜ ∈(cid:5) LID(δ˜ pre ,(cid:5)),thentheFLCI
is strictly longer than the length of the identified set, rega pr r e dle p s re s of the value of (cid:10) , and thus
n
some points outside of the identified set must be covered with non-vanishing probability. This
reflectsthefactthatFLCIsarebyconstructionfixedlength,andthustheirlengthdoesnotadapt
to information in the data about the length of the identified set. By contrast, the length of the
conditional/hybrid confidence sets can depend on
βˆ
and thus “adapts” to the length of the
pre
identifiedset.
In the three-period DiD example, Assumption 9 holds everywhere for (cid:5)SD(M) (since the
identifiedsetisalwaysthesamelength,2M),forvaluesofδ wherethesignrestrictionsdonot
bindfor(cid:5)SDPB(M),andnowhereforthepolyhedrathatform(cid:5)RM(M ¯).Therestrictivenessof
Assumption9thusdependsgreatlyon(cid:5).
Theresultsinthissectionestablishthatwhencertainconditionson(cid:5)aresatisfied,optimal
FLCIs are consistent and have desirable finite-sample guarantees in terms of expected length.
FLCIsarethusattractiveforourbaselinesmoothnessclass(cid:5)SD(M),sincetheyareguaranteedto
beconsistentandofferattractivefinite-sampleguarantees.Ourinconsistencyresultshows,how-
ever,thatFLCIsmayperformpoorlyforotherchoicesof(cid:5)thatmaybeofinterestinempirical
applications,suchasthosethatconstructboundsusingapre-treatmentmaximumorincorporate
signandmonotonicityrestrictions.
5. SIMULATIONSTUDY
In this section, we conduct a simulation study to investigate the performance of the discussed
confidencesetsacrossarangeofrelevantdata-generatingprocesses.Wefindgoodsizecontrol
foralloftheprocedures,andthereforefocusinthemaintextonacomparisonofpowertopro-
videconcreterecommendationsonthebestapproachinpractice.Inthesupplementarymaterial,
wepresentresultsonsizecontrolandotheradditionalsimulationresults.
5.1. Simulationdesign
Our simulations are calibrated using the estimated covariance matrix from the 12 recently-
published papers surveyed inRoth (2022). For any given paper inthe survey, we denote by
(cid:10)ˆ
theestimatedvariance-covariancematrixfromtheevent-studyinthepaper,calculatedusingthe
clusteringschemespecifiedbytheauthors.Forachosenmeanvectorβ,wesimulateevent-study
coefficients βˆ from a normal model, βˆ ∼N(β, (cid:10)ˆ).28 In simulation s, we construct nominal
s s
95%confidencesetsfortheparameterofinterestθ usingthepair(βˆ ,(cid:10)ˆ)foreachproposedpro-
s
cedure.Theparameterofinterestisthecausaleffectinthefirstpost-treatmentperiod(θ =τ );
1
inthesupplementarymaterial,wepresentsimulationresultsinwhichtheparameterofinterest
28. Wefocusonthenormalsimulationsinthemaintextsinceitallowsforatractablecomputationoftheoptimal
excess length of procedures that control size. In the supplementary material, we show that our procedures perform
similarlyinsimulationsbasedontheempiricaldistributionintheoriginalpaper.
Downloaded
from
https://academic.oup.com/restud/article/90/5/2555/7039335
by
Northwestern
University
Libraries
user
on
20
June
2026

RAMBACHANANDROTH AMORECREDIBLEAPPROACHTOPARALLELTRENDS 2579
TABLE1
Summaryofexpectedpropertiesforeachsimulationdesign
ParallelTrends PulsePre-Trend
(cid:5)SD(M) (cid:5)SDPB(M) (cid:5)SDRM(M ¯) (cid:5)RM(M ¯)
ConditionalandHybrid
Consistent (cid:3) (cid:3) (cid:3) (cid:3)
Asymptotically(near-)optimal (cid:3) (cid:3) (cid:3) ×
FLCI
Consistent (cid:3) × × ×
Finite-samplenear-optimal (cid:3) × × ×
istheaverage causaleffectinthepost-treatmentperiods(θ =τ¯ ),withqualitatively similar
post
results.
Foragivenchoiceof(cid:5),wecomputetheidentifiedsetS(β,(cid:5))usingtheformulasprovided
in Lemma 2.1 and calculate the expected excess length for each of the proposed confidence
sets. We benchmark the expected excess length of our proposed confidence sets relative to an
efficiencyboundforconfidencesetsthatsatisfytheuniformcoveragerequirement.29 Wereport
the efficiency ratio of each procedure, which is defined as the ratio of the optimal benchmark
relative to the average excess length for the procedure. All results are calculated over 1,000
simulationsperpaper.
Weconsiderfourchoicesof(cid:5)tohighlighttheperformanceofourproposedconfidencesets
across a range of conditions: (cid:5)SD(M), (cid:5)SDPB(M), (cid:5)RM(M ¯), and (cid:5)SDRM(M ¯). We consider
simulations under the assumption of zero treatment effects, so that τ =0 and thus β =δ. We
considertwoformsforδ.First,weconsiderthebaselinecaseofparalleltrends(δ =0).Second,
we consider a “pulse” pre-trend in which δ −1 is non-zero and the remaining elements of δ are
zero.Suchapre-trendmightariseinpracticeifthereareconfounding policychangesorother
events close to the time of treatment. These different choices of δ allow us to highlight the
relativestrengthsoftheproposedinferenceprocedures.Forexample,FLCIshavenear-optimal
expected length when δ =0 and (cid:5)=(cid:5)SD(M), whereas the conditional test has optimal local
asymptoticpowerunderthepulsedesignwhen(cid:5)=(cid:5)SDPB(M).Table1summarizeswhichof
¯
ourtheoreticalresultsholdforeachofthesimulationdesignswhen M and M arenon-zero.
Inpractice,wefindthatfor(cid:5)SD(M)and(cid:5)SDPB(M),theresultsdependon M butarequali-
tativelysimilaracrossvaluesofδ.Bycontrast,for(cid:5)SDRM(M ¯)and(cid:5)RM(M ¯),thechoiceofδis
¯
moreimportantthanthechoiceofM.Therefore,tohighlightthemostimportantdimensionsfor
eachofthesimulationdesigns,inthemaintextofthepaperwereportresultsfor(cid:5)SD(M)and
(cid:5)SDPB(M)underdifferentvaluesof M andδ =0(paralleltrends),whereasfor(cid:5)RM(M ¯)and
(cid:5)SDRM(M ¯)wevarythemagnitudeofthepre-treatmentpulseδ −1 ,holding M ¯ =1constant.In
thesupplementarymaterials,wereportresultsforadditionalchoicesoftheseparameters.
29. Forchoicesof(cid:5)thatareconvex(e.g.(cid:5)SD(M)and(cid:5)SDPB(M)),webenchmarktheexpectedexcesslength
ofourproposedconfidencesetsagainstasharpoptimalboundoverconfidencesetsthatsatisfythefinite-samplecoverage
requirement(10).Thisoptimalboundisprovidedinthesupplementarymaterials,andfollowsasacorollaryfromresults
inArmstrongandKolesa´r(2018)ontheoptimalexpectedlengthofaconfidencesetsatisfyingtheuniformcoverage
requirement(10).Forchoicesof(cid:5)thatcanbewrittenastheunionofconvexsets(e.g.(cid:5)RM(M ¯)and(cid:5)SDRM(M ¯)),
wecomparetheexpectedexcesslengthofourproposedconfidencesetsagainstthemaximaloptimalboundovereach
setintheunion,whichisapotentiallynon-sharpboundforanyconfidencesetwithcorrectcoverage.
Downloaded
from
https://academic.oup.com/restud/article/90/5/2555/7039335
by
Northwestern
University
Libraries
user
on
20
June
2026

2580 REVIEWOFECONOMICSTUDIES
FIGURE2
Simulationresultsfor(cid:5)SD(M)and(cid:5)SDPB(M):Medianefficiencyratiosforproposedprocedures.
Note:Medianefficiencyratiosforourproposedconfidencesetsover(cid:5)SD(M)and(cid:5)SDPB(M)undertheassumptionofparalleltrends
andzerotreatmenteffects(i.e.β=0).Theefficiencyratioforaprocedureisdefinedastheefficiencybounddividedbytheprocedure’s
expectedexcesslength.TheresultsfortheFLCIareplottedinpurple,conditional-LF(“C-LFHybrid”)hybridinblue,andconditional
confidencesetingreen.Resultsareaveragedover1,000simulationsforeachofthe12paperssurveyed,andthemedianacrosspapersis
reportedhere.
We report results for three methods for constructing confidence sets: FLCIs, conditional
confidence sets, and conditional-least favourable hybrid confidence sets.30 For (cid:5)RM(M ¯) and
(cid:5)SDRM(M ¯),weomitresultsfortheFLCIsincetheFLCIshaveinfinitelength.
5.2. Simulationresults
To compare results easily across the 12 papers in the simulation study, we normalize the units
of δ −1 and M by the standard deviation of βˆ 1 (denoted σ 1 ). Large normalized values of M or δ −1 correspond with the case where the identified set is large relative to sampling variation,
mimickingourasymptoticpowerresultsinwhichsamplingvariationgrowssmallrelativetothe
identifiedset.Inthegraphsbelow,wereportthemedianvalueofexcesslengthefficiencyacross
thepapersinthesurvey.Thenormalizationdescribedaboveimpliesthattheunitsofthe x-axis
correspondwiththeworst-casebiasofthenaiveestimatorβˆ dividedbyitsstandarderror.31
1
5.2.1. Results for (cid:2)SD(M). The left panel of Figure 2 plots the efficiency ratio for each
procedure as a function of M/σ when (cid:5)=(cid:5)SD(M). All procedures perform well as M/σ
1 1
grows large with efficiency ratios approaching 1, illustrating our asymptotic (near-)optimality
results for this design. However, the FLCIs perform best for smaller values of M/σ , includ-
1
ingthepoint-identifiedcasewhere M =0,illustratingthefinite-samplenear-optimalityresults
for the FLCIs when Assumption 8 holds. Although the conditional and hybrid confidence sets
have efficiency approaching the optimal bound for M/σ large, their efficiency is only about
1
50% when M/σ =0, in which case θ is point identified and thus LICQ does not hold. The
1
conditionalandhybridconfidencesetsperformsimilarly.
30. Fortheconditional-leastfavourablehybridconfidencesets,weuseafirst-stageleast-favourabletestofsize
κ=α/10,followingARPandRomanoetal.(2014).
31.
Forβˆ
1normallydistributed,theworst-casecoverageofaconventional95%confidenceintervalasafunction
ofthenormalizedworst-casebiasbis(cid:21)(1.96+b)−(cid:21)(−1.96+b),whichis0.95forb=0,0.83forb=1,0.48for
b=2,etc.
Downloaded
from
https://academic.oup.com/restud/article/90/5/2555/7039335
by
Northwestern
University
Libraries
user
on
20
June
2026

RAMBACHANANDROTH AMORECREDIBLEAPPROACHTOPARALLELTRENDS 2581
FIGURE3
Simulationresultsfor(cid:5)SDRM(M ¯)and(cid:5)RM(M ¯):Medianefficiencyratiosforproposedprocedures.
Note:Medianefficiencyratiosforourproposedconfidencesetsover(cid:5)SDRM(M¯)and(cid:5)RM(M¯)withM¯ =1undertheassumptionof
zerotreatmenteffectsanda“pulse”pre-trend(i.e.β−1 =δ−1andβ
t
=0forallt(cid:4)=−1).Theefficiencyratioforaprocedureisdefined
astheefficiencybounddividedbytheprocedure’sexpectedexcesslength.Theresultsfortheconditional-leastfavourable(“C-LF”)
hybridareplottedinblue,andconditionalconfidencesetingreen.Resultsareaveragedover1,000simulationsforeachofthe12papers
surveyed,andthemedianacrosspapersisreportedhere.
5.2.2. Results for (cid:2)SDPB(M). The right panel of Figure 2 plots the efficiency ratio for
eachprocedureasafunctionof M/σ when(cid:5)=(cid:5)SDPB(M).Theefficiencyratiosforthecon-
1
ditionalandhybridconfidencesetsareagain(near-)optimalas M/σ growslarge,highlighting
1
ourasymptotic(near-)optimalityresultsfortheseproceduresinthissimulationdesign.Bycon-
trast,theefficiencyratiosfortheFLCIssteadilydecreaseas M/σ increases,reflectingthatthe
1
FLCIsarenotconsistentinthissimulationdesignwhenM >0.Theconditional-LFhybridcon-
fidencesetsslightlyimproveefficiencyrelativetotheconditionalconfidencesetswhen M/σ is
1
smallandretainnear-optimalperformanceas M/σ growslarge.
1
5.2.3. Results for (cid:2)SDRM(M ¯). The left panel of Figure 3 plots the efficiency ratios for
theconditionalandconditional-leastfavourablehybridconfidencesetsasafunctionofδ
−1
/σ
1
when(cid:5)=(cid:5)SDRM(M ¯).WeomitresultsfortheoptimalFLCIsincetheoptimalFLCIhasinfi-
nitelengthforthisdesign.Bothproceduresperformwellasδ −1 /σ 1 growslargewithefficiency
ratios approaching 1, illustrating our asymptotic (near-) optimality result for this design. Both
proceduresalsohavesimilarpowercurves,withslightlyhigherpowerfortheconditional.
5.2.4. Results for (cid:2)RM(M ¯). The right panel of Figure 3 plots the efficiency ratio for the
conditionalandconditional-leastfavourablehybridconfidencesetsasafunctionofδ −1 /σ 1 when
(cid:5)=(cid:5)RM(M ¯).WeagainomitresultsfortheoptimalFLCIsincetheoptimalFLCIhasinfinite
lengthforthisdesign.Theconditionsforourasymptotic(near-)optimalityresultforunionsof
convex sets do not hold in this simulation design (as the maximum pre-period violation is not
unique).Nonetheless,wefindthattheefficiencyratiosfortheconditionalandhybridconfidence
setsapproachabout83%whenδ −1 /σ 1 growlarge.Wefinditsomewhatencouragingthatthese
procedurescanhaveexcesslengthwithin17%oftheoptimumevenincaseswhereLICQfails.
Onceagain,wealsofindthattheconditionalandconditional-leastfavourablehybridhavesimilar
power.
5.2.5. Takeaways from simulations. Two clear patterns emerge from our simulations.
First, the conditional and hybrid confidence sets perform well across a wide range of speci-
fications,withparticularlygoodpowerwhenthelengthoftheidentifiedsetislargerelativeto
samplingvariation.Second,theFLCIshavethebestperformancefor(cid:5)SD(M),particularlywhen
Downloaded
from
https://academic.oup.com/restud/article/90/5/2555/7039335
by
Northwestern
University
Libraries
user
on
20
June
2026

2582 REVIEWOFECONOMICSTUDIES
M is small, which aligns with the finite-sample near-optimality results in Section 4. However,
FLCIscanperformquitepoorlyforotherclassesof(cid:5).
Overall, we therefore recommend to use the conditional-LF hybrid confidence sets for
generic forms of (cid:5), and optimal FLCIs for the special case of (cid:5)SD(M) (or other special
cases where the consistency/finite-sample near-optimality of FLCIs is guaranteed). Although
the conditional and hybrid approaches perform similarly in our simulations, we recommend
the hybrid approach in general based on the guidance provided in ARP. We implement these
recommendationsinourapplicationsinthenextsection.
6. PRACTICALGUIDANCEANDEMPIRICALILLUSTRATIONS
6.1. Practicalguidance
Werecommendthatresearchersuseourmethodstoconstructrobustconfidenceintervalsunder
restrictionsonthepossibleviolationsofparalleltrends(cid:5)thataremotivatedbydomainknowl-
edge in their empirical setting. We also suggest that researchers report sensitivity analyses to
illustrate the sensitivity of their causal conclusions to alternative assumptions on the possible
violationsofparalleltrends.
6.1.1. Choiceof(cid:2). Thechoiceof(cid:5)shouldbemotivatedbyeconomicknowledgeaboutthe
types of possible confounding factors that could produce non-parallel trends. We now provide
some guidance on how the choice of (cid:5) can be motivated by domain knowledge, highlighting
somecaseswhereourleadingexamples,(cid:5)RM(M ¯)and(cid:5)SD(M),wouldbesensiblechoices.
Insomeempiricalsettings,researchersmaybeconcernedaboutdifferentialeconomicshocks
to the treated and control groups that generate violations of parallel trends. If the researcher
believes that the magnitude of these differential shocks in the post-treatment period is not too
different from the magnitude in the pre-treatment period, then it may be reasonable to assume
δ ∈(cid:5)RM(M ¯), which explicitly bounds the relative magnitudes of violations of parallel trends
inthepost-treatmentbasedonobservedviolationsinthepre-treatmentperiod.Inothersettings,
researchers may be worried about violations of parallel trends that arise due to differences in
smoothly evolving secular trends that differentially affect the treated and comparison groups.
In this case, it may be reasonable to assume δ ∈(cid:5)SD(M), which explicitly bounds the extent
to which the slope of the difference in trends can vary across consecutive periods. Economic
knowledgemayimplyadditionalrestrictionsaswell.Forexample,iftheresearcherknowsofa
confoundingpolicychangethatwouldhaveapositiveeffectontheoutcome,thenitisreasonable
tofurtherassumethatpost-treatmentdifferenceintrendsmustbepositive(i.e.δ ≥0fort >0).
t
In our empirical applications below, we illustrate how domain knowledge about the types
of possible violations of parallel trends can inform the choice of (cid:5). We encourage applied
researcherstousesuchdomainknowledgetoinformtherestrictionstheyimposeonthepossible
choicesofparalleltrendsintheircontext.
6.1.2. Choice of inference procedure. Based on our theoretical results and Monte Carlo
simulations,werecommendtheARPhybridconfidencesetsforgeneric,polyhedralformsof(cid:5).
For the special case of (cid:5)SD(M)—or other choices of (cid:5) for which the consistency and finite-
sample-near-optimality of FLCIs are guaranteed—we recommend FLCIs. Our recommended
choice of inference procedure is implemented in the HonestDiD R and Stata packages that
Downloaded
from
https://academic.oup.com/restud/article/90/5/2555/7039335
by
Northwestern
University
Libraries
user
on
20
June
2026

RAMBACHANANDROTH AMORECREDIBLEAPPROACHTOPARALLELTRENDS 2583
accompanythepaper.32Furthermore,theseconfidencesetsarequicktocompute.Eachsensitiv-
ity analysis plot in the empirical applications below took less than 9 minutes to compute on a
2012MacbookProwitha2.3GHzQuad-CoreIntelCorei7and16GBRAM.
6.1.3. Sensitivityanalyses. Oncetheresearcherhaschosenabaselineclassofrestrictions
on the possible violations of trends (e.g. relative magnitudes bounds (cid:5)RM(M ¯) or smoothness
bounds (cid:5)SD(M)), we recommend conducting sensitivity analysis over the associated param-
eter (M ¯ ≥0 or M ≥0, respectively) that governs how different the post-treatment violations
of parallel trends can be from the pre-trends. It is natural to report both the sensitivity of the
researcher’s causal conclusion to the choice of this parameter and the “breakdown” parameter
valueatwhichparticularhypothesesofinterestcannolongerberejected;similar“breakdown”
conceptsappearinthepartialidentificationsettingsofHorowitzandManski(1995),Klineand
Santos(2013),ManskiandPepper(2018),andMastenandPoirier(2020).33 Weillustratehow
one can interpret the magnitudes of the breakdown points in our two empirical illustrations
below.
6.2. Estimatingtheincidenceofavalue-addedtaxcut
Benzarti and Carloni (2019b, henceforth, BC) study the incidence of a decrease in the value-
addedtax(VAT)onrestaurantsinFrance.FrancereduceditsVATonsit-downrestaurantsfrom
19.6 % to 5.5 % in July of 2009. BC analyse the impact of this change using a dynamic DiD
designthatcomparesrestaurantstoacontrolgroupofothermarketservicesfirmsthatwerenot
affectedbytheVATchange,estimatingtheOLSregressionspecification
(cid:8)
Y = β ×1[t =s]×D +φ +λ +(cid:9) , (19)
it s i i t it
s(cid:4)=2008
where Y is the log of (before-tax) profits for firm i in year t; D is an indicator for whether
it i
firmi isarestaurant;φ andλ arefirmandyearfixedeffects;andstandarderrorsareclustered
i t
at the regional level. BC’s main finding is that the VAT reduction had a large, positive effect
on restaurant profits. Figure 4 shows the estimated event-study coefficients {βˆ } from specifi-
s
cation(19)(BenzartiandCarloni,2019a).Wecanformallyrejectthehypothesisthatβ =0
pre
(p <0.01),asthereappearstohavebeenadifferenceintrendsbetween2006and2007.Nev-
ertheless, the post-treatment coefficients for 2009–2011 appear to be substantially larger in
magnitudethananyofthepre-trendscoefficients.
A key concern in this empirical setting is that there may be unobserved, industry-specific
or macroeconomic shocks that would have affected restaurants differently from other market-
services firms even in the absence of a change in VAT. It seems reasonable to impose that
theindustry-specificshockstorestaurantsinthepost-treatmentperiodarenottoomuchlarger
32. The latest version of the R and Stata packages are respectively available at
http://github.com/asheshrambachan/HonestDiDandhttps://github.com/mcaceresb/stata-honestdid/.
33. Ourmainfocusinthispaperisonconstructingrobustconfidencesetsgivenaparticularrestriction(cid:5)(M),
ratherthaninferenceontheidentificationbreakdownpointorbreakdownfrontierasine.g.MastenandPoirier(2020).
Note,however,thatifwedefineM
∗=minMs.t.0∈S(β,(cid:5)(M))tobetheidentificationbreakdownpointforanull
effect,and M ˆ∗=minMs.t.0∈C(βˆ n ,(cid:10)ˆ n ;(cid:5)(M))tobethesamplebreakdownpoint,then P(M ˆ∗≥M ∗)≥P(0∈
C(βˆ n ,(cid:10)ˆ n ;(cid:5)(M ∗)).Itfollowsthat(−∞,M ˆ∗]isavalid(1−α)-levelconfidenceintervalfor M ∗ providedthatour
conditionsforsizecontrolaresatisfiedfor(cid:5)(M ∗).Wesuspectthatourresultscouldbeextendedtoallowforuniform
coverageofthebreakdownfrontierunderadditionalregularityconditions,butleavethistofuturework.
Downloaded
from
https://academic.oup.com/restud/article/90/5/2555/7039335
by
Northwestern
University
Libraries
user
on
20
June
2026

2584 REVIEWOFECONOMICSTUDIES
FIGURE4
Event-studycoefficients{β
s
}forlogprofits,estimatedusingtheevent-studyspecificationin(19).
than those in the pre-treatment period—whereas imposing that industry-specific shocks fol-
low a smooth trend seems unreasonable—and so we base our analysis on bounds on relative
magnitudes(cid:5)RM(M ¯).
TheleftpanelofFigure5showsrobustconfidencesetsforthetreatmenteffectin2009for
(cid:5)RM(M ¯)usingdifferentvaluesof M ¯ .Thefigureshowsthatifweimpose M ¯ =1,meaningthat
werestrictthepost-treatmentviolationsofparalleltrendstobenolargerthanthemaximalpre-
treatmentviolationofparalleltrends,thenweobtainarobustconfidencesetof[0.07,0.31]for
the causal effect on restaurant profits in 2009. This is wider than the original OLS confidence
intervalwhichisonlyvalidifparalleltrendsholdsexactly,butneverthelessrulesoutanulleffect
onrestaurantprofitsin2009.Lookingfurthertotheright,weseethatthe“breakdownvalue”for
anulleffectisaround M ¯ =2.Thus,ourconclusionofasignificanteffectonrestaurantprofits
dependsonwhetherwearewillingtorestrictthatthepost-treatmentviolationsofparalleltrends
canbenomorethantwiceaslargeasthemaximalpre-treatmentviolation.Giventhatthefirst
year after the treatment coincided with a large recession in France (2009), it may be plausible
thatthedifferentialfactorsaffectingrestaurantswerelargerinthatyearthaninthepre-treatment
period. Our approach helps formalize how much larger they would need to be to reject the
conclusionofanulleffect(orotherhypotheses).
TherightpanelofFigure5showsanalogousresultswhentheestimandistheaveragecausal
effectonrestaurantprofitsacrossallfourpost-treatmentperiods(τ¯).When M ¯ =1,ourrobust
confidencesetnowincludeszero,andisabouttwiceaslargeasforthefirst-periodeffect.The
intuition for why the confidence sets are larger when looking at τ¯ than τ is that (cid:5)RM(M ¯)
2009
¯
bounds the violation of parallel trends across consecutive periods by M times the max in the
pre-treatmentperiod.Thus,theidentifiedsetwillbelargerforlaterperiods,sincethetreatment
andcontrolgroupshavemoretimetodiverge(e.g.theidentifiedsetforthesecondperiodwill
betwiceaslargerasforthefirstperiod).34Ifwearewillingtoboundthemagnitudeofeconomic
34. Thisintuitionholdsgenerallyforchoicesof(cid:5)thatboundchangesacrossconsecutiveperiods,butneednot
necessarilyholdforothertypesofrestrictions.
Downloaded
from
https://academic.oup.com/restud/article/90/5/2555/7039335
by
Northwestern
University
Libraries
user
on
20
June
2026

RAMBACHANANDROTH AMORECREDIBLEAPPROACHTOPARALLELTRENDS 2585
FIGURE5
SensitivityanalysisforBenzartiandCarloni(2019b).
shocks by the max in the pre-treatment period, we will thus typically obtain wider confidence
setsforparametersinvolvinglaterperiods.
Finally, in Supplementary Material, Appendix C, we compare the confidence sets reported
inFigure5tothesampleanaloguetotheidentifiedset,S(βˆ,(cid:5)),whichweshowisaHausdorff
consistent estimator of the identified set in this example. We find that the reported confidence
setsarebetween40and80%longerthantheestimatedidentifiedset,suggestingthatbothsam-
plinguncertainty andthelengthoftheidentified setplayanimportantroleinthewidthofthe
confidencesets.
6.3. Theeffectofduty-to-bargainlawsonlong-runstudentoutcomes
Lovenheim and Willen (2019a, henceforth LW) study the impact of state-level public sector
duty-to-bargain (DTB) laws, which mandated that school districts bargain in good faith with
teachers’unions.LWexaminetheimpactsoftheselawsontheadultlabourmarketoutcomesof
peoplewhowerestudentsaroundthetimethattheselawswerepassed,comparingindividuals
acrossdifferentstatesanddifferentbirthcohortstoexploitthedifferentialtimingofthepassage
of DTB laws across states. The authors estimate the following OLS regression specification
separatelyformenandwomen,usingdatafromtheAmericanCommunitySurvey(ACS),
(cid:8)21
Y = D β +X (cid:2) γ +λ +φ +(cid:9) . (20)
sct scr r sct ct s sct
r=−11
Y isanaverageoutcomeforthecohortofstudentsborninstates incohortcinACScalendar
sct
yeart. D isanindicatorforwhetherstates passedaDTBlawr yearsbeforecohortcturned
scr
age18.35 Theevent-study coefficients {βˆ }estimatethedynamic treatmenteffects (orplacebo
r
35. Dsc,−11issetto1ifstatespassedalaw11yearsormoreaftercohortcturned18.Likewise,Dsc,21isset
to1ifstatespassedalaw21ormoreyearsbeforecohortcturned18.
Downloaded
from
https://academic.oup.com/restud/article/90/5/2555/7039335
by
Northwestern
University
Libraries
user
on
20
June
2026

2586 REVIEWOFECONOMICSTUDIES
FIGURE6
Event-studycoefficient{β
r
}foremployment,estimatedusingtheevent-studyspecificationin(20).
effects) r years after DTB passage.36 The remaining terms include time-varying controls,
birth-cohort-by-ACS-year fixed effects, and state fixed effects. We normalize the event-study
coefficientβ −2 to0.37 Wefocusontheresultswheretheoutcomeisemployment.
Figure6plotstheestimatedevent-studycoefficients{βˆ }fromspecification(20)(Lovenheim
r
andWillen,2019b).Intheevent-studyformen(leftpanel),thepre-periodcoefficientsarerel-
ativelyclosetozero,whereasthelonger-runpost-periodcoefficientsarenegative.Bycontrast,
theresultsforwomen(rightpanel)suggestadownward-slopingpre-existingtrend.
LW write that, the “primary concern in our identification strategy is the existence of secu-
lar trends that differ systematically with treatment” (p. 318), such as confounding changes in
laboursupplyoreducationalattainment.Giventhattheconcernislong-runtrendsthatarelikely
toevolvesmoothlyovertime,smoothnessrestrictionsoftheform(cid:5)SDseemnaturalinthiscon-
text.Indeed,insomeoftheirrobustnesschecks,LWestimatemodelswithgroup-specificlinear
trends, which roughly corresponds with the case (cid:5)SD(0).38 It thus seems natural to consider
relaxationsoftheform(cid:5)SD(M),whichallowsfordeviationsfromnon-linearityofnomorethan
M betweenconsecutiveperiods.
Figure7reportsresultsforthetreatmenteffectonemploymentforthecohort15yearsafter
the passage of a DTB law (as in Table 2 of LW), constructing robust confidence sets about
how non-linear the difference in trends can be. In blue, we plot the original OLS confidence
36. TreatmenttiminginLWisstaggered,andthereforetheresultsinSunandAbraham(2020)implythatβ r
canbeinterpretedasasensibleweightedaverageofcausaleffectsunderparalleltrendsonlyiftreatmenteffectsare
homogeneousacrossadoptioncohorts.Forsimplicity,wefocusontherobustnessoftheresultstoviolationsofparallel
trendsusingtheoriginalspecificationinLW,whichisvalidundertheassumptionofhomogeneoustreatmenteffects.
AsdiscussedinSection2.1,oursensitivityanalysiscanalsobeappliedtoestimatorsthatarerobusttotreatmenteffect
heterogeneity.
37. LWnormalizeeventtime−1to0,butdiscusshowcohortsateventtime-1mayhavebeenpartiallytreated
sinceLWimputetheyearthatastudentstartsschoolwitherror.Sinceourrobustconfidencesetsassumethatthereisno
causaleffectinthepre-period(τ
pre
=0),weinsteadtreatevent-time−2asthereferenceperiodinouranalysis.
38. Thetwoarenotexactlyequivalent,however,becauseLWincludeparametrictrendsintowhattheycalla
“parametricevent-study”model(seetheirspecification(2)),whichimposesthattreatmenteffectsarelinearintime
sincetreatment,ratherthantheflexibledynamicevent-studyspecification(20).
Downloaded
from
https://academic.oup.com/restud/article/90/5/2555/7039335
by
Northwestern
University
Libraries
user
on
20
June
2026

RAMBACHANANDROTH AMORECREDIBLEAPPROACHTOPARALLELTRENDS 2587
FIGURE7
Sensitivityanalysisforθ =τ 15using(cid:5)=(cid:5)SD(M).
intervalsforβˆ fromspecification(20).Inred,weplotFLCIswhen(cid:5)=(cid:5)SD(M)fordifferent
15
valuesof M;recallthat M =0correspondswithallowingonlyforlinearviolationsofparallel
trends,andlargervaluesof M allowforlargerdeviationsfromlinearity.Intheanalysisformen
(left panel), the FLCIs are similar to those from OLS when allowing for violations of parallel
trends that are approximately linear (M ≈0), but become wider as we allow for more non-
linearity;thebreakdownvalueforasignificanteffectisM ≈0.01.Forwomen(rightpanel),the
originalOLSestimatesarenegativeandtheconfidenceintervalrulesout0.Whenweallowfor
linear violations of parallel trends (M =0), however, the picture changes substantially owing
tothepre-existingdownwardtrendthatisvisibleinFigure6.Indeed,for M <0.01therobust
confidence set contains only positive values. Intuitively, this is because the point estimate for
t =15 lies above a linear extrapolation of the negative pre-trend. Thus, if we were to impose
the same smoothness restrictions for men as for women, we would either have to reconcile
significanteffectsofoppositesignsbygender(if M <0.01)orwewouldnotbeabletoruleout
nulleffectsforbothgenders(M ≥0.01).
Howcanweinterpretthemagnitudesof M inthisexample?Weconsideracalibrationexer-
cise based on the magnitudes of possible possible confounds: if violations of parallel trends
weredrivenbyconfoundingchangesineducationquality,whatwouldagivenvalueofM imply
abouttheevolutionofthoseconfounds?Chettyetal.(2014)estimatethata1standarddeviation
increaseinteachervalue-added(VA)correspondswitha0.4percentagepointincreaseinadult
employment.Hence,avalueof M =0.01wouldcorrespondwithallowingtheslopeofthedif-
ferentialtrendtochangebytheequivalentofaone-fourtiethofastandarddeviationofteacher
VAacrossconsecutiveperiods.Sincetherobustconfidencesetsforbothmenandwomenbegin
to include zero around this value of M, the strength with which we can rule out a null effect
dependsonourassessmentoftheeconomicplausibilityofsuchnon-linearities.
Finally,inSupplementaryMaterial,AppendixC,weagaincomparethereportedconfidence
setstotheestimatedidentifiedsetS(βˆ,(cid:5)).Ourresultssuggestthatsamplinguncertaintyislarge
relativetothelengthoftheidentifiedsetwhenM isclosetozero,butbecomeslessimportantas
M increases.
Downloaded
from
https://academic.oup.com/restud/article/90/5/2555/7039335
by
Northwestern
University
Libraries
user
on
20
June
2026

2588 REVIEWOFECONOMICSTUDIES
7. CONCLUSION
This paper considers the problem of conducting inference in DiD and related designs that is
robusttoviolationsoftheparalleltrendsassumption.Weintroduceavarietyofrestrictionson
the class of possible differences in trends that formalize commonly made arguments in empir-
ical work, generalizing the framework for partial identification in Manski and Pepper (2018).
We provide inference procedures that are uniformly valid so long as the difference in trends
satisfies these restrictions, and derive novel results on the power of these procedures. We rec-
ommend that applied researchers report robust confidence sets under economically motivated
restrictions on parallel trends. We also recommend that researchers conduct formal sensitivity
analyses,inwhichtheyreportconfidencesetsforthecausaleffectofinterestunderavarietyof
possiblerestrictionsontheunderlyingtrends.Suchsensitivityanalysesmaketransparentwhat
assumptionsareneededinordertodrawparticularconclusions.
Acknowledgments. This paper was previously titled, “An Honest Approach to Parallel Trends.” We are grate-
ful to Isaiah Andrews, Elie Tamer, and Larry Katz for their invaluable advice and encouragement. We also thank
Cle´mentdeChaisemartin,GaryChamberlain,RajChetty,PeterGanong,EdGlaeser,NathanHendren,RyanHill,Ariella
Kahn-Lang,JensLudwig,SendhilMullainathan,ClaudiaNoack,FrankPinter,AlexPoirier,AdrienneSabety,Pedro
Sant’Anna,JesseShapiro,NeilShephard,JannSpiess,JimStock,andseminarparticipantsatBrown,ChicagoBooth,
Dartmouth,Harvard,Michigan,Microsoft,Princeton,Rochester,UCL,Yale,SEA2021,andASSA2022forhelpful
comments,andDorianCarloniforkindlysharingdata.WearegratefultoMauricioCa´ceresBravoforhishelpdevel-
opingtheHonestDiDStatapackage.WegratefullyacknowledgefinancialsupportfromtheNSFGraduateResearch
FellowshipunderGrantDGE1745303(Rambachan)andGrantDGE1144152(Roth).
SupplementaryData
SupplementarydataareavailableatReviewofEconomicStudiesonline.
DataAvailabilityStatement
ThedataandcodeunderlyingthisresearchisavailableonZenodoathttps://doi.org/10.5281/zenodo.7388015.
REFERENCES
ABADIE, A. (2005), “Semiparametric Difference-in-Differences Estimators”, The Review of Economic Studies,
72,1–19.
ANDREWS,I.,ROTH,J.andPAKES,A.InferenceforLinearConditionalMomentInequalities”,ReviewofEconomic
Studies,forthcoming.
ARMSTRONG,T.andKOLESA´R,M.(2018),“OptimalInferenceinaClassofRegressionModels”,Econometrica,
86,655–683.
ARMSTRONG,T.andKOLESA´R,M.(2020a),“SensitivityAnalysisUsingApproximateMomentConditionModels”,
QuantitativeEconomics,12,77–108.
ARMSTRONG,T.andKOLESA´R,M.(2020b),“SimpleandHonestConfidenceIntervalsinNonparametricRegres-
sion”,QuantitativeEconomics,11,1–39.
ASHENFELTER,O.(1978),“EstimatingtheEffectofTrainingProgramsonEarnings”,TheReviewofEconomicsand
Statistics,60,47–57.
ATHEY,S.andIMBENS,G.W.(2021),“Design-basedAnalysisinDifference-In-DifferencesSettingswithStaggered
Adoption”,JournalofEconometrics,226,62–79.
BENZARTI,Y.andCARLONI,D.(2019a),“ReplicationDataFor:WhoReallyBenefitsfromConsumptionTaxCuts?
EvidencefromaLargeVATReforminFrance”(TechnicalReport,AmericanEconomicAssociation[publisher],
Inter-universityConsortiumforPoliticalandSocialResearch[distributor]).https://doi.org/10.3886/E114723V1.
BENZARTI,Y.andCARLONI,D.(2019b),“WhoReallyBenefitsfromConsumptionTaxCuts?EvidencefromaLarge
VATReforminFrance”,AmericanEconomicJournal:EconomicPolicy,11,38–63.
BHULLER, M., HAVNES, T., LEUVEN, E. and MOGSTAD, M. (2013), “Broadband Internet: An Information
SuperhighwaytoSexCrime?”,TheReviewofEconomicStudies,80,1237–1266.
BILINSKI,A.andHATFIELD,L.A.(2020),“NothingtoSeeHere?Non-inferiorityApproachestoParallelTrendsand
OtherModelAssumptions”arXiv:1805.03273[stat.ME].
Downloaded
from
https://academic.oup.com/restud/article/90/5/2555/7039335
by
Northwestern
University
Libraries
user
on
20
June
2026

RAMBACHANANDROTH AMORECREDIBLEAPPROACHTOPARALLELTRENDS 2589
BORUSYAK,K.andJARAVEL,X.(2016),“RevisitingEventStudyDesigns”(SSRNScholarlyPaperID2826228,
Rochester,NY:SocialScienceResearchNetwork).
BUGNI,F.A.,CANAY,I.A.andSHI,X.(2017),“InferenceforSubvectorsandOtherFunctionsofPartiallyIdentified
ParametersinMomentInequalityModels”,QuantitativeEconomics,8,1–38.
CALLAWAY,B.andSANT’ANNA,P.H.C.(2021),“Difference-in-DifferenceswithMultipleTimePeriods”,Journal
ofEconometrics,225,200–230.
CANAY,I.andSHAIKH,A.(2017),“PracticalandTheoreticalAdvancesinInferenceforPartiallyIdentifiedModels”in
Honore´,B.,Pakes,A.,Piazzesi,M.andSamuelson,L.(eds)AdvancesinEconomicsandEconometrics(Cambridge:
CambridgeUniversityPress)271–306.
CHEN, X., CHRISTENSEN, T. M. and TAMER, E. (2018), “Monte Carlo Confidence Sets for Identified Sets”,
Econometrica,86,1965–2018.
CHERNOZHUKOV, V., NEWEY, W. K. and SANTOS, A. (2015), “Constrained Conditional Moment Restriction
Models”arXiv:1509.06311[math,stat].
CHETTY,R.,FRIEDMAN,J.N.andROCKOFF,J.E.(2014),“MeasuringtheImpactsofTeachersII:TeacherValue-
AddedandStudentOutcomesinAdulthood”,AmericanEconomicReview,104,2633–2679.
CHO,J.andRUSSELL,T.M.(2019),“SimpleInferenceonFunctionalsofSet-IdentifiedParametersDefinedbyLinear
Moments”arXiv:1810.03180[econ.EM].
COX,G.andSHI,X.(2023),“SimpleAdaptiveSize-ExactTestingforFull-VectorandSubvectorInferenceinMoment
InequalityModels”,TheReviewofEconomicStudies,90,201–228.
DECHAISEMARTIN,C.andD’HAULTFÆUILLE,X.(2020),“Two-WayFixedEffectsEstimatorswithHeteroge-
neousTreatmentEffects”,AmericanEconomicReview,110,2964–2996.
DE CHAISEMARTIN, C. and D’HAULTFÆUILLE, X. (2021), “Two-Way Fixed Effects and Differences-in-
DifferenceswithHeterogeneousTreatmentEffects:ASurvey”(SSRNScholarlyPaperID3980758,Rochester,NY:
SocialScienceResearchNetwork).
DETTE,H.andSCHUMANN,M.(2020),“Difference-in-DifferencesEstimationUnderNon-ParallelTrends”(Working
Paper).
DOBKIN,C.,FINKELSTEIN,A.,KLUENDER,R.andNOTOWIDIGDO,M.J.(2018),“TheEconomicConsequences
ofHospitalAdmissions”,AmericanEconomicReview,108,308–352.
DONOHO,D.L.(1994),“StatisticalEstimationandOptimalRecovery”,TheAnnalsofStatistics,22,238–270.
FLYNN, Z. (2019), “Inference Based on Continuous Linear Inequalities via Semi-Infinite Programming” (SSRN
ScholarlyPaperID3390788,Rochester,NY:SocialScienceResearchNetwork).
FRANDSEN,B.R.(2016),“TheEffectsofCollectiveBargainingRightsonPublicEmployeeCompensation:Evidence
fromTeachers,Firefighters,andPolice”,ILRReview,69,84–112.
FREYALDENHOVEN,S.,HANSEN,C.andSHAPIRO,J.(2019),“Pre-eventTrendsinthePanelEvent-studyDesign”,
AmericanEconomicReview,109,3307–3338.
GAFAROV,B.(2019),“Inferenceinhigh-dimensionalset-identifiedaffinemodels”arXiv:1904.00111[econ.EM].
GOODMAN-BACON,A.(2018),“PublicInsuranceandMortality:EvidencefromMedicaidImplementation”,Journal
ofPoliticalEconomy,126,216–262.
GOODMAN-BACON,A.(2021),“Difference-in-DifferenceswithVariationinTreatmentTiming”,JournalofEcono-
metrics,225,254–277.
GREENSTONE,M.andHANNA,R.(2014),“EnvironmentalRegulations,AirandWaterPollution,andInfantMortality
inIndia”,AmericanEconomicReview,104,3038–3072.
HANSEN, C. B. (2007),“Asymptotic Properties ofa RobustVariance Matrix Estimator forPanel Data WhenT is
Large”,JournalofEconometrics,141,597–620.
HANSEN, B. E. and LEE, S. (2019), “Asymptotic Theory for Clustered Samples”, Journal of Econometrics,
210,268–290.
HECKMAN,J.,ICHIMURA,H.,SMITH,J.andTODD,P.(1998),“CharacterizingSelectionBiasUsingExperimental
Data”,Econometrica,66,1017–1098.
HIRANO, K. and PORTER, J. R. (2012), “Impossibility Results for Nondifferentiable Functionals”, Econometrica,
80,1769–1790.
HO,K.andROSEN,A.(2017),“PartialIdentificationinAppliedResearch:BenefitsandChallenges”inHonore´,B.,
Pakes,A.,Piazzesi,M.andSamuelson,L.(eds)AdvancesinEconomicsandEconometrics(Cambridge:Cambridge
UniversityPress)307–359.
HOROWITZ,J.L.andMANSKI,C.F.(1995),“IdentificationandRobustnesswithContaminatedandCorruptedData”,
Econometrica,63,281–302.
HUDSON,S.,HULL,P.andLIEBERSOHN,J.(2017),“InterpretingInstrumentedDifference-in-Differences”(Working
Paper).
KADANE, J. B. (1971), “Comparison of k-Class Estimators When the Disturbances Are Small”, Econometrica,
39,723–737.
KAHN-LANG,A.andLANG,K.(2020),“ThePromiseandPitfallsofDifferences-in-Differences:Reflectionson16
andPregnantandOtherApplications”,JournalofBusinessandEconomicStatistics,38,613–620.
KAIDO,H.andSANTOS,A.(2014),“AsymptoticallyEfficientEstimationofModelsDefinedbyConvexMoment
Inequalities”,Econometrica,82,387–413.
Downloaded
from
https://academic.oup.com/restud/article/90/5/2555/7039335
by
Northwestern
University
Libraries
user
on
20
June
2026

2590 REVIEWOFECONOMICSTUDIES
KAIDO,H.,SANTOS,A.,MOLINARI,F.andSTOYE,J.(2019),“ConfidenceIntervalsforProjectionsofPartially
IdentifiedParameters”,Econometrica,87,1397–1432.
KAIDO,H.,SANTOS,A.,MOLINARI,F.andSTOYE,J.(2022),“ConstraintQualificationsInPartialIdentification”,
EconometricTheory,38,1–24.
KEELE,L.J.,SMALL,D.S.,HSU,J.Y.andFOGARTY,C.B.(2019),“PatternsofEffectsandSensitivityAnalysis
forDifferences-in-Differences”arXiv:1901.01869[stat.AP].
KIM,W.,KWON,K.,KWON,S.andLEE,S.(2018),“TheIdentificationPowerofSmoothnessAssumptionsinModels
withCounterfactualOutcomes”,QuantitativeEconomics,9,617–642.
KLINE,P.andSANTOS,A.(2013),“SensitivitytoMissingDataAssumptions:TheoryandanEvaluationoftheU.S.
WageStructure”,QuantitativeEconomics,4,231–267.
KOLESA´R, M. and ROTHE, C. (2018), “Inference in Regression Discontinuity Designs with a Discrete Running
Variable”,AmericanEconomicReview,108,2277–2304.
LEAVITT, T. (2020), “Beyond Parallel Trends: Improvements on Estimation and Inference in the Difference-in-
DifferencesDesign”(WorkingPaper).
LEE,J.Y.andSOLON,G.(2011),“TheFragilityofEstimatedEffectsofUnilateralDivorceLawsonDivorceRates”,
TheB.E.JournalofEconomicAnalysis&Policy,11,1–9.
LOVENHEIM,M.F.andWILLEN,A.(2019a),“TheLong-RunEffectsofTeacherCollectiveBargaining”,American
EconomicJournal:EconomicPolicy,11,292–324.
LOVENHEIM, M. F. and WILLEN, A. (2019b), “Replication Data For: The Long-Run Effects of Teacher Collec-
tiveBargaining”(TechnicalReport,AmericanEconomicAssociation[publisher],Inter-universityConsortiumfor
PoliticalandSocialResearch[distributor]).https://doi.org/10.3886/E116525V1.
LOW, M. G. (1995), “Bias-Variance Tradeoffs in Functional Estimation Problems”, The Annals of Statistics, 23,
824–835.
MANSKI,C.F.(1989),“AnatomyoftheSelectionProblem”,TheJournalofHumanResources,24,343–360.
MANSKI,C.F.(1990),“NonparametricBoundsonTreatmentEffects”,TheAmericanEconomicReview,80,319–323.
MANSKI,C.F.(1997),“MonotoneTreatmentResponse”,Econometrica,65,1311–1334.
MANSKI,C.F.(2003),PartialIdentificationofProbabilityDistributions(NewYork,NY:Springer).
MANSKI,C.F.(2007),IdentificationforPredictionandDecision(Cambridge,MA:HarvardUniversityPress).
MANSKI,C.F.(2008),IdentificationforPredictionandDecision(illustrateded.,Cambridge,Mass:HarvardUniversity
Press).
MANSKI, C. F. (2013), Public Policy in an Uncertain World: Analysis and Decisions (Cambridge, MA: Harvard
UniversityPress).
MANSKI,C.F.andPEPPER,J.V.(2013),“DeterrenceandtheDeathPenalty:PartialIdentificationAnalysisUsing
RepeatedCrossSections”,JournalofQuantitativeCriminology,29,123–141.
MANSKI,C.F.andPEPPER,J.V.(2018),“HowDoRight-to-CarryLawsAffectCrimeRates?CopingwithAmbiguity
UsingBounded-VariationAssumptions”,ReviewofEconomicsandStatistics,100,232–244.
MASTEN,M.A.andPOIRIER,A.(2020),“InferenceonBreakdownFrontiers”,QuantitativeEconomics,11,41–111.
MOLINARI,F.(2020),“MicroeconometricswithPartialIdentification”,inDurlauf,S.N.,Hansen,L.P.,Heckman,J.
J.andMatzkin,R.L.(eds)HandbookofEconometrics,Vol.7ofHandbookofEconometrics,Volume7A,Chapter5
(Amsterdam:Elsevier)355–486.
MOREIRA,M.J.(2003),“AConditionalLikelihoodRatioTestforStructuralModels”,Econometrica,71,1027–1048.
MOREIRA, M. J. and RIDDER, G. (2019), “Efficiency Loss of Asymptotically Efficient Tests in an Instrumental
VariablesRegression”(SSRNScholarlyPaperID3348716,Rochester,NY:SocialScienceResearchNetwork).
MU¨LLER,U.K.(2011),“EfficientTestsUnderaWeakConvergenceAssumption”,Econometrica,79,395–435.
NOACK, C. and ROTHE, C. (2020), “Bias-Aware Inference in Fuzzy Regression Discontinuity Designs”
arXiv:1906.04631[econ.EM].
RAMBACHAN,A.andROTH,J.(2021),“AnHonestApproachtoParallelTrends”(Workingpaper,p.126).
ROMANO,J.P.andSHAIKH,A.M.(2008),“InferenceforIdentifiableParametersinPartiallyIdentifiedEconometric
Models”,JournalofStatisticalPlanningandInference,138,2786–2807.
ROMANO, J. P., SHAIKH, A. M. and WOLF, M. (2014), “A Practical Two-Step Method for Testing Moment
Inequalities”,Econometrica,82,1979–2002.
ROTH,J.(2022),“PretestwithCaution:Event-StudyEstimatesafterTestingforParallelTrends”,AmericanEconomic
Review:Insights,4,305–322.
ROTH,J.,SANT’ANNA,P.H.C.,BILINSKI,A.andPOE,J.(2022),“What’sTrendinginDifference-in-Differences?
ASynthesisoftheRecentEconometricsLiterature”arXiv:2201.01194[econ,stat].
SANT’ANNA,P.H.C.andZHAO,J.B.(2020),“DoublyRobustDifference-in-DifferencesEstimators”,Journalof
Econometrics,219,101–122.
SCHRIJVER,A.(1986),TheoryofLinearandIntegerProgramming(Chicester:Wiley-Interscience).
STOCK, J. and WATSON, M. (2008), “Heteroskedasticity-Robust Standard Errors for Fixed Effects Panel Data
Regression”,Econometrica,76,155–174.
SUN,L.andABRAHAM,S.(2021),“EstimatingDynamicTreatmentEffectsinEventStudieswithHeterogeneous
TreatmentEffects”,JournalofEconometrics,225,175–199.
TAMER,E.(2010),“PartialIdentificationinEconometrics”,AnnualReviewofEconomics,2,167–195.
VANDERVAART,A.W.andWELLNER,J.A.(1996),WeakConvergenceandEmpiricalProcesses:WithApplications
toStatistics(NewYork,NY:Springer).
Downloaded
from
https://academic.oup.com/restud/article/90/5/2555/7039335
by
Northwestern
University
Libraries
user
on
20
June
2026

RAMBACHANANDROTH AMORECREDIBLEAPPROACHTOPARALLELTRENDS 2591
WOLFERS, J. (2006), “Did Unilateral Divorce Laws Raise Divorce Rates? A Reconciliation and New Results”,
AmericanEconomicReview,96,1802–1820.
YE, T., KEELE, L., HASEGAWA, R. and SMALL, D. S. (2020), “A Negative Correlation Strategy for Bracket-
ing in Difference-in-Differences with Application to the Effect of Voter Identification Laws on Voter Turnout”
arXiv:2006.02423[stat.ME]. Downloaded
from
https://academic.oup.com/restud/article/90/5/2555/7039335
by
Northwestern
University
Libraries
user
on
20
June
2026