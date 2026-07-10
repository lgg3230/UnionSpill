

Econometrica,Vol.91,No.6(November,2023),2155–2185
# Nonrandom Exposure to Exogenous Shocks
KIRILLBORUSYAK
DepartmentofAgriculturalandResourceEconomics,UCBerkeleyandCEPR
PETERHULL
DepartmentofEconomics,BrownUniversityandNBER
Wedevelopanewapproachtoestimatingthecausaleffectsoftreatmentsorinstrumentsthatcombinemultiplesourcesofvariationaccordingtoaknownformula.Examplesincludetreatmentscapturingspilloversinsocialortransportationnetworksand
simulatedinstrumentsforpolicyeligibility.Weshowhowexogenousshockstosome—
butnotall—determinantsofsuchvariablescanbeleveragedwhileavoidingomitted
variablesbias.Oursolutioninvolvesspecifyingcounterfactualshocksthatmayaswell
havebeenrealizedandadjustingforasummarymeasureofnonrandomnessinshock
exposure:theaveragetreatment(orinstrument)acrossshockcounterfactuals.Weuse
this approach to address bias when estimating employment effects of market access
growthfromChinesehigh-speedrailconstruction.
KEYWORDS:Instrumental variables,formulainstruments,recenteredinstruments,
marketaccess.

# INTRODUCTION

MANYQUESTIONSINECONOMICSinvolvethecausaleffectsoftreatmentswhicharecomputed from multiple sources of variation, sometimes observed at different “levels,” according to a known formula. Consider three examples. First, when estimating spillovers
from a randomized intervention, one might count the number of an individual’s neighborswhowereselectedfortheintervention.Thisspillovertreatmentcombinesvariation
in who was selected with variation in who neighbors whom. Second, in studies of transportationinfrastructureeffects,onemightmeasurethegrowthofregionalmarketaccess:
a treatment computed from the location and timing of transportation upgrades and the
spatialdistributionofeconomicactivityinacountry.Athirdexampleisatreatmentcapturingindividualeligibilityforapublicprogram,suchasMedicaid,whichisjointlydeterminedbytheeligibilitypolicyintheindividual’sstateandherhousehold’sdemographics
andincome.1
This paper develops a new approach to estimating the effects of such formula treatmentswhensome—butnotall—oftheirdeterminantsaregeneratedbyatrueornatural
KirillBorusyak:k.borusyak@berkeley.edu
PeterHull:peter_hull@brown.edu
WearegratefultoRodrigoAdão,GabrielAhlfeldt,JoshAngrist,DmitryArkhangelsky,NateBaum-Snow,
SophieCalder-Wang,VascoCarvalho,GabrielChodorow-Reich,DaveDonaldson,RaffaellaGiacomini,Paul
Goldsmith-Pinkham, RichardHornbeck, Kilian Huber, Xavier Jaravel, Tetsuya Kaji, Vishal Kamat, Michal
Kolesár,DariaKuznetsova,WhitneyNewey,AureodePaula,AndrésRodríguez-Clare,JonathanRoth,Cyrus
Samii,JesseShapiro,BenSommers,ChenziXu,andnumerousseminarparticipantsforhelpfulcomments.
RuixueLi,EliseParrish,andStevenShiprovidedoutstandingresearchassistance.
1ExamplesofthesethreesettingsincludeMiguelandKremer(2004),DonaldsonandHornbeck(2016),and
CurrieandGruber(1996),respectively.Ourworkingpaper(BorusyakandHull(2021))discussesothercommontreatmentsandinstrumentsnestedinourframework:linearandnonlinearshift-sharevariables,modelimpliedoptimalinstruments,instrumentsbasedoncentralizedschoolassignmentmechanisms,“free-space”
instrumentsforaccesstomassmedia,andvariablesleveragingweathershocks.
©2023TheEconometricSociety https://doi.org/10.3982/ECTA19367

experiment. We ask, for example, how one can estimate market access effects by leveraging the timing of new railroad line construction as exogenous shocks, when the other
determinantsofmarketaccess(suchasthepredeterminedlocationoflargemarketsand
plannedlines)arenonrandom.
Wefirstshowthatomittedvariablebias(OVB)mayconfoundconventionalregression
approaches in such settings. Bias arises from different observations receiving systematicallydifferentvaluesofthetreatmentbecauseoftheirindividualnonrandom“exposure”
to the exogenous shocks. For example, even when construction is delayed for a random
setoflines,regionsthatareeconomicallyorgeographicallymorecentralwilltendtosee
a larger growth in market access because they are closer to a typical potential line (and
thus closer to a typical constructed line). Regression estimation of market access effects
then fails without an additional assumption on the exogeneity of economic geography:
that more exposed (e.g., central) regions do not differ in their relevant unobservables,
suchaschangesinlocalproductivityoramenities.Intuitively,randomizingtransportation
upgradesdoesnotrandomizethemarketaccessgrowthgeneratedbythem.
Oursolutiontothis OVBchallengeisbasedonthespecificationofcounterfactualexogenousshocksthatmightaswellhavebeenrealized.Thisapproachviewstheobserved
shocksasonerealizationofsomedata-generatingprocess—whatwecalltheshockassignmentprocess—whichcanbesimulatedtoobtaincounterfactuals.Inatrueexperiment,the
shockassignmentprocessisgivenbytherandomizationprotocol.Innaturalexperiments,
shockcounterfactualsmakeexplicitthecontrastswhichtheresearcherwishestoleverage,
forinstancebyspecifyingpermutationsoftheshocksthatwereaslikelytohaveoccurred.
For example, if line construction delays are considered as good as random, one might
producecounterfactualnetworkmapsbyrandomlyexchangingthelineswhichwerecompletedearliervs.later.
Valid shock counterfactuals can be used to avoid OVB by a “recentering” procedure
which involves measuring and appropriately adjusting for a single confounder: the expected treatment. To do so, a researcher draws counterfactual shocks from the assignmentprocessandrecomputestheinstrumentmanytimes.Then,foreachobservation,the
treatmentisaveragedacrossthesemanydrawstoobtaintheexpectedtreatment.Finally,
theexpectedtreatmentissubtractedfromtherealizedtreatmenttoobtaintherecentered
treatment.Weshowthatusingthisrecenteredtreatmentasaninstrumentfortherealized
treatment removes the bias from nonrandom shock exposure. Intuitively, observations
onlygethighversuslowvaluesoftherecenteredtreatmentbecausetheobservedshocks
were drawn instead of the counterfactuals—which is assumed to happen by chance. For
example, when the expected treatment is constructed by permuting the timing of new
lineconstruction,regressionsthatinstrumentwithrecenteredmarketaccessgrowthcompare regions which received higher vs. lower market access growth because proximate
lineswereconstructedearlyvs.lateandnotbecauseoftheeconomicgeography.Another
closely related solution to OVB is to include the expected treatment as a control in the
regression of an outcome on the realized treatment. This can be viewed as recentering
the treatment while also removing some residual variation in the outcome, in a control
functionapproach.2
Thisapproachtocausalinferencewithformulatreatments,inwhichsomedeterminants
are labeled as exogenous and characterized by an assignment process, can be seen as
2WhilerecenteringisthekeystepthatremovesOVB,removingresidualvariationislikelytoincreasethe
efficiencyofestimationinlargesamples.Wegivepracticalrecommendationsforeachadjustmentinthepaper’s
conclusion.
NONRANDOMEXPOSURETOEXOGENOUSSHOCKS 2157
formalizingthenaturalexperimentofinterestandbringingformulatreatmentstofamiliar
econometric territory.3 Indeed, the conditions we impose on the exogenous shocks are
similar to those which might be used if the shocks were directly used as treatments, for
example, if shocks to the timing of railroad line upgrades were used in a regression of
outcomes defined at the “level” of those lines. Recentering ensures identification from
the natural experiment, even when the regression is estimated at a different level (e.g.,
acrossregionsinsteadoflines).
The framework further allows the treatment to have endogenous or unobserved determinants. In this case, one may construct candidate formula instruments based on the
treatment’s exogenous and predetermined components. The same OVB problem arises
inthisinstrumentalvariable(IV)case,anditcanagainbesolvedbyrecenteringthecandidate instrument by its expectation over the shock assignment process. Controlling for
theexpectedinstrumentisagainanothersolution.
Weestablishseveralattractivepropertiesoftherecenteringapproach,beyondourprimary results on OVB. First, recentered estimators are consistent provided the exogenousshocksinducesufficientcross-sectionalvariationintheinstrumentandtreatment—
regardless of the correlation structure of unobservables. Second, shock counterfactuals
can be used for exact finite-sample inference and specification tests via randomization
inference (RI). Finally, while our consistency and RI results rely on an assumption of
constanttreatmenteffects,recenteredIVestimatorsgenerallycaptureaconvexaverage
ofheterogeneouseffectsunderanaturalfirst-stagemonotonicitycondition.
We apply this framework to estimate the employment effects of market access (MA)
growth due to a new high-speed railway system in China. We show how recentering can
help leverage variation in the timing of transportation upgrades to purge OVB. Simple
regressionsofemploymentgrowthonMAgrowthsuggestalargeandstatisticallysignificanteffectwhichisonlypartiallyreducedbyconventionalgeography-basedcontrols.But
thiseffectiseliminatedwhenweadjustforexpectedMAgrowth,measuredbypermuting
constructedHSRlineswithsimilaronesthatwereplannedbutnotbuilt.Theunadjusted
estimatesthusreflectthefactthatemploymentgrewinregionswhichweremoreexposed
toplannedhigh-speedrailconstruction,whetherornotconstructionactuallyoccurred.
Econometrically, expected treatment and instrument adjustment is similar to propensityscoremethodsforremovingOVB(RosenbaumandRubin(1983)),withtwokeydifferences.First,weproposeusingthestructureofformulatreatmentsandinstrumentsto
compute their expectation from more primitive assumptions on the assignment process
forexogenousshocks.ThisapproachissimilartohowBorusyak,Hull,andJaravel(2022)
and Aronow and Samii (2017) address OVB when using linear shift-share instruments
and network treatments, respectively. It differs from conventional methods of directly
estimatingpropensityscores;suchmethodsaretypicallyinfeasibleinthesettingsweconsiderbecausetheexposuretoexogenousshocksisintractablyhigh-dimensional.Second,
our regression-based adjustment differs from conventional approaches of weighting by
ormatchingonpropensityscores.4 Regressionadjustmentismorepopularinappliedre3Our approach is “design-based,” in that identification is achieved by specifying the assignment process
of some observed shocks (see, e.g., Lee (2008), Athey and Imbens (2022), Shaikh and Toulis (2021), and
deChaisemartinandBehaghel(2020)).Thisstrategyforanalyzingobservationaldatabuildsonalongtradition
intheanalysisofrandomizedexperiments,goingbacktoNeyman(1923).Itcontrastswithotheridentification
strategiesthatinsteadmodeltheresidualdeterminantsoftheoutcome,suchasdifference-in-differencestrategies(e.g.,deChaisemartinandD’Haultfœuille(2020)andAthey,Bayati,Doudchenko,Imbens,andKhosravi
(2021))orfully-specifiedstructuralmodels.
4Anotableexceptionofarecentering-typeregressionadjustmentinthetraditionalpropensityscoressetting
istheE-estimatorofRobins,Mark,andNewey(1992).

search, avoids practical issues of limited overlap (due to, e.g., propensity scores that are
close to zero or one), does not require the treatments or instruments to be binary, and
is natural for estimating constant structural parameters or convex averages of heterogeneoustreatmenteffects.
The remainder of this paper is organized as follows. The next section motivates our
analysis with three examples related to network spillovers, market access effects, and
Medicaid eligibility effects. Section 3 develops our general framework and results. Section4presentsourapplication,andSection5concludes.Additionalresultsandextensions
aregiveninanearlierworkingpaper,BorusyakandHull(2021,henceforthBH).

# MOTIVATINGEXAMPLES

Wedevelopthreestylizedexamples,inspiredrespectivelybythesettingsofMigueland
Kremer(2004),DonaldsonandHornbeck(2016),andCurrieandGruber(1996),toillustratethemaininsightsofthispaper.Ineachexample,weconsiderestimatingtheparameterβofacausalorstructuralmodelwhichrelatesanoutcomey toatreatmentx,
i i
y =βx +ε(cid:4) (1)
i i i
forasetofunitsi=1(cid:4)(cid:5)(cid:5)(cid:5)(cid:4)N withanunobservederrorε.Thecommonfeatureofthese
i
examplesisthatx iscomputedfrommultiplesourcesofvariationbyaknownformula.
i
Networkspillovers:Supposey isstudenti’seducationalachievementandx counts
i i
thenumberofi’sneighborswhohavebeendewormedinanintervention:
(cid:2)N
x = Neighbor Dewormed (cid:5)
i ik k
k=1
Here, Dewormed ∈ {0(cid:4)1} is an indicator for student k being selected for the dek
worming intervention and Neighbor ∈ {0(cid:4)1} indicates that i and k are neighbors
ik
(i.e., connected by anobservednetwork link). The errorterm ε captures i’s educai
tionaloutcomewhennoneofherneighborsaredewormed.Thisexampleisastylized
versionofthemainspecificationinMiguelandKremer(2004).5
Marketaccess:Supposey isthegrowthoflandvaluesinregionibetweentwodates
i
t∈ {0(cid:4)1}andx =logMA −logMA isthegrowthofregionalmarketaccessdueto
i i1 i0
improvementstotheinterregionalrailroadnetwork.Marketaccessiscomputedas
(cid:2)N
Pop
MA = j (cid:4)
it τ(Network(cid:4)Loc(cid:4)Loc )
j=1 t i j
following standard models of economic geography (e.g., Redding and Venables
(2004)). Here, Pop is the time-invariant population of region j, Network is the set
j t
ofrailwaylinesandothertypesoftransitwhichcomprisethetransportationnetwork
in operation at time t, Loc is the location of region j on the map, and τ(·) is a j
function giving the travel time between regions i and j. The error term ε captures
i
5Nothingischangedinwhatfollowsif oneinsteadconsidersthenumber ofnot-dewormed neighborsas
thetreatment.Forsimplicity,hereweconsideronlythespillovertreatmentandnotalsothedirectdeworming
treatment;seeSection3.6foranextensiontomultipletreatments.
NONRANDOMEXPOSURETOEXOGENOUSSHOCKS 2159
locationi’slandvaluegrowthintheabsenceofmarketaccessgrowth,duetosomeregionalamenity andproductivity shocks. Similarmarketaccessgrowthspecifications
areconsideredin,forexample,DonaldsonandHornbeck(2016).
Medicaideligibility:Suppose y isindividual i’shealthoutcomeand x ∈ {0(cid:4)1}indii i
cateshereligibilityforMedicaid.Let IncDem beavectorofindividualincomeand
i
demographics, State ∈ {1(cid:4)(cid:5)(cid:5)(cid:5)(cid:4)50} index i’s state of residence, and Policy be state
i k
k’s eligibility policy: that is, the set of income and demographic groups eligible for
Medicaidinthatstate.Then
x =1[IncDem ∈Policy ](cid:5)
i i Statei
Theerrortermε capturesindividuali’soutcomewhensheisineligibleforMedicaid.
i
ThisexamplecomesfromCurrieandGruber(1996).
To estimate β in each example, we consider a true or natural experiment that manipulates some of the determinants of x. Formally, we partition the variables from which
i
x= (x (cid:4)(cid:5)(cid:5)(cid:5)(cid:4)x ) is computed into two groups: a set of shocks g and a set of predeter1 N
mined variables w. The shocks g=(g (cid:4)(cid:5)(cid:5)(cid:5)(cid:4)g ) are assumed to be exogenous—that is,
1 K
independentoftheerrorsε=(ε (cid:4)(cid:5)(cid:5)(cid:5)(cid:4)ε ).Shockexogeneitycombinestwoconceptually
1 N
distinct assumptions: that g is as good as randomly assigned, and that this assignment
onlyaffectstheoutcomeofeachunitiviaitstreatmentx (anexclusionrestriction).The
i
shockscanbeassignedatadifferent“level”thantheobservations,with K(cid:3)=N. Theremaining variables w have an arbitrary structure and f(·;w) governs the mapping from i
the exogenous shocks to each unit’s treatment—that is, the observation’s “exposure” to
the shocks.6 We assume that w is determined prior to the (natural) experiment and is
unaffectedbytheshocks.
Network spillovers (cont.) Suppose deworming is assigned in a randomized control
trial(RCT)andβx fullycapturesitsspillovereffects.Theng=(Dewormed )K coli k k=1
lectstheexogenousshocks,forK=N.Theremainingdeterminantsofthespillover
treatmentsofallunits,w=(Neighbor )N ,arefixedintheexperiment.
ik i(cid:4)k=1
Market access (cont.) Suppose the timing of new railroads is exogenous. Specifically, suppose that among K lines planned to be constructed by t = 1 some are
randomly delayed by unexpected engineering problems (unrelated to the potential
trends in regional land values). Suppose also the model of economic geography
is correctly specified, so βlogMA fully captures the effects of transportation upit
grades. Then g=(Open )K collects the exogenous shocks, where Open is an ink k=1 k
dicator for whether planned line k faces no delays. Assuming no other changes to
the network at t =1, we can partition the determinants of MA growth into g and
w=((Loc(cid:4)Pop)N (cid:4)Network ),asNetwork isfullydeterminedbyNetwork andthe
i i i=1 0 1 0
setofnewlyopenedlines.
Medicaid eligibility (cont.) Suppose Medicaid policies across the K=50 states are
exogenous—that is, they are chosen irrespective of the potential health outcomes
and affect individual outcomes only via Medicaid eligibility. Then g= (Policy )K
k k=1
6AronowandSamii(2017)useasimilar“exposuremapping”terminologyforobjectslike f(·;w) inthe
i
networkspillovercontext.Wedepartfromthisliteraturebyreferringtotherealizedf(g;w)asthe“treatment”
i
or“candidateinstrument”andnottherealized“exposure.”

