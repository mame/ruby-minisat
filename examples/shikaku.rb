#!/usr/bin/env ruby

# ruby-minisat example -- shikaku.rb
# ref: http://en.wikipedia.org/wiki/Shikaku

##
## SAT configuration:
##   - Variables: assign variable to every possible boxes around each number
##   - Clauses: exact one variable of possible box at each cell is true
##
## For example, there are four possible boxes around number 2:
##
##      a        b        c        d
##    +---+
##    | . |
##    |   |  +-------+  +---+  +-------+
##    | 2 |  | 2   . |  | 2 |  | .   2 |
##    +---+  +-------+  |   |  +-------+
##                      | . |
##                      +---+
##
## And, every cell must be covered by exact one boxes.
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
    case line
    when /^\s*#.*$/, /^\s*$/
    else
      line = line.split.map {|n| n[/^\d+$/] && n.to_i }
      width ||= line.size
      unless width == line.size
        error "illegal width: row #{ field.size + 1 }"
      end
      field << line
    end
  end

  field
end


def define_sat(solver, field)
  w = field.first.size
  h = field.size
  ary = field.map {|line| line.map { [] } }

  field.each_with_index do |line, y|
    line.each_with_index do |c, x|
      next unless c
      enum_boxes(c) do |xys|
        catch(:next) do
          xys.each do |xo, yo|
            x2, y2 = x + xo, y + yo
            throw :next if x2 < 0 || x2 >= w || y2 < 0 || y2 >= h
            throw :next if field[y2][x2] && (x != x2 || y != y2)
          end
          v = solver.new_var
          xys.each {|xo, yo| ary[y + yo][x + xo] |= [v] }
        end
      end
    end
  end

  ary.each do |line|
    line.each do |vs|
      solver << vs
      vs.combination(2) {|v1, v2| solver << [-v1, -v2] }
    end
  end

  ary
end


def enum_boxes(n)
  (1..n).each do |m|
    next unless (n / m) * m == n
    a = (0 ... n / m).to_a.product((0...m).to_a)
    a.each {|x, y| yield a.map {|x2, y2| [x2 - x, y2 - y] } }
  end
end


def solve_sat(solver)
  start = Time.now
  result = solver.solve
  eplise = Time.now - start
  puts "time: %.6f sec." % eplise
  result
end


def add_constraint(solver, vars)
  solver << vars.flatten.map {|v| solver[v] ? -v : v }
end


def make_solution(solver, ary)
  ary.map {|line| line.map {|vs| vs.find {|v| solver[v] } } }
end


def output_field(solution, field)
  w = field.first.size
  h = field.size

  ary = (0 .. h * 2).map { (0 .. w * 2).map { nil } }
  field.each_with_index do |line, y|
    line.each_with_index do |c, x|
      ary[y * 2 + 1][x * 2 + 1] = c ? c.to_s.rjust(2) : " ."

      if x == 0 || solution[y][x - 1] != solution[y][x]
        ary[y * 2 + 1][x * 2] = " |" 
      end
      ary[y * 2 + 1][x * 2 + 2] = " |" if x == w - 1
      if y == 0 || solution[y - 1][x] != solution[y][x]
        ary[y * 2][x * 2 + 1] = "--"
      end
      ary[y * 2 + 2][x * 2 + 1] = "--" if y == h - 1
    end
  end

  (0 .. h * 2).step(2) do |y|
    (0 .. w * 2).step(2) do |x|
      u = y > 0         && ary[y - 1][x]
      d = y < h * 2 - 1 && ary[y + 1][x]
      l = x > 0         && ary[y][x - 1]
      r = x < w * 2 - 1 && ary[y][x + 1]
      ary[y][x] ||= "--" if !u && !d && r && l
      ary[y][x] ||= " |" if u && d && !r && !l
      ary[y][x] ||= "-+" if l
      ary[y][x] ||= " +" if u || d || r || l
    end
  end

  puts ary.map {|line| " " + line.map {|s| s || "  " }.join }
end



error "usage: shikaku.rb shikaku.sample" if ARGV.empty?

ARGV.each do |file|
  field = parse_file(file)

  solver = MiniSat::Solver.new

  puts "defining SAT..."
  vars = define_sat(solver, field)

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
