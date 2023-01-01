using TestItems
using TestItemRunner
@run_package_tests


@testitem "_" begin
    import Aqua
    Aqua.test_all(Skipper; ambiguities=false)
    Aqua.test_ambiguities(Skipper)

    import CompatHelperLocal as CHL
    CHL.@check()
end
