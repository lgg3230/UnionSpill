# Coding Standards: Python

These standards apply to all Python code produced by the Coder agent. Derived from C++ Core Guidelines engineering discipline, adapted for Python in empirical economics. The coder-critic enforces these rules.

---

## 1. Runtime and Dependencies

- **Python >= 3.11** (`tomllib`, improved error messages, `ExceptionGroup`)
- **`conda`** (preferred) or **`venv`** for environments
- `environment.yml` or `requirements.txt` committed, versions pinned
- No `pip install` inside scripts

### Core Stack

| Package | Purpose |
|---------|---------|
| `numpy` | Array operations, linear algebra |
| `scipy` | Statistical distributions, optimization |
| `pandas` | Panel data manipulation |
| `matplotlib` | All figures |
| `joblib` | Parallel bootstrap/simulation |
| `statsmodels` | Auxiliary regression tools |
| `linearmodels` | Panel models, IV, fixed effects |

### Prohibited

| Package | Reason | Replacement |
|---------|--------|-------------|
| `sklearn` for inference | Not designed for causal inference | Custom or `statsmodels` |
| `plotly` / `seaborn` for paper figures | PDF output issues, non-standard for econ | `matplotlib` |

---

## 2. Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Files / modules | `snake_case.py` | `estimation.py` |
| Functions | `snake_case` | `estimate_att()` |
| Variables | `snake_case` | `n_obs`, `y_grid` |
| Constants | `UPPER_SNAKE_CASE` | `N_BOOT`, `ALPHA` |
| Classes | `PascalCase` | `EstimationResult` |
| Type aliases | `PascalCase` | `LinkFunction` |
| Booleans | `is_`, `has_` prefix | `is_treated`, `has_converged` |
| Private helpers | `_leading_underscore` | `_validate_index()` |

---

## 3. Code Style

- **Formatter:** `black` (mandatory, run before commit)
- **Linter:** `ruff` (mandatory, zero warnings)
- **Import order:** `isort` (stdlib → third-party → local)
- **Line width:** 88 characters (Black default)
- **Docstrings:** NumPy style
- **Type hints:** required on all function signatures

```python
from typing import Callable
import numpy as np
from numpy.typing import NDArray

FloatArray = NDArray[np.float64]
LinkFunction = Callable[[FloatArray], FloatArray]

def estimate_att(
    data: pd.DataFrame,
    g: int,
    t: int,
    *,
    weights: FloatArray | None = None,
) -> dict[str, FloatArray | int]:
    ...
```

---

## 4. Numerical Discipline

### NumPy Discipline
- All numerical computation through NumPy arrays, never Python lists
- Use `np.float64` explicitly
- `np.sum()`, `np.min()`, `np.max()` — never Python builtins on arrays

### Float Safety
```python
def safe_link_inv(
    p: FloatArray, link_inv: LinkFunction, eps: float = 1e-12
) -> FloatArray:
    """Apply inverse link with boundary clamping."""
    p_clamped = np.clip(p, eps, 1.0 - eps)
    return link_inv(p_clamped)
```

### CDF Monotonicity
```python
def enforce_monotone(f: FloatArray) -> FloatArray:
    """Enforce non-decreasing constraint on CDF values."""
    return np.maximum.accumulate(f)
```

### Reproducibility
```python
# RIGHT: explicit RNG object
rng = np.random.default_rng(seed=SEED)
weights = rng.exponential(scale=1.0, size=(N, N_BOOT))

# WRONG: global state
np.random.seed(42)
weights = np.random.exponential(1.0, size=(N, N_BOOT))
```

### Pre-allocation
```python
# RIGHT
boot_results = np.empty((n_grid, N_BOOT), dtype=np.float64)
for b in range(N_BOOT):
    boot_results[:, b] = estimate_weighted(...)

# WRONG: growing a list
results = []
for b in range(N_BOOT):
    results.append(estimate_weighted(...))
```

---

## 5. Function Design

### Consistent API
```python
def estimate_att(
    data: pd.DataFrame,
    g: int,
    t: int,
    *,
    link_fn: LinkFunction = scipy.stats.norm.cdf,
    link_inv: LinkFunction = scipy.stats.norm.ppf,
    y_grid: FloatArray,
    weights: FloatArray | None = None,
) -> dict[str, FloatArray | int]:
    """Estimate ATT for group g at time t.

    Parameters
    ----------
    data : pd.DataFrame
        Panel data with columns: unit_id, group, time, outcome.
    ...

    Returns
    -------
    dict
        Keys: 'estimate', 'se', 'n_obs'.
    """
```

### Fail Fast
```python
def ecdf_panel(data: pd.DataFrame, g: int, t: int, y_grid: FloatArray) -> FloatArray:
    mask = (data["group"] == g) & (data["time"] == t)
    outcomes = data.loc[mask, "outcome"].to_numpy()
    if len(outcomes) == 0:
        raise ValueError(f"No observations for group {g}, time {t}")
    return np.array([np.mean(outcomes <= y) for y in y_grid])
```

---

## 6. Parallelism

```python
from joblib import Parallel, delayed

results = Parallel(n_jobs=-1)(
    delayed(estimate_weighted)(data, weights=boot_weights[:, b], ...)
    for b in range(N_BOOT)
)
```

Pass `rng` objects or pre-generated seeds — never rely on global state for parallel work.

---

## 7. Error Handling

- Raise `ValueError` for bad inputs, `RuntimeError` for computation failures
- Never return `None` silently on failure
- Check for `np.nan` / `np.inf` after numerical operations:
```python
if np.any(np.isnan(estimates)) or np.any(np.isinf(estimates)):
    raise RuntimeError(f"NaN/Inf in estimates for group {g}, time {t}")
```

---

## 8. Prohibited Patterns

| Pattern | Reason | Replacement |
|---------|--------|-------------|
| `os.chdir()` | Breaks portability | `pathlib.Path` relative to project root |
| Hardcoded paths | Breaks portability | `pathlib.Path` or config module |
| `from module import *` | Namespace pollution | Explicit imports |
| Python `sum/min/max` on arrays | Slow, wrong semantics | `np.sum`, `np.min`, `np.max` |
| `np.random.seed()` global state | Not thread-safe, not parallel-safe | `np.random.default_rng(seed)` |
| Growing lists in loops | O(n²) for large n | Pre-allocate `np.empty()` |
| `except:` bare | Swallows all errors | `except SpecificError:` |
| Mutable default arguments | Shared state bug | `None` default + create inside |
