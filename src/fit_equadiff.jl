using SymPy
using DifferentialEquations
using Parameters

export EqDiffAdn, EqDiffParams
export action, create_random, mutate, create_child


struct EqDiffAdn <: AbstractAdn
    params::Dict{Sym, Float64}
end
const ArrayCouple1 = AbstractArray{Tuple{Sym, T}} where T<:Real
EqDiffAdn(params::ArrayCouple1) = EqDiffAdn(Dict{Sym, Float64}(params))
EqDiffAdn(params::Pair{Sym, <:Real}...) = EqDiffAdn(Dict{Sym, Float64}(params))
Base.getindex(adn::EqDiffAdn, key::Sym) = adn.params[key]


struct EqDiffParams
    mutate_max_speed::Float64
    params_span::Dict{Sym, StepRangeLen}
end


const DEFAULT_MUTATE_MAX_SPEED=5.0
const ArrayCouple2 = AbstractArray{Tuple{Sym, T}} where T<:StepRangeLen
EqDiffParams(params_span::ArrayCouple2; mutate_max_speed=DEFAULT_MUTATE_MAX_SPEED) = EqDiffParams(mutate_max_speed, Dict(params_span))
EqDiffParams(params_span::Pair{Sym, <:StepRangeLen}...; mutate_max_speed=DEFAULT_MUTATE_MAX_SPEED) = EqDiffParams(mutate_max_speed, Dict(params_span))
EqDiffParams(params_span::Dict{Sym, <:StepRangeLen}; mutate_max_speed=DEFAULT_MUTATE_MAX_SPEED) = EqDiffParams(mutate_max_speed, params_span)

Base.getindex(params::EqDiffParams, key::Sym) = params.params_span[key]



function action(adn::EqDiffAdn, custom_params::EqDiffParams)::Float64
end

function create_random(::Type{EqDiffAdn}, custom_params::EqDiffParams)::EqDiffAdn
    adn = EqDiffAdn()

    for param in custom_params.params_span
        adn.params[param.first] = rand(param.second)
    end

    return adn
end

function mutate(adn::EqDiffAdn, custom_params)::EqDiffAdn
    return adn
end

function create_child(parents::Vector{EqDiffAdn}, custom_params)::EqDiffAdn
end

# function each_gen(adn_score_list::Vector{Tuple{EqDiffAdn,Float64}},
#                   best_score::Float64,
#                   duration::Period,
#                   generation::Int,
#                   params::Kami.Params,
#                   custom_params::EqDiffParams)
# end
