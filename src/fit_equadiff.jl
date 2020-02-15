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
end

# function each_gen(adn_score_list::Vector{Tuple{EqDiffAdn,Float64}},
#                   best_score::Float64,
#                   duration::Period,
#                   generation::Int,
#                   params::Kami.Params,
#                   custom_params::EqDiffParams)
# end
