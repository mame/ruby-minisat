#!/usr/bin/env ruby

# ruby-minisat example -- slitherlink.rb
# ref: http://en.wikipedia.org/wiki/Slitherlink

##
## SAT configuration:
##   - Variables: assign one variable to each edge
##   - Clauses: some rules of slither link (below)
##
##
## rules of slither link:
##   - rule 1. at each vertex, zero or two surround edges are drawn
##   - rule 2. at each cell, specified number of surround edges are drawn
##   - rule 3. drawn edges make exact one loop
##
##
## We have no good idea how to write the rule 3; SAT solver may find bad
## solution in that there are multiple loops.  So we use following approach:
##
##   - find any solution that satisfies only the rules 1 and 2,
##   - count loops of the solution,
##   - if the number of loop is exact one, it is good solution
##   - if the number of loop is more than one, add new constraint that prevents
##     the solution, and retry to solve
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
      line = line.split.map {|x| x[/^\d$/] && x.to_i }
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

  # define horizontal and vertical edges
  h_vars = (0..h).map { (0...w).map { solver.new_var } }
  v_vars = (0...h).map { (0..w).map { solver.new_var } }

  # define clauses
  # rule 1
  (0..h).each do |y|
    (0..w).each do |x|
      edges = []
      edges << h_vars[y][x - 1] if x > 0
      edges << h_vars[y][x    ] if x < w
      edges << v_vars[y - 1][x] if y > 0
      edges << v_vars[y    ][x] if y < h

      # exact zero or two variables are true
      a, b, c, d = edges
      case edges.size
      when 2
        solver << [a, -b] << [-a, b]
      when 3
        solver << [-a, b, c] << [a, -b, c] << [a, b, -c] << [-a, -b, -c]
      when 4
        solver <<
          [-a,  b,  c,  d] <<
          [ a, -b,  c,  d] <<
          [ a,  b, -c,  d] <<
          [ a,  b,  c, -d] <<
          [-a, -b, -c] <<
          [-b, -c, -d] <<
          [-c, -d, -a] <<
          [-d, -a, -b]
      end
    end
  end

  ## rule 2
  field.each_with_index do |line, y|
    line.each_with_index do |c, x|
      edges = [h_vars[y][x], h_vars[y + 1][x], v_vars[y][x], v_vars[y][x + 1]]

      # specified number of variables are true
      case c
      when 0
        edges.each {|v| solver << -v }
      when 1
        solver << edges
        edges.combination(2) {|v1, v2| solver << [-v1, -v2] }
      when 2
        edges.combination(3) do |v1, v2, v3|
          solver << [v1, v2, v3] << [-v1, -v2, -v3]
        end
      when 3
        solver << edges.map {|v| -v }
        edges.combination(2) {|v1, v2| solver << [v1, v2] }
      when 4
        edges.each {|v| solver << v }
      end
    end
  end

  [h_vars, v_vars]
end


def count_loops(solver, vars)
  h_vars, v_vars = vars

  ps = {}
  h_vars.each_with_index do |l, y|
    l.each_with_index {|c, x| ps[[x * 2 + 1, y * 2]] = true if solver[c] }
  end
  v_vars.each_with_index do |l, y|
    l.each_with_index {|c, x| ps[[x * 2, y * 2 + 1]] = true if solver[c] }
  end
  loops = []
  until ps.size == 0
    ary = []
    x, y = ps.keys.first
    loop do
      ary << [x, y]
      ps.delete [x, y]
      if x % 2 == 0
        case
        when ps[[x - 1, y - 1]] then x, y = x - 1, y - 1
        when ps[[x + 1, y - 1]] then x, y = x + 1, y - 1
        when ps[[x    , y - 2]] then x, y = x    , y - 2
        when ps[[x - 1, y + 1]] then x, y = x - 1, y + 1
        when ps[[x + 1, y + 1]] then x, y = x + 1, y + 1
        when ps[[x    , y + 2]] then x, y = x    , y + 2
        else break
        end
      else
        case
        when ps[[x - 1, y - 1]] then x, y = x - 1, y - 1
        when ps[[x - 1, y + 1]] then x, y = x - 1, y + 1
        when ps[[x - 2, y    ]] then x, y = x - 2, y
        when ps[[x + 1, y - 1]] then x, y = x + 1, y - 1
        when ps[[x + 1, y + 1]] then x, y = x + 1, y + 1
        when ps[[x + 2, y    ]] then x, y = x + 2, y
        else break
        end
      end
    end
    loops << ary
  end
  loops
end


def add_constraint(solver, vars, loops)
  h_vars, v_vars = vars

  loops.map do |ary|
    ary.map do |x, y|
      v = (x % 2 == 0 ? v_vars : h_vars)[y / 2][x / 2]
      solver[v] ? -v : v
    end
  end.each {|e| solver << e }
end


def output_field(solver, vars, field)
  w = field.first.size
  h = field.size
  h_vars, v_vars = vars

  ary = (0 .. h * 2).map { (0 .. w * 2).map { nil } }
  h_vars.each_with_index do |l, y|
    l.each_with_index do |c, x|
      ary[y * 2][x * 2 + 1] = "--" if solver[c]
    end
  end
  v_vars.each_with_index do |l, y|
    l.each_with_index do |c, x|
      ary[y * 2 + 1][x * 2] = " |" if solver[c]
    end
  end
  field.each_with_index do |l, y|
    l.each_with_index do |c, x|
      ary[y * 2 + 1][x * 2 + 1] = c ? c.to_s.rjust(2) : " ."
    end
  end
  (0 .. h * 2).step(2) do |y|
    (0 .. w * 2).step(2) do |x|
      u = y > 0     && ary[y - 1][x]
      d = y < h * 2 && ary[y + 1][x]
      ary[y][x] = " |" if u && d
      r = x > 0     && ary[y][x - 1]
      l = x < w * 2 && ary[y][x + 1]
      ary[y][x] = "--" if r && l
      ary[y][x] ||= " +" if l
      ary[y][x] ||= "-+" if u || d || r || l
    end
  end
  ary.each {|l| puts "  " + l.map {|c| c || "  " }.join }
end


def solve(solver, vars, field, prog_msg, found_msg, not_found_msg)
  trial = 0
  loop do
    trial += 1
    puts "#{ prog_msg }... (trial #{ trial })"
    puts "clauses : #{ solver.clause_size }"

    start = Time.now
    result = solver.solve
    eplise = Time.now - start
    puts "time: %.6f sec." % eplise
    puts
    unless result
      puts not_found_msg
      return false
    end

    loops = count_loops(solver, vars)

    error "no loop is needed" if loops.empty?

    if loops.size == 1
      puts found_msg
      output_field(solver, vars, field)
      puts
    end

    add_constraint(solver, vars, loops)

    return true if loops.size == 1
  end
end



error "usage: slitherlink.rb slitherlink.sample" if ARGV.empty?

ARGV.each do |file|
  field = parse_file(file)

  solver = MiniSat::Solver.new

  puts "defining SAT..."
  vars = define_sat(solver, field)
  puts "variables : #{ solver.var_size }"
  puts

  prog_msg = "solving SAT"
  found_msg = "solution found."
  not_found_msg = "unsolvable."
  solve(solver, vars, field, prog_msg, found_msg, not_found_msg) or exit 1

  prog_msg = "finding different solution"
  found_msg = "different solution found."
  not_found_msg = "different solution not found."
  solve(solver, vars, field, prog_msg, found_msg, not_found_msg) and exit 1
  puts
  puts
end