collectstheexogenousshocks,withtheotherdeterminantsofeligibilitycollectedin
w=(IncDem(cid:4)State)N .
i i i=1
Thefirstpointofthispaperisthatordinaryleastsquares(OLS)estimationofβcansuffer
fromOVB,despitetheexogenousvariationinx.7TheOVBproblemarisesbecausesome
i
units receive systematically higher values of x than others, as a consequence of their
i
nonrandom exposure to the shocks. This systematic variation may be cross-sectionally
correlatedwiththeerrorsε,generatingbiasinOLSestimationofequation(1).
i
Network spillovers (cont.) Even when deworming is randomly assigned to students,
those with more neighbors (e.g., because they live in dense urban areas) will tend
tohavemoredewormedneighborsand,therefore,bemoreexposedtothedeworming intervention. Urban areas may have different educational outcomes for reasons
unrelatedtodeworming,generatingOVB.
Marketaccess(cont.)Evenwhentheopeningstatusoflinesisasgoodasrandomly
assigned, regions in the economic and geographic center of the country will tend to
see more market access growth than peripheral regions as the former are closer to
atypicalpotential line. Centralregionsmayfacedifferentamenityandproductivity
shocks,generatingOVB.
Medicaid eligibility (cont.) Even when Medicaid policies are as good as randomly
assignedtostates,poorerindividualswilltendtoseehigherratesofeligibility.Poor
individualsmayfacedifferenthealthshocks,generatingOVB.
Our second insight is that this OVB problem has a conceptually simple solution, which
follows from viewing the set of realized g as one draw from a shock assignment process
and considering what counterfactual sets of exogenous shocks could have as likely been
drawn. The specification of such counterfactuals allows one to measure and remove the
systematic component of variation in the treatment which drives OVB. Specifically, the
researcherrecomputesthetreatmentx ofeachunitiacrossmanycounterfactualsetsof
i
shocks and takes their average to measure the expected treatment, μ. We show that this
i
μ,whichiscodeterminedbytheexposureofx totheshocksgandtheshockassignment
i i
process,isthesoleconfounderinequation(1).OVBcanthenbepurgedby“recentering”
the treatment: that is, by instrumenting x with x˜ =x −μ in equation (1) or by simply
i i i i
addingμ asacontrolinOLSestimation.Thekeytoremovingbiaswiththisapproachis
i
thustocrediblyspecifyandaverageovershockcounterfactuals—ataskwhichistrivialin
trueexperimentsandwhichotherwiseformalizesthenaturalexperimentofinterest.
Network spillovers (cont.) With deworming assigned in an RCT, the shock assignment process is given by the known randomization protocol. If, say, each student
has a 30% chance of being dewormed then the expected number of i’s dewormed
neighbors over repeated draws of deworming shocks μ is 0.3 times their number (cid:3) i
ofneighbors, K Neighbor .OVBisthuspurgedbycontrollingforthenumberof k=1 ik
neighbors,orbyusingtherecenterednumberofdewormedneighborsx˜ =x −μ to
i i i
instrumentforx.Witheitheradjustment,theregressionwillonlycomparestudents
i
whohadmoreneighborsdewormedthanexpected(giventhenetwork)tothosewith
fewerthanexpecteddewormedneighbors.
7SuchOVBmayariseevenif(asinthenetworkspilloversandmarketaccessexamples)variationinthe
treatment“results”fromtheexperimentalshocks,inthatx =···=x =0wheneverg =···=g =0.
1 N 1 K
NONRANDOMEXPOSURETOEXOGENOUSSHOCKS 2161
Marketaccess(cont.)Theasgoodasrandomassignmentoflineopeningstatuscan
beformalizedbyeachplannedlinefacinganequalandindependentchanceofopen- (cid:3)
ing.Then,if K Open =K railwaylinesopenbyt=1,everycounterfactualnetk=1 k 1
workinwhichK linesfromtheplanopenedwasaslikelytohaveoccurred.Onecan
1
thus compute expected MA growth μ asthe averageMA growthofregion i across
i
these counterfactuals (or a random subset of them). Recentering by or controlling
for this μ ensures that the regressions only compare regions which saw higher MA
i
growththanexpected(givenpreexistingeconomicgeographyandtheplan)tothose
whichsawlessthanexpectedMAgrowth.
Medicaideligibility(cont.)TheasgoodasrandomassignmentofMedicaidpolicies
can be formalized by each state randomly drawing from a pool of potential policies, such that every permutation of the realized policies was equally likely to have
occurred. Averaging individual i’s eligibility across these permutations yields an expected eligibility μ, which equals the share of states in which she would be eligii
ble.Oursolutionistoinstrumentactualeligibilitywithrecenteredeligibilityx −μ,
i i
or control for μ in an OLS regression. Either approach would, for example, effeci
tivelyremovefromthesample“always-eligible”or“never-eligible”individuals(with
x =μ =1 or x =μ =0)whoseincome and demographicsmakethem unaffected
i i i i
bypolicyvariation.
The recentering solution generally dominates more conventional ones, such as instrumentingdirectlybytheshocksorcontrollingfortheotherdeterminantsofx.Instrumenti
ingwiththeshocksisinfeasiblewhentheshocksareassignedatadifferentlevelthanthe
units, and generally discards variation in the treatment that is due to w. Controlling for
an observation’s nonrandom shock exposure flexibly is also typically infeasible, because
such exposure can be high-dimensional. Conversely, low-dimensional controls are only
guaranteed to purge OVB (absent additional nonexperimental restrictions on the error
term) when they linearly span μ, which is difficult to establish except when μ is known i i
andrecenteringisfeasible.Ifeithertheassignmentprocessorshockexposuremappingis
complex,μ isunlikelytobeasimplefunctionofobservedcharacteristics.
i
Networkspillovers(cont.)Usingstudenti’sowndewormingstatusasaninstrument
is infeasible as it does not predict the number of dewormed neighbors; incorporatingthenonrandomnetworkadjacencymatrixisnecessary.Controllingfortheentire
row of the adjacency matrix (which characterizes student’s exposure) is also infeasible, as it would absorb all cross-sectional variation in the treatment. Controlling
for the number of i’s neighbors is enough to purge OVB under completely random
assignment of deworming, since this control is proportional to μ. However, such
i
simple controls would not linearly span μ with more complex randomization proi
tocols,suchaswithtwotiers(byschool,thenbystudent)orstratification(e.g.,with
girlsdewormedwithaknownhigherprobability).Simplecontrolsarealsogenerally
insufficientwithmorecomplexspecificationsofspillovers.8
Market access (cont.) Railroad timing shocks vary at the level of lines, so it is infeasibletousethemasinstrumentsforregionalmarketaccesswithoutincorporating
8AnexampleisgivenbyCarvalho,Nirei,Saito,andTahbaz-Salehi(2021),whereiisaJapanesefirmand
x is the distance in the firm-to-firm supply network from i to the nearest firm located in the area hit by i
an earthquake. Unlike the number of treated neighbors, this spillover treatment is a nonlinear function of
theearthquakeshockdummies.Theearthquakeassignmentprocessisalsomorecomplex,exhibitingspatial
correlation.Therecenteringapproachstillappliesnaturallyincaseslikethis.

some nonrandom features of economic geography. Controlling perfectly for these
featuresisalsoinfeasible,aseachregion’smarketaccessdependsontheentirespatialdistributionofeconomicactivity.Simplesetsofcontrols,suchaspolynomialsin
thelatitudeandlongitudeofaregion,neednotlinearlyspanμ giventhecomplexity
i
ofx,andthusarenotguaranteedtopurgeOVB.
i
Medicaid eligibility (cont.) Currie and Gruber (1996) propose instrumenting individual eligibility with a measure of the overall policy generosity of her state—a socalled “simulated instrument.” Such instruments are simple functions of Policy for
k
all individuals in state k and are thus exogenous and relevant under random policy
assignment. However, they discard relevant within-state variation in i’s income and
demographics and are thus likely to yield a less powerful first-stage prediction of x
i
thanrecenteredeligibility.9
WeconcludethissectionbynotingthattheOVBproblemandrecenteringsolutionboth
extendtothecasewithanarbitraryendogenousx andacandidateinstrumentz whichis
i i
constructed from exogenous shocks and other variables by a known formula. This approach is natural when the treatment can be represented as a function of exogenous
shocks g, predetermined variables w, and endogenous (and possibly unobserved) variablesu,thatis,whenx =h(g(cid:4)w(cid:4)u)foraknownh(·).Anintuitivecandidateinstrument
i i i
forx isthepredictionofx inthescenariowhentheushocksareignored:z =h(g(cid:4)w(cid:4)0).
i i i i
Our framework shows that these candidate instruments are generally invalid, again becauseofthenonrandomexposureofz tog.YetOVBcanagainbepurgedbymeasuring
i
theexpectedinstrument μ—nowtheaverage z acrosscounterfactual g—andeitherini i
strumentingx withtherecenteredIVz˜ =z −μ orcontrollingforμ whileinstrumenti i i i i
ingwithz.
i
Market access (cont.) Suppose population sizes also change between t =0 and t =
1, and the observable changes u= (Pop −Pop )N are not exogenous (e.g., they
i1 i0 i=1
respond to amenity shocks in ε). Then one can consider instrumenting the realized
change in MA by a predicted change in MA which keeps population sizes fixed at
t=0levels.Withoutrecentering,thisIVregressionmaysufferfromthesameOVB
astheOLSregressiondiscussedabove.OVBisnowavoidedbyrecenteringtheMA
predictionviacounterfactualrailroadnetworks.
Medicaideligibilty(cont.)SupposeoneisinterestedintheeffectsofMedicaidtakeup, instead of eligibility. Take-up is the product of eligibility and 1−NeverTaker,
i
where NeverTaker indicates that individual i would decline Medicaid if eligible and
i
u=(NeverTaker)N isunobserved.Undertheappropriateexclusionrestriction,one
i i=1
can consider instrumenting take-up with eligibility; our recentering strategy then
againremovesOVBfromnonrandomvariationinpolicyexposure.

# THEORY

Wenowdevelopageneraleconometricframeworkforsettingswithnonrandomexposure to exogenous shocks. We first introduce the baseline setting, develop our approach
9Withcompletelyrandompolicyassignment,flexiblycontrollingforIncDem maypurgeOVBasthisisthe
i
onlysourceofvariationinμ.However,eveninthissettingtherelevantdemographicsinIncDem andtheir
i i
interactionscanbehigh-dimensional,asdiscussedbyGruber(2003).Thisproblemisexacerbatedundermore
complexassignmentprocesses,forexample,ifpoliciescanbeviewedasrandomonlywithinsomegroupsof
states, in which case group indicators and their interactions with the demographics would also have to be
included.Recenteringextendsnaturallyandavoidsthecurseofdimensionality.
NONRANDOMEXPOSURETOEXOGENOUSSHOCKS 2163
to estimation based on recentering, and discuss how recentering can be performed by
specifyingcounterfactualshocksinSections3.1–3.3.Wethendiscussconditionsforconsistency of recentered IV estimators in Section 3.4 and how inference can be conducted
inSection3.5.SeveralextensionsareoutlinedinSection3.6.

## Setting

