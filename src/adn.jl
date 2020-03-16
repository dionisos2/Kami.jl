module Adn

using Parameters
using StatsBase
using Dates
using ProgressMeter
using Serialization

export AbstractAdn, Params, EnrichedAdn, Species

export improve!, create_improve_generator, run_session, load_session
export create_random_list, create_mutant_list, create_child_list

export create_random_species, create_random_species_list
export delete_close_species, delete_bad_stagnant_species
export get_best_adn, get_best_score, get_enriched_adn_list, is_better

#API export
export action, create_random, mutate, create_child


abstract type AbstractAdn end

mutable struct EnrichedAdn{AdnType<:AbstractAdn}
    adn::AdnType
    score::Float64
    good_mutation::Any
    good_mutation_count::Int
end

EnrichedAdn(adn::AbstractAdn, custom_params) = EnrichedAdn(adn, action(adn, custom_params), nothing, 0)

"All the necessary parameters for using this module"
@with_kw struct Params
    score_max::Float64 = 0
    duration_max::Period = Second(10)

    species_count::Int = 7
    adn_by_species::Int = 10
    stagnation_max::Int = 20

    random_ratio::Float64 = 0.1
    child_ratio::Float64 = 0.1
    mutant_ratio::Float64 = 0.4

end

mutable struct Species{AdnType<:AbstractAdn}
    enriched_adn_list::Vector{EnrichedAdn{AdnType}}
    params::Params
    custom_params
    stagnation_count::Int

    function Species{AdnType}(enriched_adn_list::Vector{EnrichedAdn{AdnType}},
                              params::Params,
                              custom_params,
                              stagnation_count::Int) where AdnType<:AbstractAdn
        sort!(enriched_adn_list, by=el->el.score, rev=true)
        return new(enriched_adn_list, params, custom_params, stagnation_count)
    end
end

Generation = Vector{Species{AdnType}} where AdnType <: AbstractAdn

Species(enriched_adn_list::Vector{EnrichedAdn{AdnType}}, params::Params, custom_params, stagnation_count=0) where AdnType<:AbstractAdn = Species{AdnType}(enriched_adn_list, params, custom_params, stagnation_count)

function Species(adn_list::Vector{AdnType},
                 params::Params,
                 custom_params,
                 stagnation_count=0) where AdnType<:AbstractAdn
    enriched_adn_list = [EnrichedAdn(adn, custom_params) for adn in adn_list]
    return Species{AdnType}(enriched_adn_list, params, custom_params, stagnation_count)
end

function Base.copy(species::Species)
    enriched_adn_list = deepcopy(species.enriched_adn_list)
    params = species.params
    custom_params = species.custom_params
    stagnation_count = species.stagnation_count
    return Species(enriched_adn_list, params, custom_params, stagnation_count)
end

mutable struct IterGeneration{AdnType}
    current_generation::Vector{Species{AdnType}}
    start_date::DateTime
    best_score::Float64
    generation::Int
end
# ---------- API start ----------

# The parentheses in (f(x::T)::T) where T are here because otherwise it throw an error.

"Make the adn do something return the score of the adn (bigger = better)"
action(adn::AbstractAdn, custom_params)::Float64 = throw(MissingException("action should be defined for concrete type of AbstractAdn"))


"Create a adn with random property"
(create_random(_::Type{T}, custom_params)::T) where T<:AbstractAdn = throw(MissingException("create_random should be defined for concrete type of AbstractAdn"))

"Mutate a adn"
(mutate(adn::T, custom_params)::T) where T<:AbstractAdn = throw(MissingException("mutate should be defined for concrete type of AbstractAdn"))

# alternatively and preferably to defining the preceding mutate(adn::T, custom_params), you can define this two methods (create_mutation and mutate)
"create a mutation to be used later on a adn, return nothing if undefined for concrete type"
create_mutation(adn::AbstractAdn, custom_params) = nothing
(mutate(adn::AdnType, custom_params, mutation)::AdnType) where AdnType<:AbstractAdn = throw(MissingException("mutate should be defined for concrete type of AbstractAdn"))


