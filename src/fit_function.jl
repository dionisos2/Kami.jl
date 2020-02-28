module FitFunction

include("utils.jl")

struct FunctionParams
    wanted_values::FunctionGraph
    funct
end

struct FunctionAdn <: AbstractAdn
    params::Vector{Float64}
end


function action(adn::FunctionAdn, custom_params)::Float64
    funct(x) = custom_params(x, adn.params)
    actual_values = [(x, funct(x)) for x,_ in custom_params.wanted_values]

    return get_score(wanted_values, actual_values)
end

end
