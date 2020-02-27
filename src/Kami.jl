module Kami

using SymEngine
using CSV
using Debugger
using Plots
using TerminalMenus
using ProgressMeter

include("adn.jl")
include("fit_equadiff.jl")

export main, @enter

function main()

    @vars t I a1 a2 a3 q n
    dI = -a1*I - a2*I^2 + (a3 * I + q) * I^(1-(1/n))
    # data = CSV.read("dataset/kami.csv")
    # wanted_values = collect(zip(data[:,:x],data[:,:y]))

    # c1*e^(a1*t)-a2/a1
    # a1 = 1/300 ; a2=2*-a1= -2/300
    wanted_values = [(Float64(t), 2+exp(t/300)) for t in 0:1000]
    dI = a1*I + a2

    params_span = Tuple{Basic, StepRangeLen}[
        (a1, 0.0001:eps():0.01),
        (a2, -0.01:eps():-0.0001),
        # (a3, 0:eps():10),
        # (q, 0:eps():10),
        # (n, 1:eps():2)
    ];


    params = Params(duration_max=Second(60), adn_count=10)
    custom_params = EqDiffParams(params_span, dfunct=dI, funct=I, variable=t, dvariable=0.5, wanted_values=wanted_values, mutate_max_speed=0.001)

    run_finder(EqDiffAdn, params, custom_params)
end

function run_finder(EqDiffAdn, params, custom_params)
    progress_time = Progress(Millisecond(params.duration_max).value, "Time : ")
    generator = improve_until(EqDiffAdn, params, custom_params)
    adn = nothing
    ok = true

    while ok
        try
            println("try")
            result = take!(generator)
            println(generator.state)
            if generator.state == :closed
                break
            end

            sleep(2)
            println("ok")
            adn = result[1][1][1]
            to_show = [
                ("generation", result[:generation])
                ("best score", "$(result[:best_score]))/$(params.score_max)")
            ]

            update!(progress_time, Millisecond(result[:duration]).value, showvalues = to_show)
        catch error
            println(error)
            if isa(error, InterruptException)
                menu = RadioMenu(["quit", "continue"], pagesize=10)
                choice = request("Choose :", menu)
                if choice == 1
                    break
                else
                    println("Good choice")
                end
            else
                rethrow()
            end
        end
    end

    sol = generate_solution(adn, custom_params)

    graph = plot(custom_params.wanted_values, label="Wanted", ls=:dash, linewidth=3)
    plot!(graph, sol, label="Result")

    display(graph)
end

end # module
