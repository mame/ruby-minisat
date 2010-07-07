#!/usr/bin/env ruby

# ruby-minisat example -- kakuro.rb
# ref: http://en.wikipedia.org/wiki/Kakuro

##
## SAT configuration:
##   - Variables: 9 variables for number to each blank cell
##   - Clauses: sum of each entry is specified
##

require "minisat"
require File.dirname($0) + "/compat18" if RUBY_VERSION < "1.9.0"


def error(msg)
  $stderr.puts msg
  exit 1
end


def parse_file(file)
  width = nil
  field = []
  File.read(file).split(/\n/).each do |line|
    next if line[/^\s*#/]
    field << (line + "  ").
      scan(/\G(?:(\*\*|\d+)\\(\*\*|\d+)|(\.))(?:\s+|$)/).
      map {|v, h, b| b ? nil : [v.to_i, h.to_i] }
  end
  field
end


def define_sat(solver, field)
  # define variables
  vars = field.map do |line|
    line.map do |c|
      next if c
      vs = (1..9).map { solver.new_var }
      solver << vs
      vs.combination(2) {|v1, v2| solver << [-v1, -v2] }
      vs
    end
  end

  # define clauses
  define_entries(solver, field          , vars          ) {|c| c.last }
  define_entries(solver, field.transpose, vars.transpose) {|c| c.first }

  vars
end

def define_entries(solver, field, vars)
  field.zip(vars) do |fline, vline|
    num = nil
    ary = []
    fline.zip(vline) do |c, vs|
      if c
        define_entry(solver, num, ary)
        num, ary = (yield c), []
      else
        ary << vs
      end
    end
    define_entry(solver, num, ary) 
  end
end

# define constraints for entry
def define_entry(solver, num, ary)
  return unless num && !ary.empty?
  h = {}
  enum_entry(num, ary.size, 1, []) do |is|
    (0 ... is.size).each do |n|
      h[is[0...n]] ||= []
      h[is[0...n]] |= [is[n]]
    end
  end
  error "bad field" if h.empty?
  h.each do |bs, as|
    a = bs.zip(ary).map {|i, vs| -vs[i - 1] }
    a += as.map {|i| ary[bs.size][i - 1] }
    solver << a
  end
end

# enumerate possible numbers for entry
#   enum_entry(8, 2) -> [1, 7], [2, 6], [3, 5] and these permutations
#   enum_entry(9, 3) -> [1, 2, 6], [1, 3, 5], [2, 3, 4] and these permutations
def enum_entry(num, count, start = 1, ary = [])
  if count == 0
    ary.permutation {|r| yield r } if num == 0
  else
    (start .. 9).each do |x|
      break if num < x
      enum_entry(num - x, count - 1, x + 1, ary + [x]) {|r| yield r }
    end
  end
end


def solve_sat(solver)
  start = Time.now
  result = solver.solve
  eplise = Time.now - start
  puts "time: %.6f sec." % eplise
  result
end


def make_solution(solver, vars)
  vars.map {|line| line.map {|vs| (1..9).find {|i| solver[vs[i - 1]]} if vs } }
end


def add_constraint(solver, vars)
  solver << vars.flatten.compact.map {|v| solver[v] ? -v : v }
end


def output_field(solution, field)
  field.zip(solution) do |fline, sline|
    line = fline.zip(sline).map do |c, s|
      if c
        f = c.first == 0 ? "##" : "%02d" % c.first
        s = c.last  == 0 ? "##" : "%02d" % c.last 
        f + "\\" + s
      else
        s.to_s.center(5)
      end
    end.join(" ")
    puts line
  end
end



error "usage: kakuro.rb kakuro.sample" if ARGV.empty?

ARGV.each do |file|
  field = parse_file(file)

  solver = MiniSat::Solver.new

  puts "defining SAT..."
  vars = define_sat(solver, field)
  puts "variables : #{ solver.var_size }"
  puts "clauses : #{ solver.clause_size }"
  puts

  puts "solving SAT..."
  result = solve_sat(solver)
  puts "result: " + (result ? "solvable" : "unsolvable")
  puts
  next unless result

  puts "translating model into solution..."
  solution = make_solution(solver, vars)
  puts "solution found:"
  output_field(solution, field)
  puts

  puts "checking different solution..."
  add_constraint(solver, vars)
  result = solve_sat(solver)
  puts "result: " +
    (result ? "different solution found" : "different solution not found")
  puts
  next unless result

  puts "translating model into solution..."
  solution = make_solution(solver, vars)
  puts "different solution:"
  output_field(solution, field)
  puts
  puts
end
