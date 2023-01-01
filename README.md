# Skipper.jl

`skip(predicate, collection)`: extension of `skipmissing` that
- allows arbitrary predicates, such as `ismissing`, `isnan` or `x -> isnan(x) || iszero(x)`
- supports setting values

# Usage

```julia
julia> using Skipper

julia> a = [missing, -1, 2, NaN, 3]
5-element Vector{Union{Missing, Float64}}:
    missing
  -1.0
   2.0
 NaN
   3.0

# skip all missing and NaN values
julia> sa = skip(x -> ismissing(x) || isnan(x), a)
skip(var"#5#6"(), Union{Missing, Float64}[missing, -1.0, 2.0, NaN, 3.0])

# only floats remain
julia> eltype(sa)
Float64

# and only those that are not NaNs
julia> collect(sa)
3-element Vector{Float64}:
 -1.0
  2.0
  3.0

# indexing works when the target value is valid
julia> sa[2]
-1.0

# but errors when it's not
julia> sa[1]
ERROR: MissingException: the value at index (1,) is skipped
Stacktrace:
 [1] getindex(s::Skipper.Skip{var"#5#6", Vector{Union{Missing, Float64}}}, I::Int64)
   @ Skipper ~/.julia/dev/Skipper/src/Skipper.jl:27
 [2] top-level scope
   @ REPL[8]:1

# broadcasting and aggregations work just fine with skip() objects
julia> sa .* 2
3-element Vector{Float64}:
 -2.0
  4.0
  6.0

julia> using Statistics
julia> mean(sa)
1.3333333333333333

# skip() objects support setindex!
# this makes transforming valid (non-skipped) elements easy:
julia> sa .= ifelse.(sa .> 2, 3, 1)
skip(var"#5#6"(), Union{Missing, Float64}[missing, 1.0, 1.0, NaN, 3.0])
julia> a
5-element Vector{Union{Missing, Float64}}:
    missing
   1.0
   1.0
 NaN
   3.0

# as well as replacing/imputing skipped values:
julia> Skipper.complement(sa) .= mean(sa);
julia> a
5-element Vector{Union{Missing, Float64}}:
 1.6666666666666667
 1.0
 1.0
 1.6666666666666667
 3.0
```