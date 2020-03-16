# Kami
Some julia training with genetic algorithms.
## How to use
```console

julia> using Kami

julia> main() #then follow the option

```

```julia

using Kami

function main()
    real_funct(x) = 1470.0*x + 1036.0*x^2 - 257.1*x^3 - 77.6*x^4 + 5.7*x^5 + x^6
    wanted_values = [(x, real_funct(x)) for x in 0:0.1:10]
    params_span = repeat([-20:0.1:20], 6)

    params = Params(duration_max=Second(60*5),
                    score_max=-1.,
                    random_ratio=0,
                    stagnation_max=20,
                    species_count=10,
                    adn_by_species=20
                    )

    custom_params = FunctionParams(params_span,
                                   funct=funct,
                                   wanted_values=wanted_values,
                                   mutate_max_speed=0.005,
                                   )

    run_session(FunctionAdn, params, custom_params)
end
```

## How to adapt the genetic algorithm for your own use

look at the API in src/adn.jl.

```julia

using Kami

struct MyAdn <: AbstractAdn
...
end

function Kami.Adn.action(adn::MyAdn, custom_params)::Float64
    ...
end

function Kami.Adn.create_random(_::Type{MyAdn}, custom_params)::MyAdn
    ...
end

function Kami.Adn.create_child(parents::Vector{MyAdn}, custom_params)::MyAdn
...
end

# This
function Kami.Adn.mutate(adn::MyAdn, custom_params)::MyAdn
    ...
end

# Or that
function create_mutation(adn::MyAdn, custom_params)
    ...
    return mutation
end

function Kami.Adn.mutate(adn::MyAdn, custom_params, mutation)::MyAdn
    ...
end
```
