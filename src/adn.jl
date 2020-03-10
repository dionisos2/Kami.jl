module Adn

using Parameters
using StatsBase
using Dates
using ProgressMeter
using Serialization

export AbstractAdn, Params, Species

export improve!, create_improve_generator, run_session, load_session
export create_random_list, create_mutant_list, create_child_list

export create_random_species, create_random_species_list
export delete_close_species, delete_bad_stagnant_species
export get_best_adn, get_best_score, get_adn_score_list, is_better

#API export
export action, create_random, mutate, create_child


abstract type AbstractAdn end

"All the necessary parameters for using this module"
@with_kw struct Params
    score_max::Float64 = 0
    duration_max::Period = Second(10)

    species_count::Int = 5
    adn_by_species::Int = 10
    stagnation_max::Int = 10

    random_ratio::Float64 = 0.1
    child_ratio::Float64 = 0.1
    mutant_ratio::Float64 = 0.4

end

mutable struct Species{AdnType<: AbstractAdn}
    adn_score_list::Vector{Tuple{AdnType, Float64}}
    params::Params
    custom_params
    stagnation_count::Int
end

Species(adn_score_list::Vector{Tuple{AdnType, Float64}}, params::Params, custom_params) where AdnType<:AbstractAdn = Species{AdnType}(adn_score_list, params, custom_params, 0)

function Species(adn_list::Vector{AdnType},
                 params::Params, custom_params) where AdnType<:AbstractAdn
    adn_score_list = [(adn, action(adn, custom_params)) for adn in adn_list]
    sort!(adn_score_list, by=el->el[2], rev=true)
    return Species{AdnType}(adn_score_list, params, custom_params, 0)
end

function Base.copy(species::Species)
    adn_score_list = deepcopy(species.adn_score_list)
    params = species.params
    custom_params = species.custom_params
    stagnation_count = species.stagnation_count
    return Species(adn_score_list, params, custom_params, stagnation_count)
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

"Check if adn1 and adn2 are close in term of their inherents properties"
is_close(adn1::AbstractAdn, adn2::AbstractAdn, custom_params)::Bool= throw(MissingException("is_close should be defined for concrete type of AbstractAdn"))

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

function create_random_species_list(AdnType::Type{<:AbstractAdn}, species_count::Int, params::Params, custom_params)
    return [create_random_species(AdnType, params, custom_params) for _ in 1:species_count]
end

function create_random_species(AdnType::Type{<:AbstractAdn}, params::Params, custom_params)
    adn_list = create_random_list(AdnType, params.adn_by_species, custom_params)
    return Species(adn_list, params, custom_params)
end

function improve!(species::Species{AdnType}) where AdnType<:AbstractAdn
    adn_count = species.params.adn_by_species
    mutant_ratio = species.params.mutant_ratio
    child_ratio = species.params.child_ratio
    random_ratio = species.params.random_ratio
    mutant_count = round(Int, adn_count*mutant_ratio)
    child_count = round(Int, adn_count*child_ratio)
    random_count = round(Int, adn_count*random_ratio)
    to_remove_count = mutant_count + child_count + random_count
    if to_remove_count >= adn_count
        throw(DomainError("mutant_ratio + child_ratio + random_ratio > 1"))
    end

    best_score = get_best_score(species)
    species.adn_score_list = species.adn_score_list[1:end-to_remove_count]
    best_adn_list = [adn_score[1] for adn_score in species.adn_score_list]

    custom_params = species.custom_params
    new_random_list = create_random_list(AdnType, random_count, custom_params)
    new_child_list = create_child_list(best_adn_list, child_count, custom_params)
    new_mutant_list = create_mutant_list(best_adn_list, mutant_count, custom_params)
    new_adn_list = [new_random_list; new_child_list; new_mutant_list]

    new_adn_score_list = [(adn, action(adn, custom_params)) for adn in new_adn_list]
    append!(species.adn_score_list, new_adn_score_list)
    sort!(species.adn_score_list, by=el->el[2], rev=true)

    new_best = get_best_score(species)
    if new_best == best_score
        species.stagnation_count += 1
    end
end

function delete_close_species(species_list::Vector{SpeciesType}) where SpeciesType<:Species
    new_species_list = SpeciesType[]
    if length(species_list)==0
        error("delete_close_species : species_list should not be empty")
    end

    custom_params = species_list[1].custom_params

    for species1 in species_list
        if all(is_better(species1, species2) || !is_close(species1, species2) for species2 in species_list if species1!=species2)
            push!(new_species_list, species1)
        end
    end

    sort!(new_species_list, lt=is_better)
    return new_species_list
end


function is_close(species1::Species, species2::Species)
    return is_close(get_best_adn(species1), get_best_adn(species2), species1.custom_params)
