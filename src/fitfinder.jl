using SymPy
using Plots
using DifferentialEquations
using CSV
using StatsPlots
using StatsBase

export find_fit, get_scores, get_khi, create_adns, create_childs

function find_fit(values, equa_diff, func, variable, params_span, step=10, n_adns=100)
    adns = create_adns(params_span, n_adns)
    n_mutants = floor(Int, n_adns*0.15)
    n_childs = floor(Int, n_adns*0.15)
    n_parents = floor(Int, (n_adns-n_mutants-n_childs)*0.3)

    for i in 1:step
        scores = get_scores(adns, values, equa_diff, func, variable)
        sort!(scores, by=el->el[2])
        println("best = ", scores[end])

        scores = scores[n_mutants+n_childs:end]
        adns = [score[1] for score in scores]

        new_mutants = create_adns(params_span, n_mutants)
        new_childs = create_childs(adns, n_childs, n_parents)
        adns = vcat(new_mutants, new_childs, adns)
    end

    return scores[end]
end

function get_khi(values1, values2)
    return 10
end

function get_scores(adns, values, equa_diff, func, variable)
    scores = []
    tspan = (Float64(values[1][1]), Float64(values[end][1]))
    u0 = Float64(values[1][2])

    for adn in adns
        f = subs(equa_diff, adn...)
        f = lambdify(f, (func, variable))
        F(u,_,t) = f(u,t)
        prob = ODEProblem(F,u0,tspan)

        adn_score = -Inf
        try
            sol = DifferentialEquations.solve(prob, Euler(), dt=0.01, verbose=false)
            adn_score = get_khi(values, sol)
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
