
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
