using Test
using Kami.FitFunction

@testset "test fit_function" begin
    @testset "FunctionAdn and FunctionParams constructors" begin
        adn1 = FunctionAdn([1.0, 2.2])
        adn2 = FunctionAdn([1, 2])
        adn3 = FunctionAdn(1.0, 2.2)

        params1 = FunctionParams([1:0.1:10, -5:0.5:5])
        params2 = FunctionParams([1:0.1:10], mutate_max_speed=0.5)
        params3 = FunctionParams(1:0.1:10, 1:0.5:5)
        params4 = FunctionParams(1:0.1:10, 1:0.5:5, mutate_max_speed=0.5)


        @test adn1.params[1] == adn1[1] == 1.0
        @test adn1.params[2] == adn1[2] == 2.2
        @test adn2[1] === 1.0
        @test adn2[2] === 2.0

        @test params1.params_span[1] == params1[1] == 1:0.1:10
        @test params1.params_span[2] == params1[2] == -5:0.5:5
    end

    @testset "create_random" begin
        params = FunctionParams(1:0.1:10, -5:0.5:5)

        adn = create_random(FunctionAdn, params)

        @test adn[1] in params[1]
        @test adn[2] in params[2]
    end

    @testset "mutate" begin
        params = FunctionParams(1:eps():10, -5:eps():5, mutate_max_speed=0.5)

        for _ in 1:20
            adn = FunctionAdn(10, -5)
            mutant = mutate(adn, params)

            @test mutant[1] in params[1]
            @test mutant[2] in params[2]
            @test abs(mutant[1]-adn[1]) <= 0.5
            @test abs(mutant[2]-adn[2]) <= 0.5
        end
    end

    @testset "create_child" begin
        params = FunctionParams(1:eps():10, -5:eps():5, mutate_max_speed=0.5)
        parents = [create_random(FunctionAdn, params) for _ in 1:10]

        child = create_child(parents, params)
        @test child[1] == sum(el->el[1], parents)/length(parents)
        @test child[2] == sum(el->el[2], parents)/length(parents)
    end


    @testset "action" begin
        correct_funct(t) = 5*t^2 - 2*t + 7
        wanted_values = [(t,correct_funct(t)) for t in 0:0.1:50]

        funct(x::Float64, params::Vector{Float64}) = params[1]*x^2 + params[2]*x + 7


        params = FunctionParams(funct=funct, wanted_values=wanted_values)

        adn_less = FunctionAdn(5, -2.1)
        adn_perfect = FunctionAdn(5, -2)
        adn_more = FunctionAdn(5.1, -2)
        adn_very_bad = FunctionAdn(10, -10)


        score_less, score_perfect, score_more, score_very_bad = [action(adn, params) for adn in [adn_less, adn_perfect, adn_more, adn_very_bad]]
        @test score_perfect > score_less
        @test score_perfect > score_more
        @test score_very_bad < score_less
        @test score_very_bad < score_more
        @test isapprox(score_perfect, 0.0)
    end
end