Weconsiderestimationofβinthecausalorstructuralmodel
y =βx +ε(cid:4) (2)
i i i
from a data set of scalar and demeaned y and x, i=1(cid:4)(cid:5)(cid:5)(cid:5)(cid:4)N. Below we discuss exteni i
sions to heterogeneous causal effects, nonlinear models, multiple treatments, and additionalcontrolvariables.Althoughweuseasingleindexofiforobservations,wenoteour
frameworkaccommodatesrepeatedcross-sectionsandpaneldata.
Importantly for the applicability of our framework, we do not assume that the observations of y and x are independently or identically distributed (iid) as when arising
i i
from random sampling. This allows for complex dependencies across the units due to
theircommonexposuretoobservedandpotentiallyunobservedshocks.Itisalsoconsistent with settings where the N units represent a population—forexample, all regions of
a country—and conventional random sampling assumptions are inappropriate (Abadie,
Athey,Imbens,andWooldridge(2020)).10
Wesupposethattoestimateβaresearcherhasconstructedacandidateinstrument
z =f(g;w)(cid:4) (3)
i i
where f (·)(cid:4)(cid:5)(cid:5)(cid:5)(cid:4)f (·) is a list of known nonstochastic functions, g is a K ×1 vector of
1 N
shocks, and w is a list of other variables of unrestricted dimension. Equation (3) is very
general: any z that can be computed from a set of observed data, according to a known
i
formula,canbedescribedinthisway.11Italsoallowsx =z,inwhichcaseβisthecausal
i i
effectoftheformulatreatment.
We assume that the shocks g are exogenous, which we formalize by their conditional
independencefromthevectoroferrorsgiventheothersourcesofinstrumentvariation.
ASSUMPTION1—ShockExogeneity: g⊥⊥ε|w
As noted in Section 2, this notion of shock exogeneity combines two conceptually distinct conditions. First, it imposes an exclusion restriction which reflects an economic
model of how g can affect y. Second, it requires as good as random shock assignment.
Thislatterconditionissatisfiedwhentheshocksarefullyrandomlyassigned,asinanRCT
10Formally,weassume(x(cid:4)ε)N andthegandwvariablesintroducedbelowarealldrawnfromsomejoint i i i=1
distribution,whichisunrestrictedatthispoint.
11Insomecases(suchasthenetworkspilloverandMedicaideligibilityexamplesintheprevioussection),the
candidateinstrumentcanbenaturallywrittenasz =f(g(cid:4)w)withacommonfunctionf(·)andaunit-specific i i
measureofexposurew.Inothercases,amoregeneralnotationisnecessary:inthemarketaccessexample,for
i
example,theMAofeachregiondependsontheentirecountry’seconomicgeography.Analternativewayto
formalizegeneralformulainstrumentsisz =f(g;w(cid:4)w˜ )foracommonwandunit-specificw˜ .Thisnotation i i i
isequivalentto(3);weusef(g;w)asitismorecompact.Wealsonotealsothatequation(3)doesnotcontain
i
a residual: it formalizes an algorithm for computing an instrument rather than characterizing an economic
relationship.

(i.e.,g⊥⊥(ε(cid:4)w)),butalsoallowswtocontainvariablesthatgoverntheshockassignment
process.12 Importantly, Assumption 1 allows E[ε |w] to vary arbitrarily across i; this rei
flectsthelackofnon-experimentalassumptions,suchasparalleltrends,constrainingthe
error in equation (2).13 Assumption 1 is consistent with a two-step data-generating processwhere w isdeterminedpriortotherealizationofshocks g anderrors ε,whichthen
togetherdetermine (x(cid:4)y).14
We start by considering an instrumental variable regression of y on x that instrui i
ments with z. As usual, this strategy requires z to be relevant to the treatment and
i i
orthogonal to the error term. In our non-iid(cid:3)setting, we forma(cid:3)lize these two conditions
in terms of the full-sample IV moments E[1 zx] and E[1 zy]. Since (2) implies
(cid:3) (cid:3) (cid:3) N i i i N i i i
E[1 zy]=βE[1 zx]+E[1 zε],βisrecoverablefromtheratioofthesemoN i i i N i i i N i i i (cid:3)
ments(whatwetermidentification)undertherelevanceconditionofE[1 zx](cid:3)=0and
(cid:3) N i i i
theorthogonalityconditionofE[1 zε]=0.15Tostart,weassumethetwoIVmoments
N i i i areknown,inordertofocusonthepotentialforOVBwhentheorthogonalitycondition
fails.WediscussconditionsforconsistentestimationinSection3.4.

## OVBandInstrumentRecentering

Wedefinetheexpectedinstrumentμ =E[f(g;w)|w]astheaveragevalueofz across i i i
differentrealizationsoftheshocks,conditionalonw.OurfirstresultshowsthatOVBmay
arisewhenpredeterminedexposuretothenaturalexperimentisendogenous,andthatthe
potentialforsuchbiasisentirelygovernedbytherelationshipbetweenμ
i
andt(cid:3)heerrorε
i
.
Formally,instrumentorthogonalityneednotholdunderAssumption1:E[1 zε](cid:3)=0
N i i i ingeneral.Rather,
(cid:4) (cid:5) (cid:4) (cid:5)
(cid:2) (cid:2)
1 1
E zε =E με (cid:5) (4)
N i i N i i
i i
Thisresultfollowsfromthelawofiteratedexpectations:E[zε]=E[E[f(g;w)ε |w]]=
i i i i
E[μE[ε |w]]=E[με] for all i, where the second equality uses Assumption 1 and the
i i i i
definitionofμ.
i
Thecentralroleofμ ingoverningOVBsuggeststherecenteringsolution:eventhough
i
OVB results from potentially high-dimensional variation in units’ exposure to shocks,
adjustment for the one-dimensional confounder μ is sufficient for instrument orthogoi
nality. We adjust z by defining the recentered instrument z˜ =z −μ. By equation (4),
i i i i
12TheexclusionandasgoodasrandomassignmentassumptionsareisolatedinAppendixC.1ofBH,viaa
generalpotentialoutcomesmodel.
13Our identification results hold under the weaker conditional mean independence assumption of E[ε|
g(cid:4)w]=E[ε|w]. This can be understood as defining a partially linear model, as in Robinson (1988): y =
i
βx +ψ(w)+ε˜ whereψ(w)=E[ε |w]andE[ε˜ |g(cid:4)w]=0forε˜ =ε −ψ(w).AdifferencefromRobinson
i i i i i i i i i (1988)arisesbecausewedonotassumeiiddata;forinstance,wedonotassumeψ(w)≡ψ(w)foriidw.
i i i
14Throughout,weallow(ε(cid:4)w)tobestochastic(aswhensomecomponentsaresampledfromasuperpopulation)orfixed(asinamoreconventional“design-based”analysis;e.g.,AtheyandImbens(2022)).Inthe
Medicaideligibilityexample,itmaybemorenaturaltoviewtheobserved(IncDem(cid:4)state)assampledfrom i i
thenationalpopulationalongwithuntreatedpotentialoutcomesε.Conversely,inthemarketaccessexample,
i
itmaybemorenaturaltoviewthesetofobservedregionsasafinitepopulationwithfixedgeography(Loc)N .
i i=1
Withfixed(ε(cid:4)w),Assumption1holdstriviallybutAssumption2,below,isstillrestrictive.
15Itisworthemphasizingthatinournon-iidsetup,theseconditionscombinetwodimensionsofvariation:
overthestochasticrealizationsofg,w,x,andε,andacrossthecross-sectionofobservationsi=1(cid:4)(cid:5)(cid:5)(cid:5)(cid:4)N.In
theiidcase,theyreducetothemorefamiliarconditionsofE[zx](cid:3)=0andE[zε]=0.
i i i i
NONRANDOMEXPOSURETOEXOGENOUSSHOCKS 2165
orthogonalityalwaysholdsforthisinstrument:
(cid:4) (cid:5) (cid:4) (cid:5) (cid:4) (cid:5)
(cid:2) (cid:2) (cid:2)
1 1 1
E z˜ ε =E zε −E με =0(cid:5)
N i i N i i N i i
i i i
Thus,ifz˜ isalsorelevant,βisidentifiedbytheIVregressionwhichusestherecentered
i
instrumentz˜ insteadofz.16
i i
A closely related solution, also suggested by equation (4), is to include the expected
instrumentμ asacontrolinspecification(2)whileusingtheoriginalz astheinstrument
i i
inacontrolfunctionapproach(Wooldridge(2015)).Controllingforμ canbethoughtof
i
asrecenteringz whilealsoremovingtheresidualvariationiny whichiscross-sectionally
i i
correlatedwithμ.Asusual,removingthisresidualvariationmaygenerateprecisiongains
i
inlargesamples;similargainsmayarisefromincluding(afixednumberof)anypredeterminedcontrolsinarecenteredIVregression.17
Equation(4)furthershowsthatadjustingforμ isgenerallynecessaryforidentification,
i
absent additional restrictions on the unobserved error. Conventional controls and fixed
effectsareonlyguaranteedtopurgeOVBwhentheylinearlyspanμ:aconditionthatis
i
difficulttoverifyexceptwhenrecenteringisalsofeasible.18
Adjustmentsbasedonμ,asthesoleconfounderofz,aresimilartomoreconventional
i i
propensityscoremethods.Therearethreekeydifferences,concerningthesetting,adjustmentmethod, andcomputationof μ.First, propensity scoremethods have mostly been
i
applied to binary treatments starting from Rosenbaum and Rubin (1983). While generalizations to binary instruments (e.g., Abadie (2003)) and nonbinary treatments (e.g.,
Imbens(2000))havebeenproposed,oursettingallowsforarbitrarytreatmentsorinstruments.Second,thepropensityscoreliteraturehasmostlyusednonregressionadjustment
methods, such as matching or binning (Abadie and Imbens (2016), King and Nielsen
(2019)). A notable exception is the E-estimator of Robins, Mark, and Newey (1992),
which similarly leverages linearity of an outcome model like (2) to recenter by a scalar
variable. Third, and most importantly, propensity scores are usually estimated from the
databyrelatingthetreatmenttoavectorofobservation-specificcovariates.Thisapproach
is generally not feasible because exposure to exogenous shocks is high-dimensional: for
instance, as noted in Section 2, the expected market access of any region i depends on
theentireeconomicgeographyofthecountry.Wethereforetakeadifferentapproachto
computingμ,whichweturntonext.
i
16Thereexist f(·) constructions thatyielda relevant recentered instrument whenever the shocksinduce
i
somevariationintreatment.Formally,whenVar[E[x |g(cid:4)w]|w]isnotalmostsurelyzeroatleastforsomei,
i
therecenteredinstrumentcon(cid:3)structedasz˜
i
=
(cid:3)
E[x
i
|g(cid:4)w]−E[x
i
|w]i(cid:3)srelevant.Thisagainfollowsbythelaw
ofiteratedexpectations:E[ N 1 i z˜ i x i ]=E[ N 1 i z˜ i E[x i |g(cid:4)w]]=E[ N 1 i Var[E[x i |g(cid:4)w]|w]]. (cid:3)
17Formally,theregressionwithμ asacontrolyieldsthereduced-formandfirst-stagemomentsE[1 zy⊥]
(cid:3) i N i i i
andE[1 zx⊥],wherev⊥ denotestheresidualsfromacross-sectionalprojectionofv onμ.Weshowin N i i i i i i
AppendixB.1ofBHthatthesemomentsalsoidentifyβunderAssumption1.AppendixC.9ofBHshowsthat
controllingforμ alwaysreducesasymptoticvarianceoftheestimatorwhenz |wishomoskedastic,whilealso i i
givingacounterexampleunderheteroskedasticity.
18In panel data with z =f (g(cid:4)w), for example, unit fixed effects generally purge OVB only when the
it it t t
expectedinstrumentistime-invariant,whichgenerallyrequiresthe f (·) mapping,thevalueof w,andthe it t
distributionofg tobetime-invariant.Whileplausibleinsomeapplications,theseconditions(inparticular,
t
stationarityoftheshockdistribution)canbequiterestrictive.Forinstance,whennewrailroadlinestendtobe
builtmorethandestroyed,expectedmarketaccesswilltendtogrowovertime.

## ComputingtheExpectedInstrumentviaShockCounterfactuals

Weproposecomputingtheexpectedinstrumentby(i)specifyinganassignmentprocess
fortheshocks,(ii)drawingmanysetsofcounterfactualshocksfromthisprocess,recomputingthecandidateinstrumenteachtime,and(iii)averagingtheinstrumentacrossthe
counterfactuals. Here we formalize this approach, discuss ways in which counterfactual
shockscanbespecified,andhighlighttheadvantagesoftheapproachoveralternatives.
We define the shock assignment process as the conditional distribution of g|w, with
cumu(cid:6)lativedistributionfunctionG(g|w).WhenG(·)isknown,theexpectedinstrument
μ = f(γ;w)dG(γ|w) can be computed and either used to recenter z or added as a
i i i
regressioncontrol.19 Toemphasizetheimportanceofaknownshockassignmentprocess,
wewriteitasanassumption.
ASSUMPTION2—KnownAssignmentProcess: G(g|w) isknowninthesupportofw.
Thisassumptionisunrestrictivewhentheshocksaredeterminedbyaknownrandomizationprotocol,asinanRCTorwithpolicyrandomizations(suchastie-breakinglottery
numbers in centralized assignment mechanisms; Abdulkadiroglu, Angrist, Narita, and
Pathak (2017)).The assignment processmay alsobegivenby scientific knowledge when
shocksarerandomizednaturally,suchaswhengcapturesweatherorseismicshocksgovernedbymeteorologicalorgeologicalprocesses(e.g.,Carvalhoetal.(2021),Madestam,
Shoag,Veuger,andYanagizawa-Drott(2013)).Policydiscontinuities(asinregressiondiscontinuitydesigns)canalsoyieldaknownG(·)whenviewedasgeneratinglocalrandomizationaroundcutoffs(Lee(2008),Cattaneo,Frandsen,andTitiunik(2015)).
Inobservationaldata,wherethe distributionofshocksisunknown, Assumption2can
be satisfied by specifying some permutations of shocks that were as likely to have occurred. For instance, if one is willing to assume the shocks g are iid across k, it follows
k
thatallpermutationsoftheobservedgareequallylikely.Inthiscase,G(g|w)isuniform
whenwisaugmentedbythepermutationclass(cid:9)(g)= {π(g)|π(·)∈(cid:9) },where(cid:9) deK K
notes the set of permutation operators π(·) on vectors of length K (e.g., Lehmann and
Romano(2006,p.634)).Thedistributionofeachg (conditionallyonothercomponents
k
of w) then needs not be specified; the expected instrument is the average z across all
i
permutationsofshockswhichserveascounterfactuals:
(cid:2) (cid:7) (cid:8)
1
μ = f π(g);w (cid:5)
i K! i
π(·)∈(cid:9)K
Suchμ areeasytocompute(orapproximatewitharandomsetofpermutations).
i
Similar expected instrument calculations follow under weaker shock exchangeability
conditions,suchaswhentheg areiidwithin,butnotacross,asetofknownclustersand k
theclassofwithin-clusterpermutationsisusedtodrawcounterfactuals.Weillustratethis
approachinSection4.InBH,wediscusshowourframeworkcanalsoapplywithG(g|w)
specified up to a set of consistently estimable parameters (Appendix C.5); we also show
how Assumption 2 can derive from an economic model (e.g., of transportation network
19Fortheidentificationresults,itisenoughtoapproximateμ
i
byanaverageoff
i
(g(s);w)forany (cid:3)number
S of g(s) drawn from G(g|w), independently of each other and of g. We have, for example, E[1 (z − (cid:3) N i i
1 f(g(s);w))ε]=0byiteratedexpectations,sinceE[z |w(cid:4)ε]=E[f(g(s);w)|w(cid:4)ε].Wediscusshowthe
S s i i i i
numberofdrawsaffectstheasymptoticbehavioroftherecenteredIVestimatorbelow.
NONRANDOMEXPOSURETOEXOGENOUSSHOCKS 2167
formation)withstochasticshocksorfromsymmetriesofthejointshockdistribution(AppendicesD.1andD.2).
We note that even when G(·) is challenging to specify, a possibly incorrect specification can be useful as a sensitivity check. Specifically, if Assumption 1 holds and there
is already no OVB because the included regression controls perfectly capture either the
endogenousfeaturesofexposureortheexpectedinstrumentthencontrollingforanycandidateexpectedinstrumentm(w)cannotintroducebias.Inthiscase,theresearchermay
i
safely control for one or several m(w) based on some guesses of the assignment proi
cess.20 More generally, researchers may achieve additional robustness by controlling for
multiplecandidatem(w) basedonmultipleshockassignmentprocessguesses;onlyone
i
suchguessneedstoberighttopurgeOVB.

