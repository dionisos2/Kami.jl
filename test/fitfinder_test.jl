using Test
using Kami

using SymPy
using CSV
using StatsBase

const filepath = "dataset/test.csv"

@testset "fitfinder" begin
    @testset "read_CSV" begin
        data = CSV.read(filepath)
        @test data[:,:x][1] == 1
        @test data[:,:y][1] == 10
        @test data[:,:x][3] == 3
        @test data[:,:y][5] == 50
    end

    @testset "create_adns" begin
        @vars a1 a2 a3
        params_span = [
            (a1, -10:eps():10),
            (a2, -10:eps():10),
            (a3, -10:eps():10),
        ]

        adns = create_adns(params_span, 10)
        @test length(adns) == 10
        @test adns[1][1][1] == a1
        @test adns[1][2][1] == a2
        @test adns[1][3][1] == a3
        @test all(-10 <= adns[1][n][2] <= 10 for n in 1:3)
    end

    @testset "create_childs" begin
        @vars x y
        adn1 = [(x,1.0), (y,1.0)]
        adn2 = [(x,2.0), (y,4.0)]
        adn3 = [(x,4.0), (y,8.0)]
        adns = [adn1, adn2, adn3]

        childs = create_childs(adns, 2, 3)
        @test length(childs) == 2
        @test childs[1] == childs[2]
        @test childs[1][1][1] == x
        @test childs[1][1][2] == (1+2+4)/3
        @test childs[1][2][1] == y
        @test childs[1][2][2] == (1+4+8)/3
    end

    @testset "get_scores" begin
        @vars I x y t
        adn1 = [(x,1.0), (y,1.0)]
        adn2 = [(x,2.0), (y,4.0)]
        adn3 = [(x,4.0), (y,8.0)]
        adns = [adn1, adn2, adn3]

        data = CSV.read(filepath)
        values = collect(zip(data[:,:x],data[:,:y]))

        # I(t) = -(x^2*e^(t*x))/(c_1*x^2 + y*e^(t*x)*(t*x - 1))
        dI = x*I+t*y*I^2

        get_scores(adns, values, dI, I, t)
    end

    @testset "get_scores invalide equation" begin
        @vars I x t
        adn1 = [(x,-1.0)]
        adn2 = [(x,1.0)]
        adn3 = [(x,-5.0)]
        adns = [adn1, adn2, adn3]

        values = [[1,10], [2,20]]

        dI = (x*I)^(1/2)

        scores = get_scores(adns, values, dI, I, t)

        @test length(scores) == 3
        @test scores[1][2] == -Inf
        @test scores[3][2] == -Inf
    end
end
