"""
    readworkwrite(rf, wf, wrf, data; nworkers=Threads.nthreads(), buf=nworkers+2)

Run a pipeline:
  - `rf(d)` → produces work item from input element
  - `wf(item)` → transforms work item
  - `wrf(result)` → consumes the transformed result

Data flows through channels with backpressure, up to `buf` in-flight items.
"""# General form: explicit writer
function readworkwrite(rf, wf, wrf::Function, data;
                       nworkers=Threads.nthreads(), buf=nworkers+2)
    in_ch  = Channel{Any}(buf)
    out_ch = Channel{Any}(buf)

    writer = @async begin
        for out in out_ch
            wrf(out)
        end
    end

    @async begin
        for d in data
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
function readworkwrite(rf, wf, results::Vector, data;
                       nworkers=Threads.nthreads(), buf=nworkers+2)
    readworkwrite(rf, wf, x -> push!(results, x), data;
                  nworkers=nworkers, buf=buf)
    return results
end

function workwrite(wf, results::Vector, data;
                       nworkers=Threads.nthreads(), buf=nworkers+2)
    readworkwrite((x)->x, wf, x -> push!(results, x), data;
                  nworkers=nworkers, buf=buf)
    return results
end