## RecenteredIVConsistency

With the ratio of recentered IV moments identifying β, we now consider whether the
(cid:3) (cid:3)
corresponding IV estimator β ˆ = (1 z˜ y)/(1 z˜ x) is consistent, that is, whether
N i i i N i i i
β ˆ −→p β as the number of observed outcomes and treatments grows large (N →∞). To
formalize consistency in our non-iid context, we consider a sequence of distributions
P for the complete data (y(cid:4)x(cid:4)g(cid:4)w). Only in this section, to make the asymptotic seN
quence explicit, w(cid:3)e index moments b(cid:3)y P
N
, for example, we write the recentered IV moments as E [1 z˜ y] and E [1 z˜ x]. We allow the number of observed shocks,
K N =dim(g P ) N ,a N ndt i he i d i imensio P n N so N fw i to i c i hangearbit(cid:3)rarilywithN. (cid:3)
We first consider mean-square convergence of 1 z˜ ε to E [1 z˜ ε] = 0 un-
(cid:3) N i i i PN N i i i (cid:3)
der Assumption 1, that is, whether Var [1 z˜ ε] → 0. Since β ˆ = β+ (1 z˜ ε)/
(cid:3) PN N i i i N i i i
(1 z˜ x) by (2), such convergence implies β ˆ −→p β so long as the instrument is asympN i i i
toticallyrelevant(aconditionwereturntobelow).Weestablishthisconvergenceundera
regularityconditiononε andasubstantiverestrictiononz˜ whichwetermweakmutual
i i
dependence.
ASSUMPTION3—WeakMutualDependence:
(cid:4) (cid:5)
(cid:2)(cid:9) (cid:9)
E 1 (cid:9) Cov [z˜ (cid:4)z˜ |w] (cid:9) →0(cid:5)
PN N2 PN i j
i(cid:4)j
PROPOSITION 1: Suppose Assum(cid:3)ptions 1–3 hold and E
PN
[ε
i
2|w]≤U
ε
uniformly across
N andi=1(cid:4)(cid:5)(cid:5)(cid:5)(cid:4)N.ThenVar [1 z˜ ε]→0.
PN N i i i
PROOF: SeeAppendixD. Q.E.D.
Assumption3holdswhentheshocksinducerichcross-sectionalvariationintherecentered instrument, through heterogeneous exposure, such that most pairs of (z˜ (cid:4)z˜ ) have
i j
20Formally,supposeeither E[zˇ
i
|w]=0 orE [εˇ
i
|w]=0 foreach i,where vˇ
i
d(cid:3)enotesthecross-sectional
residualizationofvariablev onsomefunctionsofw usedascontrols.ThenE[1 zˇ⊥εˇ⊥]=0,wherehere
v⊥ denotestheresidualsfro i macross-sectionalprojectionofv onm(w).SeeA N ppe i nd i ix i C.6ofBHforour
i i i
frameworkextendedtopredeterminedcontrols.

aweakcovarianceacrosspossibler(cid:3)ealizationsofg.Theproofshowsthisisenoughfora
lawoflargenumberstoapplyto 1 z˜ ε.21
N i i i
Note that in line with our approach to identification, Proposition 1 makes no substantive restrictions on the errors ε beyond Assumption 1 (in particular, it puts no rei
strictions on the dependence of ε across observations). In the absence of such restrici
tions, Pro(cid:3)position 2 in Appendix C shows the Assumption 3 is not only sufficient for
Var [1 z˜ ε]→0 but, under regularity conditions, also necessary. Of course, more
PN N i i i
conventionalrestrictionsonthemutualdependenceoferrors(suchasiidorclusteredε)
i
mayalsosufficeforconvergencewhenweakmutualdependenceofz˜ fails.
i
Three additional results in Appendix C, which extend the results on consistency with
linearshift-shareinstrumentsfromBorusyak,Hull,andJaravel(2022),unpackAssumption3further.First,alargenumberofexogenousshocksisessentiallynecessaryfortherecenteredinstrumenttonothavemanystrongcross-sectionaldependencies.Proposition3
formalizesthisintuition byshowingthat,withsufficiently smooth f(·;w),Assumption3
i
can only hold with K →∞. Moreover, the concentration of exposure to this growing
N
number of shocks matters. Proposition 4 formalizes this idea by considering a concentrationmeasureforaverageshockexposurewhichissimilartoaHerfindahl–Hirschman
(cid:3) (cid:3)
Index (HHI): E [ KN (∂f ¯ (g;w))2], where f ¯ (g;w) = 1 (f(g;w) −μ). For binary g
andweaklymon
P
o
N
tone
k=
f
1
(·;
∂
w
gk
) (asinthenetworkspill
N
over
i
sa
i
ndmarketa
i
ccessexamples
k
)
i
andwithmutually-independentshocks,Assumption3issatisfiedw(cid:3)henthismeasureconvergestozerosuchthattheimpactofanyfinitesetofshockson 1 z˜ vanishes.22PropoN i i
sition5considersadifferentlow-levelconditioninacasecoveringtheMedicaideligibility example: Assumption 3 holds when most pairs of observations of z˜ are affected by
i
nonoverlappingsetso(cid:3)fshocks.
Convergenceof 1 z˜ ε impliesconsistencyoftherecenteredIVestimatorsolongas
(cid:3) N i i i (cid:3) (cid:3)
(i)E [1 z˜ x]remainsboundedawayfromzeroand(ii) 1 z˜ x −E [1 z˜ x]−→p
PN N i i i N i i i PN N i i i
0.23Condition(i)followswhentherelationshipbetweenz andx isstrongandwhenmost
i i
observations of z˜ have exposure concentrated in a small number of exogenous shocks,
i
such that Var [z˜ ] does not dissipate even as K →∞. Proposition 6 in Appendix C
PN i N
formalizes these conditions with a linear first stage model of x =πz +u, with g⊥⊥u|
i i i
w, and a different measure of shock exposure concentration: the HHI of the effects of
(cid:3)
differentshocksonz˜ , KN (E [∂fi(g;w) |w])2,averagedacrossobservationsi.Inthecase
ofmutually-independ
i
ent
k
b
=
i
1
nar
P
y
N
sho
∂
c
gk
ks,werequireπ(cid:3)=0andthattheexpectationofthis
concentration measure is bounded above zero. The HHI conditions from Propositions
4 and 6 may simultaneously hold when most observations are mostly exposed to a small
21TheprooftoProposition1showsAssumption3isalsosufficientforconsistencywhe(cid:3)nμ
i
isapproximated
byanaverageoff(g(s);w)forg(s)drawnasinfootnote19.Intuitively,thevarianceof 1 z˜ε ishigherwith
i N i i i fewersimulationsSbutconvergestozeroforanyfixedSunderAssumption3.
22Proposition4alsoapplieswhenshocksarenormallydistributed,andwhenf(·;w)islinearregardlessof
i
theshockdistribution.ItfurthergivesanecessaryconditionforAssumption3inallofthesecases,whichisa
slightlystrongernotionofvanishingaverageshockexposureconcentration.Forbinaryshocks,∂f ¯ (g;w)/∂g is
k
¯
definedasthedifferenceinf wheng k switchesfrom0to(cid:3)1,keepingallothershoc(cid:3)ksfixed. (cid:3)
23Thisfollowsbecauseβ ˆ−β=h (r (cid:4)r )≡r /(E [1 z˜x]+r )forr = 1 z˜ε andr = 1 z˜x −
(cid:3) N 1 2 1 PN N i i i 2 1 N i i i 2 N i i i
E [1 z˜x].Sinceh (·)isLipschitz-continuousat(0(cid:4)0)withaLipschitzconstantuniformlyboundedfrom
PN N i i i N
above,β ˆ−→p βifr andr convergetozeroinprobability.
1 2
NONRANDOMEXPOSURETOEXOGENOUSSHOCKS 2169
number of shocks, differentially across a large number of shocks. Conditions similar to
Assumption3canbederivedtoensureconvergenceofthesamplefirststage,(ii).24

## RandomizationInferenceandSpecificationTests

In some applications of our framework, natural assumptions on the mutual independence of z˜ or ε across observations can make conventional (e.g., clustered) asymptotic
i i
inference valid. Generally, however, the common exposure of observations to observed
andunobservedshocksgeneratescomplexdependenciesacrossobservationswhichmake
conventionalasymptoticanalysisinapplicable.25Insuchcases,itmaybeattractivetoconstruct confidence intervals for the constant effect β and tests for Assumptions 1 and 2
based onthe specification of the shock assignment process, following a long tradition of
randomization inference (Fisher (1935)). The RI approach guarantees correct coverage
in finite samples of both observations and shocks.26 We focus on a particular type of RI
ˆ
testwhichistightlylinkedtotherecenteredIVestimatorβ.
RItestsandconfidenceintervalsforβarebasedonascalarteststatisticT =T (g(cid:4)y−
bx(cid:4)w),where b isacandidate parametervalue. Underthe null hypothesis of β=b and
Assumption1,thedistributionofT =T (g(cid:4)ε(cid:4)w)conditionalonεandwisimpliedbythe
shockassignmentprocessG(g|w).Onemaysimulatethisdistributionbyredrawingthe
g shocksandrecomputingT.IftheoriginalvalueofT isfarinthetailsofthesimulated
distribution, one has grounds to reject the null. Inversion of such tests yields the confidenceintervalforβbycollectingallbthatarenotrejected.Theseintervalshavecorrect
size,bothconditionallyon (ε(cid:4)w) andunconditionally(seeAppendixC.3ofBH).
We propose addressing the practical issue of choosing a randomization test statistic
by picking a T that is tightly linked to the recentered IV estimator, building on the
theory of Hodges and Lehmann (1963) and Rosenbaum (2002). Specifically, we consider the sample covariance of the recentered instrument and implied residual: T =
(cid:3)
1 (f(g;w) −μ) · (y −bx). Lemma 2 of BH shows that β ˆ is a Hodges–Lehmann
N i i i i i
ˆ
estimatorcorrespondingtothis T,meaningthat β equates T withitsexpectationacross
counterfactual shocks (specifically, zero).27 This connection makes RI tests and confiˆ
dence intervals based on T inherit the consistency of β: the test power asymptotically
increasestooneforanyfixedalternativeb(cid:3)=βunderregularityconditions(seePropositionS2ofBH).28
(cid:3) (cid:3) (cid:3)
24For example, with a linear first stage, Var [1 z˜x]=Var [π1 z˜2+ 1 z˜(πμ +u)]. Here,
PN N i i i PN N i i N (cid:3)i i i i
with mutually-independent binary shocks, Lemma 4 in Appendix C ensures Var [1 z˜2]→0 when the
(cid:3) PN N i i
expectedsumofsquaredeffectsofindividualshockson 1 z˜2convergestozero,andProposition1implies
(cid:3) N i i
Var [1 z˜(πμ +u)]→0whenAssumption3holdsandE [(πμ +u)2|w]isuniformlybounded.
PN N i i i i PN i i 25AnexceptionisAdão,Kolesár,andMorales(2019),whod(cid:3)erivenonstandardasymptoticinferenceinone
suchsetting:whenz isalinearshift-sharevariable,f(g;w)= w g . i i k ik k
26Specifically,RIguaranteesthevalidityoftestsforthemodelparameterβwhichcanbeinterpretedasa
constanttreatmenteffect.Validinferencewithheterogeneouseffectsinthekindofinterdependentdatawe
studyisadifficultchallenge,evenwithanasymptoticapproach(Adão,Kolesár,andMorales(2019)).
27Withadditionalpredeterm(cid:3)inedcontrolsincludedintheregression(e.g.,μ
i
),thesamepropertyissatisfied
by the residualized statistic 1 z˜(y⊥−bx⊥), where here v⊥ denotes the residuals from a cross-sectional N i i i i i projectionofv ontheincludedcontrols.
i
28RIconfidenceintervalsbasedonthisstatisticarestillobtainedbytestinversion,andnotfromthedistributionoftherecenteredestimatoritselfacrosscounterfactualshocksg∗.ThelatterideafailsinIVsincethe
rerandomizedinstrumentf(g∗;w)−μ hasatruefirst-stageofzero.Thedistributionofreduced-formcoeffii i
cientsacrosscounterfactualshocksisalsonotuseful,exceptfortestingβ=0,asthatdistributioniscentered
aroundzeroratherthanβ.

RandomizationinferencecanalsobeusedtoperformfalsificationtestsonAssumptions
1 and 2. Recentering implies a testable prediction that z˜ is orthogonal to any variable
i
r = (r)N satisfying g ⊥⊥r |w, such as any function of w or other observables (either
i i=1
predetermined or contemporaneous) thought to be conditionally in(cid:3)dependent of g. To
testthisrestriction,onemaycheckthatthesamplecovarianceT = 1 z˜ r issufficiently
N i i i
close to zero by drawing counterfactual shocks and checking that T is not in the tails
of its conditional on (w(cid:4)r) distribution. Multiple falsification tests, based on a vector
of predetermined variables R, can be combined by an appropriate RI procedure, for
i
example,bytakingT tobethesumofsquaredfittedvaluesfromregressingz˜ onR.29
i i
Falsification tests can be useful in two ways. First, when r is a lagged outcome or ani
othervariablethoughttoproxyforε,theyprovideanRIimplementationofconventional
i
placebo and covariate balance tests of Assumption 1. While the use of RI for inference
oncausaleffectsmaybecomplicatedbytreatmenteffectheterogeneity,thesharphypothesis of zero placebo effects is a natural null. Second, RI tests will generally have power
to reject false specifications of the shock assignment process—that is, violations of Assumption2—evenwhenr doesnotproxyforε.Forr =1,forexample(whichistrivially
i i i
conditionallyindependentofg),thetestverifiesthatthesamplemeanofz istypicalfor
i therealizationsofthespecifiedassignmentprocess.Settingr =μ insteadchecksthatthe
i i
recentered instrument is notcorrelatedwith the expected instrument thatit issupposed
toremove.

## Extensions