"Create a child adn from parents"
(create_child(parents::Vector{T}, custom_params)::T) where T<:AbstractAdn = throw(MissingException("create_child should be defined for concrete type of AbstractAdn"))

"Check if adn1 and adn2 are close in term of their inherents properties"
is_close(adn1::AbstractAdn, adn2::AbstractAdn, custom_params)::Bool= throw(MissingException("is_close should be defined for concrete type of AbstractAdn"))

# ---------- API end ----------

function create_random_list(AdnType::Type{<:AbstractAdn}, count, custom_params)
    random_list = EnrichedAdn{AdnType}[]

    for _ in 1:count
        adn = create_random(AdnType, custom_params)
        push!(random_list, EnrichedAdn(adn, custom_params))
    end

    return random_list
end

function create_mutant_list(enriched_adn_list::Vector{EnrichedAdn{AdnType}}, count, custom_params, good_mutation_for_adn = nothing) where AdnType<:AbstractAdn
    mutant_list = EnrichedAdn{AdnType}[]
    len = length(enriched_adn_list)

    for index in 0:count-1
        enriched_adn = enriched_adn_list[(index%len)+1]
        mutation = create_mutation(enriched_adn.adn, custom_params)
        if mutation == nothing
            mutant = mutate(enriched_adn.adn, custom_params)
            enriched_mutant = EnrichedAdn(mutant, custom_params)
        else
            if enriched_adn.good_mutation != nothing
                mutation = enriched_adn.good_mutation
            end
            mutation_to_do = 2^enriched_adn.good_mutation_count
            mutant = enriched_adn.adn
            for _ in 1:mutation_to_do
                mutant = mutate(mutant, custom_params, mutation)
            end

            enriched_mutant = EnrichedAdn(mutant,
                                          action(mutant, custom_params),
                                          mutation,
                                          enriched_adn.good_mutation_count + 1)

            if enriched_adn.good_mutation_count <= 1
                enriched_adn.good_mutation_count = 0
                enriched_adn.good_mutation = nothing
            else
                enriched_adn.good_mutation_count = 1
            end
        end
        push!(mutant_list, enriched_mutant)
    end


    return mutant_list
end

function create_child_list(enriched_adn_list::Vector{EnrichedAdn{AdnType}}, count, custom_params) where AdnType<:AbstractAdn
    child_list = EnrichedAdn{AdnType}[]
    adn_list = map(el->el.adn, enriched_adn_list)

    for _ in 1:count
        adn = create_child(adn_list, custom_params)
        push!(child_list, EnrichedAdn(adn, custom_params))
    end
    return child_list
end

function create_random_species_list(AdnType::Type{<:AbstractAdn}, species_count::Int, params::Params, custom_params)
    return [create_random_species(AdnType, params, custom_params) for _ in 1:species_count]
end

function create_random_species(AdnType::Type{<:AbstractAdn}, params::Params, custom_params)
    enriched_adn_list = create_random_list(AdnType, params.adn_by_species, custom_params)
    return Species(enriched_adn_list, params, custom_params)
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
    species.enriched_adn_list = species.enriched_adn_list[1:end-to_remove_count]

    custom_params = species.custom_params
    new_random_list::Vector{EnrichedAdn{AdnType}} = create_random_list(AdnType, random_count, custom_params)
    new_child_list::Vector{EnrichedAdn{AdnType}} = create_child_list(species.enriched_adn_list, child_count, custom_params)
    new_mutant_list::Vector{EnrichedAdn{AdnType}} = create_mutant_list(species.enriched_adn_list, mutant_count, custom_params)
    new_enriched_adn_list = [new_random_list; new_child_list; new_mutant_list]

    append!(species.enriched_adn_list, new_enriched_adn_list)
    sort!(species.enriched_adn_list, by=el->el.score, rev=true)

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

