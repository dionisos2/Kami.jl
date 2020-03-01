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

export main, @enter, show_result, main2

function main()
    menu = RadioMenu(["run_finder",
                      "show_result"],
                     pagesize=10)

    choice = request("Choose : ", menu)

    if choice == 1
        run_finder()
    elseif choice ==2
        show_result()
    end
end

function main2()
    funct(x, params) = params[1]*x^2 + params[2]*x + params[3]

    real_funct(x) = 2*x^2 + 4.5*x - 7
    wanted_values = [(x, real_funct(x)) for x in 0:0.1:10]
    params_span = [-10:0.1:10, -10:0.1:10, -10:0.1:10]

    params = Params(duration_max=Second(60), adn_count=20)
    custom_params = FunctionParams(params_span,
                                   funct=funct,
                                   wanted_values=wanted_values,
                                   mutate_max_speed=0.1)


    generator = create_improve_generator(FunctionAdn, params, custom_params)

    adn = nothing
    for result in generator
        println(result[:generation], " : ", result[:best_score])
        adn = result[:adn_score_list][1][1]
    end

    graph = plot(custom_params.wanted_values, label="Wanted", ls=:dash, linewidth=3)
    plot!(graph, x->adn[1]*x^2+adn[2]*x+adn[3], label="Result")

    display(graph)

    println(adn)
end

function initialise()

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


    params = Params(duration_max=Second(60*3), adn_count=10)
    custom_params = EqDiffParams(params_span, dfunct=dY, funct=Y, variable=t, dvariable=0.5, wanted_values=wanted_values, mutate_max_speed=0.001)

    return (EqDiffAdn, params, custom_params)
end

function run_finder()
    EqDiffAdn, params, custom_params = initialise()

    progress_time = Progress(Millisecond(params.duration_max).value, "Time : ")
    generator = create_improve_generator(EqDiffAdn, params, custom_params)

    serialize("current_session", (params, custom_params))

    for result in generator
        to_show = [
            ("generation", result[:generation])
            ("best score", "$(result[:best_score]))/$(params.score_max)")
        ]
        update!(progress_time, Millisecond(result[:duration]).value, showvalues = to_show)

        open("current_session", "a") do file
            serialize(file, map(x->x[1], result[:adn_score_list]))
        end

    end

end

function show_adn_graph(adn, custom_params)
    sol = generate_solution(adn, custom_params)

    graph = plot(custom_params.wanted_values, label="Wanted", ls=:dash, linewidth=3)
    plot!(graph, sol, label="Result")

    display(graph)
end

function show_result()
    history = Vector{EqDiffAdn}[]
    params, custom_params = nothing, nothing

    open("current_session", "r") do file
        (params, custom_params) = deserialize(file)
        while !eof(file)
            push!(history, deserialize(file))
        end
    end

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

        best_adn = history[end][1]
        if choice == 1
            println("best adn = ", best_adn)
            println("score = ", action(best_adn, custom_params))
        elseif choice == 2
            show_adn_graph(best_adn, custom_params)
        elseif choice == 3
            for (generation, adn_list) in enumerate(history)
                println("Generation $generation = ", action(adn_list[1], custom_params))
            end
        elseif choice == 4
            for (generation, adn_list) in enumerate(history)
                println("-"^10," Generation $generation ", "-"^10)
                println(adn_list)
            end
        elseif choice == 5
            println("goodbye")
            leaving = true
        end
    end
end

end # module
