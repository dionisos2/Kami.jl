using Test
using Kami

tests = ["adn_test.jl"]

for test in tests
  include(test)
end