While we analyze the constant-effect model (2), identification by μ-adjusted regresi
sionsextendstosettingswithheterogeneoustreatmenteffects.Namely,AppendixC.1of
BH shows that the recentered IV estimator identifies a convex-weighted averageof heterogeneouseffectsunderanappropriatemonotonicity condition, extending Imbensand
Angrist (1994). The weights are proportional to the conditional variance of z˜ |w across
i
counterfactual shocks, σ2. These σ2, like μ, are given by the shock assignment process
i i i
(Assumption 2) and can therefore be computed and analyzed by the researcher. Moreover, computed σ2 can be used to identify more conventional weighted average effects.
i
Forexample,inreduced-formmodelsoftheformy =βz +ε arecenteredandrescaled
(cid:3)i i i i
IV (z −μ)/σ2 identifies the average effect E[1 N β]. In IV settings with binary x
i i i N i=1 i i
and z, this rescaled instrument identifies the local average treatment effect of Imbens
i
andAngrist(1994).30
Further extensions aregiven inthe Appendix ofBH.Appendix C.6 shows how predeterminedobservablescanbeincludedasregressioncontrolstoreduceresidualvariation
andpotentiallyincreasepower.AppendixC.7discussesidentificationandinferencewith
multipletreatmentsorinstruments.Finally,AppendixC.8extendstheframeworktononlinearoutcomemodels.
4. APPLICATION:EFFECTSOFTRANSPORTATIONINFRASTRUCTURE
Wenowpresentanempiricalapplicationshowinghowrecenteringcanbeusedtoavoid
OVB in practice. We estimate the effect of market access growth on Chinese regional
29ThisT =z˜(cid:10)R(R(cid:10)R)−1R(cid:10)z˜ extendsoursingle-dimensionaltest:itisaquadraticformofthevector-valued
(cid:3)
statistic 1 z˜R,weightedby(R(cid:10)R)−1,whereRisthematrixcollectingR andz˜isthevectorcollectingz˜.
N i i i i i
30Wenotethatthisheterogeneouseffectsextensionappliestoidentificationbutnotrandomization-based
confidenceintervalswhich,asnotedabove,arebasedonasharpnullhypothesisofβ =bforalli.
i
NONRANDOMEXPOSURETOEXOGENOUSSHOCKS 2171
employmentgrowthover2007–2016,leveragingtherecentconstructionofhigh-speedrail
(HSR).WeshowhowcounterfactualHSRshockscanbespecified,andhowcorrectingfor
expectedmarketaccessgrowthcanhelppurgeOVB.
The recent construction of Chinese HSR has produced a network longer than in all
othercountriescombined(Lawrence,Bullock,andLiu(2019)).Thenetworkmostlyconsists of dedicated passenger lines and has developed rapidly since 2007.31 Construction
objectives included freeing up capacity on the low-speed rail network and supporting
economic development by improving regional connectivity (Lawrence, Bullock, and Liu
(2019), Ma (2011)). While affordable fares make HSR popular for multiple purposes,
businesstravelisanimportantcomponentofrailtraffic,rangingbetween28%and62%,
depending on the line (Ollivier, Bullock, Jin, and Zhou (2014), Lawrence, Bullock, and
Liu(2019)).TheroleofHSRmayalsoextendbeyonddirectlyconnectedregions,aspassengersfrequentlytransferbetweenHSRandtraditionallines(andbetweenintersecting
HSRlines).AnearlyanalysisbyZhengandKahn(2013)findspositiveeffectsofHSRon
housingprices,whileLin(2017)similarlyfindspositiveeffectsonregionalemployment.
We analyze HSR-induced market access effects for 340 subprovince-level administrativedivisionsinmainlandChina,referredtoasprefectures.32 Wemeasuremarketaccess
growth between 2007 and 2016 by combining data on the development of the HSR network and each prefecture’s location and population (as measured in the 2000 census).
A total of 83 HSR lines opened between these years, with the first in 2008; a further 66
lineswerecompletedorunderconstructionasofApril2019.33Wecomputeasimplemarket access measure in(cid:3)each prefecture i and year t based on the formula in Zheng and
Kahn (2013): MA = exp(−0(cid:5)02τ )·Pop , where Pop denotes the year 2000
it j ijt j(cid:4)2000 j(cid:4)2000
populationofprefecturej andτ denotespredictedtraveltimebetweenregionsi andj
ijt
inyeart (inminutes).Traveltimepredictionsarebasedontheoperationalspeedofeach
HSRlineaswellasgeographicdistance,whichproxiesforthetraveltimebycaroralowspeed train. We relate MA growth, x =logMA −logMA , to the corresponding
i i(cid:4)2016 i(cid:4)2007
growthinprefecture’surbanemploymenty fromChineseCityStatisticalYearbooks.This
i
yieldsasetof275prefectureswithnonmissingoutcomedata;seeAppendixAfordetails
on the sample construction and MA measure. Panel A of Figure 1 shows the Chinese
HSRnetworkasoftheendof2016,alongwiththeimpliedMAgrowthsince2007.
Column1ofTableI,PanelA,reportsthecoefficientfromaregressionofemployment
growth on MA growth.34 The estimated elasticity, at 0.23, is large. With an average MA
growth of 0.54 log points, it implies a 12.4% employment growth attributable to HSR
for an average prefecture—almost half of the 26.6% average employment growth. The
estimateisalsohighlysignificantusingConley(1999)spatially-clusteredstandarderrors.
Panel A of Figure 1, however, gives reason for caution against a causal interpretation
of the OLS coefficient. Prefectures with high MA growth, which serve as the effective
treatmentgroup,tendtobeclusteredinthemaineconomicareasinthesoutheastofthe
country where HSR lines and large markets are concentrated. A comparison between
31ConstructionwasstartedbytheMedium-andLong-TermRailwayPlanin2004;thisplanwaslaterexpandedin2008andagainin2016.
32Mostprefecturesareofficiallycalled“prefecture-levelcities,”buttypicallyincludemultipleurbanareas.
33WedefinealinebyacontiguoussetofinterprefectureHSRlinksthatwereproposedtogetherandopened
simultaneously.OnepilotHSRlinebetweenQinhuangdaoandShenyangopenedin2003.Weincludeitinour
marketaccessmeasurebutfocusonthebulkofHSRgrowthover2007–2016.
34ThisregressioncanbeviewedasareducedformofahypotheticalIVregression,inwhichthetreatment
isameasureofmarketaccessthataccountsforchangesinpopulation.Wefocusonthereducedformbecause
ofdataconstraints:weonlyobservethepopulationofall340prefecturesinthe2000Census.

FIGURE1.—ChineseHighSpeedRailandMarketAccessGrowth,2007–2016.Note:PanelAshowsthecompletedChinahigh-speedrailnetworkbytheendof2016,withshadingindicatingMAgrowth(i.e.,log-change
in MA) relative to 2007. Panel B shows the network of all HSR lines, including those planned but not yet
completedasof2016.
these prefectures and the economic periphery may be confounded by the effects of unobserved policies, both contemporaneous and historical, that differentially affected the
economiccenter.
TABLEI
EMPLOYMENTEFFECTSOFMARKETACCESSGROWTH:UNADJUSTEDANDRECENTEREDESTIMATES.
Unadjusted Recentered Controlled
OLS IV OLS
(1) (2) (3)
PanelA:NoControls
MarketAccessGrowth 0.232 0.084 0.072
(0.075) (0.097) (0.093)
[−0(cid:5)245(cid:4)0(cid:5)337] [−0(cid:5)169(cid:4)0(cid:5)337]
ExpectedMarketAccessGrowth 0.317
(0.096)
PanelB:WithGeographyControls
MarketAccessGrowth 0.133 0.056 0.047
(0.064) (0.089) (0.092)
[−0(cid:5)135(cid:4)0(cid:5)280] [−0(cid:5)146(cid:4)0(cid:5)280]
ExpectedMarketAccessGrowth 0.214
(0.073)
Recentered No Yes Yes
Prefectures 275 275 275
Note: ThistablereportscoefficientsfromregressionsofemploymentgrowthonMAgrowthinChineseprefecturesfrom2007–
2016.MAgrowthisunadjustedinColumn1.InColumn2,thistreatmentisinstrumentedbyMAgrowthrecenteredbypermutingthe
openingstatusofbuiltandunbuiltHSRlineswiththesamenumberofcross-prefecturelinks.Column3insteadestimatesanOLS
regressionwithrecenteredMAgrowthastreatmentandcontrollingforexpectedMAgrowthgivenbythesameHSRcounterfactuals.
TheregressionsinPanelBcontrolfordistancetoBeijing,latitude,andlongitude.Standarderrors,whichallowforlinearlydecaying
spatialcorrelation(uptoabandwidthof500km),arereportedinparentheses.95%RIconfidenceintervalsbasedontheHSR
counterfactualsarereportedinbrackets.
NONRANDOMEXPOSURETOEXOGENOUSSHOCKS 2173
TABLEII
REGRESSIONSOFMARKETACCESSGROWTHONMEASURESOFECONOMICGEOGRAPHY.
Unadjusted Recentered
(1) (2) (3) (4)
DistancetoBeijing −0(cid:5)291 0.069 0.088
(0.062) (0.039) (0.045)
Latitude/100 −3(cid:5)324 −0(cid:5)342 −0(cid:5)182
(0.646) (0.276) (0.319)
Longitude/100 1.321 0.485 0.440
(0.458) (0.237) (0.240)
ExpectedMarketAccessGrowth 0.026 0.054
(0.056) (0.069)
Constant 0.536 0.018 0.018 0.018
(0.029) (0.018) (0.021) (0.018)
JointRIp-value 0.443 0.711 0.492
R2 0.824 0.083 0.010 0.086
Prefectures 275 275 275 275
Note: ThistablereportscoefficientsfromregressingtheunadjustedandrecenteredMAgrowthofChineseprefectures(2007–
2016)ongeographiccontrols.Recenteringisdonebypermutingtheopeningstatusofbuiltandunbuiltlineswiththesamenumber
ofcross-prefecturelinks.Allregressorsaremeasuredfortheprefecture’smaincityanddemeanedsuchthattheconstantineach
regressioncapturestheaverageoutcome.DistancetoBeijingismeasuredin1000km;latitudeandlongitudearemeasuringindegrees.
Standarderrors,whichallowforlinearlydecayingspatialcorrelation(uptoabandwidthof500km),arereportedinparentheses.Joint
RIp-valuesarebasedonthe1999HSRcounterfactualsandthesum-of-squarefittedvaluesstatistic,asdescribedinfootnote29.
We quantify the systematic nature of spatial variation in MA growth in Column 1 of
Table II, by regressing it on a prefecture’s distance to Beijing, latitude, and longitude.
These predictors capture over 80% of the variation in MA growth (as measured by the
regression’s R2), reinforcing the OVB concern: fora causalinterpretation ofthe TableI
regression, one would need to assume that all unobserved determinants of employment
growth (e.g., local productivity shocks) are uncorrelated with these geographic features.
WhileonecouldofcoursecontrolforthespecificgeographicvariablesfromTableII(as
weexplorebelow),controllingperfectlyforgeographyisimpossiblewithoutremovingall
variationinx.
i
Our solution to the OVB concern is to view certain features of the HSR network as
realizationsofanaturalexperiment.ByspecifyingasetofcounterfactualHSRnetworks,
wecancomputetheappropriatefunctionofgeographyμ whichremovesthesystematic
i
variationinMAgrowth.
Our specification of counterfactuals exploits the heterogeneous timing of HSR construction. Specifically, we permute the 2016 completion status of the built and unbuilt
(butplanned)lines,assumingthatthetimingoflinecompletionisconditionally asgood
asrandom.PanelBofFigure1comparesthebuiltandunbuiltlineswhichformourcounterfactuals.UnbuiltlinestendtobeconcentratedinthesameareasofChinaasbuiltlines,
reinforcingthefactthatconstructionisnotuniformlydistributedinspace.Moreover,built
linestendtoconnectmoreregions:theaveragenumberofcross-prefecture“links”is3.19
and2.44forbuiltandunbuiltlines,respectively,withastatisticallysignificantdifference
(p=0(cid:5)048).Toaccountforthisdifference,weconstructcounterfactualupgradesbypermuting the 2016 completion status only among lines with the same number of links. For
example,themainBeijingtoShanghaiHSRline,whichhasthegreatestnumberoflinks,
is always included in the counterfactuals. This procedure generates 1999 counterfactual

FIGURE2.—ExpectedandRecenteredMarketAccessGrowthfromChineseHSR.Note:PanelAshowsthe
variationinexpected2007–2016MAgrowthacrossChineseprefectures,computedfrom1999HSRcounterfactualsthatpermutetheopeningstatusofbuiltandunbuiltlineswiththesamenumberofcross-prefecture
links.PanelBplotsthevariationincorrespondingrecenteredMAgrowth:thedifferencebetweentheMA
growthshowninPanelAofFigure1andexpectedMAgrowth.TheHSRnetworkasof2016isalsoshownin
thispanel.
HSRmapsthatarevisuallysimilartotheactual2016network;AppendixFigureA1gives
anillustrativeexample.
Columns 2–4 of Table II validate this specification of the HSR assignment process by
the test described in Section 3.5. Column 2 shows that this recentering successfully removes the systematic geographic variation in market access. Specifically, we regress recenteredMAgrowthonaconstantandthesamegeographiccontrolsasinColumn1.The
regressioncoefficientsandR2falldramaticallyrelativetoColumn1,whileapermutationbased p-value for their joint significance (based on the regression’s sum-of-squares, as
suggested in footnote 29) is 0.44. Columns 3 and 4 further show that recentered MA
growthisuncorrelatedwithexpectedMAgrowth.35
Figure2plotsexpectedandrecenteredMAgrowthgivenbythepermutationsofbuilt
andunbuiltlines.Theeffectofrecenteringisapparentbycontrastingthesolidandstriped
regions in Panel B of Figure 2 (indicating high and low recentered MA growth) with
the dark- and light-shaded regions in Panel A of Figure 1 (indicating high and low MA
growth). The recentered treatment no longer places western prefectures in the effective
control group, since their MA growth is as low as expected. Similarly, some prefectures
in the east (such as Tianjin) are no longer in the effective treatment group, as they saw
an expectedly large increase in MA. At the same time, recentering provides a justification for retaining other regional contrasts. Hohhot, for example, expected a higher MA
growth than Harbin due to the planned connection to Beijing. This line was still under
constructionin2016,however,resultinginlowerMAgrowthinHohhotthanHarbin.
Column 2 of Table I, Panel A, shows that instrumenting MA growth with recentered
MAgrowthreducestheestimatedemploymentelasticitysubstantially,from0.23to0.08.
ControllingforexpectedMAgrowthyieldsasimilarestimateof0.07inColumn3.Neither
ofthetwoadjustedestimatesisstatisticallydistinguishablefromzeroaccordingtoeither
Conley (1999) spatial-clustered standard errors or permutation-based inference (which
35Theseresultsareconsistentwithcorrectspecificationofcounterfactuals(i.e.,wecannotrejectAssumption 2), though we note they do not provide direct support for the exogeneity of HSR construction to the
unobserveddeterminantsofemployment(Assumption1).
NONRANDOMEXPOSURETOEXOGENOUSSHOCKS 2175
yieldsawiderconfidenceintervalinthissetting).Thedifferencebetweentheunadjusted
and adjusted estimates is explained by the fact that employment growth is strongly predicted by expected MA growth. In Column 3, we find a large coefficient on μ, of 0.32,
i
meaning that employment grew faster in prefectures that were more highly exposed to
potentialHSRconstruction,whetherornotthenearbylineswerebuiltyet.
Panel B of Table I shows that the geographic controls from Table II do not isolate
the same variation as expected MA growth adjustment. Including these controls in the
unadjustedregressionofColumn1yieldsasmallerbutstilleconomicallyandstatistically
significant coefficient of 0.13. In contrast, Columns 2 and 3 show that the finding of no
significantMAeffectafteradjustingforμ isrobusttoincludinggeographiccontrols.The
i
μ adjustment aloneappearssufficienttoremovethe geographicdependence ofMA,as
i
TableIIalsoshowed.36
Whileourprimaryinterestistoillustratetherecenteringapproach,wenotethatthere
areseveralpossibleexplanationsforthesubstantivefindingofasmallemploymenteffect
of MA. Unlike other transportation networks used for trading goods, the Chinese HSR
network primarily operates passenger trains. Its scope for directly affecting production
isthereforesmaller,althoughitcouldstillfacilitatecross-regionalbusinessrelationships.
Inaddition,theemploymenteffectsofgrowingmarketaccesscouldbepositiveforsome
regionsbutnegativeforothers,aseasiercommutingbetweenregionsrelocatesemployers.
Weleaveanalysesofsuchmechanismsandheterogeneityforfuturestudy.
InBH,wediscusshowmarketaccessrecenteringrelatestootherapproachesinthelong
literature estimating transportation infrastructure upgrade effects (Redding and Turner
(2015)).Wefirstcontrastthewell-knownchallengeofstrategicallychosentransportation
upgrades with the less discussed problem that regional exposure to exogenous upgrades
may be unequal. We then explain how common strategies to address the former issue
(e.g., by leveraging historical routes or inconsequential places) can be incorporated in
ourframework,atleastinprinciple.Atthesametime,wehighlightthatrecenteringmay
still be needed to address the latter issue. We further discuss how some of the existing
approaches naturally yield specifications of counterfactual networks (e.g., the placebos
in Donaldson (2018) and Ahlfeldt and Feddersen (2018)) and summarize the conceptual and practical advantages of our approach relative to employing more conventional
controls.Weemphasizethatevenwhenitischallengingtoobtainaconvincingspecificationofcounterfactuals,anyspecificationcanyieldarobustnesscheckonthesealternative
strategies(seefootnote20).

