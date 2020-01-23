using Test
using Kami

tests = ["fitfinder_test.jl"]

for test in tests
  include(test)
end
