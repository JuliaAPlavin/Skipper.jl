using TestItems
using TestItemRunner
@run_package_tests


@testitem "basic" begin
    a = [missing, -1, 2, 3]
    sa = @inferred(skip(x -> ismissing(x) || x < 0, a))
    @test collect(sa) == [2, 3]
    @test length(sa) == 2
    # ensure we get a view
    a[4] = 20
    @test collect(sa) == [2, 20]

    @test collect(skip(ismissing, [1, 2]))::Vector{Int} == [1, 2]
    @test collect(skip(ismissing, [missing]))::Vector{Union{}} == []
    @test collect(skip(ismissing, Union{Missing, Int}[missing]))::Vector{Int} == []
    @test collect(skip(ismissing, Missing[]))::Vector{Union{}} == []
    @test collect(skip(ismissing, Union{Missing, Int}[]))::Vector{Int} == []

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

    @test @inferred(eltype(skip(ismissing, [1, missing, nothing, 2, 3]))) == Union{Int, Nothing}
    @test @inferred(eltype(skip(isnothing, [1, missing, nothing, 2, 3]))) == Union{Int, Missing}
    @test @inferred(eltype(skip(x -> !(x isa Int), [1, missing, nothing, 2, 3]))) == Int
    @test @inferred(eltype(skip(x -> ismissing(x) || x < 0, [1, missing, 2, 3]))) == Int
    @test @inferred(eltype(skip(x -> ismissing(x) || x < 0, (x for x in [1, missing, 2, 3])))) == Int

    @test skip(ismissing, a) === keep(!ismissing, a)
end

@testitem "views, slices" begin
    a = [1 NaN; 2 3]
    sa = @inferred skip(isnan, a)

    @test collect(view(sa, 1:1, 1:1)::Skipper.Skip) == [1]
    @test collect(view(sa, 2, :)::Skipper.Skip) == [2, 3]
    sv = view(sa, 1, 1:2)
    @test sv[1] == 1
    @test_throws "is skipped" sv[2] == 2

    @test maximum(sa) == 3
    @test isequal( maximum.(eachslice(a; dims=2)), [2, NaN] )
    @test maximum.(eachslice(sa; dims=2)) == [2, 3]

    @test isequal( maximum.(eachrow(a)), [NaN, 3] )
    @test maximum.(eachrow(sa)) == [1, 3]
    @test isequal( maximum.(eachcol(a)), [2, NaN] )
    @test maximum.(eachcol(sa)) == [2, 3]

    @test isequal( maximum(a; dims=2), [NaN; 3;;] )
    @test_broken maximum(sa; dims=2) == [1, 3]
end

@testitem "similar" begin
    s = skip(isnothing, [1, 2, nothing, missing])
    @test eltype(s) == Union{Int, Missing}
    @test length(similar(s)::Vector{Union{Int, Missing}}) == 3
    @test length(similar(s, 1)::Vector{Union{Int, Missing}}) == 1
    @test length(similar(s, Float64)::Vector{Float64}) == 3
    @test length(similar(s, Float64, 5)::Vector{Float64}) == 5

    s = skip(x -> isnothing(x) || ismissing(x), [1, 2, nothing, missing])
    @test eltype(s) == Int
    @test length(similar(s)::Vector{Int}) == 2
    @test length(similar(s, 1)::Vector{Int}) == 1
    @test length(similar(s, Float64)::Vector{Float64}) == 2
    @test length(similar(s, Float64, 5)::Vector{Float64}) == 5
end

@testitem "set" begin
    using Accessors
    if VERSION >= v"1.9-DEV"
        a = [missing, -1, 2, 3]
        normalize(x) = x ./ sum(x)
        b = @modify(normalize, a |> skip(ismissing, _))
        @test b isa Vector{Union{Missing,Float64}}
        @test isequal(b, [missing, -0.25, 0.5, 0.75])
    end
end

@testitem "setindex" begin
    a = [missing, -1, 2, 3]
    sa = @inferred(skip(x -> ismissing(x) || x < 0, a))

    # @test_throws "is skipped" sa .= .-sa  # should it check the new value?
    sa .= 2 .* sa
    @test collect(sa) == [4, 6]
    @test isequal(a, [missing, -1, 4, 6])
    sa .= sa .+ sa
    @test collect(sa) == [8, 12]
    @test isequal(a, [missing, -1, 8, 12])
    sa .= (i for i in sa)
    @test collect(sa) == [8, 12]
    @test isequal(a, [missing, -1, 8, 12])

    a = [missing, 2, 3, missing]
    skip(!ismissing, a) .= sum(skip(ismissing, a))
    @test a == [5, 2, 3, 5]

    a = [missing, 2, 3, missing]
    sa = skip(ismissing, a)
    Skipper.complement(sa) .= sum(sa)
    @test a == [5, 2, 3, 5]
