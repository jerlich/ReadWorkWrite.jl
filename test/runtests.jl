
using ReadWorkWrite
using Test
using JSON

dummy_read(x) = (;key=x, data=fill(x,x))
dummy_work(x) = merge(x, (;data=sum(x.data)))
results = NamedTuple{(:key, :data)}[]

io = IOBuffer()
dummy_write(x) = println(io, JSON.json(x))

@testset "ReadWorkWrite basic test" begin
	if Threads.nthreads() == 1
		@warn "Tests running with single thread - multithreading behavior not fully tested. Run with julia --threads=4 for complete testing."
	end
	
	ReadWorkWrite.readworkwrite(dummy_read, dummy_work, results, 1:3)
	# Sort by key since order is not guaranteed with multithreading
	sort!(results, by=x->x.key)
	expected = [(key=1, data=1), (key=2, data=4), (key=3, data=9)]
	@test results == expected

    ReadWorkWrite.readworkwrite(dummy_read, dummy_work, dummy_write, 1:3)
	output_lines = split(strip(String(take!(io))), '\n')
	parsed_results = [JSON.parse(line) for line in output_lines]
	sort!(parsed_results, by=x->x["key"])
	expected_json = [Dict("key"=>1, "data"=>1), Dict("key"=>2, "data"=>4), Dict("key"=>3, "data"=>9)]
	@test parsed_results == expected_json

	# Test workwrite function
	work_results = NamedTuple{(:key, :data)}[]
	test_data = [(key=1, data=[1]), (key=2, data=[2,2]), (key=3, data=[3,3,3])]
	ReadWorkWrite.workwrite(x -> merge(x, (data=sum(x.data),)), work_results, test_data)
	sort!(work_results, by=x->x.key)
	expected_work = [(key=1, data=1), (key=2, data=4), (key=3, data=9)]
	@test work_results == expected_work

end

@testset "Type inference and async features" begin
	# Test automatic type inference - should infer concrete types
	type_results_inferred = NamedTuple{(:key, :data), Tuple{Symbol, Int64}}[]
	ReadWorkWrite.readworkwrite(x -> (key=Symbol("item_$x"), data=x), x -> (key=x.key, data=x.data * 2), type_results_inferred, [1, 2, 3])
	sort!(type_results_inferred, by=x->x.key)
	@test type_results_inferred == [(key=:item_1, data=2), (key=:item_2, data=4), (key=:item_3, data=6)]
	@test eltype(type_results_inferred) == NamedTuple{(:key, :data), Tuple{Symbol, Int64}}
	
	# Test manual type specification with Any - should allow mixed types
	manual_results_any = Any[]
	ReadWorkWrite.readworkwrite(x -> (key=Symbol("item_$x"), data=x), x -> (key=x.key, data=x.data * 2), manual_results_any, [1, 2, 3]; T=Any)
	sort!(manual_results_any, by=x->x.key)
	@test manual_results_any == [(key=:item_1, data=2), (key=:item_2, data=4), (key=:item_3, data=6)]
	@test eltype(manual_results_any) == Any
	
	# Test return_on_completion=false
	async_results = Int[]
	handles = ReadWorkWrite.readworkwrite(x -> x, x -> x * 2, async_results, [1, 2, 3]; return_on_completion=false)
	@test haskey(handles, :in_ch)
	@test haskey(handles, :out_ch) 
	@test haskey(handles, :writer)
	@test haskey(handles, :workers)
	
	# Wait for completion
	wait.(handles.workers)  # workers is now an array
	close(handles.out_ch)    # need to close output channel
	wait(handles.writer)
	sort!(async_results)
	@test async_results == [2, 4, 6]
	
	# Test error handling for inconsistent types
	inconsistent_data = [1, "hello", 3.14]
	@test_throws ArgumentError ReadWorkWrite.readworkwrite(x -> x, x -> x, Int[], inconsistent_data)
	
	# But should work with T=Any
	any_results = Any[]
	ReadWorkWrite.readworkwrite(x -> x, x -> x, any_results, inconsistent_data; T=Any)
	sort!(any_results, by=string)  # Sort by string representation since mixed types
	@test any_results == [1, 3.14, "hello"]
end

@testset "Early Stopping" begin
	stop_results = NamedTuple{(:key, :data), Tuple{Symbol, Int64}}[]
	
	# Start processing with one slow item
	task = ReadWorkWrite.readworkwrite(
		x -> (key=Symbol("item_$x"), data=x), 
		x -> begin
			if x.key == :item_2
				sleep(2)  # This should be interrupted
			end
			(key=x.key, data=x.data * 10)
		end, 
		stop_results, 
		[1, 2, 3]; 
		return_on_completion=false
	)
	
	# Give it a moment to start processing
	sleep(0.1)
	
	# Stop early - this should interrupt the sleep(2) for :item_2
	close(task.out_ch)
	
	# Clean up all tasks properly
	try
		# Give a moment for tasks to notice the closed channel and exit
		sleep(0.1)
		# Force cleanup if needed
		for worker in task.workers
			if !istaskdone(worker)
				Base.schedule(worker, InterruptException(), error=true)
			end
		end
	catch
		# Ignore cleanup errors
	end
	
	# Should have processed :item_1 but not :item_2 (which was sleeping)
	# :item_3 might or might not be processed depending on timing
	sort!(stop_results, by=x->x.key)
	
	# At minimum, we should have :item_1, and we should NOT have the full set
	@test length(stop_results) >= 1
	@test length(stop_results) < 3  # Should be stopped before completing all
	@test (key=:item_1, data=10) in stop_results
	
	# The sleeping :item_2 should not be completed
	@test (key=:item_2, data=20) ∉ stop_results
end
