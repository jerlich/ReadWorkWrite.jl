# Examples

This directory contains working examples demonstrating ReadWorkWrite.jl usage patterns.

## MCMC Example (`mcmc_example.jl`)

A complete Bayesian analysis pipeline using Turing.jl that demonstrates:

- **Read**: Loading synthetic datasets from JSON files
- **Work**: Running NUTS sampling for Bayesian linear regression (multi-threaded)
- **Write**: Saving posterior summaries and generating trace plots

### Usage

From the `examples/` directory:

```julia
using Pkg
Pkg.activate(".")
Pkg.instantiate()
include("mcmc_example.jl")
```

This will:
1. Generate 4 synthetic linear regression datasets
2. Run MCMC sampling on each dataset in parallel
3. Save posterior summaries and trace plots
4. Clean up temporary files

### Output Files

- `results_*.json`: Posterior parameter estimates
- `traces_*.png`: MCMC trace plots for visual diagnostics

The example demonstrates how ReadWorkWrite.jl handles the common pattern of loading data, running expensive computations (MCMC), and saving results while maintaining thread safety for IO operations.