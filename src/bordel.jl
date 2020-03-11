

function show_adn_graph(adn::AbstractAdn, custom_params)
    funct = get_adn_function(adn, custom_params)

    graph = plot(custom_params.wanted_values, label="Wanted", ls=:dash, linewidth=3)
    plot!(graph, funct, label="Result")

    display(graph)
end

get_adn_function(adn::FunctionAdn, custom_params) = x->custom_params.funct(x, adn.params)
get_adn_function(adn::EqDiffAdn, custom_params) = generate_solution(adn, custom_params)


function create_gif_from_result(dir_path="result", gif_path="anim.gif")
    fps = 10
    run(`ffmpeg -i $dir_path/plot_00001.png -vf palettegen the_palette.png`)
    run(`ffmpeg -y -r $fps -f image2 -i $dir_path/plot_%05d.png -i the_palette.png -filter_complex paletteuse $gif_path`)
    rm("the_palette.png")
end

function get_plot_for_params(xparam, yparam, adn_list::Vector{<:AbstractAdn}, color::Colorant, custom_params, graph::Union{<:Plots.Plot, Nothing}=nothing)
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
    if graph == nothing
        graph = scatter(points_random; legend = :none, color=color, markershape=:circle, legendfontsize=4, label="randoms", plot_params...)
    else
        scatter!(graph, points_random; legend = :none, color=color, markershape=:circle, legendfontsize=4, label="randoms", plot_params...)
    end
    scatter!(graph, points_child; label="children", color=color, markershape=:hexagon, plot_params...)
    scatter!(graph, points_mutant; label="mutants", color=color, markershape=:ltriangle, plot_params...)

    return graph
end

function get_plot_for_params(xparam, adn_list::Vector{<:AbstractAdn}, color::Colorant, custom_params, graph::Union{<:Plots.Plot, Nothing}=nothing)
    return get_plot_for_params(xparam, nothing, adn_list, color, custom_params, graph)
end

function get_plot_list_of_species_list(species_list::Vector{<:Species}, custom_params)
    len = length(species_list)

    if len > 1
        step = 1/(len-1)
        color_list = [RGB(x,1-x,0.5-abs(x-0.5)) for x in 0:step:1]
    else
        color_list = [RGB(0,1,0)]
    end
    @assert length(color_list) == length(species_list)

    species_list = sort(species_list, lt=is_better)


    plot_list = nothing
    for (species, color) in zip(species_list, color_list)
        adn_list = map(el->el.adn, species.enriched_adn_list)
        plot_list = get_plot_list_of_adn_list(adn_list, color, custom_params, plot_list)
    end

    return plot_list
end

function get_plot_list_of_adn_list(adn_list::Vector{<:AbstractAdn}, color::Colorant, custom_params, plot_list::Union{Vector{<:Plots.Plot}, Nothing}=nothing)
    result = Plots.Plot[]

    the_keys = collect(keys(custom_params.params_span))
    len = length(custom_params.params_span)
    if plot_list == nothing
        plot_list = [nothing for _ in 1:2:(len-1)]
    end

    for (plot, xparam, yparam) in zip(plot_list, the_keys[1:2:(len-1)], the_keys[2:2:len])
        plot = get_plot_for_params(xparam, yparam, adn_list, color, custom_params, plot)
        push!(result, plot)
    end

    if len%2 == 1
        plot = get_plot_for_params(the_keys[end], adn_list, color, custom_params, plot_list[end])
        push!(result, plot)
    end

    return result
end

function create_pics_of_history(history::Vector{Vector{Species{AdnType}}}, custom_params, dir_path="result") where AdnType<:AbstractAdn
    if ispath(dir_path)
        error("'$dir_path' already exists")
    else
        mkdir("$dir_path")
    end

    xlims = (custom_params.wanted_values[1][1], custom_params.wanted_values[end][1])
    yvalues = map(el->el[2], custom_params.wanted_values)
    ylims = (minimum(yvalues), maximum(yvalues))

    progress_time = Progress(length(history), "Time : ")

    last_best_score = -Inf
    number = 1

    for (generation, species_list) in enumerate(history)
        best_score = get_best_score(species_list)
        if best_score > last_best_score
            title = plot(title = "$generation : $best_score", grid = false, showaxis = false)
            species_plot_list = get_plot_list_of_species_list(species_list, custom_params)

            adn = get_best_adn(species_list)
            funct = get_adn_function(adn, custom_params)
            graph = plot(custom_params.wanted_values, label="Wanted", xlims=xlims, ylims=ylims, ls=:dash, linewidth=3)
            plot!(graph, funct, label="Result $generation")

            result = plot(title, plot(graph, species_plot_list...), layout=@layout([a{0.02h}; b{0.98h}]))
            formatted_number = format("{1:0>5}", number)
            savefig(result, "$dir_path/plot_$formatted_number.png")
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
    yvalues = map(el->el[2], custom_params.wanted_values)
    ylims = (minimum(yvalues), maximum(yvalues))

    progress_time = Progress(length(adn_list), "Time : ")

    last_adn = nothing
    number = 1
    for (generation, adn) in enumerate(adn_list)
        if last_adn != adn
            funct = get_adn_function(adn, custom_params)
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
