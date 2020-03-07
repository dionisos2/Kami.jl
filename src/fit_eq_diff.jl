module FitEqDiff

using AutoHashEquals
using ..Kami
using ..Kami.Adn
Adn = Kami.Adn

using SymEngine
using DifferentialEquations
using Parameters

export EqDiffAdn, EqDiffParams
# export action, create_random, mutate, create_child
export generate_solution, get_score

""" ! Don’t use :I as a variable name ! """
@auto_hash_equals struct EqDiffAdn <: AbstractAdn
    params::Dict{Symbol, Float64}
    type::String
end


#AbstractArray{Tuple{Symbol, T} where T<:Real} invalide because Array{Tuple{Int,Float64},1} <: AbstractArray{Tuple{Int, <:Real}}
const ArrayCouple1 = AbstractArray{Tuple{Symbol, T}} where T<:Real

EqDiffAdn(params::Dict{Symbol, Float64}; type="default") = EqDiffAdn(params, type)
EqDiffAdn(params::ArrayCouple1; type="default") = EqDiffAdn(Dict{Symbol, Float64}(params), type)
EqDiffAdn(params::Pair{Symbol, <:Real}...; type="default") = EqDiffAdn(Dict{Symbol, Float64}(params), type)
Base.getindex(adn::EqDiffAdn, key::Symbol) = adn.params[key]


const FunctionGraph = Union{Vector{Tuple{Float64, Float64}}, Vector{Vector{Float64}}}

"""
ex : EqDiffParams(x=>0:1:10, y=>-10:esp():5)
Take care of the fact mutation will choose between all 0:eps():10 for x, and not 0:1:10
"""
@auto_hash_equals struct EqDiffParams
    mutate_max_speed::Float64
    close_range::Float64

    "dfunct should be a sym representing a differential equation (ex dI/dt=2*I → dfunct=dI and funct=I)"
    dfunct::Union{Symbol, Real}
    funct::Union{Symbol, Nothing}
    variable::Union{Symbol, Nothing}

    "dvariable (often called dt), is the size of each step on the abscissa used to approximate the solution of the differential equation"
    dvariable::Float64
    wanted_values::FunctionGraph

    params_span::Dict{Symbol, StepRangeLen}
end

const DEFAULT_MUTATE_MAX_SPEED = 0.5
const DEFAULT_CLOSE_RANGE = DEFAULT_MUTATE_MAX_SPEED*5
const DEFAULT_DFUNCT = 1
const DEFAULT_FUNCT = nothing
const DEFAULT_VARIABLE = nothing
const DEFAULT_DVARIABLE = 0.1
const DEFAULT_WANTED_VALUES = Tuple{Float64, Float64}[]
const ArrayCouple2 = AbstractArray{Tuple{Symbol, T}} where T<:StepRangeLen

function EqDiffParams(params_span::Union{ArrayCouple2, Dict{Symbol, <:StepRangeLen}};
                      mutate_max_speed::Float64=DEFAULT_MUTATE_MAX_SPEED,
                      close_range=DEFAULT_CLOSE_RANGE,
                      dfunct::Union{Symbol, Real}=DEFAULT_DFUNCT,
                      funct::Union{Symbol, Nothing}=DEFAULT_FUNCT,
                      variable::Union{Symbol, Nothing}=DEFAULT_VARIABLE,
                      dvariable::Float64=DEFAULT_DVARIABLE,
                      wanted_values::FunctionGraph = DEFAULT_WANTED_VALUES)
    return EqDiffParams(mutate_max_speed, close_range, dfunct, funct, variable, dvariable, wanted_values, Dict(params_span))
end

function EqDiffParams(params_span::Pair{Symbol, <:StepRangeLen}...;
                      mutate_max_speed::Float64=DEFAULT_MUTATE_MAX_SPEED,
                      close_range=DEFAULT_CLOSE_RANGE,
                      dfunct::Union{Symbol, Real}=DEFAULT_DFUNCT,
                      funct::Union{Symbol, Nothing}=DEFAULT_FUNCT,
                      variable::Union{Symbol, Nothing}=DEFAULT_VARIABLE,
                      dvariable::Float64=DEFAULT_DVARIABLE,
                      wanted_values::FunctionGraph = DEFAULT_WANTED_VALUES)
    return EqDiffParams(mutate_max_speed, close_range, dfunct, funct, variable, dvariable, wanted_values, Dict(params_span))
end

Base.getindex(params::EqDiffParams, key::Symbol) = params.params_span[key]


function Adn.action(adn::AbstractAdn, custom_params::EqDiffParams):Float64
    sol = generate_solution(adn, custom_params)
    wanted_values = custom_params.wanted_values

    if (sol != nothing) && (sol.retcode == :Success)
        actual_values = collect(zip(sol.t, sol.u))
        adn_score = get_score(wanted_values, actual_values)
    else
        adn_score = -Inf
    end

    return adn_score
end

function Adn.create_random(::Type{EqDiffAdn}, custom_params::EqDiffParams)::EqDiffAdn
    adn = EqDiffAdn(;type="random")

    for param in custom_params.params_span
        adn.params[param.first] = rand(param.second)
    end

    return adn
end

"Take care of the fact mutation will choose between all 0:eps():10 for a StepRangeLen of 0:0.5:10"
function Adn.mutate(adn::EqDiffAdn, custom_params::EqDiffParams)::EqDiffAdn
    adn_res = EqDiffAdn(;type="mutant")
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

function Adn.create_child(parents::Vector{EqDiffAdn}, custom_params)::EqDiffAdn
    if isempty(parents)
        throw(DomainError("parents should not be empty"))
    end

    adn_res = EqDiffAdn(;type="child")
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

    adn_params = Dict([(SymEngine._symbol(key)=>value) for (key, value) in adn.params])
    variable = SymEngine._symbol(custom_params.variable)
    dfunct = Basic(custom_params.dfunct)
    funct = SymEngine._symbol(custom_params.funct)

    dfunct = subs(dfunct, adn_params...)

    lambdified_funct = lambdify(dfunct, (funct, variable))
    correct_funct(f,_,t) = lambdified_funct(f,t)


    prob = ODEProblem(correct_funct, f0, tspan)
    sol = nothing

    begin
    try
        sol = DifferentialEquations.solve(prob, Euler(), alg_hints=[:stiff], dt=custom_params.dvariable, verbose=false)
        # sol = DifferentialEquations.solve(prob, Rosenbrock23(autodiff=false), dt=custom_params.dvariable, verbose=false)
    catch error
        if !isa(error, DomainError)
            rethrow()
        end
    end
    end

    return sol
end

function Adn.is_close(adn1::EqDiffAdn, adn2::EqDiffAdn, custom_params::EqDiffParams)::Bool
    distance = sum(abs(adn1[key]-adn2[key]) for key in keys(adn1.params))
    return distance <= custom_params.close_range
end

end
