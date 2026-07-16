# Coding Standards: Julia

These standards apply to all Julia code produced by the Coder agent. Derived from C++ Core Guidelines engineering discipline, adapted for Julia in empirical economics. The coder-critic enforces these rules.

---

## 1. Runtime and Dependencies

- **Julia >= 1.10** (package extensions, improved compilation)
- **`Project.toml` + `Manifest.toml`** committed (built-in package manager)
- Activate: `] activate .` — Instantiate: `] instantiate`

### Core Stack

| Package | Purpose |
|---------|---------|
| `DataFrames` | Panel data manipulation |
| `CSV` | Data I/O |
| `Distributions` | CDFs, quantile functions |
| `StatsBase` | Weighted statistics, ECDF |
| `LinearAlgebra` | Matrix operations |
| `Random` | RNG management |
| `PGFPlotsX` or `CairoMakie` | Figures (LaTeX-native or publication quality) |
| `Distributed` / `ThreadsX` | Parallelization |
| `FixedEffectModels` | Panel regression with high-dimensional FE |

### Preferred Figure Backend

**`PGFPlotsX`** produces native LaTeX/PGF output matching the paper's fonts. `CairoMakie` acceptable for complex layouts.

---

## 2. Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Files | `snake_case.jl` | `estimation.jl` |
| Modules | `PascalCase` | `DistributionalDiD` |
| Functions | `snake_case` | `estimate_att()` |
| Variables | `snake_case` | `n_obs`, `y_grid` |
| Constants | `UPPER_SNAKE_CASE` | `N_BOOT`, `ALPHA` |
| Types / Structs | `PascalCase` | `EstimationResult`, `IndexSet` |
| Type parameters | Single uppercase | `T`, `F` |
| Booleans | `is_`, `has_` prefix | `is_treated`, `has_converged` |
| Mutating functions | `!` suffix | `clamp_cdf!()` |
| Abstract types | `Abstract` prefix | `AbstractLinkFunction` |

---

## 3. Code Style

- **Formatter:** `JuliaFormatter.jl` (run before commit)
- **Line width:** 92 characters
- **Indentation:** 4 spaces (Julia convention)
- **Docstrings:** triple-quoted, Markdown format

---

## 4. Type System

Julia's type system is a major advantage. Use it to prevent bugs at compile time.

### Custom Types for Estimation
```julia
struct IndexQuadruple
    g::Int    # treatment group
    t::Int    # post-treatment period
    h::Int    # control group
    s::Int    # pre-treatment period

    function IndexQuadruple(g, t, h, s)
        s < g || throw(ArgumentError("Pre-period s=$s must precede group g=$g"))
        new(g, t, h, s)
    end
end

struct EstimationResult{T<:AbstractFloat}
    estimate::Vector{T}
    se::Vector{T}
    n_obs::Int
end
```

### Multiple Dispatch for Link Functions
```julia
abstract type AbstractLink end
struct NormalLink <: AbstractLink end
struct LogisticLink <: AbstractLink end

link_fn(::NormalLink, x::AbstractVector) = cdf.(Normal(), x)
link_inv(::NormalLink, p::AbstractVector) = quantile.(Normal(), p)
```

---

## 5. Numerical Discipline

### Float Safety
```julia
const EPS_LINK = 1e-12

function safe_link_inv(link::AbstractLink, p::Vector{Float64})::Vector{Float64}
    p_clamped = clamp.(p, EPS_LINK, 1.0 - EPS_LINK)
    return link_inv(link, p_clamped)
end
```

### In-Place Operations
For performance-critical inner loops (bootstrap), use mutating functions:
```julia
function clamp_cdf!(f::Vector{Float64})
    @inbounds for i in eachindex(f)
        f[i] = clamp(f[i], 0.0, 1.0)
    end
    return f
end
```

### Pre-allocation
```julia
# RIGHT
boot_results = Matrix{Float64}(undef, n_grid, N_BOOT)
for b in 1:N_BOOT
    boot_results[:, b] .= estimate_weighted(...)
end

# WRONG: growing an array
results = Vector{Float64}[]
for b in 1:N_BOOT
    push!(results, estimate_weighted(...))
end
```

### Reproducibility
```julia
# Explicit RNG
using Random
rng = MersenneTwister(SEED)

# For parallel: create independent RNG streams
rngs = [MersenneTwister(SEED + i) for i in 1:nworkers()]
```

---

## 6. Function Design

### Documentation
```julia
"""
    estimate_att(data, idx, link, y_grid)

Estimate ATT for group `idx.g` at time `idx.t`.

# Arguments
- `data::DataFrame`: panel data with columns `:unit_id`, `:group`, `:time`, `:outcome`.
- `idx::IndexQuadruple`: the (g, t, h, s) index.
- `link::AbstractLink`: working CDF.
- `y_grid::Vector{Float64}`: evaluation points.

# Returns
- `EstimationResult` with estimates at `y_grid`.
"""
function estimate_att(
    data::DataFrame,
    idx::IndexQuadruple,
    link::AbstractLink,
    y_grid::Vector{Float64},
)::EstimationResult
    # Implementation
end
```

### Fail Fast
```julia
function ecdf_panel(data::DataFrame, g::Int, t::Int, y_grid::Vector{Float64})
    sub = filter(r -> r.group == g && r.time == t, data)
    isempty(sub) && throw(ArgumentError("No observations for group $g, time $t"))
    outcomes = sub.outcome
    return [mean(outcomes .<= y) for y in y_grid]
end
```

---

## 7. Performance

Julia's advantage is speed. Leverage it:

- **Type-stable functions:** avoid containers with `Any` type
- **`@inbounds`** in hot inner loops after verifying correctness
- **Broadcasting:** `.=` for in-place assignment, `.+` for element-wise
- **Avoid global variables:** pass everything through function arguments
- **`@views`** for array slices to avoid copies
- Profile with `@time`, `@btime` (BenchmarkTools), or `ProfileView`

---

## 8. Parallelism

```julia
using Distributed
addprocs(Sys.CPU_THREADS - 1)
@everywhere using DistributionalDiD

results = pmap(1:N_BOOT) do b
    estimate_weighted(data, weights=boot_weights[:, b], ...)
end
```

Or with threads:
```julia
using ThreadsX
results = ThreadsX.map(1:N_BOOT) do b
    estimate_weighted(data, weights=boot_weights[:, b], ...)
end
```

---

## 9. Error Handling

- `throw(ArgumentError(...))` for bad inputs
- `throw(ErrorException(...))` for computation failures
- Inner constructors validate invariants (see IndexQuadruple above)
- Check for `NaN` / `Inf`:
```julia
any(isnan, estimates) && error("NaN in estimates for group $(idx.g), time $(idx.t)")
any(isinf, estimates) && error("Inf in estimates for group $(idx.g), time $(idx.t)")
```

---

## 10. Prohibited Patterns

| Pattern | Reason | Replacement |
|---------|--------|-------------|
| `cd()` | Breaks portability | `joinpath(@__DIR__, ...)` |
| Hardcoded paths | Breaks portability | `joinpath` relative to project |
| Global mutable state | Performance killer, thread-unsafe | Pass through arguments |
| `Any`-typed containers | Type instability, slow | Parameterized types |
| `push!` in hot loops | Growing arrays | Pre-allocate `Matrix{Float64}` |
| Untyped struct fields | Performance loss | Always annotate: `x::Float64` |
| `eval` / `@eval` in runtime | Compilation overhead, fragile | Multiple dispatch |