end

@testitem "collection types" begin
    using StructArrays
    using AxisKeys
    using Accessors

    a = StructArray(a=[missing, -1, 2, 3])
    sa = @inferred skip(x -> ismissing(x.a) || x.a < 0, a)

    @test collect(sa).a == [2, 3]
    @test (@inferred map(x -> x.a + 1, sa)) == [3, 4]
    @test (@inferred map(x -> (a=x.a + 1,), sa)).a == [3, 4]

    @test_broken collect(sa).a::Vector{Int} == [2, 3]
    @test_broken map(x -> x.a + 1, sa)::Vector{Int} == [3, 4]
    @test_broken map(x -> (a=x.a + 1,), sa).a::Vector{Int} == [3, 4]

    a = KeyedArray([missing, -1, 2, 3], b=[1, 2, 3, 4])
    sa = @inferred skip(x -> ismissing(x) || x < 0, a)
    @test_broken collect(sa)::KeyedArray == KeyedArray([2, 3], b=[3, 4])
    if VERSION >= v"1.9-DEV"
        normalize(x) = x ./ sum(x)
        b = @modify(normalize, a |> skip(ismissing, _))
        @test b isa KeyedArray{Union{Missing,Float64}}
        @test isequal(b, [missing, -0.25, 0.5, 0.75])
    end

    s = @inferred skip(isnan, (1., 2., NaN))
    @test collect(s) == [1., 2.]
    s = @inferred skip(isnan, (a=1., b=2., c=NaN))
    @test collect(s) == [1., 2.]
end

@testitem "filterview" begin
    a = [missing, -1, 2, 3]
    fa = @inferred filterview(x -> !ismissing(x) && x > 0, a)
    @test fa == [2, 3]
    @test fa[2] == 3
    @test fa isa AbstractVector{Int}
    # ensure we get a view
    a[4] = 20
    fa[1] = 10
    @test isequal(a, [missing, -1, 10, 20])
    @test fa == [10, 20]

    @test eltype(@inferred(filterview(x -> !ismissing(x) && x > 0, a))) == Int
    @test eltype(@inferred(filterview(x -> !ismissing(x) && x > 0, [missing, -1]))) == Int
    @test eltype(@inferred(filterview(x -> !ismissing(x) && x > 0, Union{Int, Missing}[missing]))) == Int
    @test eltype(@inferred(filterview(x -> !ismissing(x) && x > 0, [missing]))) == Union{}
    @test eltype(@inferred filterview(!ismissing, [1, missing, nothing, 2, 3])) == Union{Int, Nothing}
    @test eltype(@inferred filterview(!isnothing, [1, missing, nothing, 2, 3])) == Union{Int, Missing}
    @test eltype(@inferred filterview(x -> x isa Int, [1, missing, nothing, 2, 3])) == Int
    @test eltype(@inferred filterview(x -> !ismissing(x) && x > 0, [1, missing, 2, 3])) == Int

    using StructArrays
    a = StructArray([1+2im, Inf+3im])
    fa = @inferred filterview(isfinite, a)
    @test fa isa StructArray{ComplexF64}
    @test fa == [1+2im]
    @test fa.re == [1]
    a = StructArray(x=[1, 2], y=[3, missing])
    fa = @inferred filterview(r -> !ismissing(r.y), a)
    @test fa.x == [1]

    if VERSION >= v"1.9-DEV"
        using Dictionaries: dictionary
        a = dictionary(zip([:a, :b, :c], [missing, -1, 2]))
        fa = @inferred(filterview(!ismissing, a))
        @test fa == dictionary(zip([:b, :c], [-1, 2]))
    end

    using Accessors
    if VERSION >= v"1.9-DEV"
        a = [missing, -1., 2, 3]
        normalize(x::AbstractVector{Float64}) = x ./ sum(x)
        b = @modify(normalize, a |> filterview(!ismissing, _))
        @test b isa AbstractVector{Union{Missing,Float64}}
        @test isequal(b, [missing, -0.25, 0.5, 0.75])

        using AxisKeys
        a = KeyedArray([missing, -1., 2, 3], b=[1, 2, 3, 4])
        b = @modify(normalize, a |> filterview(!ismissing, _))
        @test b isa KeyedArray{Union{Missing,Float64}}
        @test isequal(b, [missing, -0.25, 0.5, 0.75])
    end
end

@testitem "curried" begin
    a = [1, 2, missing]
    @test skip(ismissing)(a) === skip(ismissing, a)
    @test filterview(!ismissing)(a) == filterview(!ismissing, a)
end


@testitem "_" begin
    import Aqua
    Aqua.test_all(Skipper; ambiguities=false, piracy=false)
    Aqua.test_ambiguities(Skipper)

    import CompatHelperLocal as CHL
    CHL.@check()
end
