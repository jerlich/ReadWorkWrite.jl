module ReadWorkWrite

export readworkwrite, workwrite
"""
    readworkwrite(rf, wf, wrf, data; nworkers=Threads.nthreads(), buf=nworkers+2)

Run a pipeline:
  - `rf(d)` → produces work item from input element
  - `wf(item)` → transforms work item
  - `wrf(result)` → consumes the transformed result

Data flows through channels with backpressure, up to `buf` in-flight items.
"""# General form: explicit writer
function readworkwrite(rf, wf, wrf::Function, data;
                       nworkers=Threads.nthreads(), buf=nworkers+2, T=nothing, 
                       return_on_completion=true)
    # Type inference from first element
    if T === nothing
        first_elem = first(data)
        first_read = rf(first_elem)
        first_work = wf(first_read)
        InType = typeof(first_read)
        OutType = typeof(first_work)
        in_ch = Channel{InType}(buf)
        out_ch = Channel{OutType}(buf)
        
        # Put the already-computed first work item
        put!(out_ch, first_work)
        remaining_data = Iterators.drop(data, 1)
    else
        in_ch = Channel{T}(buf)
        out_ch = Channel{T}(buf)
        remaining_data = data
    end

    writer = @async begin
        for out in out_ch
            wrf(out)
        end
    end

    reader = @async begin
        try
            for d in remaining_data
                put!(in_ch, rf(d))
            end
        catch e
            @debug e
            if e isa MethodError || e isa TypeError
                throw(ArgumentError("Type mismatch detected. Your reader `rf` produces inconsistent types. Try using T=Any for heterogeneous data processing."))
            else
                rethrow(e)
            end
        finally
            close(in_ch)
        end
    end

    workers = [Threads.@spawn begin
        try
            for item in in_ch
                put!(out_ch, wf(item))
            end
        catch e
            @debug e
            if e isa MethodError || e isa TypeError
                throw(ArgumentError("Type mismatch detected in work function. Your pipeline produces inconsistent types. Try using T=Any for heterogeneous data processing."))
            else
                rethrow(e)
            end
        end
    end for _ in 1:nworkers]
    
    if return_on_completion
        try
            wait(reader)  # Wait for reader to finish
            wait.(workers)  # Wait for all worker tasks
            close(out_ch)   # Close output channel after workers finish
            wait(writer)    # Now writer can finish
        catch e
            if e isa TaskFailedException
                # Unwrap the nested exception for cleaner error messages
                rethrow(e.task.exception)
            else
                rethrow(e)
            end
        end
        return nothing
    else
        return (;in_ch, out_ch, writer, workers, reader)
    end
end

# Mutating variant: push into given vector
function readworkwrite(rf, wf, results::Vector, data; kwargs...)
    readworkwrite(rf, wf, x -> push!(results, x), data; kwargs...)
end

function workwrite(wf, results::Vector, data; kwargs...)
    readworkwrite((x)->x, wf, x -> push!(results, x), data; kwargs...)
end


end # module
