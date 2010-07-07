#!/usr/bin/env ruby

# ruby-minisat example -- sudoku.rb
# ref: http://en.wikipedia.org/wiki/Sudoku

##
## SAT configuration:
##   - Variables: assign to each cell the same number variables as puzzle size
##   - Clauses: sudoku rules (below)
##
##
## sudoku basic rules:
##   - rule 1. There is at least one number in each entry
##   - rule 2. Each number appears at most once in each row
##   - rule 3. Each number appears at most once in each column
##   - rule 4. Each number appears at most once in each sub-grid
##
## sudoku auxiliary rules (for speed up):
##   - auxiliary rule 1. There is at most one number in each entry
##   - auxiliary rule 2. Each number appears at least once in each row
##   - auxiliary rule 3. Each number appears at least once in each column
##   - auxiliary rule 4. Each number appears at least once in each sub-grid
##
##
## see [1] in detail.
##
## [1] I. Lynce, and J. Ouaknine.  Sudoku as a SAT Problem.  Proceedings of the
##     Ninth International Symposium on Artificial Intelligence and Mathematics
##     (AIMATH 2006), Jan. 2006
##

require "minisat"
require File.dirname($0) + "/compat18" if RUBY_VERSION < "1.9.0"


def error(msg)
  $stderr.puts msg
  exit 1
end


def parse_file(file)
  s_puzz = w_grid = h_grid = nil
  field = []
  File.read(file).split(/\n/).each do |line|
    case line
    when /^\s*#.*$/, /^\s*$/
    when /^\s*grid-size\s*:\s*(\d+)x(\d+)\s*$/
      w_grid = $1.to_i
      h_grid = $2.to_i
    else
      line = line.split.map {|n| n.to_i }
      s_puzz ||= line.size
      unless s_puzz == line.size
        error "illegal width: row #{ field.size + 1 }"
      end
      field << line
    end
  end
  error "illegal height" unless field.size == s_puzz
  unless w_grid * h_grid == s_puzz
    error "illegal size: #{ s_puzz } != #{ w_grid } * #{ h_grid }"
  end

  a_puzz = (0...s_puzz).to_a
  a_grid = (0...s_puzz).step(w_grid).to_a.
             product((0...s_puzz).step(h_grid).to_a)
  a_off = (0...w_grid).to_a.product((0...h_grid).to_a)

  [a_puzz, a_grid, a_off, field]
end


def define_sat(solver, a_puzz, a_grid, a_off, field)
  # define variables
  vars = a_puzz.map {|x| a_puzz.map {|y| a_puzz.map {|z| solver.new_var }}}

  # define clauses
  a_puzz.each do |x|
    a_puzz.each do |y|
      # rule 1
      solver << a_puzz.map {|z| vars[x][y][z] }

      # auxiliary rule 1
      a_puzz.combination(2) do |z1, z2|
        solver << [-vars[x][y][z1], -vars[x][y][z2]]
      end
    end
  end
  a_puzz.each do |z|
    a_puzz.each do |i|
      a_puzz.combination(2) do |j, k|
        # rule 2
        solver << [-vars[j][i][z], -vars[k][i][z]]

        # rule 3
        solver << [-vars[i][j][z], -vars[i][k][z]]
      end

      # auxiliary rule 2
      solver << a_puzz.map {|j| vars[j][i][z] }

      # auxiliary rule 3
      solver << a_puzz.map {|j| vars[i][j][z] }
    end

    a_grid.each do |xg, yg|
      a_off.combination(2) do |(xo1, yo1), (xo2, yo2)|
        # rule 4
        solver << [-vars[xg + xo1][yg + yo1][z], -vars[xg + xo2][yg + yo2][z]]
      end

      # auxiliary rule 4
      solver << a_off.map {|xo, yo| vars[xg + xo][yg + yo][z] }
    end
  end

  vars
end


def make_assumptions(vars, a_puzz, a_grid, a_off, field)
  # translate fixed cells into assumption
  assumps = []

  field.zip(a_puzz) do |line, y|
    line.zip(a_puzz) do |n, x|
      next if n == 0
      a_puzz.each do |z|
        v = vars[x][y][z]
        assumps << (z == n - 1 ? v : -v)
      end
    end
  end

  assumps
end


def solve_sat(solver, assumps)
  start = Time.now
  result = solver.solve(*assumps)
  eplise = Time.now - start
  puts "time: %.6f sec." % eplise
  result
end


def make_solution(solver, vars, a_puzz, a_grid, a_off, field)
  a_puzz.map do |y|
    a_puzz.map do |x|
      1 + a_puzz.find {|z| solver[vars[x][y][z]] }
    end
  end
end


def add_constraint(solver, vars)
  solver << vars.flatten.map {|v| solver[v] ? -v : v }
end


def output_field(field)
  puts field.map {|l| "  " + l.map {|c| c == 0 ? "." : c }.join(" ") }
end



error "usage: sudoku.rb sudoku.sample" if ARGV.empty?

ARGV.each do |file|
  sudoku = parse_file(file)
  puts "problem:"
  output_field(sudoku.last)
  puts

  solver = MiniSat::Solver.new

  puts "defining SAT..."
  vars = define_sat(solver, *sudoku)
  puts "variables : #{ solver.var_size }"
  puts "clauses : #{ solver.clause_size }"
  puts

  puts "translating fixed cells into assumptions..."
  assumps = make_assumptions(vars, *sudoku)
  puts "assumptions : #{ assumps.size }"
  puts

  puts "solving SAT..."
  result = solve_sat(solver, assumps)
  puts "result: " + (result ? "solvable" : "unsolvable")
  puts
  next unless result

  puts "translating model into solution..."
  solution = make_solution(solver, vars, *sudoku)
  puts "solution found:"
  output_field(solution)
  puts

  puts "checking different solution..."
  add_constraint(solver, vars)
  result = solve_sat(solver, assumps)
  puts "result: " +
    (result ? "different solution found" : "different solution not found")
  puts
  next unless result

  puts "translating model into solution..."
  solution = make_solution(solver, vars, *sudoku)
  puts "different solution:"
  output_field(solution)
  puts
  puts
end
