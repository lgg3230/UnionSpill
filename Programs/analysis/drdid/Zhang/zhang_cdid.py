"""
Zhang (2026, Econometrics Journal) continuous DiD with DML: the panel estimator
`cdid_panel` from the author's code (zhang_drdid_cont.py, kept unchanged next to
this file), as an importable module with three minimal changes:

  1. Reproducibility: the bootstrap multipliers come from the caller (`mp`), drawn
     once from a seeded generator. The original drew them with an unseeded
     np.random inside every call.
  2. Same multipliers at every dose d: the caller passes one `mp` for the whole
     grid. The original drew new multipliers for each d, which makes the sup-t
     uniform band treat the doses as independent.
  3. Speed only (and 4. below): the propensity score and the outcome regression do not depend on
     d, so they are fitted once per fold and reused across the grid (`cache`).
     Every forest has a fixed random_state, so this reproduces the original
     numbers exactly.

  4. Each forest runs single-threaded (see default_estimators), so repeated runs
     are byte-identical.

Everything else (score, kernel, variance, multiplier bootstrap, estimators) is the
author's. Known issues left as they are (see Programs/analysis/drdid/README.md):
the outcome model is fitted on all units with a D=0 indicator rather than on
controls only; the bootstrap perturbs the raw score without the density
correction term; P(D=0|X) is clipped only at 1e-6.
"""

import os
os.environ["OMP_NUM_THREADS"] = "1"
os.environ["MKL_NUM_THREADS"] = "1"
os.environ["OPENBLAS_NUM_THREADS"] = "1"
os.environ["NUMEXPR_NUM_THREADS"] = "1"

from copy import deepcopy

import numpy as np
from joblib import Parallel, delayed
from scipy.stats import norm
from sklearn.calibration import CalibratedClassifierCV
from sklearn.ensemble import RandomForestClassifier, RandomForestRegressor
from sklearn.model_selection import KFold


def default_estimators():
    """The nuisance estimators of the author's empirical application, single-threaded.

    The author used n_jobs=5 / 2. A multithreaded forest sums its trees'
    predictions in thread-completion order, which changes the last bits from run
    to run; folds already run in parallel (joblib), so each forest runs on one
    thread. Estimates are otherwise identical.
    """
    return {
        'propensity': CalibratedClassifierCV(
            estimator=RandomForestClassifier(max_depth=20, min_samples_leaf=5, n_estimators=200, random_state=923),
            cv=5,
            n_jobs=1
        ),
        'outcome': RandomForestRegressor(max_depth=20, min_samples_leaf=5, n_estimators=200, n_jobs=1, random_state=923),
        'condens': RandomForestRegressor(max_depth=20, min_samples_leaf=5, n_estimators=200, n_jobs=1, random_state=923),
    }


def multipliers(n, B, seed):
    """Gaussian multipliers with E = Var = 1, shared by every d of a grid."""
    rng = np.random.default_rng(seed)
    return [rng.normal(1, 1, n) for _ in range(B)]


