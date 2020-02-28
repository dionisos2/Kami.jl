module Kami

using SymEngine
using CSV
using Debugger
using Plots
using TerminalMenus
using ProgressMeter
using Dates

include("fit_eq_diff.jl")

using .FitEqDiff

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


    params = Params(duration_max=Second(60*3), adn_count=10)
    custom_params = EqDiffParams(params_span, dfunct=dI, funct=I, variable=t, dvariable=0.5, wanted_values=wanted_values, mutate_max_speed=0.001)

    run_finder(EqDiffAdn, params, custom_params)
end

function run_finder(EqDiffAdn, params, custom_params)
    progress_time = Progress(Millisecond(params.duration_max).value, "Time : ")
    generator = create_improve_generator(EqDiffAdn, params, custom_params)

    for result in generator
        if isready(generator)
            continue # We empty the channel until asking question
        end

        having_question = true
        while having_question
            println("Generation : $(result[:generation])")
            menu = RadioMenu(["quit",
                              "continue",
                              "show info",
                              "show best adn graph"]
                             , pagesize=10)

            choice = request("Choose : ", menu)

            if choice == 1
                close(generator)
                return "FIN"
            elseif choice == 2
                having_question = false
                println("Continue")
            elseif choice == 3
                println("Generation : $(result[:generation])")
                println("Best score : $(result[:best_score])")
                println("Best adn : $(result[:adn_score_list][1][1])")
            elseif choice == 4
                best_adn = result[:adn_score_list][1][1]
                show_adn_graph(best_adn, custom_params)
            end
        end

    end

end

function show_adn_graph(adn, custom_params)
    sol = generate_solution(adn, custom_params)

    graph = plot(custom_params.wanted_values, label="Wanted", ls=:dash, linewidth=3)
    plot!(graph, sol, label="Result")

    display(graph)
end

end # module