# CONCLUSION

Many studies in economics use treatments or instruments which combine multiple
sourcesofvariation,sometimesobservedatdifferent“levels,”accordingtoaknownformula. We develop a general approach to causal inference when some—but not all—of
thisvariationisexogenous.Nonrandomexposuretotheexogenousshockscanbiasconventionalregressionestimators,butthisproblemcanbesolvedbyspecifyingashockassignment process: namely, a set of counterfactual shocks that might as well have been
realized.Averagingthetreatmentorinstrumentoverthesecounterfactualsyieldsasingle
μ which can be adjusted for to achieve identification and consistency. The specification
i
ofcounterfactualsalsoyieldsanaturalformofvalidfinite-sampleinference.
36InBHweprovideadditionalrobustnesschecks:adjustingthedefinitionsofMAandoutcomevariables,usingabinarymeasureofconnectivitytotheHSRnetwork,includingprovincefixedeffects,droppinginfluential
prefectures,andexaminingtheroleoftreatmenteffectheterogeneity.

In practice, researchers face a choice of how to use μ in a regression analysis: receni
teringbyitorcontrollingforit.Whentheassignmentprocessisgivenbyatruerandomization protocol, as in a RCT, we recommend researchers recenter first to purge OVB.
Thenanypredeterminedcontrols(i.e.,functionsofexposure)canbeincludedtoremove
variationintheerrortermandlikelyincreaseestimationefficiency.Whileμ isonepossii
ble control, which automatically recenters the treatment or instrument, it need not be
the best choice in terms of predicting the residual variation. Our recommendation is
different in natural experiments where assumptions must be placed on the assignment
process. Then controlling for candidate μ instead of recentering can have a valuable
i
“double-robustness” property. Researchers can compute and control for several candidateμ basedondifferentassignmentprocesses,suchthatOVBispurgedifatleastone
i
oftheprocessesisspecifiedcorrectly(orifthereisnoOVBtobeginwith).
Weconcludebynotingthatourframeworkbearspracticallessonsforarangeofcommon treatments and instruments, well beyond the market access measure in our empirical application. In our working paper (Borusyak and Hull (2021)), we discuss and
illustrate some of these implications for policy eligibility treatments, network spillover
treatments, linearandnonlinearshift-shareinstruments, model-impliedinstruments, instrumentsfromcentralizedschoolassignmentmechanisms,“free-space”instrumentsfor
mass media access, and weather instruments. We expect other settings may also benefit
fromexplicitspecificationofshockcounterfactualsandappropriateadjustmentfornonrandomshockexposure.
APPENDIXA: DATAAPPENDIX
Ouranalysisofmarketaccesseffectsusesdataon340prefecturesofmainlandChina.
ThisexcludestheislandsofHainanandTaiwanandthespecialadministrativeregionsof
HongKongandMacau,butincludes sixsubprefecture-levelcities(e.g.,Shihezi) thatdo
notbelongtoanyprefecture.WeuseUnitedNationsshapefilestogeocodeeachprefecturebythelocationofitsmaincity(or,inafewcases,bytheprefecturecentroid).37
WeuseavarietyofsourcestoassembleacomprehensivedatabaseoftheHSRnetwork
in 2016 as well as the lines planned (and in many cases under construction) as of April
2019butnotopenedyetbytheendof2016.OurstartingpointsareMap1.2ofLawrence,
Bullock, and Liu (2019), China Railway Yearbooks (China Railway Yearbook Editorial
Board(2001–2013)),andthereplicationfilesofLin(2017).Wecross-checknetworklinks
across these sources and use Internet resources such as Wikipedia and Baidu Baike to
confirmandfillinmissinginformation.OurdatabaseincludesvarioustypesofHSRlines,
including the National HSR Grid (4+4 and 8+8) and high-speed intercity railways.
HoweverweonlyconsidernewlybuiltHSRlines,excludingtraditionallinesupgradedto
higherspeeds.Wedonotputfurtherrestrictionsontheclassoftrains(e.g.,toG-andDclassesonly)orspecifyanexplicitminimumspeed.Theoperatingspeedthereforeranges
between160and380kph,althoughthemajorityoflinesareat250kph.Foreachline,we
collectthedateofitsofficialopening(ifithasopened),theactualorplannedoperating
speed,andthelistofprefecturestops.Whendifferentsectionsofthesamelineopenedin
astaggeredway,weclassifyeachsectionasaseparatelineforthepurposesofconstructing
our1999counterfactuals,followingthedefinitionofalineinfootnote33.Weincludeonly
onecontiguousstopperprefectureanddroplinesthatdonotcrossprefectureborders.
37TheshapefilesareobtainedfromOCHARegionalOfficeforAsiaandthePacific(2018,2020),accessed
onApril4,2020.
NONRANDOMEXPOSURETOEXOGENOUSSHOCKS 2177
We compute travel time τ between all pairs of prefectures i and j as of the ends of
ijt
2007 and 2016 for both the actual and counterfactual networks. Travel time combines
traditional modes of transportation (car or low-speed train) with HSR, where available.
WeallowforunlimitedchangesbetweendifferentHSRlinesandbetweenHSRandtraditional modes without a layover penalty, as HSR trains tend to operate frequently and
traditional modes also involve downtime. Following the existing literature, we proxy for
travel time by traditional modes by the straight-line distance and specify the speed of
100=120/1(cid:5)2 kph, where 120 kph is their typical speed and the 1.2 adjustment for actualroutesthatarelongerthanastraightline.FortwoprefecturesconnectedbyanHSR
linewecomputethedistancealongthelineasthesumofstraight-linedistancesbetween
adjacent prefectures on the line. We use the operating speed of each line divided by an
adjustmentfactorof1.3tocapturethefactthattheaveragespeedislowerthanthenominalspeedwerecord.ComputingMAfurtherrequiresthepopulationofeachofthe340
prefecturesfromthe2000populationCensus,whichweobtainfromBrinkhoff(2018).38
We measure prefecture employment in the 2008–2017 China City Yearbooks (China
StatisticsPress(2000–2017)).39Eachyearbookcoversthepreviousyear(soourdatacover
2007–2016). While the yearbooks provide several employment variables, we use “The
AverageNumberofStaffandWorkers”(fromthe“People’sLivingConditionsandSocial
Security”chapter),asmeasuredintheentireprefectureandnotjustthemainurbancore.
This employment series has by far the lowest number of strong year-to-year deviations,
whichmayindicatedataqualityissues.
We finally apply a data cleaning procedure to the outcome variable. We first mark a
prefecture-yearobservationasexhibitinga“structuralbreak”if(i)theoutcomechanges
by more than twice in either direction relative to the previous nonmissing value for the
prefecture,(ii)itisnotfollowedbyachangeintheoppositedirectionthatisbetween3/4
and 4/3 as large in terms of log-changes (which we view as a one-off jump and ignore),
and (iii) the previous change does not satisfy (i). We view the outcome change between
2007and2016asvalidonlyiftherearenostructuralbreaksinanyyearinbetween.This
reducesthesamplefrom283tothefinalsetof275prefectures.
38AccessedonNovember20,2018.
39Datafor2008–2015,excluding2009and2011,arefromhttp://oversea.cnki.net.proxy.uchicago.edu/kns55/
default.aspx;datafrom2009,2011,2016,and2017arefromhttp://tongji.oversea.cnki.net/chn/navi/HomePage.
aspx?id=N2018050234&name=YZGCA(allaccessedonJanuary23,2019,viaaUniversityofChicagoportal).

APPENDIXB: ADDITIONALEXHIBITS
FIGUREA1.—SimulatedHSRLinesandMarketAccessGrowth.Note:Thisfigureshowsanexamplemap
ofsimulatedChineseHSRlinesandmarketaccessgrowthover2007–2016,obtainedbypermutingtheopening
statusofbuiltandunbuiltlineswiththesamenumberofcross-prefecturelinks.
APPENDIXC: ADDITIONALRESULTS
Throughouttheresultsandlaterproofs,weomitthephrase“almostsurelywithrespect
tow”forbrevity.Wealsoabbreviateweakmutualdependence(Assumption3)asWMD.
PROPOSITION2—ConvergenceforAllE(cid:3)rrorsImplies WMD: Suppose Var
PN
[z˜
i
|w]≤
U uniformly. If, for some U >0, Var [1 z˜ ε]→0 for every sequence of distributions
z ε PN N i i i
ofεsuchthatVar [ε]≤U forallN andi=1(cid:4)(cid:5)(cid:5)(cid:5)(cid:4)N,thenWMDholds.
PN i ε
PROPOSITION 3—WMD Implies Growing Number of Shocks: Suppose the support of
g isboundeduniformlyacrossacrossN andk=1(cid:4)(cid:5)(cid:5)(cid:5)(cid:4)K .Supposefurtherthat,uniformly
k N
acrossN,f ˜ (g;w)≡f(g;w)−E [f(g;w)|w]isLipschitz-continuousing withtheLipschitzconst i antbelow U i andtha P t N Va i r [f ˜ (g;w)|w]≥L >0 foratleast N ·L units i,
Lip PN i z V
withL >0.ThenWMDimpliesK →∞.
V N
PROPOSITION 4—WMD and Dispersed Shock Exposure: Suppose f
i
(g;w) is weakly
monotoneingforalli,thecomponentsofgarejointlyindependentconditionallyonw,and
Var [g |w]∈[L (cid:4)U ] for 0<L <U <∞. Consider three cases: conditionally on w,
PN k σ σ σ σ
(i)allcomponentsofgarenormallydistributedandE [|∂f ¯ (g)||w]<∞,(ii)allcomponents
¯ PN ∂gk
ofghavetheBernoullidistribution,or(iii)f islinearing.Ineachcase:
(cid:3) (a) If E [(∂f ¯ (g;w))2]→0,WMDholds;
k PN ∂gk (cid:3)
(b) IfWMDholds,E [ (E [∂f ¯ (g;w) |w])2]→0,
PN k PN ∂gk
wherewedefine ∂f ¯ (g) ≡f ¯ (g (cid:4)(cid:5)(cid:5)(cid:5)(cid:4)g (cid:4)1(cid:4)g (cid:4)(cid:5)(cid:5)(cid:5)(cid:4)g )−f ¯ (g (cid:4)(cid:5)(cid:5)(cid:5)(cid:4)g (cid:4)0(cid:4)g (cid:4)(cid:5)(cid:5)(cid:5)(cid:4)g )
∂gk 1 k−1 k+1 KN 1 k−1 k+1 KN
intheBernoullishockcase.
NONRANDOMEXPOSURETOEXOGENOUSSHOCKS 2179
PROPOSITION5—WMDandNonoverlappingExposureSets: ForeachN,letG (·)(cid:4)(cid:5)(cid:5)(cid:5)(cid:4)
1
G (·) be a fixed set of functions of w to subsets of{1(cid:4)(cid:5)(cid:5)(cid:5)(cid:4)K }such that f(·;w) does not
N N i
dependong foranyk∈/G(w).Supposethecomponentsofg arejointlyindependentconk i
ditionallyon w,and Var [z˜ |w]≤U ,uniformlyacross N and i=1(cid:4)(cid:5)(cid:5)(cid:5)(cid:4)N.ThenWMD
(cid:3) PN i z
holdsifE [ 1 N 1[G(w)∩G (w)(cid:3)=∅]]→0.
PN N2 i(cid:4)j=1 i j
PROPOSITION 6—First Stage and Concentrated Individual Exposure: Suppose x
i
=
πz +u with u ⊥⊥g|w,forall i and π (cid:3)=0.Supposefurther,conditionally on w,thecomi i i
ponentsofgaremutuallyindependentwithVar [g |w]≥L >0uniformlyacrossN and
k=1(cid:4)(cid:5)(cid:5)(cid:5)(cid:4)K . Moreover, one of three conditio P n N s h k old: (i) al σ l components of g are mutuN
ally independent and E [|∂f ˜ i(g;w) | w|] < ∞, (ii) all components of g have the Bernoulli
PN ∂gk (cid:3) (cid:3)
distribution, or (iii) all f ˜ (·;w) are linear in g. Then if E [1 (E [∂f ˜ i(g;w) |w])2]≥
i (cid:3) PN N i k PN ∂gk
L >0uniformlyacrossN,E [1 xz˜ ]isalsouniformlyboundedawayfromzero(by
|π H | H · I L L ). PN N i i i
HHI σ
APPENDIXD: PROOFS
We dropthe P subscripting ofmoments forall proofsto simplify notation. We again
N
abbreviateweakmutualdependence(Assumption3)asWMD.
PROOFOFPROPOSITION1: ByAssumption1andtheCauchy–Schwarzinequality,
(cid:4) (cid:5) (cid:4)(cid:10) (cid:11) (cid:5)
1 (cid:2) 1 (cid:2) 2 1 (cid:2)
Var z˜ ε =E z˜ ε = E[z˜ z˜ εε ]
N i i N i i N2 i j i j
i i i(cid:4)j
(cid:2) (cid:12) (cid:13) 1
= E E[z˜ z˜ |w]E[εε |w]
N2 i j i j
i(cid:4)j
(cid:2) (cid:12)(cid:9) (cid:9) (cid:14) (cid:12) (cid:13) (cid:12) (cid:13)(cid:13)
≤ 1 E (cid:9)E[z˜ z˜ |w] (cid:9) E ε2|w E ε2|w
N2 i j i j
i(cid:4)j
(cid:4) (cid:5)
(cid:2)(cid:9) (cid:9)
≤U E 1 (cid:9) Cov[z˜ (cid:4)z˜ |w] (cid:9) →0(cid:5) (5)
ε N2 i j
i(cid:4)j
(cid:3)
Whenμ isapproximatedby 1 S z(s) forz(s)=f(g(s);w)andforafinitenumberSof
i S s=1 i i
randomdrawsg(s) fromG(g|w),thesameargumentholdswithavarianceupperbound
thatisatmosttwiceaslarge.Indeed,since
(cid:4)(cid:10)
(cid:2)
(cid:11)(cid:10)
(cid:2)
(cid:11)(cid:9) (cid:5)
1 1 (cid:9)
E z − z(s) z − z(s) (cid:9)w
i S i j S j
s s
(cid:4) (cid:2) (cid:2) (cid:9) (cid:5) (cid:4) (cid:2) (cid:9) (cid:5) (cid:4) (cid:2) (cid:9) (cid:5)
1 1 (cid:9) 1 (cid:9) 1 (cid:9)
=Cov z − z(s)(cid:4)z − z(s)(cid:9)w +E z − z(s)(cid:9)w E z − z(s)(cid:9)w
i S i j S j i S i j S j
s s s s
S+1 S+1
= Cov[z(cid:4)z |w]= Cov[z˜ (cid:4)z˜ |w](cid:4)
S i j S i j