function get_enriched_adn_list(species_list::Vector{Species{AdnType}}) where AdnType <: AbstractAdn
    enriched_adn_list = EnrichedAdn{AdnType}[]

    for species in species_list
        append!(enriched_adn_list, species.enriched_adn_list)
    end
    sort!(enriched_adn_list, by=el->el.score, rev=true)
    return enriched_adn_list
end

get_best_score(enriched_adn_list::Vector{EnrichedAdn{AdnType}}) where AdnType<:AbstractAdn = enriched_adn_list[1].score
get_best_adn(enriched_adn_list::Vector{EnrichedAdn{AdnType}}) where AdnType<:AbstractAdn = enriched_adn_list[1].adn
get_best_enriched_adn(enriched_adn_list::Vector{EnrichedAdn{AdnType}}) where AdnType<:AbstractAdn = enriched_adn_list[1]

get_best_score(species::Species) = get_best_score(species.enriched_adn_list)
get_best_adn(species::Species) = get_best_adn(species.enriched_adn_list)
get_best_enriched_adn(species::Species) = get_best_enriched_adn(species.enriched_adn_list)

get_best_score(species_list::Vector{<:Species}) = get_best_score(get_enriched_adn_list(species_list))
get_best_adn(species_list::Vector{<:Species}) = get_best_adn(get_enriched_adn_list(species_list))
get_best_enriched_adn(species_list::Vector{<:Species}) = get_best_enriched_adn(get_enriched_adn_list(species_list))


get_best_score(history::Vector{<:Generation}) = get_best_enriched_adn(history).score
get_best_adn(history::Vector{<:Generation}) = get_best_enriched_adn(history).adn


function get_best_enriched_adn(history::Vector{<:Generation})
    best_score = -Inf
    best_enriched_adn = nothing

    for species_list in history
        current_enriched_adn = get_best_enriched_adn(species_list)
        if current_enriched_adn.score >= best_score
            best_score = current_enriched_adn.score
            best_enriched_adn = current_enriched_adn
        end
    end

    return best_enriched_adn
end

function Base.iterate(iter_generation::IterGeneration{AdnType}, state=nothing) where AdnType<:AbstractAdn
    first_species = iter_generation.current_generation[1]
    params = first_species.params
    custom_params = first_species.custom_params
    @unpack score_max, duration_max, species_count = params

    duration = now()-iter_generation.start_date
    if state == nothing
        species_list = iter_generation.current_generation
        result = (species_list=species_list, duration=duration, params=params, custom_params=custom_params)
        return (result, iter_generation)
    end

    if ((iter_generation.best_score >= score_max) || (duration >= duration_max))
        return nothing
    end

    for species in iter_generation.current_generation
        improve!(species)
    end

    species_list = delete_close_species(iter_generation.current_generation)
    species_list = delete_bad_stagnant_species(species_list)

    species_to_add = species_count - length(species_list)
    new_species = create_random_species_list(AdnType, species_to_add, params, custom_params)
    append!(species_list, new_species)
    sort!(species_list, lt=is_better)

    iter_generation.generation += 1
    iter_generation.best_score = get_best_score(species_list)
    iter_generation.current_generation = species_list

    result = (species_list=species_list, duration=duration, params=params, custom_params=custom_params)

    return (result, iter_generation)
end


"Improve a list of adn, until we get something bigger than score_max or until duration_max passed"
function create_improve_generator(AdnType::Type{<:AbstractAdn}, params::Params, custom_params)
    @unpack score_max, duration_max, species_count = params

    best_score = -Inf
    start_date = now()
    duration = now()-start_date
    generation = 1

    species_list = create_random_species_list(AdnType, species_count, params, custom_params)
    sort!(species_list, lt=is_better)
    best_score = get_best_score(species_list)

    iter_generation = IterGeneration{AdnType}(species_list, start_date, best_score, generation)

    return iter_generation
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
