module Kami

using SymPy
using CSV
using Debugger

include("adn.jl")
include("fit_equadiff.jl")

export main, tt

function main()
    # wanted_values = [(t, 2+exp(t/300)) for t in 0:1000]
    # dI = a1*I + a2

    # data = CSV.read("dataset/kami.csv")
    # wanted_values = collect(zip(data[:,:x],data[:,:y]))

    wanted_values = Tuple{Float64, Float64}[(0,0),(1,1),(2,4)]


    @vars t I a1 a2 a3 q n
    dI = -a1*I - a2*I^2 + (a3 * I + q) * I^(1-(1/n))



    params_span = [
        (a1, 0:eps():10),
        (a2, 0:eps():10),
        (a3, 0:eps():10),
        (q, 0:eps():10),
        (n, 1:eps():2)
    ];


    params = Params(duration_max=Second(30))
    custom_params = EqDiffParams(params_span, dfunct=dI, funct=I, variable=t, wanted_values=wanted_values)

    improve_until(EqDiffAdn, params, custom_params)
end

function tt()
    include("test/runtests.jl")
end

end # module