def cdid_panel(Y1, Y0, D, nD, X, d, v, h, B, estimators, mp, cache=None):
    """
    Estimate the Average Treatment Effect on the Treated (ATT) using repeated outcomes (panel) methods
    and implement multiplier bootstrap for standard errors.

    Parameters:
    Y1 (array-like): Outcome post-treatment.
    Y0 (array-like): Outcome pre-treatment.
    D (array-like): Treatment variable (D=0 for control, D=d for treated).
    nD (array-like): Indicator for the control group (1 if D=0, 0 otherwise).
    X (pd.DataFrame or array-like): Covariates.
    d (float): Specific treatment intensity to learn the ATT for.
    v (int): Number of folds for cross-fitting.
    h (float): Undersmooth kernel bandwidth, e.g., np.around(n**(-1/4)).
    B (int): Number of bootstrap samples.
    estimators (dict): Dictionary specifying estimators for 'propensity', 'outcome', and 'condens'.
    mp (list): B multiplier vectors of length len(Y1), from `multipliers` (CHANGED: was drawn here).
    cache (dict or None): fold-level propensity and outcome predictions, filled on the first
        call and reused for later d (CHANGED: speed only).

    Returns:
    tuple: (Mean ATT, Mean variance, List of bootstrap ATTs)
    """

    # Initialize cross-validation
    kf = KFold(n_splits=v, shuffle=True, random_state=923)
    epsilon = 1e-6

    # Define Gaussian kernel function
    def K(h, x, d):
        return norm.pdf((x - d) / h) / h

    # Create cross-validation splits
    xs = [(train_index, test_index) for train_index, test_index in kf.split(X)]

    # CHANGED: d-independent nuisances, fitted once per fold.
    def fit_fold(train_index, test_index):
        trainX, testX = X.iloc[train_index], X.iloc[test_index]
        trainY1, trainY0 = Y1[train_index], Y0[train_index]
        trainnD = nD[train_index]

        # Propensity score P(D=0|X)
        propensity_estimator = deepcopy(estimators['propensity']).fit(trainX, trainnD)
        g = np.clip(propensity_estimator.predict_proba(testX)[:, 1], epsilon, 1)

        # Regression E[(Y1-Y0)|X,D]
        yl = trainY1 - trainY0
        trainX0 = trainX.copy()
        trainX0.insert(0, 'nD', trainnD)  # Include nD variable
        outcome_estimator = deepcopy(estimators['outcome']).fit(trainX0, yl)
        testX0 = testX.copy()
        testX0.insert(0, 'nD', 1)  # Adding a column of 1's for nD = 1{D=0}
        E = outcome_estimator.predict(testX0)
        return g, E

    if cache is None:
        cache = {}
    if 'folds' not in cache:
        cache['folds'] = Parallel(n_jobs=-1)(delayed(fit_fold)(tr, te) for tr, te in xs)

    # Function to compute ATT and variance for each fold
    def compute_fold(k, train_index, test_index):
        trainX, testX = X.iloc[train_index], X.iloc[test_index]
        trainD, testD = D[train_index], D[test_index]
        testY1, testY0 = Y1[test_index], Y0[test_index]
        testnD = nD[test_index]
        g, E = cache['folds'][k]

        # Kernel regression model
        condens_estimator = deepcopy(estimators['condens']).fit(trainX, K(h, trainD, d))
        fh = condens_estimator.predict(testX)

        # Kernel density at f_D(d)
        fd = np.mean(K(h, trainD, d))

        # Step 2: Estimate the i-th ATT inside the cross-fitting using testing sample
        ylt = testY1 - testY0

        # Calculate orthogonal score psi
        psi = (ylt - E) * (K(h, testD, d) * g - testnD * fh) / (fd * g)

        # Calculate ATT for this fold
        theta = np.mean(psi)

        # Asymptotic variance calculation
        sig2 = (psi - (theta * K(h, testD, d)) / fd) ** 2
        VAR = np.mean(sig2)

        return theta, VAR, psi

    # Compute results for each fold and implement multiplier bootstrap
    results = Parallel(n_jobs=-1)(delayed(compute_fold)(k, tr, te) for k, (tr, te) in enumerate(xs))

    att = []
    var = []
    attb = [[] for _ in range(v)]

    for i, (theta, VAR, psi) in enumerate(results):
        att.append(theta)
        var.append(VAR)

        # Multiplier bootstrap
        for b in range(B):
            attb[i].append(np.mean(mp[b][xs[i][1]] * psi))

    # Return mean ATT, mean variance, and bootstrap ATTs
    return np.mean(att), np.mean(var), [np.mean(x) for x in zip(*attb)]


def uniform_band(att, sd, attb, level=95):
    """Sup-t critical value from the bootstrap draws, as in the author's code."""
    B = len(attb[0])
    unif = [max(np.abs(att[i] - attb[i][b]) / sd[i] for i in range(len(att))) for b in range(B)]
    return np.percentile(unif, level)
