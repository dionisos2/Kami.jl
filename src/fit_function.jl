module FitFunction

using AutoHashEquals
using ..Kami
using ..Kami.Adn
Adn = Kami.Adn

const FunctionGraph = Union{Vector{Tuple{Float64, Float64}}, Vector{Vector{Float64}}}

export FunctionParams, FunctionAdn
# export action, create_random, mutate, create_child

@auto_hash_equals struct FunctionParams
    funct
    mutate_max_speed::Float64
    wanted_values::FunctionGraph
    close_range::Float64
    params_span::Vector{StepRangeLen}
end

const DEFAULT_FUNCT = x->x
const DEFAULT_MUTATE_MAX_SPEED = 0.5
const DEFAULT_CLOSE_RANGE = DEFAULT_MUTATE_MAX_SPEED*5
const DEFAULT_WANTED_VALUES = Tuple{Float64,Float64}[]


function FunctionParams(params_span::Vector{<:StepRangeLen};
                        funct=DEFAULT_FUNCT,
                        mutate_max_speed=DEFAULT_MUTATE_MAX_SPEED,
                        close_range=DEFAULT_CLOSE_RANGE,
                        wanted_values=DEFAULT_WANTED_VALUES)
    return FunctionParams(funct, mutate_max_speed, wanted_values, close_range, params_span)
end

function FunctionParams(params_span::StepRangeLen...;
                        funct=DEFAULT_FUNCT,
                        mutate_max_speed=DEFAULT_MUTATE_MAX_SPEED,
                        close_range=DEFAULT_CLOSE_RANGE,
                        wanted_values=DEFAULT_WANTED_VALUES)
    return FunctionParams(funct, mutate_max_speed, wanted_values, close_range, collect(params_span))
end

Base.getindex(params::FunctionParams, key::Int) = params.params_span[key]

@auto_hash_equals struct FunctionAdn <: AbstractAdn
    params::Vector{Float64}
    type::String
end

FunctionAdn(params::Vector{<:Real}; type="default") = FunctionAdn(params, type)

FunctionAdn(params::Real...; type="default") = FunctionAdn(collect(params), type)

Base.getindex(adn::FunctionAdn, key::Int) = adn.params[key]
Base.copy(adn::FunctionAdn) = FunctionAdn(Base.copy(adn.params), adn.type)
copy(adn::FunctionAdn, type::String) = FunctionAdn(Base.copy(adn.params), type)

function Adn.action(adn::FunctionAdn, custom_params::FunctionParams)::Float64
    funct(x) = custom_params.funct(x, adn.params)
    actual_values = [(x, funct(x)) for (x,_) in custom_params.wanted_values]

    return get_score(custom_params.wanted_values, actual_values)
end

function Adn.create_random(_::Type{FunctionAdn}, custom_params::FunctionParams)::FunctionAdn
    params = Float64[]
    for param_span in custom_params.params_span
        push!(params, rand(param_span))
    end

    return FunctionAdn(params, type="random")
end

function Adn.mutate(adn::FunctionAdn, custom_params::FunctionParams)::FunctionAdn
    adn_res = copy(adn, "mutant")
    msp = custom_params.mutate_max_speed

    for (index, param) in enumerate(adn.params)
        adn_res.params[index] = param + rand(-msp:eps():msp)
        if adn_res.params[index] > maximum(custom_params[index])
            adn_res.params[index] = maximum(custom_params[index])
        end

        if adn_res.params[index] < minimum(custom_params[index])
            adn_res.params[index] = minimum(custom_params[index])
        end
    end

    return adn_res
end

function Adn.create_child(parents::Vector{FunctionAdn}, custom_params)::FunctionAdn
    if isempty(parents)
        throw(DomainError("parents should not be empty"))
    end

    adn_res = copy(parents[1], "child")
    len = length(parents)

    for (index, param) in enumerate(custom_params.params_span)
        adn_res.params[index] = sum(el->el[index], parents)/len
    end

    return adn_res
end

function Adn.is_close(adn1::FunctionAdn, adn2::FunctionAdn, custom_params::FunctionParams)
    distance = sum(abs(param1-param2) for (param1,param2) in zip(adn1.params, adn2.params))
    return distance <= custom_params.close_range
end

end
