module Kami

using SymPy
using CSV

include("adn.jl")
include("fit_equadiff.jl")

export main, test

function main()
    data = CSV.read("dataset/kami.csv")

    wanted_values = collect(zip(data[:,:x],data[:,:y]))


    # wanted_values = [(t, 2+exp(t/300)) for t in 0:1000]


    @vars t I a1 a2 a3 q n
    #dI (t) = −a_1*I(t) − a_2*I(t)^2 + (a_3 * I(t) + q) * I (t)^(1−(1/n))
    dI = -a1*I - a2*I^2 + (a3 * I + q) * I^(1-(1/n))

    # dI = a1*I + a2

    params_span = [
        (a1, 0:eps():10),
        (a2, 0:eps():10),
        (a3, 0:eps():10),
        (q, 0:eps():10),
        (n, 1:eps():2)
    ];


    # find_fit(wanted_values, dI, I, t, params_span, 500, 15)

    # adn = [(a1, 0.0033094511474171277), (a2, -0.006758205949772471)]
    # sol = generate_solution(adn, wanted_values, dI, I, t);
    # getted_values = collect(zip(sol.t, sol.u))
    # println(get_khi(wanted_values, getted_values))


    # adn = [(a1, 3.7678417264335256), (a2, 0.01658842607337263), (a3, 0.8146613188623284), (q, 7.665662121065622), (n, 1.68225673180426)]
    # display_result(adn, wanted_values, dI, I, t)
end

function test()
    include("test/runtests.jl")
end

end # module
