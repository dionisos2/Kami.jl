using Test
using Kami

@vars x y
const filepath = "dataset/test.csv"

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
        @vars Y t

        # Y(t) = -(x^2*e^(t*x))/(c_1*x^2 + y*e^(t*x)*(t*x - 1))
        dY = x*Y+t*y*Y^2

        adn = EqDiffAdn(x=>2.0, y=>-5.0)
        params = EqDiffParams(x=>1:eps():10, y=>-5:eps():5, dfunct=dY, funct=Y, variable=t, wanted_values=[(0.0,1.0), (10.0,10.0)])

        sol = generate_solution(adn, params)
    end

    @testset "get_score" begin
        F = Float64
        v_sparce = Tuple{F, F}[(1,1), (2,2), (3,3), (4,4)]
        v_dense = Tuple{F, F}[(1,2), (1.1,0), (1.8,0), (2.3,4), (2.7,3), (3.5, -3), (4,3)]

        score = -(1 + 2^2 + 6^2 + 1)

        @test get_score(v_sparce, v_dense) == score
    end

    @testset "action" begin
        @vars Y t x

        # dY = 2*Y + 3*t →
        # y(t) = C*e^(2*t) - 3*t/2 - 3/4 (C=2)
        y(t) = 2*exp(2*t) - 3*t/2 - 3/4
        dY = x*Y + 3*t


        adn_less = EqDiffAdn(x=>1.9)
        adn_good = EqDiffAdn(x=>2.0)
        adn_more = EqDiffAdn(x=>2.1)
        adn_very_bad = EqDiffAdn(x=>7)

        wanted_values = [(t,y(t)) for t in 0:0.02:2]
        params = EqDiffParams(x=>0:eps():10, dfunct=dY, funct=Y, variable=t, dvariable=0.02, wanted_values=wanted_values)

        score_less, score_good, score_more, score_very_bad = [action(adn, params) for adn in [adn_less, adn_good, adn_more, adn_very_bad]]
        @test score_good > score_less
        @test score_good > score_more
        @test score_very_bad < score_less
        @test score_very_bad < score_more
    end
end
