using Test
using Kami.Adn
using Dates

struct AdnMock <: AbstractAdn
    x
    y
end

AdnMock() = AdnMock(10, 10)

Kami.Adn.action(adn::AdnMock, custom_params)::Float64 = -abs(adn.x*(adn.y+custom_params))
Kami.Adn.create_random(_::Type{AdnMock}, custom_params)::AdnMock = AdnMock(10, custom_params)
function Kami.Adn.mutate(adn::AdnMock, custom_params)
    return AdnMock(adn.x-1, adn.y-1)
end

function Kami.Adn.create_child(parents::Vector{AdnMock}, custom_params=nothing)
    return AdnMock(7, 5)
end

Kami.Adn.is_close(adn1::AdnMock, adn2::AdnMock, custom_params)::Bool = false

@testset "test AbstractAdn" begin
    @testset "test Adn API" begin
        adn = AdnMock()
        @test action(adn, 5) == -10*(10+5)
        @test create_random(AdnMock, 4) == AdnMock(10, 4)
        @test mutate(adn, 1) == AdnMock(9, 9)
        @test create_child([adn]) == AdnMock(7, 5)
    end

    @testset "create_improve_generator" begin
        params = Kami.Params(adn_by_species = 10, duration_max=Second(2))
        generator = create_improve_generator(AdnMock, params, -4)
        adn = nothing
        for result in generator
            adn = result[:adn_score_list][1][1]
        end
        @test action(adn, -4) == 0
    end
end
