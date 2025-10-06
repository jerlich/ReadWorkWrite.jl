# ReadWorkWrite.jl

A Julia package for efficient parallel processing pipelines that separates IO-bound operations from CPU-intensive work.

## Overview

ReadWorkWrite.jl implements a pattern where:
- **Read**: Single-threaded IO operations (loading files from disk)
- **Work**: Multi-threaded CPU-intensive processing (e.g., MCMC sampling, data analysis)
- **Write**: Single-threaded IO operations (writing to databases, files)

This design prevents threading issues with IO operations while maximizing parallelization for computational work.

## Installation

```julia
using Pkg
Pkg.add("ReadWorkWrite")
```

## Usage

Your functions should compose:

`save_results(process_data(load_data(filename)))`


### Basic Pipeline: Read → Work → Write

```julia
using ReadWorkWrite

# Define your pipeline functions
function load_data(filename)
    # Load data from file (single-threaded)
    return read_some_file(filename)
end

function process_data(data)
    # Expensive computation (multi-threaded)
    # e.g., MCMC sampling, numerical analysis
    return expensive_computation(data)
end

function save_results(results)
    # Write to database (single-threaded)
    write_to_database(results)
end



# Run the pipeline
filenames = ["config1.json", "config2.json", "config3.json"]
readworkwrite(load_data, process_data, save_results, filenames)
```

For complete working examples, see the `examples/` directory.

## API Reference

### `readworkwrite(readfn, workfn, writefn, data; nworkers=Threads.nthreads(), buf=nworkers+2)`

Execute a full read-work-write pipeline.

**Arguments:**
- `readfn`: Function to read/load data (single-threaded)
- `workfn`: Function to process data (multi-threaded)
- `writefn`: Function to write results (single-threaded) or Vector to collect results
- `data`: Iterable of input items
- `nworkers`: Number of worker threads (default: all available threads)
- `buf`: Channel buffer size for backpressure control

### `workwrite(workfn, results, data; nworkers=Threads.nthreads(), buf=nworkers+2)`

Execute work-write pipeline, skipping the read step.

**Arguments:**
- `workfn`: Function to process data (multi-threaded)
- `results`: Vector to collect processed results
- `data`: Iterable of input items to process directly

## Examples

See the `examples/` directory for complete working examples including MCMC analysis with Turing.jl.

For additional usage patterns and advanced features (like early stopping, type inference, and structured data handling), check out `test/runtests.jl`.

## Key Features

- **Thread Safety**: IO operations remain single-threaded to avoid concurrency issues
- **Backpressure Control**: Built-in channel buffering prevents memory overflow
- **Flexible Output**: Write to functions, databases, or collect in vectors
- **Scalable**: Automatically uses available CPU threads for work processing
- **Order Independence**: Handles unordered results from parallel processing

## Design Rationale

Many applications need to:
1. Load data from files/databases (IO-bound, often not thread-safe)
2. Perform expensive computations (CPU-bound, benefits from parallelization)
3. Save results (IO-bound, often requires serialization)

ReadWorkWrite.jl provides a clean abstraction for this common pattern while handling the complexities of thread coordination and backpressure management.

## License

MIT License# Test
