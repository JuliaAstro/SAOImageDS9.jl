module SAOImageDS9Tests
using Test
using SAOImageDS9, XPA
using XPA: TupleOf

proc = Base.Process[]

function ds9start(timeout::Real = 30.0)
    global proc
    elapsed = 0.0
    seconds = 0.5
    while true
        try
            return SAOImageDS9.connect()
        catch
            if length(proc) < 1
                push!(proc, run(`/usr/bin/ds9`; wait=false))
            end
            if elapsed > timeout
                error("cannot connect to SAOImage/DS9")
            end
            seconds = min(timeout - elapsed, 2*seconds)
            sleep(seconds)
        end
    end
end

function ds9kill()
    global proc
    if length(proc) ≥ 1
        kill(pop!(proc))
    end
    nothing
end

ds9start()
@info "DS9 started successfully"

@testset "Get requests" begin
    @test typeof(SAOImageDS9.get(VersionNumber)) === VersionNumber
    @test typeof(SAOImageDS9.get(Int, "width")) === Int
    @test typeof(SAOImageDS9.get(Int, "height")) === Int
end

ds9kill()

end # module
