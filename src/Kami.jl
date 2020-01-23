module Kami

include("fitfinder.jl")
#include("test/runtests.jl")

export main, test

function main()
    data = CSV.read("dataset/kami.csv")
    # graph = @df data plot(:x,:y)

    #dI (t) = −a_1*I(t) − a_2*I(t)^2 + (a_3 * I(t) + q) * I (t)^(1−(1/n))

    @vars I a1 a2 a3 q n


    dI = -a1*I - a2*I^2 + (a3 * I + q) * I^(1-(1/n))

    params_span = [
        (a1, -10:eps():10),
        (a2, -10:eps():10),
        (a3, -10:eps():10),
        (q, -10:eps():10),
        (n, -10:eps():10)
    ];

    #find_fit(nothing, dI, I, t, params_span)

    print(data[:,:x])
end

function test()
    include("test/runtests.jl")
end

end # module
