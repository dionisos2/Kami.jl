using SymPy
using DifferentialEquations

export EqDiffAdn, EqDiffParams
export action, create_random, mutate, create_child

struct EqDiffAdn <: AbstractAdn
    params::Dict{Sym, Float64}
end

EqDiffAdn(params::Vector) = EqDiffAdn(Dict(params))

struct EqDiffParams
    params_span::Dict{Sym, StepRangeLen}
end

EqDiffParams(params_span::Vector) = EqDiffParams(Dict(params_span))

function action(adn::EqDiffAdn, custom_params::EqDiffParams)::Float64
end

function create_random(::Type{EqDiffAdn}, custom_params::EqDiffParams)::EqDiffParams
end

function mutate(adn::EqDiffAdn, custom_params)::EqDiffAdn
end

function create_child(parents::Vector{EqDiffAdn}, custom_params)::EqDiffAdn
end

# function each_gen(adn_score_list::Vector{Tuple{EqDiffAdn,Float64}}, best_score::Float64, duration::Period, generation::Int, params::Kami.Params, custom_params::EqDiffParams)
# end
