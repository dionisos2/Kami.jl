using Test
using Kami
using Dates

struct AdnMock <: AbstractAdn
    x
    y
end

AdnMock() = AdnMock(10, 10)

Kami.action(adn::AdnMock, custom_params)::Float64 = -abs(adn.x*(adn.y+custom_params))
Kami.create_random(_::Type{AdnMock}, custom_params)::AdnMock = AdnMock(10, custom_params)
function Kami.mutate(adn::AdnMock, custom_params)
    return AdnMock(adn.x-1, adn.y-1)
end

function Kami.create_child(parents::Vector{AdnMock}, custom_params=nothing)
    return AdnMock(7, 5)
end


@testset "test AbstractAdn" begin
    @testset "test Adn API" begin
        adn = AdnMock()
        @test action(adn, 5) == -10*(10+5)
        @test create_random(AdnMock, 4) == AdnMock(10, 4)
        @test mutate(adn, 1) == AdnMock(9, 9)
        @test create_child([adn]) == AdnMock(7, 5)
    end

    @testset "improve_until" begin
        params = Kami.Params(adn_count = 10, duration_max=Second(1))
        generator = improve_until(AdnMock, params, -4)
        adn = nothing
        for result in generator
            adn = result[:adn_score_list][1][1]
        end
        @test action(adn, -4) == 0
    end
end
