using ReadWorkWrite
using Turing
using JSON
using Random
using Distributions
using StatsPlots

# Example: Bayesian linear regression with synthetic data
# This demonstrates the read-work-write pattern for MCMC analysis

# Define a simple Bayesian linear regression model
@model function linear_regression(x, y)
    # Priors
    α ~ Normal(0, 10)
    β ~ Normal(0, 10)
    σ ~ Exponential(1)
    
    # Likelihood
    for i in eachindex(y)
        y[i] ~ Normal(α + β * x[i], σ)
    end
end

# Generate synthetic dataset and save to JSON
function generate_dataset(dataset_id)
    Random.seed!(dataset_id)  # For reproducible results
    n = 50
    true_α = 2.0
    true_β = 1.5
    true_σ = 0.5
    
    x = randn(n)
    y = true_α .+ true_β .* x .+ true_σ .* randn(n)
    
    dataset = Dict(
        "id" => dataset_id,
        "x" => x,
        "y" => y,
        "true_params" => Dict("α" => true_α, "β" => true_β, "σ" => true_σ)
    )
    
    filename = "dataset_$(dataset_id).json"
    open(filename, "w") do f
        JSON.print(f, dataset)
    end
    
    return filename
end

# Read function: load dataset from JSON file
function read_dataset(filename)
    data = JSON.parsefile(filename)
    return (
        id = data["id"],
        x = data["x"],
        y = data["y"],
        true_params = data["true_params"]
    )
end

# Work function: run MCMC sampling
function run_mcmc(data)
    println("Running MCMC for dataset $(data.id)...")
    
    # Set up model
    model = linear_regression(data.x, data.y)
    
    # Sample using NUTS
    chain = sample(model, NUTS(), 1000)
    
    # Extract posterior means
    posterior_means = Dict(
        "α" => mean(chain[:α]),
        "β" => mean(chain[:β]),
        "σ" => mean(chain[:σ])
    )
    
    return (
        id = data.id,
        posterior_means = posterior_means,
        true_params = data.true_params,
        chain = chain
    )
end

# Write function: save results and create plots
function save_results(result)
    println("Saving results for dataset $(result.id)...")
    
    # Save posterior summary
    summary_file = "results_$(result.id).json"
    summary = Dict(
        "id" => result.id,
        "posterior_means" => result.posterior_means,
        "true_params" => result.true_params
    )
    
    open(summary_file, "w") do f
        JSON.print(f, summary)
    end
    
    # Create and save trace plots
    p = plot(result.chain)
    savefig(p, "traces_$(result.id).png")
    
    println("Results saved for dataset $(result.id)")
    return nothing
end

# Main execution
function main()
    println("ReadWorkWrite.jl MCMC Example")
    println("=" ^ 40)
    
    # Generate synthetic datasets
    println("Generating datasets...")
    dataset_files = [generate_dataset(i) for i in 1:4]
    
    # Run the read-work-write pipeline
    println("\nRunning MCMC analysis pipeline...")
    readworkwrite(read_dataset, run_mcmc, save_results, dataset_files)
    
    println("\nAnalysis complete! Check the generated files:")
    println("- dataset_*.json: Original datasets")
    println("- results_*.json: Posterior summaries")
    println("- traces_*.png: MCMC trace plots")
    
    # Clean up dataset files
    for file in dataset_files
        rm(file, force=true)
    end
end

# Run the example
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end