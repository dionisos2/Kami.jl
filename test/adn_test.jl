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

Kami.Adn.is_close(adn1::AdnMock, adn2::AdnMock, custom_params)::Bool = abs(adn1.x-adn2.x)<=1

@testset "test AbstractAdn" begin
    @testset "test Adn API" begin
        adn = AdnMock()
        @test action(adn, 5) == -10*(10+5)
        @test create_random(AdnMock, 4) == AdnMock(10, 4)
        @test mutate(adn, 1) == AdnMock(9, 9)
        @test create_child([adn]) == AdnMock(7, 5)
    end

    @testset "create_improve_generator" begin
        params = Params(adn_by_species = 10, duration_max=Second(2))
        generator = create_improve_generator(AdnMock, params, -4)
        adn = nothing
        for result in generator
            adn = get_best_adn(result[:species_list])
        end
        @test action(adn, -4) == 0
    end
end

@testset "test species system" begin
    @testset "constructors and simple functions" begin
        params = Params(adn_by_species = 10, duration_max=Second(2))
        custom_params = 5
        spe1 = Species{AdnMock}([], params, custom_params, 10)
        adn = AdnMock()
        spe2 = Species([(adn, action(adn, custom_params))], params, custom_params)
        spe3 = Species([adn], params, custom_params)
        spe_list = create_random_species_list(AdnMock, 5, params, custom_params)
        @test length(spe_list) == 5
    end

    @testset "improve!" begin
        params = Params(adn_by_species = 10, duration_max=Second(2))
        custom_params = 5
        spe_list = create_random_species_list(AdnMock, 5, params, custom_params)
        spe1 = spe_list[1]
        spe1_imp = copy(spe1)

        improve!(spe1_imp)

        @test spe1 != spe1_imp
        @test get_best_score(spe1_imp) > get_best_score(spe1)

        for _ in 1:20
            improve!(spe1)
        end

        @test get_best_score(spe1) == 0
        @test spe1.stagnation_count > 10
    end

    @testset "delete_bad_stagnant_species" begin
        params = Params(adn_by_species = 10, duration_max=Second(2), stagnation_max = 3)
        custom_params = 5
        adn_score_list = [(AdnMock(x, x), action(AdnMock(x, x), custom_params)) for x in 1:10]
        species_list = [Species([adn_score_list[index]], params, custom_params)
                        for index in 1:length(adn_score_list)]
        for species in species_list[1:5]
            species.stagnation_count = 3
        end

        species_list2 = delete_bad_stagnant_species(species_list)
        @test length(species_list) == length(species_list2)
        @test species_list == species_list2

        for species in species_list[6:10]
            species.stagnation_count = 3
        end

        species_list2 = delete_bad_stagnant_species(species_list)
        @test length(species_list2) == 5
    end

    @testset "delete_close_species" begin
        params = Params(adn_by_species = 10, duration_max=Second(2), stagnation_max = 3)
        custom_params = 5
        adn_score_list = [(AdnMock(x, x), action(AdnMock(x, x), custom_params))
                          for x in [1, 2, 4,5, 8, 10, 7]]

        species_list = [Species([adn_score_list[index]], params, custom_params)
                        for index in 1:length(adn_score_list)]

        species_list2 = delete_close_species(species_list)

        @test length(species_list2) == 4

        @test get_best_adn(species_list2[1]).x == 1
        @test get_best_adn(species_list2[2]).x == 4
        @test get_best_adn(species_list2[3]).x == 7
        @test get_best_adn(species_list2[4]).x == 10
    end
end
