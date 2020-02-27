module Kami

using SymPy
using CSV
using Debugger
using Plots

include("adn.jl")
include("fit_equadiff.jl")

export main, tt, @enter

function main()

    @vars t I a1 a2 a3 q n
    dI = -a1*I - a2*I^2 + (a3 * I + q) * I^(1-(1/n))
    # data = CSV.read("dataset/kami.csv")
    # wanted_values = collect(zip(data[:,:x],data[:,:y]))

    # c1*e^(a1*t)-a2/a1
    # a1 = 1/300 ; a2=2*-a1= -2/300
    wanted_values = [(Float64(t), 2+exp(t/300)) for t in 0:1000]
    dI = a1*I + a2

    params_span = Tuple{Sym, StepRangeLen}[
        (a1, 0.0001:eps():0.01),
        (a2, -0.01:eps():-0.0001),
        # (a3, 0:eps():10),
        # (q, 0:eps():10),
        # (n, 1:eps():2)
    ];


    params = Params(duration_max=Second(60*3))
    custom_params = EqDiffParams(params_span, dfunct=dI, funct=I, variable=t, dvariable=0.5, wanted_values=wanted_values, mutate_max_speed=0.001)

    result = improve_until(EqDiffAdn, params, custom_params)
    # adn = EqDiffAdn(Dict(a2 => -2/300,a1 => 1/300))
    # result = [adn]

    sol = generate_solution(result[1], custom_params)

    graph = plot(wanted_values, label="Wanted", ls=:dash, linewidth=3)
    plot!(graph, sol, label="Result")

    display(graph)
end

function tt()
    include("test/runtests.jl")
end

end # module
