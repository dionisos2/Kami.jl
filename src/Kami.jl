module Kami

using SymEngine
using CSV
using Debugger
using Plots
using TerminalMenus
using ProgressMeter
using Dates
using Serialization
using Formatting

include("adn.jl")
include("utils.jl")
include("fit_eq_diff.jl")
include("fit_function.jl")

using .Adn
using .FitEqDiff
using .FitFunction
include("bordel.jl")

export main, @enter, show_result

function main()
    menu = RadioMenu(["run_function_finder",
                      "run_eq_diff_finder",
                      "show_result",
                      "quit"],
                     pagesize=10)

    choice = request("Choose : ", menu)

    if choice == 1
        run_function_finder()
    elseif choice == 2
        run_eq_diff_finder()
    elseif choice == 3
        show_result()
    else
        return nothing
    end
end

funct(x, params) = (params[1]+x)*(params[2]+x)*(params[3]+x)*(params[4]+x)

function run_function_finder()
    real_funct(x) = 147.0 + 88.9*x - 34.6*x^2 - 4.3*x^3 + x^4
    wanted_values = [(x, real_funct(x)) for x in 0:0.1:10]
    params_span = [-20:0.1:20, -20:0.1:20, -20:0.1:20, -20:0.1:20]

    params = Params(duration_max=Second(10), score_max=-1.)
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

    params = Params(duration_max=Second(60*5))
    custom_params = EqDiffParams(params_span, dfunct=dY, funct=Y, variable=t, dvariable=0.5, wanted_values=wanted_values, mutate_max_speed=0.001)

    run_session(EqDiffAdn, params, custom_params)
end


function show_result()
    history, params, custom_params = load_session()

    menu = RadioMenu(["best adn",
                      "show best adn graph",
                      "score history",
                      "create pics of function",
                      "create pics of adn history",
                      "create gif from pics directory",
                      "quit"
                      ]
                     , pagesize=10)

    leaving = false
    while !leaving
        println("-"^50)
        choice = request("Choose : ", menu)

        best_adn = get_best_adn(history)
        best_score = get_best_score(history)
        if choice == 1
            println("best adn = ", best_adn)
            println("score = ", best_score)
        elseif choice == 2
            show_adn_graph(best_adn, custom_params)
        elseif choice == 3
            for (generation, species_list) in enumerate(history)
                println("Generation $generation = ", get_best_score(species_list))
            end
        elseif choice == 4
            adn_list = [get_best_adn(species_list) for species_list in history]
            ask_with_default_dir(create_pics_of_function, adn_list, custom_params)
        elseif choice == 5
            ask_with_default_dir(create_pics_of_history, history, custom_params)
        elseif choice == 6
            ask_with_default_dir(create_gif_from_result)
        else
            println("goodbye")
            leaving = true
        end
    end
end

function ask_with_default_dir(funct, args...)
    println("choose directory name (default 'result')")
    dir_path = readline()

    if dir_path != ""
        funct(args..., dir_path)
    else
        funct(args...)
    end
end

end # module