end

function is_better(species1::Species, species2::Species)
    return get_best_score(species1) >= get_best_score(species2)
end

function delete_bad_stagnant_species(species_list::Vector{<:Species})
    if length(species_list)==0
        error("delete_bad_stagnant_species : species_list should not be empty")
    end

    max_st = species_list[1].params.stagnation_max

    middle = div(length(species_list), 2)
    species_list = sort(species_list, lt=is_better)

    bad_species = filter(species->species.stagnation_count < max_st, species_list[middle+1:end])
    return [species_list[1:middle]; bad_species]
end

function get_adn_score_list(species_list::Vector{Species{AdnType}}) where AdnType <: AbstractAdn
    adn_score_list = Tuple{AdnType, Float64}[]

    for species in species_list
        append!(adn_score_list, species.adn_score_list)
    end
    sort!(adn_score_list, by=el->el[2], rev=true)
    return adn_score_list
end

get_best_score(adn_score_list::Vector{Tuple{AdnType, Float64}}) where AdnType<:AbstractAdn = adn_score_list[1][2]
get_best_adn(adn_score_list::Vector{Tuple{AdnType, Float64}}) where AdnType<:AbstractAdn = adn_score_list[1][1]

get_best_score(species::Species) = get_best_score(species.adn_score_list)
get_best_adn(species::Species) = get_best_adn(species.adn_score_list)

get_best_score(species_list::Vector{<:Species}) = get_best_score(get_adn_score_list(species_list))
get_best_adn(species_list::Vector{<:Species}) = get_best_adn(get_adn_score_list(species_list))


get_best_score(history::Vector{Vector{Species{AdnType}}}) where AdnType<:AbstractAdn = get_best_adn_score(history)[2]
get_best_adn(history::Vector{Vector{Species{AdnType}}}) where AdnType<:AbstractAdn = get_best_adn_score(history)[1]


function get_best_adn_score(history::Vector{Vector{Species{AdnType}}}) where AdnType<:AbstractAdn
    best_score = -Inf
    best_adn = nothing

    for species_list in history
        current_score = get_best_score(species_list)
        if current_score >= best_score
            best_score = current_score
            best_adn = get_best_adn(species_list)
        end
    end

    return (best_adn, best_score)
end

"Improve a list of adn, until we get something bigger than score_max or until duration_max passed"
function create_improve_generator(AdnType::Type{<:AbstractAdn}, params::Params, custom_params)
    @unpack score_max, duration_max, species_count = params

    best_score = -Inf
    start_date = now()
    duration = now()-start_date
    generation = 1

    function producer(c::Channel)
        species_list = create_random_species_list(AdnType, species_count, params, custom_params)
        adn_score_list = get_adn_score_list(species_list)
        best_score = get_best_score(adn_score_list)

        put!(c, (species_list=species_list, duration=duration, params=params, custom_params=custom_params))

        while ((best_score < score_max) && (duration < duration_max))
            for species in species_list
                improve!(species)
            end

            species_list = delete_close_species(species_list)
            species_list = delete_bad_stagnant_species(species_list)

            species_to_add = species_count - length(species_list)
            new_species = create_random_species_list(AdnType, species_to_add, params, custom_params)
            append!(species_list, new_species)

            adn_score_list = get_adn_score_list(species_list)

            generation += 1
            best_score = get_best_score(adn_score_list)
            duration = now()-start_date
            put!(c, (species_list=species_list, duration=duration, params=params, custom_params=custom_params))
            sleep(0.01)
        end
    end

    return Channel(producer)
end


"Run a search, and save results in 'file_path'"
function run_session(AdnType::Type{<:AbstractAdn}, params::Params, custom_params;
                     file_path::String="current_session")
    progress_time = Progress(Millisecond(params.duration_max).value, "Time : ")
    generator = create_improve_generator(AdnType, params, custom_params)

    serialize(file_path, (params, custom_params))

    for (generation, result) in enumerate(generator)
        best_score = get_best_score(result[:species_list])
        to_show = [
            ("generation", generation)
            ("best score", "$best_score/$(params.score_max)")
        ]
        update!(progress_time, Millisecond(result[:duration]).value, showvalues = to_show)

        open(file_path, "a") do file
            serialize(file, result[:species_list])
        end

    end
end

function load_session(file_path="current_session")
    history = []
    params, custom_params = nothing, nothing

    open("current_session", "r") do file
        (params, custom_params) = deserialize(file)
        while !eof(file)
            push!(history, deserialize(file))
        end
    end

    # We want to have a specific container
    SpeciesType = typeof(history[1][1])
    history = convert(Vector{Vector{SpeciesType}}, history)

    return (history, params, custom_params)
end

end
