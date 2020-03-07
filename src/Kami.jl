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

funct(x, params) = params[1]*x^2 + params[2]*x + params[3]

function run_function_finder()
    real_funct(x) = 2*x^2 + 4.5*x - 7
    wanted_values = [(x, real_funct(x)) for x in 0:0.1:10]
    params_span = [-10:0.1:10, -10:0.1:10, -10:0.1:10]

    params = Params(duration_max=Second(60), score_max=-1.)
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


function show_adn_graph(adn::AbstractAdn, custom_params)
    funct = create_adn_function(adn, custom_params)

    graph = plot(custom_params.wanted_values, label="Wanted", ls=:dash, linewidth=3)
    plot!(graph, funct, label="Result")

    display(graph)
end

create_adn_function(adn::FunctionAdn, custom_params) = x->custom_params.funct(x, adn.params)
create_adn_function(adn::EqDiffAdn, custom_params) = generate_solution(adn, custom_params)


function create_gif_from_result(dir_path="result", gif_path="anim.gif")
    fps = 1
    run(`ffmpeg -i $dir_path/plot_00001.png -vf palettegen the_palette.png`)
    run(`ffmpeg -y -r $fps -f image2 -i $dir_path/plot_%05d.png -i the_palette.png -filter_complex paletteuse $gif_path`)
    rm("the_palette.png")
end

function create_pic_for_params(xparam, yparam, adn_list::Vector{<:AbstractAdn}, custom_params)
    xlims = (minimum(custom_params[xparam]), maximum(custom_params[xparam]))

    if yparam == nothing
        ylims = (-1,1)
        get_yparam = (adn, yparam) -> 0
    else
        ylims = (minimum(custom_params[yparam]), maximum(custom_params[yparam]))
        get_yparam = (adn, yparam) -> adn[yparam]
    end

    adn_random = filter(x->x.type=="random", adn_list)
    adn_child = filter(x->x.type=="child", adn_list)
    adn_mutant = filter(x->x.type=="mutant", adn_list)


    points_random = [(adn[xparam], get_yparam(adn, yparam)) for adn in adn_random]
    points_child = [(adn[xparam], get_yparam(adn, yparam)) for adn in adn_child]
    points_mutant = [(adn[xparam], get_yparam(adn, yparam)) for adn in adn_mutant]

    plot_params = (xlims=xlims, ylims=ylims, xlabel=string(xparam), ylabel=string(yparam))
    graph = scatter(points_random; legend = :none, color=:blue, legendfontsize=4, label="randoms", plot_params...)
    scatter!(graph, points_child; label="children", color=:red, plot_params...)
    scatter!(graph, points_mutant; label="mutants", color=:green,  plot_params...)

    return graph
end

function create_pic_for_params(xparam, adn_list::Vector{<:AbstractAdn}, custom_params)
    return create_pic_for_params(xparam, nothing, adn_list, custom_params)
end

function create_pics_of_adn_list(adn_list::Vector{<:AbstractAdn}, custom_params)
    result = Plots.Plot[]

    the_keys = collect(keys(custom_params.params_span))
    len = length(custom_params.params_span)
    for (xparam, yparam) in zip(the_keys[1:2:(len-1)], the_keys[2:2:len])
        pic = create_pic_for_params(xparam, yparam, adn_list, custom_params)
        push!(result, pic)
    end

    if len%2 == 1
        pic = create_pic_for_params(the_keys[end], adn_list, custom_params)
        push!(result, pic)
    end

    return result
end

function create_pics_of_history(history::Vector{Vector{Tuple{AbstractAdn, Float64}}}, custom_params, dir_path="result")
    if ispath(dir_path)
        error("'$dir_path' already exists")
    else
        mkdir("$dir_path")
    end

    progress_time = Progress(length(history), "Time : ")

    last_best_score = -Inf
    number = 1
    for (generation, adn_score_list) in enumerate(history)
        best_score = adn_score_list[1][2]
        if best_score > last_best_score
            adn_list = map(el->el[1], adn_score_list)
            title = plot(title = "$generation : $best_score", grid = false, showaxis = false)
            adn_plot_list = create_pics_of_adn_list(adn_list, custom_params)
            result = plot(title, plot(adn_plot_list...), layout=@layout([a{0.02h}; b{0.98h}]))
            formatted_number = format("{1:0>5}", number)
            savefig(result, "$dir_path/adn_plot_$formatted_number.png")
            last_best_score = best_score
            number += 1
        end
        next!(progress_time)
    end
end

function create_pics_of_function(adn_list::Vector{<:AbstractAdn}, custom_params, dir_path="result")
    if ispath(dir_path)
        error("'$dir_path' already exists")
    else
        mkdir("$dir_path")
    end

    xlims = (custom_params.wanted_values[1][1], custom_params.wanted_values[end][1])
    ylims = (custom_params.wanted_values[1][2], custom_params.wanted_values[end][2])

    progress_time = Progress(length(history), "Time : ")

    last_adn = nothing
    number = 1
    for (generation, adn) in enumerate(adn_list)
        if last_adn != adn
            funct = create_adn_function(adn, custom_params)
            graph = plot(custom_params.wanted_values, label="Wanted", xlims=xlims, ylims=ylims, ls=:dash, linewidth=3)
            plot!(graph, funct, label="Result $generation")
            formatted_number = format("{1:0>5}", number)
            number += 1
            savefig(graph, "$dir_path/plot_$formatted_number.png")
            last_adn = adn
        end
        next!(progress_time)
    end
end

function show_result()
    history, params, custom_params = load_session()

    menu = RadioMenu(["best adn",
                      "show best adn graph",
                      "score history",
                      "history",
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

        best_adn_score = history[end][1]
        if choice == 1
            println("best adn = ", best_adn_score[1])
            println("score = ", best_adn_score[2])
        elseif choice == 2
            show_adn_graph(best_adn_score[1], custom_params)
        elseif choice == 3
            for (generation, adn_score_list) in enumerate(history)
                adn_score = adn_score_list[1]
                println("Generation $generation = ", adn_score[2])
            end
        elseif choice == 4
            for (generation, adn_score_list) in enumerate(history)
                println("-"^10," Generation $generation ", "-"^10)
                println(map(el->el[1], adn_score_list))
            end
        elseif choice == 5
            adn_list = [adn_score_list[1][1] for adn_score_list in history]
            ask_with_default_dir(create_pics_of_function, adn_list, custom_params)
        elseif choice == 6
            ask_with_default_dir(create_pics_of_history, history, custom_params)
        elseif choice == 7
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
