using Test
using Kami

tests = ["adn_test.jl", "fit_eq_diff_test.jl", "fit_function_test.jl"]

for test in tests
  include(test)
end
