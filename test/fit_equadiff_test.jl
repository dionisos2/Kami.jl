using Test
using Kami
@vars x y

@testset "test fit_equadiff" begin
    @testset "EqDiffAdn and EqDiffParams constructors" begin
        adn = EqDiffAdn([(x, 1.0), (y, 2.2)])
        adn2 = EqDiffAdn([(x, 1), (y, 2)])
        adn3 = EqDiffAdn(x=>1.0, y=>2.2)
        adn4 = EqDiffAdn(Dict(x=>1.0, y=>2.2))

        params = EqDiffParams([(x, 1:0.1:10), (y, -5:0.5:5)])
        params2 = EqDiffParams([(x, 1:0.1:10)], mutate_max_speed=0.5)
        params3 = EqDiffParams(x=>1:0.1:10, y=>1:0.5:5)
        params4 = EqDiffParams(x=>1:0.1:10, y=>1:0.5:5, mutate_max_speed=0.5)
        params5 = EqDiffParams(Dict(x=>1:0.1:10, y=>1:0.5:5))

        @test adn.params[x] == adn[x] == 1.0
        @test adn.params[y] == adn[y] == 2.2
        @test adn2[x] === 1.0
        @test adn2[y] === 2.0

        @test params.params_span[x] == params[x] == 1:0.1:10
        @test params.params_span[y] == params[y] == -5:0.5:5
    end

    @testset "create_random" begin
        params = EqDiffParams(x=>1:0.1:10, y=>-5:0.5:5)

        adn = create_random(EqDiffAdn, params)

        @test adn[x] in params[x]
        @test adn[y] in params[y]
    end

    @testset "mutate" begin
        params = EqDiffParams(x=>1:eps():10, y=>-5:eps():5, mutate_max_speed=0.5)

        for _ in 1:20
            adn = EqDiffAdn(x=>10, y=>-5)
            mutant = mutate(adn, params)

            @test mutant[x] in params[x]
            @test mutant[y] in params[y]
            @test abs(mutant[x]-adn[x]) <= 0.5
            @test abs(mutant[y]-adn[y]) <= 0.5
        end
    end

    @testset "create_child" begin
        params = EqDiffParams(x=>1:eps():10, y=>-5:eps():5, mutate_max_speed=0.5)
        parents = [create_random(EqDiffAdn, params) for _ in 1:10]

        child = create_child(parents, params)
        @test child[x] == sum(el->el[x], parents)/length(parents)
        @test child[y] == sum(el->el[y], parents)/length(parents)
    end

    @testset "generate_solution" begin
        
    end

    @testset "get_score" begin
    end

    @testset "action" begin
    end
end
