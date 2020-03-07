module Adn

using Parameters
using StatsBase
using Dates
using ProgressMeter
using Serialization

export AbstractAdn, Params
export create_improve_generator, run_session, load_session
export create_random_list, create_mutant_list, create_child_list

#API export
export action, create_random, mutate, create_child


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
function print_generation_result(adn_score_list::Vector{Tuple{T,Float64}}, best_score::Float64, duration::Period, generation::Int, params::Params, custom_params) where T<:AbstractAdn
    println("-"^10,"GENERATION:",generation,"-"^10)
    println("score = ", best_score, "/", params.score_max)
    println("duration = ", duration.value/1000, "/", params.duration_max)
    println(adn_score_list[1])
end

# ---------- API end ----------

function create_random_list(AdnType::Type{<:AbstractAdn}, count, custom_params)
    return [create_random(AdnType, custom_params) for _ in 1:count]
end

function create_mutant_list(adn_list::Vector{<:AbstractAdn}, count, custom_params)
    mutant_list = []
    len = length(adn_list)

    for index in 0:count-1
        push!(mutant_list, mutate(adn_list[(index%len)+1], custom_params))
    end

    return mutant_list
end

function create_child_list(adn_list::Vector{<:AbstractAdn}, count, custom_params)
    return [create_child(adn_list, custom_params) for _ in 1:count]
end

# function create_improve_generator2()
#     while ok
#         for species in species_list
#             improve(species)
#         end

#         delete_close_species!(species_list)
#         delete_bad_stagnant_species!(species_list)

#         species_to_add = species_count - length(species_list)
#         new_species = create_new_species_list(species_to_add)
#         append!(species_list, new_species)

#         adn_score_list = map(get_adn_score_list, species_list)
#         sort!(adn_score_list)
#     end
# end

"Improve a list of adn, until we get something bigger than score_max or until duration_max passed"
function create_improve_generator(AdnType::Type{<:AbstractAdn}, params::Params, custom_params)
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
    generation = 1


    function producer(c::Channel)
        adn_score_list = [(adn, action(adn, custom_params)) for adn in adn_list]
        sort!(adn_score_list, by=el->el[2], rev=true)
        best_score = adn_score_list[1][2]
        put!(c, (adn_score_list=adn_score_list, best_score=best_score, duration=duration, generation=generation, params=params, custom_params=custom_params))

        while ((best_score < score_max) && (duration < duration_max))
            adn_score_list = adn_score_list[1:end-to_remove_count]
            best_adn_list = [adn_score[1] for adn_score in adn_score_list]

            new_random_list = create_random_list(AdnType, random_count, custom_params)
            new_child_list = create_child_list(best_adn_list, child_count, custom_params)
            new_mutant_list = create_mutant_list(best_adn_list, mutant_count, custom_params)
            new_adn_list = [new_random_list; new_child_list; new_mutant_list]

            new_adn_score_list = [(adn, action(adn, custom_params)) for adn in new_adn_list]
            adn_score_list = [adn_score_list; new_adn_score_list]
            sort!(adn_score_list, by=el->el[2], rev=true)

            generation += 1
            best_score = adn_score_list[1][2]
            duration = now()-start_date
            put!(c, (adn_score_list=adn_score_list, best_score=best_score, duration=duration, generation=generation, params=params, custom_params=custom_params))
            sleep(0.01)
        end
    end

    channel = Channel(producer)
    return channel
end

"Run a search, and save results in 'file_path'"
function run_session(AdnType::Type{<:AbstractAdn}, params::Params, custom_params;
                     file_path::String="current_session")
    progress_time = Progress(Millisecond(params.duration_max).value, "Time : ")
    generator = create_improve_generator(AdnType, params, custom_params)

    serialize(file_path, (params, custom_params))

    for result in generator
        to_show = [
            ("generation", result[:generation])
            ("best score", "$(result[:best_score]))/$(params.score_max)")
        ]
        update!(progress_time, Millisecond(result[:duration]).value, showvalues = to_show)

        open(file_path, "a") do file
            serialize(file, result[:adn_score_list])
        end

    end
end

function load_session(file_path="current_session")
    history = Vector{Tuple{AbstractAdn, Float64}}[]
    params, custom_params = nothing, nothing

    open("current_session", "r") do file
        (params, custom_params) = deserialize(file)
        while !eof(file)
            push!(history, deserialize(file))
        end
    end

    return (history, params, custom_params)
end

end
