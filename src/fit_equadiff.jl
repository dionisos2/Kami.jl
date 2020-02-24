using SymPy
using DifferentialEquations
using Parameters

export EqDiffAdn, EqDiffParams
export action, create_random, mutate, create_child


struct EqDiffAdn <: AbstractAdn
    params::Dict{Sym, Float64}
end


#AbstractArray{Tuple{Sym, T} where T<:Real} invalide because Array{Tuple{Int,Float64},1} <: AbstractArray{Tuple{Int, <:Real}}
const ArrayCouple1 = AbstractArray{Tuple{Sym, T}} where T<:Real
EqDiffAdn(params::ArrayCouple1) = EqDiffAdn(Dict{Sym, Float64}(params))
EqDiffAdn(params::Pair{Sym, <:Real}...) = EqDiffAdn(Dict{Sym, Float64}(params))
Base.getindex(adn::EqDiffAdn, key::Sym) = adn.params[key]


"""
ex : EqDiffParams(x=>0:1:10, y=>-10:esp():5)
Take care of the fact mutation will choose between all 0:eps():10 for x, and not 0:1:10
"""
struct EqDiffParams
    mutate_max_speed::Float64
    dfunct::Union{Sym, Real}
    funct::Union{Sym, Nothing}
    variable::Union{Sym, Nothing}
    wanted_values::Union{Vector{Tuple{Float64, Float64}}, Vector{Vector{Float64}}}

    params_span::Dict{Sym, StepRangeLen}
end


const DEFAULT_MUTATE_MAX_SPEED = 0.5
const DEFAULT_DFUNCT = 1
const DEFAULT_FUNCT = nothing
const DEFAULT_VARIABLE = nothing
const DEFAULT_WANTED_VALUES = Tuple{Float64, Float64}[]
const ArrayCouple2 = AbstractArray{Tuple{Sym, T}} where T<:StepRangeLen

function EqDiffParams(params_span::Union{ArrayCouple2, Dict{Sym, <:StepRangeLen}};
                      mutate_max_speed=DEFAULT_MUTATE_MAX_SPEED,
                      dfunct=DEFAULT_DFUNCT,
                      funct=DEFAULT_FUNCT,
                      variable=DEFAULT_VARIABLE,
                      wanted_values = DEFAULT_WANTED_VALUES)
    return EqDiffParams(mutate_max_speed, dfunct, funct, variable, wanted_values, Dict(params_span))
end

function EqDiffParams(params_span::Pair{Sym, <:StepRangeLen}...;
                      mutate_max_speed=DEFAULT_MUTATE_MAX_SPEED,
                      dfunct=DEFAULT_DFUNCT,
                      funct=DEFAULT_FUNCT,
                      variable=DEFAULT_VARIABLE,
                      wanted_values = DEFAULT_WANTED_VALUES)
    return EqDiffParams(mutate_max_speed, dfunct, funct, variable, wanted_values, Dict(params_span))
end

Base.getindex(params::EqDiffParams, key::Sym) = params.params_span[key]


function action(adn::AbstractAdn, custom_params::EqDiffParams):Float64
    sol = generate_solution(adn, custom_params)
    wanted_values = custom_params.wanted_values

    if sol.retcode == :Success
        actual_values = collect(zip(sol.t, sol.u))
        adn_score = get_score(wanted_values, actual_values)
    else
        adn_score = -Inf
    end

    return adn_score
end

function create_random(::Type{EqDiffAdn}, custom_params::EqDiffParams)::EqDiffAdn
    adn = EqDiffAdn()

    for param in custom_params.params_span
        adn.params[param.first] = rand(param.second)
    end

    return adn
end

"Take care of the fact mutation will choose between all 0:eps():10 for a StepRangeLen of 0:0.5:10"
function mutate(adn::EqDiffAdn, custom_params::EqDiffParams)::EqDiffAdn
    adn_res = EqDiffAdn()
    msp = custom_params.mutate_max_speed

    for param in adn.params
        adn_res.params[param.first] = param.second + rand(-msp:eps():msp)
        if adn_res.params[param.first] > maximum(custom_params[param.first])
            adn_res.params[param.first] = maximum(custom_params[param.first])
        end

        if adn_res.params[param.first] < minimum(custom_params[param.first])
            adn_res.params[param.first] = minimum(custom_params[param.first])
        end
    end

    return adn_res
end

function create_child(parents::Vector{EqDiffAdn}, custom_params)::EqDiffAdn
    if isempty(parents)
        throw(DomainError("parents should not be empty"))
    end

    adn_res = EqDiffAdn()
    len = length(parents)

    for param in custom_params.params_span
        adn_res.params[param.first] = sum(el->el[param.first], parents)/len
    end

    return adn_res
end

function generate_solution(adn::EqDiffAdn, custom_params::EqDiffParams)
    if isempty(custom_params.wanted_values)
        throw(DomainError("you should choose at least one wanted_values to be able to generate a solution"))
    end

    tspan = (Float64(custom_params.wanted_values[1][1]), Float64(custom_params.wanted_values[end][1]))
    f0 = custom_params.wanted_values[1][2]

    funct = subs(custom_params.dfunct, adn.params...)
    lambdified_funct = lambdify(funct, (custom_params.funct, custom_params.variable))
    correct_funct(f,_,t) = lambdified_funct(f,t)

    prob = ODEProblem(correct_funct, f0, tspan)
    sol = nothing

    try
        sol = DifferentialEquations.solve(prob, Euler(), alg_hints=[:stiff], dt=0.01, verbose=false)
    catch error
        if !isa(error, DomainError)
            rethrow()
        end
    end

    return sol
end

function get_score(values_sparce, values_dense)
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

    return -(score + last_diff^2 * gaps)
end


# function each_gen(adn_score_list::Vector{Tuple{EqDiffAdn,Float64}},
#                   best_score::Float64,
#                   duration::Period,
#                   generation::Int,
#                   params::Kami.Params,
#                   custom_params::EqDiffParams)
# end
