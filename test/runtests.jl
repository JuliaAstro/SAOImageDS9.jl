using Test
using DS9, XPA
using XPA: TupleOf

function ds9start(timeout::Real = 10.0)
    launched = false
    elapsed = 0.0
    seconds = 1.0
    while true
        try
            return DS9.connect()
        catch
            if !launched
                run(`ds9`; wait=false)
                launched = true
            end
            if elapsed > timeout
                error("cannot connect to SAOImage/DS9")
            end
            seconds = min(timeout - elapsed, 2*seconds)
            sleep(seconds)
        end
    end
end

ds9start()

@testset "Get requests" begin
    @test typeof(DS9.get(VersionNumber)) == VersionNumber
end
