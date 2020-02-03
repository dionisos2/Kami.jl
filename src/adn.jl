using Parameters
using StatsBase
using Dates

export AbstractAdn, improve_until, create_random_list, create_mutant_list, create_child_list


abstract type AbstractAdn end

"All the necessary parameters for using this module"
@with_kw struct Params
    score_max::Float64 = 0
    duration_max::Period = Second(10)
    "number of adns in each generation"
    adn_count::Int64 = 20
    random_ratio::Float64 = 0.1
    child_ratio::Float64 = 0.1
    mutant_ratio::Float64 = 0.2
end

# ---------- API start ----------

# The parentheses in (f(x::T)::T) where T are here because otherwise it throw an error.

"Make the adn do something return the score of the adn (bigger = better)"
action(adn::AbstractAdn, custom_params)::Float64 = throw(MissingException("action should be defined for concrete type of AbstractAdn"))


"Create a adn with random property"
(create_random(_::Type{T}, custom_params)::T) where T<:AbstractAdn = throw(MissingException("create_random should be defined for concrete type of AbstractAdn"))

"Mutate a adn"
(mutate(adn::T, custom_params)::T) where T<:AbstractAdn = throw(MissingException("mutate should be defined for concrete type of AbstractAdn"))

"Create a child adn from parents"
(create_child(parents::Vector{T}, custom_params)::T) where T<:AbstractAdn = throw(MissingException("create_child should be defined for concrete type of AbstractAdn"))

"Whatever you want to show at each generation"
function each_gen(adn_score_list::Vector{Tuple{T,Float64}}, best_score::Float64, duration::Period, generation::Int, params::Params, custom_params) where T<:AbstractAdn
    println("-"^10,"GENERATION:",generation,"-"^10)
    println(best_score, "/", params.score_max)
    println(duration.value/1000, "/", params.duration_max)
    println(adn_score_list)
end

# ---------- API end ----------

function create_random_list(AdnType::Type{<:AbstractAdn}, count, custom_params)
    return [create_random(AdnType, custom_params) for _ in 1:count]
end

function create_mutant_list(adn_list::Vector{<:AbstractAdn}, count, custom_params)
    mutant_list = []
    len = length(adn_list)

    for index in 0:count-1
        push!(mutant_list, mutate(adn_list[(index%len)+1]))
    end

    return mutant_list
end

function create_child_list(adn_list::Vector{<:AbstractAdn}, count, custom_params)
    return [create_child(adn_list, custom_params) for _ in 1:count]
end

"Improve a list of adn, until we get something bigger than score_max or until duration_max passed"
function improve_until(AdnType::Type{<:AbstractAdn}, params::Params, custom_params)
    @unpack score_max, duration_max, adn_count, random_ratio, child_ratio, mutant_ratio = params

    adn_list = create_random_list(AdnType, adn_count, custom_params)
    mutant_count = floor(Int, adn_count*mutant_ratio)
    child_count = floor(Int, adn_count*child_ratio)
    random_count = floor(Int, adn_count*random_ratio)

    to_remove_count = mutant_count + child_count + random_count

    if to_remove_count >= adn_count
        throw(DomainError("mutant_ratio + child_ratio + random_ratio > 1"))
    end

    best_score = -Inf
    start_date = now()
    duration = now()-start_date
    generation = 0

    while ((best_score < score_max) && (duration < duration_max))
        adn_score_list = [(adn, action(adn, custom_params)) for adn in adn_list]
        sort!(adn_score_list, by=el->el[2], rev=true)

        generation += 1
        best_score = adn_score_list[1][2]
        duration = now()-start_date
        each_gen(adn_score_list, best_score, duration, generation, params, custom_params)

        adn_score_list = adn_score_list[1:end-to_remove_count]
        best_adn_list = [adn_score[1] for adn_score in adn_score_list]

        new_random_list = create_random_list(AdnType, random_count, custom_params)
        new_child_list = create_child_list(best_adn_list, child_count, custom_params)
        new_mutant_list = create_mutant_list(best_adn_list, mutant_count, custom_params)

        adn_list = vcat(best_adn_list, new_random_list, new_child_list, new_mutant_list)


    end

    return adn_list
end