wehave,repeatingthestepsin(5),
(cid:4) (cid:10) (cid:11)(cid:5) (cid:4) (cid:5)
Var 1 (cid:2) ε z − 1 (cid:2) z(s) ≤ S+1 U E 1 (cid:2)(cid:9) (cid:9) Cov[z˜ (cid:4)z˜ |w] (cid:9) (cid:9) →0(cid:5)
N i i S i S ε N2 i j
Q.E.D.
i s i(cid:4)j
(cid:15)
PROOFOFPROPOSITION2: For each N, consider ε= U
ε
/U
z
·ε˜ where (ε˜(cid:4)w) is distributedas (z˜(cid:4)w),andε˜ ⊥g|w.ThenVar[ε]=U Var[z˜ ]/U ≤U .Moreover,
i ε i z ε
(cid:4) (cid:5)
1
(cid:2)
1
(cid:2)N (cid:12) (cid:13)
Var z˜ ε = E E[z˜ z˜ |w]E[εε |w]
N i i N2 i j i j
i i(cid:4)j=1
U 1
(cid:2)N (cid:12) (cid:13)
= ε · E E[z˜ z˜ |w]2
U N2 i j z i(cid:4)j=1
U 1
(cid:2)N (cid:12) (cid:13)
= ε · E Cov[z˜ (cid:4)z˜ |w]2 →0(cid:5)
U N2 i j
z i(cid:4)j=1
(cid:3) (cid:3)
By the Cauchy–Schwarz inequality, 1 N |Cov[z˜ (cid:4)z˜ | w]| ≤ ( 1 N Cov[z˜ (cid:4)z˜ |
N2(cid:3) i(cid:4)j=1 i j N2 (cid:3)i(cid:4)j=1 i j
w]2)0(cid:5)5.AndbyJensen’sinequality,E[ 1 N |Cov[z˜ (cid:4)z˜ |w]|]≤E[( 1 N Cov[z˜ (cid:4)z˜ |
(cid:3) N2 i(cid:4)j=1 i j N2 i(cid:4)j=1 i j
w]2)0(cid:5)5]≤E[ 1 N Cov[z˜ (cid:4)z˜ |w]2]0(cid:5)5→0. Q.E.D.
N2 i(cid:4)j=1 i j
PROOFOFPROPOSITION341: We prove this result by contradiction. Without loss of
generality,supposeK =K isconstantalongtheasymptoticsequence;whenever K (cid:3)→ N N
∞, there is a subsequence of K bounded by some K, and the proof follows for that
N
subsequence without change. Also without loss, we condition on w and suppress the w
notation.Wedenotetheupperboundonthesupportof|g |byU /2andextendthedok g
main of each f ˜ to [−U /2(cid:4)U /2]K preserving its Lipschitz constant, by the Kirszbraun
i g g
theorem.
LetR(x)=min{ (cid:14)x/δ(cid:15)·δ(cid:4)U /2}denotetheupward-roundingfunctionforsomeδ>0.
g
Considerf ˇ (g)=R(f ˜ (R(g )(cid:4)(cid:5)(cid:5)(cid:5)(cid:4)R(g ))),whichroundsboththeshocksandthevalues
i i 1 K
˜
off.Notethat
i
(cid:9) (cid:9) (cid:9) (cid:7) (cid:8)(cid:9) (cid:9) (cid:7) (cid:8) (cid:9)
(cid:9) f ˇ (g)−f ˜ (g) (cid:9)≤(cid:9) f ˇ (g)−f ˜ R(g )(cid:4)(cid:5)(cid:5)(cid:5)(cid:4)R(g ) (cid:9)+(cid:9) f ˜ R(g )(cid:4)(cid:5)(cid:5)(cid:5)(cid:4)R(g ) −f ˜ (g) (cid:9)
i i i i 1 K i 1 K i
√
≤δ+δU K(cid:4)
Lip
where the se√cond inequality uses the Lipschitz condition and (cid:17)g − (R(g
1
)(cid:4)(cid:5)(cid:5)(cid:5)(cid:4)
R(g K ))(cid:17) 2 ≤δ K since|g k −R(g k )|≤δforeachk. √
By the Lipschitz condition, |f ˜ (g ) −f ˜ (g )| ≤U U K for any g (cid:4)g ∈ [−U /2(cid:4)
i A i B Lip g A B √g U /2]K. Since E[f ˜ (g)] = 0 and g ∈ [−U /2(cid:4)U /2]K, this implies |f ˜ (g)| ≤ U U K(cid:4)
g i √ g g √ i Lip g
and,consequently,|f ˇ (g)|≤U U K+δ+δU K.Thus,forallN andi=1(cid:4)(cid:5)(cid:5)(cid:5)(cid:4)N
i Lip g Lip
thereisonlyafinitenumberU ofpossible“rounded”f ˇ (·)functions.Therefore,atleast
R i
NL /U ofobservationsiwithVar[f ˜ (g)]≥L havethesameroundedfunction,andthus
V R i z
41WethankMikhailDektiarevforhelpwiththisproof.
NONRANDOMEXPOSURETOEXOGENOUSSHOCKS 2181
there are at least (NL /U )2 such pairs of observations (i(cid:4)j). For any such pair, since
V R
E[f ˜ (g)−f ˜ (g)]=0,
i j
(cid:12) (cid:13) (cid:12) (cid:13) (cid:12) (cid:13) (cid:12)(cid:7) (cid:8) (cid:13)
2Cov f ˜ (g)(cid:4)f ˜ (g) =Var f ˜ (g) +Var f ˜ (g) −E f ˜ (g)−f ˜ (g) 2
i j i j i j
(cid:12)(cid:7)(cid:9) (cid:9) (cid:9) (cid:9) (cid:9) (cid:9)(cid:8) (cid:13)
≥2L −E (cid:9) f ˜ (g)−f ˇ (g) (cid:9)+(cid:9) f ˇ (g)−f ˇ (g) (cid:9)+(cid:9) f ˜ (g)−f ˇ (g) (cid:9) 2
z i i i j j j
(cid:12)(cid:7) √ √ (cid:8) (cid:13)
≥2L −E δ(1+U K)+0+δ(1+U K) 2 (cid:5)
z Lip Lip
Settingδ= √ Lz√ ,wehaveCov[f ˜ (g)(cid:4)f ˜ (g)]≥ Lz >0and,therefore,
2(1+ULip K) i j 2
(cid:10) (cid:11)
1 (cid:2)N (cid:9) (cid:9) Cov (cid:12) f ˜ (g)(cid:4)f ˜ (g) (cid:13)(cid:9) (cid:9)≥ 1 · NL V 2L z = L2 V L z (cid:3)→0(cid:5)
N2 i j N2 U 2 2U2
i(cid:4)j=1 R R
Thus,weakmutualdependencedoesnothold,establishingthecontradiction. Q.E.D.
To establish Proposition 4, we first state and prove four lemmas. We assume all momentsrelevantforthoselemmasexist.
LEMMA 1: If h: RK →R is weakly increasing and random variables g
1
(cid:4)(cid:5)(cid:5)(cid:5)(cid:4)g
K
are independent, then for any k∈ {1(cid:4)(cid:5)(cid:5)(cid:5)(cid:4)K −1} the conditional expectation E[h(g (cid:4)(cid:5)(cid:5)(cid:5)(cid:4)g ) |
1 K
g (cid:4)(cid:5)(cid:5)(cid:5)g ]isweaklyincreasing.
1 k
PROOF: Fix γ
1
(cid:4)(cid:5)(cid:5)(cid:5)(cid:4)γ
k
and γ
1
(cid:10)(cid:4)(cid:5)(cid:5)(cid:5)(cid:4)γ
k
(cid:10) such that γ
r
(cid:10) ≥ γ
r
for r = 1(cid:4)(cid:5)(cid:5)(cid:5)(cid:4)k, and define
theK×1vectorsg=(γ (cid:4)(cid:5)(cid:5)(cid:5)(cid:4)γ (cid:4)g (cid:4)(cid:5)(cid:5)(cid:5)(cid:4)g ) andg(cid:10)=(γ(cid:10)(cid:4)(cid:5)(cid:5)(cid:5)(cid:4)γ(cid:10)(cid:4)g (cid:4)(cid:5)(cid:5)(cid:5)(cid:4)g ).Note
1 k k+1 K 1 k k+1 K
h(g(cid:10))≥h(g). For r =k+1(cid:4)(cid:5)(cid:5)(cid:5)(cid:4)K, denote the cumulative distribution function of g by
r
G (·).Then
r
(cid:16) (cid:16)
(cid:12) (cid:7) (cid:8)(cid:13) (cid:7) (cid:8)
E h g(cid:10) = ··· h g(cid:10) dG (g )···dG (g )
k+1 k+1 K K
(cid:16) (cid:16)
(cid:12) (cid:13)
≥ ··· h(g)dG (g )···dG (g )=E h(g) (cid:5)
k+1 k+1 K K Q.E.D.
LEMMA 2: For any weakly increasing h (cid:4)h : RK →R, Cov[h (g)(cid:4)h (g)] ≥0 for g =
1 2 1 2
(g (cid:4)(cid:5)(cid:5)(cid:5)(cid:4)g ) withindependentcomponents.
1 K
PROOF: ForK=1,thisiswellknown.TheproofforK>1followsbyinduction.SupposeitistrueforK−1.Thenbythelawoftotalcovariance,
(cid:12) (cid:13) (cid:12) (cid:12) (cid:13)(cid:13) (cid:12) (cid:12) (cid:13) (cid:12) (cid:13)(cid:13)
Cov h (g)(cid:4)h (g) =E Cov h (g)(cid:4)h (g)|g +Cov E h (g)|g (cid:4)E h (g)|g (cid:5)
1 2 1 2 1 1 1 2 1
Thefirsttermistheexpectationofacovarianceoftwomonotone(byLemma1)functions
ofK−1variables.Thesecondterm,againbyLemma1,isacovarianceoftwomonotone
functionsofrandomscalars.Thusbothtermsarenonnegative. Q.E.D.
LEMMA 3: If f
i
(g;w) is weakly monotone in g for all i and components of g are jointly
independentconditionallyonw,th(cid:3)enCov[z˜
i
(cid:4)z˜
j
|w]≥0foralli andj.Furthermore,WMD
simplifiestoVar[z¯]→0forz¯ = 1 z˜ .
N i i

