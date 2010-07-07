#!/usr/bin/env ruby

# ruby-minisat example -- example.rb

require "minisat"

# initialize solver
solver = MiniSat::Solver.new

# make variable
a = solver.new_var
b = solver.new_var

# input CNF to solver: (a or b) and (not a or b) and (a or not b)
solver << [a, b] << [-a, b] << [a, -b]

# solve SAT (return true if solvable)
puts "solve: (a or b) and (not a or b) and (a or not b)"
solver.solve

# output results
puts("result: " + (solver.satisfied? ? "SAT" : "UNSAT"))  #=> SAT
if solver.satisfied?
  puts "a = #{ solver[a].inspect }"  #=> a = true
  puts "b = #{ solver[b].inspect }"  #=> a = false
end
