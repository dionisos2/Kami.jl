using SymPy
using Plots
using DifferentialEquations
using CSV
using StatsPlots
using StatsBase

export find_fit, get_scores, get_khi, create_adns, create_childs, generate_solution, display_result

function find_fit(wanted_values, equa_diff, func, variable, params_span, step=10, n_adns=100)
    adns = create_adns(params_span, n_adns)
    n_mutants = floor(Int, n_adns*0.2)
    n_childs = floor(Int, n_adns*0.1)
    n_parents = floor(Int, (n_adns-n_mutants-n_childs)*0.7)

    scores = get_scores(adns, wanted_values, equa_diff, func, variable)
    sort!(scores, by=el->el[2], rev=true)

    for generation in 1:step
        println(generation, "/", step)
        println("best = ", scores[end])

        scores = scores[n_mutants+n_childs:end]
        adns = [score[1] for score in scores]

        new_mutants = create_adns(params_span, n_mutants)
        new_childs = create_childs(adns, n_childs, n_parents)
        new_both = vcat(new_mutants, new_childs)

        new_scores = get_scores(new_both, wanted_values, equa_diff, func, variable)
        scores = vcat(scores, new_scores)
        sort!(scores, by=el->el[2], rev=true)
    end

    return scores[end]
end

function get_khi(values_sparce, values_dense)
    is, id = 1, 1
    ls, ld = length(values_sparce), length(values_dense)

    score = 0
    n = 1
    while (is < ls) && (id <= ld)
        vxs = values_sparce[is][1]
        vxd = values_dense[id][1]

        vys = values_sparce[is][2]
        vyd = values_dense[id][2]


        if vxd >= vxs
            gaps = values_sparce[is+1][1] - values_sparce[is][1]
            score += abs(vys-vyd)^2 * gaps
            is += 1
            n += 1
        end

        id += 1
    end

    gaps = values_sparce[end][1]-values_sparce[end-1][1]
    last_diff = abs(values_sparce[end][2]-values_dense[end][2])

    return score + last_diff^2 * gaps
end

function generate_solution(adn, wanted_values, equa_diff, func, variable)
    tspan = (Float64(wanted_values[1][1]), Float64(wanted_values[end][1]))
    u0 = Float64(wanted_values[1][2])

    f = subs(equa_diff, adn...)
    f = lambdify(f, (func, variable))
    F(u,_,t) = f(u,t)
    prob = ODEProblem(F,u0,tspan)

    sol = nothing
    try
        sol = DifferentialEquations.solve(prob, Euler(), alg_hints=[:stiff], dt=0.1, verbose=false)
    catch error
        if !isa(error, DomainError)
            rethrow()
        end
    end

    return sol
end

function display_result(adn, wanted_values, equa_diff, func, variable)
    sol = generate_solution(adn, wanted_values, equa_diff, func, variable)

    graph = plot(wanted_values, label="Wanted", ls=:dash, linewidth=3)
    plot!(graph, sol, label="Result")

    display(graph)
end


function get_scores(adns, wanted_values, equa_diff, func, variable)
    scores = []
    tspan = (Float64(wanted_values[1][1]), Float64(wanted_values[end][1]))
    u0 = Float64(wanted_values[1][2])

    for adn in adns
        f = subs(equa_diff, adn...)
        f = lambdify(f, (func, variable))
        F(u,_,t) = f(u,t)
        prob = ODEProblem(F,u0,tspan)

        adn_score = Inf
        try
            sol = DifferentialEquations.solve(prob, Euler(), alg_hints=[:stiff], dt=0.1, verbose=false)

            if sol.retcode == :Success
                getted_values = collect(zip(sol.t, sol.u))
                adn_score = get_khi(wanted_values, getted_values)
            else
                adn_score = Inf
            end
        catch error
            if !isa(error, DomainError)
                rethrow()
            end
        end

        push!(scores, (adn, adn_score))
    end

    return scores
end

function create_adns(params_span, n_adns)
    adns = []
    for _ in 1:n_adns
        adn = [(var, rand(span)) for (var, span) in params_span]
        push!(adns, adn)
    end
    return adns
end

function create_childs(adns, n_childs, n_parents)
    childs = []
    params = [param for (param, value) in adns[1]]

    for _ in 1:n_childs
        parents = sample(adns, n_parents, replace=false)
        child  = []

        for (i, param) in enumerate(params)
            param_value = 0
            for parent in parents
                param_value += parent[i][2]
            end
            push!(child, (param, param_value/n_parents))
        end

        push!(childs, child)
    end

    return childs
end
