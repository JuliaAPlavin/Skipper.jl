using TestItems
using TestItemRunner
@run_package_tests


@testitem "simple" begin
    a = [missing, -1, 2, 3]
    sa = @inferred(skip(x -> ismissing(x) || x < 0, a))
    @test collect(sa) == [2, 3]
    # ensure we get a view
    a[4] = 20
    @test collect(sa) == [2, 20]

    @test eltype(@inferred(skip(x -> ismissing(x) || x < 0, a))) == Int
    @test eltype(@inferred(skip(x -> ismissing(x) || x < 0, [missing, -1]))) == Int
    @test eltype(@inferred(skip(x -> ismissing(x) || x < 0, Union{Int, Missing}[missing]))) == Int
    @test eltype(@inferred(skip(x -> ismissing(x) || x < 0, [missing]))) == Union{}

    @test_throws "is skipped" sa[1]
    @test sa[3] == 2
    @test sa[CartesianIndex(3)] == 2
    @test map(x -> x + 1, sa) == [3, 21]
    @test filter(x -> x > 10, sa) == [20]
    @test findmax(sa) == (20, 4)

    @test_throws "is skipped" sa .= .-sa
    sa .= 2 .* sa
    @test collect(sa) == [4, 40]
    @test isequal(a, [missing, -1, 4, 40])
    sa .= sa .+ sa
    @test collect(sa) == [8, 80]
    @test isequal(a, [missing, -1, 8, 80])
    sa .= (i for i in sa)
    @test collect(sa) == [8, 80]
    @test isequal(a, [missing, -1, 8, 80])

    @test collect(skipnan([1, NaN, 3])) == [1, 3]

    @test @inferred(eltype(skip(ismissing, [1, missing, nothing, 2, 3]))) == Union{Int, Nothing}
    @test @inferred(eltype(skip(isnothing, [1, missing, nothing, 2, 3]))) == Union{Int, Missing}
    @test @inferred(eltype(skip(x -> !(x isa Int), [1, missing, nothing, 2, 3]))) == Int
    @test @inferred(eltype(skip(x -> ismissing(x) || x < 0, [1, missing, 2, 3]))) == Int
    @test @inferred(eltype(skip(x -> ismissing(x) || x < 0, (x for x in [1, missing, 2, 3])))) == Int
end

@testitem "array types" begin
    using StructArrays
    using AxisKeys

    a = StructArray(a=[missing, -1, 2, 3])
    sa = @inferred skip(x -> ismissing(x.a) || x.a < 0, a)
    @test collect(sa).a == [2, 3]

    a = KeyedArray([missing, -1, 2, 3], b=[1, 2, 3, 4])
    sa = @inferred skip(x -> ismissing(x) || x < 0, a)
    @test_broken collect(sa)::KeyedArray == KeyedArray([2, 3], b=[3, 4])
end


@testitem "_" begin
    import Aqua
    Aqua.test_all(Skipper; ambiguities=false)
    Aqua.test_ambiguities(Skipper)

    import CompatHelperLocal as CHL
    CHL.@check()
end
