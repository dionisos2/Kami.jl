using Test
using Kami
@vars x y

@testset "test fit_equadiff" begin
    @testset "EqDiffAdn and EqDiffParams constructors" begin
        adn = EqDiffAdn([(x, 1.0), (y, 2.2)])
        params = EqDiffParams([(x, 1:0.1:10), (y, -5:0.5:5)])

        @test adn.params[x] == 2.2
        @test adn.params[y] == 1.0
    end
end
