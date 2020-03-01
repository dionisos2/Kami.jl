module Kami

using SymEngine
using CSV
using Debugger
using Plots
using TerminalMenus
using ProgressMeter
using Dates
using Serialization

include("adn.jl")
include("utils.jl")
include("fit_eq_diff.jl")
include("fit_function.jl")

using .Adn
using .FitEqDiff
using .FitFunction

export main, @enter, show_result

function main()
    menu = RadioMenu(["run_function_finder",
                      "run_eq_diff_finder",
                      "show_result"],
                     pagesize=10)

    choice = request("Choose : ", menu)

    if choice == 1
        run_function_finder()
    elseif choice == 2
        run_eq_diff_finder()
    elseif choice == 3
        show_result()
    end
end

funct(x, params) = params[1]*x^2 + params[2]*x + params[3]

function run_function_finder()
    real_funct(x) = 2*x^2 + 4.5*x - 7
    wanted_values = [(x, real_funct(x)) for x in 0:0.1:10]
    params_span = [-10:0.1:10, -10:0.1:10, -10:0.1:10]

    params = Params(duration_max=Second(60), adn_count=20, score_max=-1.5)
    custom_params = FunctionParams(params_span,
                                   funct=funct,
                                   wanted_values=wanted_values,
                                   mutate_max_speed=0.1)

    run_session(FunctionAdn, params, custom_params)
end

function run_eq_diff_finder()
    t, Y, a1, a2, a3, q, n = :t, :Y, :a1, :a2, :a3, :q, :n
    # dY = Symbol(-a1*Y - a2*Y^2 + (a3 * Y + q) * Y^(1-(1/n))
    # data = CSV.read("dataset/kami.csv")
    # wanted_values = collect(zip(data[:,:x],data[:,:y]))

    # c1*e^(a1*t)-a2/a1
    # a1 = 1/300 ; a2=2*-a1= -2/300
    wanted_values = [(Float64(t), 2+exp(t/300)) for t in 0:1000]

    dY = Symbol("a1*Y + a2")

    params_span = Tuple{Symbol, StepRangeLen}[
        (a1, 0.0001:eps():0.01),
        (a2, -0.01:eps():-0.0001),
        # (a3, 0:eps():10),
        # (q, 0:eps():10),
        # (n, 1:eps():2)
    ];

    params = Params(duration_max=Second(50), adn_count=10)
    custom_params = EqDiffParams(params_span, dfunct=dY, funct=Y, variable=t, dvariable=0.5, wanted_values=wanted_values, mutate_max_speed=0.001)

    run_session(EqDiffAdn, params, custom_params)
end

function show_adn_graph(adn::FunctionAdn, custom_params)
    graph = plot(custom_params.wanted_values, label="Wanted", ls=:dash, linewidth=3)
    plot!(graph, x->custom_params.funct(x, adn.params), label="Result")

    display(graph)
end

function show_adn_graph(adn::EqDiffAdn, custom_params)
    sol = generate_solution(adn, custom_params)

    graph = plot(custom_params.wanted_values, label="Wanted", ls=:dash, linewidth=3)
    plot!(graph, sol, label="Result")

    display(graph)
end

function show_result()
    history, params, custom_params = load_session()

    menu = RadioMenu(["best adn",
                      "show best adn graph",
                      "score history",
                      "history",
                      "quit"
                      ]
                     , pagesize=10)

    leaving = false
    while !leaving
        println("-"^50)
        choice = request("Choose : ", menu)

        best_adn_score = history[end][1]
        if choice == 1
            println("best adn = ", best_adn_score[1])
            println("score = ", best_adn_score[2])
        elseif choice == 2
            show_adn_graph(best_adn_score[1], custom_params)
        elseif choice == 3
            for (generation, score_adn_list) in enumerate(history)
                score_adn = score_adn_list[1]
                println("Generation $generation = ", score_adn[2])
            end
        elseif choice == 4
            for (generation, score_adn_list) in enumerate(history)
                println("-"^10," Generation $generation ", "-"^10)
                println(map(el->el[1], score_adn_list))
            end
        elseif choice == 5
            println("goodbye")
            leaving = true
        end
    end
end

end # module
