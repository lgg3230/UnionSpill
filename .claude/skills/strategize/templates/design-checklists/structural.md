# Design Checklist: Structural Estimation

## Justification
- [ ] **Why structural?** What question requires a model that reduced-form can't answer?
  - Counterfactual policy simulation
  - Welfare analysis (consumer/producer/total surplus)
  - Out-of-sample prediction
  - Decomposing multiple channels
  - Parameter heterogeneity
- [ ] **What does the model buy you?** Be specific about the value-added over reduced-form.

## Model Environment
- [ ] **Agents:** Who are the decision-makers? (consumers, firms, workers, government)
- [ ] **Timing:** Static or dynamic? If dynamic, finite or infinite horizon?
- [ ] **Information:** Complete or incomplete? Symmetric or asymmetric?
- [ ] **Market structure:** Perfect competition, monopolistic competition, oligopoly, monopsony
- [ ] **Key friction or mechanism:** What economic force drives the results?
- [ ] **State variables:** What characterizes the state?
- [ ] **Equilibrium concept:** Nash, competitive, Walrasian, Bayesian Nash, MPE

## Decision Problem
- [ ] **Objective function:** utility, profit, expected payoff
- [ ] **Choice variables:** what agents choose
- [ ] **Constraints:** budget, technology, information, time
- [ ] **Solution method:** analytical, numerical (VFI, PFI, EGM), computational

## Identification of Structural Parameters
For each key parameter:
- [ ] **Which moment(s) or variation in the data identifies it?**
- [ ] **Why is that variation informative?** (economic intuition)
- [ ] **What happens if that variation is weak or contaminated?**

Common identification approaches:
- Demand estimation (BLP): price variation from cost shifters or Hausman instruments
- Dynamic models: exclusion restrictions across periods, renewal assumptions
- Entry/exit models: variation in market size, entry costs
- Matching models: variation in match-specific productivity
- General equilibrium: calibration targets + estimated parameters

## Estimation Method
- [ ] **Which method and why?**

| Method | When to Use | Key Requirement |
|--------|-------------|-----------------|
| MLE | Full likelihood tractable | Distributional assumptions stated |
| GMM | Moment conditions available, likelihood intractable | Weighting matrix choice, overid test |
| Simulated Method of Moments | Likelihood intractable, simulation feasible | N simulation draws, seed documented |
| Indirect Inference | Complex model, simple auxiliary model | Binding function specified |
| Bayesian (MCMC) | Prior information available, uncertainty quantification | Priors documented and justified |
| Calibration | Some parameters not estimable | Targets and sources for each calibrated value |

## Computational Details
- [ ] Multiple starting values for optimization (document number and range)
- [ ] Convergence criterion and algorithm (BFGS, Nelder-Mead, etc.)
- [ ] Inner/outer loop structure (if applicable, e.g., BLP)
- [ ] Computation time estimate
- [ ] Parallelization strategy

## Model Validation
- [ ] **In-sample fit:** predicted vs. actual moments (not used in estimation)
- [ ] **Out-of-sample fit:** held-out sample, different time period, different market
- [ ] **Reduced-form consistency:** do model predictions match reduced-form evidence?
- [ ] **Overidentification test:** if more moments than parameters

## Counterfactual Design
- [ ] What policy or counterfactual scenarios to simulate?
- [ ] Welfare metric: consumer surplus, total surplus, compensating variation
- [ ] Distributional analysis: who wins, who loses
- [ ] Comparison to naive (non-structural) policy evaluation
- [ ] Sensitivity of counterfactuals to parameter values (vary +/- 1 SE)

## Robustness Checks
- [ ] Alternative functional forms (e.g., utility specification)
- [ ] Alternative distributional assumptions
- [ ] Alternative estimation method (MLE vs. GMM)
- [ ] Subsample stability (estimate on subsets, check parameter stability)
- [ ] Sensitivity of counterfactuals to parameter uncertainty
- [ ] Comparison to reduced-form (if possible)
- [ ] Monte Carlo study of estimator properties (if novel method)

## Referee Objections to Anticipate
- "Your functional form drives the results"
- "Your identification is coming from [specific variation]"
- "The model is too simple / too complex"
- "Counterfactuals require out-of-sample extrapolation"
- "Why not just do reduced-form?"
