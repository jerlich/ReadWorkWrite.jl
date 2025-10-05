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
                       nworkers=Threads.nthreads(), buf=nworkers+2, T=nothing)
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

    @async begin
        for d in remaining_data
            put!(in_ch, rf(d))
        end
        close(in_ch)
    end

    @sync begin
        for wid in 1:nworkers
            Threads.@spawn begin
                for item in in_ch
                    put!(out_ch, wf(item))
                end
            end
        end
    end

    close(out_ch)
    wait(writer)
    return nothing
end

# Mutating variant: push into given vector
function readworkwrite(rf, wf, results::Vector, data; kwargs...)
    readworkwrite(rf, wf, x -> push!(results, x), data; kwargs...)
    return results
end

function workwrite(wf, results::Vector, data; kwargs...)
    readworkwrite((x)->x, wf, x -> push!(results, x), data; kwargs...)
    return results
end


end # module
