module AccessorsExt
using Skipper
using Accessors
import Accessors: set

function set(obj, opt::Base.Fix1{typeof(skip)}, val)
    IX = collect(eachindex(opt(obj)))
    @set obj[IX] = val
end

end
