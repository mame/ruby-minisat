#!/usr/bin/env ruby

# ruby-minisat example -- nonogram.rb
# ref: http://en.wikipedia.org/wiki/Nonogram

##
## SAT configuration:
##   - Variables: assign variables to each cell and each number in rule (below)
##   - Clauses: sudoku rules (below)
##
##
## Variables:
##   - one variable to each cell
##   - n * m variables to each rule (length n)
##     - or, m variables to each number
##     - where m = n - rule.sum - rule.size + 2
##
## example: rule is [1, 2], and six cells
##   - cells   : a, b, c, d, e, f
##   - number 1: p, q, r
##   - number 2: s, t, u
##
##       abcdef     pqr stu
##       1.22.. <=> 1.. 2..
##       1..22. <=> 1.. .2.
##       1...22 <=> 1.. ..2
##       .1.22. <=> .1. .2.
##       .1..22 <=> .1. ..2
##       ..1.22 <=> ..1 ..2
##
##   # p means `1 block starts from a', q means b, and r means c
##   # s means `2 blocks starts from c', t means d, and u means e
##
##
## Constraints:
##
##   - constraint type 1. exact one variable in each number is true
##   - constraint type 2. order of rule variables
##   - constraint type 3. correspondence between cell variables and rule ones
##
## for above example:
##
##   - constraint type 1.
##     - p, q, r <- exact one
##     - s, t, u <- exact one
##
##   - constraint type 2.
##     - q => t or u
##     - r => u
##     - s => p      (option)
##     - t => p or q (option)
##
##   - constraint type 3.
##             a   b   c   d   e   f
##     - a <=> p
##     - b <=>     q
##     - c <=>        r|s
##     - d <=>            s|t
##     - e <=>                t|u
##     - f <=>                     u
##
## Encoding:
##   - encoding `if':  a  =>  x1 or x2 or ... or xn:
##      (-a | x1 | x2 | ... | xn)
##
##   - encoding `iff':  a  <=>  x1 or x2 or ... or xn:
##      (a | -x1) & (a | -x2) & ... & (a | -xn) & (-a | x1 | x2 | ... | xn)
##

require "minisat"
require File.dirname($0) + "/compat18" if RUBY_VERSION < "1.9.0"


def error(msg)
  $stderr.puts msg
  exit 1
end


def parse_file(file)
  lines = []
  base = nil
  rows = []
  File.read(file).split(/\n/).each do |line|
    next if line[/^\s*#/]
    lines << line
    next unless line.index(".")

    rows << line.split.map {|x| x.to_i }.select {|x| x > 0 }

    ary = []
    line.scan(/\s*\./) {|s| ary << [$`.size, s.size] }
    base ||= ary
    error "corrupt field" unless base == ary
  end

  cols = base.map { [] }
  lines.each do |line|
    cols.zip(base) do |c, (i, j)|
      n = line[i, j].to_i
      c << n if n > 0
    end
  end

  [rows, cols]
end


def define_sat(solver, rows, cols)
  # define variables
  v_cells = rows.map { cols.map { solver.new_var } }
  v_rows = rows.map {|r| define_rule_vars(solver, cols.size, r) }
  v_cols = cols.map {|r| define_rule_vars(solver, rows.size, r) }

  # define constraints type 1 and 2
  (v_rows + v_cols).each do |r|
    define_constraint_type_1(solver, r)
    define_constraint_type_2(solver, r)
  end

  # define constraints type 3
  v_cells.zip(rows, v_rows) do |l, n, r|
    define_constraint_type_3(solver, l, n, r)
  end
  v_cells.transpose.zip(cols, v_cols) do |l, n, r|
    define_constraint_type_3(solver, l, n, r)
  end

  [v_cells, v_rows, v_cols]
end


# define rule variables : 6 -> [1, 2] -> [p, q, r]
def define_rule_vars(solver, size, rule)
  num = size - rule.inject(0) {|z, x| z + x + 1 } + 2
  rule.map { (0...num).map { solver.new_var } }
end


# constraint type 1. exact one variable in each number is true
def define_constraint_type_1(solver, r)
  # r : [[p,q,r], [s,t,u]]
  r.each do |r2|
    solver << r2
    r2.combination(2) {|v1, v2| solver << [-v1, -v2] }
  end
end


# define constraint type 2: order of rule variables
def define_constraint_type_2(solver, r)
  # r : [[p,q,r], [s,t,u]]
  r.each_cons(2) do |r2, r3|
    (1...r2.size).each do |i|
      solver << ([-r2[i]] + r3[i..-1])
    end
  end
end


# define constraint type 3: correspondence between cell variables and rule ones
def define_constraint_type_3(solver, l, n, r)
  # l : a,b,c,d,e,f
  # n : [1, 2]
  # r : [[p,q,r], [s,t,u]]
  t = l.map { [] }
  r.each_with_index do |r2, i|
    off = n[0, i].inject(0) {|z, x| z + x + 1 }
    n[i].times do |j|
      r2.each_with_index do |v, k|
        t[off + j + k] |= [v]
      end
    end
  end; t
  # t : [[p], [q], [r,s], [s,t], [t,u], [u]]
  l.zip(t) do |v, c|
    c.each {|v2| solver << [v, -v2] }
    solver << ([-v] + c)
  end
end


def solve_sat(solver)
  start = Time.now
  result = solver.solve
  eplise = Time.now - start
  puts "time: %.6f sec." % eplise
  result
end


def make_solution(solver, v_cells, v_rows, v_cols)
  v_cells.map {|l| l.map {|v| solver[v] } }
end

def output_field(field, rows, cols)
  w = rows.map {|cs| cs.size }.max
  r = rows.map do |rs|
    (["  "] * w + rs.map {|r| r.to_s.rjust(2) }).last(w).join
  end
  h = cols.map {|cs| cs.size }.max
  c = cols.map do |cs|
    (["  "] * h + cs.map {|c| c.to_s.rjust(2) }).last(h)
  end.transpose.map {|l| " " * (r.first.size + 1) + l.join }
  puts c
  field.zip(r) do |line, prefix|
    puts prefix + " " + line.map {|x| x ? "##" : " ." }.join
  end
end


def add_constraint(solver, vars)
  solver << vars.flatten.map {|v| solver[v] ? -v : v }
end



error "usage: nonogram.rb nonogram.sample" if ARGV.empty?

ARGV.each do |file|
  nonogram = parse_file(file)

  solver = MiniSat::Solver.new

  puts "defining SAT..."
  vars = define_sat(solver, *nonogram)

  puts "solving SAT..."
  result = solve_sat(solver)
  puts "result: " + (result ? "solvable" : "unsolvable")
  puts
  next unless result

  puts "translating model into solution..."
  solution = make_solution(solver, *vars)
  puts "solution found:"
  output_field(solution, *nonogram)
  puts

  puts "checking different solution..."
  add_constraint(solver, vars)
  result = solve_sat(solver)
  puts "result: " +
    (result ? "different solution found" : "different solution not found")
  puts
  next unless result

  puts "translating model into solution..."
  solution = make_solution(solver, *vars)
  puts "different solution:"
  output_field(solution, *nonogram)
  puts
  puts
end