PROOF: Applying Lemma 2 to z˜
i
= f
i
(g;w) − E[f
i
(g;w) | w] and z˜
j
= f
j
(g;w) −
E[f (g;w)|w] (or their negations, if f(g;w) is weakly decreasing) and conditioning on
j i
weverywhere,weobtainCov[z˜ (cid:4)z˜ |w]≥0.Thus,WMDsimplifiesto
i j
(cid:4) (cid:5) (cid:4) (cid:5)
(cid:2)(cid:9) (cid:9) (cid:2)
E 1 (cid:9) Cov[z˜ (cid:4)z˜ |w] (cid:9) =E 1 Cov[z˜ (cid:4)z˜ |w]
N2 i j N2 i j
i(cid:4)j i(cid:4)j
(cid:4) (cid:4) (cid:2) (cid:9) (cid:5)(cid:5) (cid:4) (cid:2) (cid:5)
1 (cid:9) 1
=E Var z˜ (cid:9)w =Var z˜ →0(cid:4)
N i N i
i i
(cid:3)
where the second line rearranges terms and the third line follows by E[1 z˜ |w]=0.
N i i
Q.E.D.
LEMMA 4: Suppose g=(g
1
(cid:4)(cid:5)(cid:5)(cid:5)(cid:4)g
K
) is jointly independent with σ
k
2 ≡Var[g
k
] and consider a scalar function h on the support of g. Then if (i) all components of g are normally
distributedandE[|∂h(g)|]<∞or(ii)allcomponentsofghavetheBernoullidistribution,
∂gk
(cid:10) (cid:4) (cid:5)(cid:11) (cid:4)(cid:10) (cid:11) (cid:5)
(cid:2) ∂h(g) 2 (cid:12) (cid:13) (cid:2) ∂h(g) 2
σ2 E ≤Var h(g) ≤ σ2E (cid:4) (6)
k ∂g k ∂g
k k
k k
with ∂h definedintheBernoullicaseasinProposition4.Further,(iii)ifhislinear,(6)holds
∂gk
withequalities,regardlessofthedistributionsofthecomponentsofg.
PROOF: For part (i), the lower bound is established by Cacoullos (1982, Proposition3.7),andtheupperboundonVar[h(g)]isestablishedbyChen(1982,Corollary3.2).
For part (ii), the lower bound follows from restricting the results for binomial distributions in Cacoullos and Papathanasiou (1989, p. 355), and the upper bound is similarly a
specialcaseoftheresultinCacoullosandPapathanasiou(1985,p.183).Part(iii)follows
triviallyfromthefactthat∂h/∂g isnonstochastic. Q.E.D.
k
PROOFOFPROPOSITION4: By Lemma 3, WMD is equivalent to Var[f ¯ (g;w)] =
E[Var[f ¯ (g;w) |w]]→0. Applying Lemma 4 conditionally on w and using the bounds
onVar[g |w],
k
E (cid:4) (cid:2) L (cid:10) E (cid:4) ∂f ¯ (g;w) (cid:9) (cid:9) (cid:9)w (cid:5)(cid:11) 2 (cid:5) ≤Var (cid:12) f ¯ (g;w) (cid:13) ≤E (cid:4) (cid:2) U E (cid:4)(cid:10) ∂f ¯ (g;w) (cid:11) 2 (cid:9) (cid:9) (cid:9)w (cid:5)(cid:5) (cid:5)
σ ∂g σ ∂g
k k
k k
The upper bound, the law of iterated expectations, and U > 0 imply that if
(cid:3) σ
E[ (∂f ¯ (g;w))2] → 0, Var[f ¯ (g;w)] → 0, and thus WMD holds. The lower bound and
k ∂gk (cid:3)
L >0 imply that if WMD holds, and thus Var[f ¯ (g;w)]→0, we have E[ (E[∂f ¯ (g;w) |
σ k ∂gk
w])2]→0. Q.E.D.
PROOFOFPROPOSITION5: ForanyN andfixedw¯ inthesupportofwandforiandj,
suchthatG(w¯)∩G (w¯)=∅wehavez˜ ⊥⊥z˜ |w=w¯ becausef andf arefunctionsoftwo
i j i j i j
nonoverlappingsubvectorsofg,thecomponentsofwhichareconditionallyindependent.
NONRANDOMEXPOSURETOEXOGENOUSSHOCKS 2183
ThusCov[z˜ (cid:4)z˜ |w=w¯]=0forsuch (i(cid:4)j) pairs,andweobtain
i j
(cid:2)(cid:9) (cid:9) (cid:2) (cid:12) (cid:13) (cid:12)(cid:9) (cid:9)(cid:13)
1 (cid:9) Cov[z˜ (cid:4)z˜ |w] (cid:9)= 1 1 G(w)∩G (w)(cid:3)=∅ E (cid:9) Cov[z˜ (cid:4)z˜ |w] (cid:9)
N2 i j N2 i j i j
i(cid:4)j i(cid:4)j
(cid:2) (cid:12) (cid:13) (cid:12) (cid:14) (cid:13)
1
≤ 1 G(w)∩G (w)(cid:3)=∅ E Var[z˜ |w]Var[z˜ |w]
N2 i j i j
i(cid:4)j
(cid:2) (cid:12) (cid:13)
1
≤U · 1 G(w)∩G (w)(cid:3)=∅
z N2 i j
i(cid:4)j
(cid:3)
and,therefore,E[ 1 |Cov[z˜ (cid:4)z˜ |w]|]→0. Q.E.D.
N2 i(cid:4)j i j
(cid:3)
PRO(cid:3)OFOFPROPOSI(cid:3)TION6: By the law of iterated expectations, E[
N
1
i
x
i
z˜
i
] =
πE[1 z˜2]=πE[1 Var[z˜ |w]]. The result then follows directly from Lemma 4 ap- N i i N i i
pliedtoeachf ˜ (g;w):
i
1 (cid:2) 1 (cid:2)(cid:2) (cid:10) (cid:4) ∂f ˜ (g;w) (cid:9) (cid:9) (cid:5)(cid:11) 2
Var[z˜ |w]≥ Var[g |w] E i (cid:9)w
N i N k ∂g
k i i k
1 (cid:2)(cid:2) (cid:10) (cid:4) ∂f ˜ (g;w) (cid:9) (cid:9) (cid:5)(cid:11) 2
≥L · E i (cid:9)w (cid:4)
σ N ∂g
k
i k
(cid:3)
andthus|E[1 xz˜ ]|≥|π|·L L . Q.E.D. N i i i σ HHI
REFERENCES
ABADIE,ALBERTO(2003):“SemiparametricInstrumentalVariableEstimationofTreatmentResponseModels,”JournalofEconometrics,113,231–263.[2165]
ABADIE,ALBERTO,ANDGUIDOW.IMBENS(2016):“MatchingontheEstimatedPropensityScore,”Econometrica,84,781–807.[2165]
ABADIE,ALBERTO,SUSANATHEY,GUIDOW.IMBENS,ANDJEFFREYM.WOOLDRIDGE(2020):“SamplingBasedvs.Design-BasedUncertaintyinRegressionAnalysis,”Econometrica,88,265–296.[2163]
ABDULKADIROGLU,ATILA,JOSHUAD.ANGRIST,YUSUKENARITA,ANDPARAGA.PATHAK(2017):“Research
Design Meets Market Design: Using Centralized Assignment for Impact Evaluation,” Econometrica, 85,
1373–1432.[2166]
ADÃO, RODRIGO, MICHAL KOLESÁR, AND EDUARDO MORALES (2019): “Shift-Share Designs: Theory and
Inference,”QuarterlyJournalofEconomics,134,1949–2010.[2169]
AHLFELDT,GABRIELM.,ANDARNEFEDDERSEN(2018):“FromPeripherytoCore:MeasuringAgglomeration
EffectsUsingHigh-SpeedRail,”JournalofEconomicGeography,18,355–390.[2175]
ARONOW,PETERM.,ANDCYRUSSAMII(2017):“EstimatingAverageCausalEffectsUnderGeneralInterference,WithApplicationtoaSocialNetworkExperiment,”AnnalsofAppliedStatistics,11,1912–1947.[2157,
2159]
ATHEY,SUSAN,ANDGUIDOW.IMBENS(2022):“Design-BasedAnalysisinDifference-in-DifferencesSettings
WithStaggeredAdoption,”JournalofEconometrics,226,62–79.[2157,2164]
ATHEY,SUSAN,MOHSENBAYATI,NIKOLAYDOUDCHENKO,GUIDOW.IMBENS,ANDKHASHAYARKHOSRAVI
(2021): “Matrix Completion Methods for Causal Panel Data Models,” Journal of the American Statistical
Association,116,1716–1730.[2157]
BORUSYAK,KIRILL,ANDPETERHULL(2021):“Non-RandomExposuretoExogenousShocks:Theoryand
Applications,”NBERWorkingPaper27845.[2155,2158,2176]
BORUSYAK,KIRILL,PETERHULL,ANDXAVIERJARAVEL(2022):“Quasi-ExperimentalShift-ShareResearch
Designs,”ReviewofEconomicStudies,89,181–213.[2157,2168]

BRINKHOFF,THOMAS(2018):“CityPopulation,”,http://www.citypopulation.de.[2177]
CACOULLOS,THEOPHILOS(1982):“OnUpperandLowerBoundsfortheVarianceofaFunctionofaRandom
Variable,”TheAnnalsofProbability,10,799–809.[2182]
CACOULLOS, THEOPHILOS, AND VASILLIS PAPATHANASIOU (1985): “On Upper Bounds for the Variance of
FunctionsofRandomVariables,”StatisticsandProbabilityLetters,3,175–184.[2182]
(1989):“CharacterizationsofDistributionsbyVarianceBounds,”StatisticsandProbabilityLetters,7,
351–356.[2182]
CARVALHO,VASCOM.,MAKOTONIREI,YUKIKOU.SAITO,ANDALIREZATAHBAZ-SALEHI(2021):“Supply
ChainDisruptions:EvidenceFromtheGreatEastJapanEarthquake,”QuarterlyJournalofEconomics,136,
1255–1321.[2161,2166]
CATTANEO,MATIASD.,BRIGHAMR.FRANDSEN,ANDROCÍOTITIUNIK(2015):“RandomizationInferencein
theRegressionDiscontinuityDesign:AnApplicationtoPartyAdvantagesintheU.S.Senate,”Journalof
CausalInference,3,1–24.[2166]
CHEN,LOUISH.Y.(1982):“AnInequalityfortheMultivariateNormalDistribution,”JournalofMultivariate
Analysis,12,306–315.[2182]
CHINA RAILWAY YEARBOOK EDITORIAL BOARD (2001–2013): “China Railway Yearbook,” https://oversea.
cnki.net/KNavi/YearbookDetail?pcode=CYFD&pykm=YZGTD&.[2176]
CHINA STATISTICS PRESS (2000–2017): “China City Statistical Yearbook,” https://cnki.net/KNavi/
YearbookDetail?pcode=CYFD&pykm=YZGCA.[2177]
CONLEY,TIMOTHYG.(1999):“GMMEstimationWithCrossSectionalDependence,”JournalofEconometrics,92,1–45.[2171,2174]
CURRIE,JANET,ANDJONATHANGRUBER(1996):“HealthInsuranceEligibility,UtilizationofMedicalCare,
andChildHealth,”TheQuarterlyJournalofEconomics,111,431–466.[2155,2158,2159,2162]
DECHAISEMARTIN,CLÉMENT,ANDLUCBEHAGHEL(2020):“EstimatingtheEffectofTreatmentsAllocated
byRandomizedWaitingLists,”Econometrica,88,1453–1477.[2157]
DECHAISEMARTIN,CLÉMENT,ANDXAVIERD’HAULTFŒUILLE(2020):“Two-WayFixedEffectsEstimators
WithHeterogeneousTreatmentEffects,”AmericanEconomicReview,110,2964–2996.[2157]
DONALDSON,DAVE(2018):“RailroadsoftheRaj:EstimatingtheImpactofTransportationInfrastructure,”
AmericanEconomicReview,108,899–934.[2175]
DONALDSON,DAVE,ANDRICHARDHORNBECK(2016):“RailroadsandAmericanEconomicGrowth:A“MarketAccess”Approach,”QuarterlyJournalofEconomics,131,799–858.[2155,2158,2159]
FISHER,RONALDA.(1935):TheDesignofExperiments.Oliver&Boyd.[2169]
GRUBER,JONATHAN(2003):“Medicaid,”inMeans-TestedTransferProgramsintheUnitedStates.Universityof
ChicagoPress,15–78.[2162]
HODGES,JONATHANL.,ANDERICHL.LEHMANN(1963):“EstimatesofLocationBasedonRankTests,”The
AnnalsofMathematicalStatistics,34,598–611.[2169]
IMBENS, GUIDO W. (2000): “The Role of the Propensity Score in Estimating Dose-Response Functions,”
Biometrika,87,706–710.[2165]
IMBENS,GUIDOW.,ANDJOSHUAD.ANGRIST(1994):“IdentificationandEstimationofLocalAverageTreatmentEffects,”Econometrica,62,467–475.[2170]
KING,GARY,ANDRICHARDNIELSEN(2019):“WhyPropensityScoresShouldNotBeUsedforMatching,”
PoliticalAnalysis,27,435–454.[2165]
LAWRENCE,MARTHA,RICHARDBULLOCK,ANDZIMINGLIU(2019):China’sHigh-SpeedRailDevelopment.
Washington,D.C.:WorldBank.[2171,2176]
LEE,DAVIDS.(2008):“RandomizedExperiments FromNon-RandomSelectioninU.S.HouseElections,”
JournalofEconometrics,142,675–697.[2157,2166]
LEHMANN,ERICHL.,ANDJOSEPHP.ROMANO(2006):TestingStatisticalHypotheses.SpringerScience&BusinessMedia.[2166]
LIN,YATANG(2017):“TravelCostsandUrbanSpecializationPatterns:EvidenceFromChina’sHighSpeed
RailwaySystem,”JournalofUrbanEconomics,98,98–123.[2171,2176]
MA,DAMIEN(2011):“China’sLong,BumpyRoadtoHigh-SpeedRail,”TheAltantic.[2171]
MADESTAM,ANDREAS,DANIELSHOAG,STANVEUGER,ANDDAVIDYANAGIZAWA-DROTT(2013):“DoPoliticalProtestsMatter?EvidenceFromtheTeaPartyMovement,”QuarterlyJournalofEconomics,128,1633–
1685.[2166]
MIGUEL,EDWARD,ANDMICHAELKREMER(2004):“Worms:IdentifyingImpactsonEducationandHealth
inthePresenceofTreatmentExternalities,”Econometrica,72,159–217.[2155,2158]
NEYMAN,JERZY(1923):“OntheApplicationofProbabilityTheorytoAgriculturalExperiments.Essayon
Principles,”Ann.AgriculturalSciences,1–51.[2157]
NONRANDOMEXPOSURETOEXOGENOUSSHOCKS 2185
OCHAREGIONALOFFICEFORASIAANDTHEPACIFIC(2018):“ProvinceandPrefectureCapitalsofChina,”
https://data.humdata.org/dataset/province-and-prefecture-capitals-of-china.
(2020): “China—Subnational Administrative Boundaries,” https://data.humdata.org/dataset/
cod-ab-chn.[2176]
OLLIVIER,GERALD,RICHARDBULLOCK,YINGJIN,ANDNANYANZHOU(2014):“High-SpeedRailwaysin
China:ALookatTraffic,”ChinaTransportTopics,1–12.[2171]
REDDING,STEPHENJ.,ANDMATTHEWA.TURNER(2015):“TransportationCostsandtheSpatialOrganizationofEconomicActivity,”inHandbookofRegionalandUrbanEconomics.Elsevier,1339–1398.[2175]
REDDING, STEPHEN J., AND ANTHONY J. VENABLES (2004): “Economic Geography and International Inequality,”JournalofInternationalEconomics,62,53–82.[2158]
ROBINS,JAMESM.,STEVEND.MARK,ANDWHITNEYK.NEWEY(1992):“EstimatingExposureEffectsby
ModellingtheExpectationofExposureConditionalonConfounders,”Biometrics,48,479–495.[2157,2165]
ROBINSON, PETER (1988): “Root-N-Consistent Semiparametric Regression,” Econometrica, 56, 931–954.
[2164]
ROSENBAUM,PAULR.(2002):“CovarianceAdjustmentinRandomizedExperimentsandObservationalStudies,”StatisticalScience,17,286–327.[2169]
ROSENBAUM,PAULR.,ANDDONALDB.RUBIN(1983):“TheCentralRoleofthePropensityScoreinObservationalStudiesforCausalEffects,”Biometrika,70,41–55.[2157,2165]
SHAIKH,AZEEM,ANDPANOSTOULIS(2021):“RandomizationTestsinObservationalStudiesWithStaggered
AdoptionofTreatment,”JournaloftheAmericanStatisticalAssociation,116,1835–1848.[2157]
WOOLDRIDGE,JEFFREYM.(2015):“ControlFunctionMethodsinAppliedEconometrics,”JournalofHuman
Resources,50,420–445.[2165]
ZHENG,SIQI,ANDMATTHEWE.KAHN(2013):“China’sBulletTrainsFacilitateMarketIntegrationandMitigatetheCostofMegacityGrowth,”ProceedingsoftheNationalAcademyofSciencesoftheUnitedStatesof
America,110,1248–1253.[2171]
Co-editorGuidoImbenshandledthismanuscript.
Manuscriptreceived19January,2021;finalversionaccepted6September,2023;availableonline7September,
2023.
The replication package for this paper is available at https://doi.org/10.5281/zenodo.8286785. The Journal
checked the data and codes included in the package for their ability to reproduce the results in the paper and
approvedonlineappendices.
