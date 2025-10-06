
using ReadWorkWrite
using Test
using JSON

dummy_read(x) = (;key=x, data=fill(x,x))
dummy_work(x) = merge(x, (;data=sum(x.data)))
results = NamedTuple{(:key, :data)}[]

io = IOBuffer()
dummy_write(x) = println(io, JSON.json(x))

@testset "ReadWorkWrite basic test" begin
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
	# Test automatic type inference
	type_results = Int[]
	ReadWorkWrite.readworkwrite(x -> x, x -> x * 2, type_results, [1, 2, 3])
	@test type_results == [2, 4, 6]
	
	# Test manual type specification
	manual_results = Any[]
	ReadWorkWrite.readworkwrite(x -> x, x -> x * 2, manual_results, [1, 2, 3]; T=Any)
	@test manual_results == [2, 4, 6]
	
	# Test return_on_completion=false
	async_results = Int[]
	handles = ReadWorkWrite.readworkwrite(x -> x, x -> x * 2, async_results, [1, 2, 3]; return_on_completion=false)
	@test haskey(handles, :in_ch)
	@test haskey(handles, :out_ch) 
	@test haskey(handles, :writer)
	@test haskey(handles, :workers)
	
	# Wait for completion
	wait(handles.workers)
	wait(handles.writer)
	@test async_results == [2, 4, 6]
	
	# Test error handling for inconsistent types
	inconsistent_data = [1, "hello", 3.14]
	@test_throws ArgumentError ReadWorkWrite.readworkwrite(x -> x, x -> x, Int[], inconsistent_data)
	
	# But should work with T=Any
	any_results = Any[]
	ReadWorkWrite.readworkwrite(x -> x, x -> x, any_results, inconsistent_data; T=Any)
	@test any_results == [1, "hello", 3.14]
end
