#!/usr/bin/env ruby

# ruby-minisat example -- example2.rb

require "minisat"

# initialize solver
solver = MiniSat::Solver.new

# make variable
a = solver.new_var
b = solver.new_var

# input CNF to solver: (a or b) and (not a or b) and (a or not b)
solver << [a, b] << [-a, b] << [a, -b]

# solve SAT (return true if solvable)
p solver
puts "solve: (a or b) and (not a or b) and (a or not b)"
solver.solve
p solver

# output results
puts("result: " + (solver.satisfied? ? "SAT" : "UNSAT"))  #=> SAT
if solver.satisfied?
  puts "a = #{ solver[a].inspect }"  #=> a = true
  puts "b = #{ solver[b].inspect }"  #=> a = false
end
puts


# solve SAT with assumption
puts "solve: (a or b) and (not a or b) and (a or not b)"
puts "assumption: a = false"
solver.solve(-a)  #=> false
p solver

# output results
puts("result: " + (solver.satisfied? ? "SAT" : "UNSAT"))  #=> UNSAT
if solver.satisfied?
  puts "a = #{ solver[a].inspect }"
  puts "b = #{ solver[b].inspect }"
end
puts


# input additonal CNF to solver: ... and (not a or not b)
solver << [-a, -b]
p solver  #=> trivially unsatisfiable

# solve SAT (return true if solvable)
puts "solve: (a or b) and (not a or b) and (a or not b) and (not a or not b)"
solver.solve

# output results
puts("result: " + (solver.satisfied? ? "SAT" : "UNSAT"))  #=> UNSAT
if solver.satisfied?
  puts "a = #{ solver[a].inspect }"
  puts "b = #{ solver[b].inspect }"
end
