#!/usr/bin/env ruby

# ruby-minisat example -- numberlink.rb
# ref: http://en.wikipedia.org/wiki/Number_Link

##
## SAT configuration:
##   - Variables:
##     - to each number cell:
##       - 4 variables for directions
##     - to each blank cell:
##       - 7 variables for patterns
##       - n variables for numbers
##         - the line of the cell links this numbers
##   - Clauses:
##     - exact one directions in each number cell
##     - exact one pattern in each blank cell
##     - zero linked numbers in each blank cell if the cell is blank
##     - exact one linked numbers if each blank cell if the cell has a line
##     - no blank pattern (if filled solution is required)
##     - neighbor blank cells are connected or disconnected
##       - line links continuously the two same numbers
##       - connectivity optimization (below)
##     - neighbor blank cells links the same number if they are connected
##     - patterns are false which makes line out of field
##     - blank cell in the direction of number cell connects the number cell
##     - blank cells not in the direction of number cell does not connects the
##       number cell
##     - corner optimization (below)
##
## patterns:
##   - 0 : vertical line
##   - 1 : orthogonal line (up and left)
##   - 2 : orthogonal line (up and right)
##   - 3 : orthogonal line (down and left)
##   - 4 : orthogonal line (down and right)
##   - 5 : horizontal line
##   - 6 : blank
##
##      |    |  |
##      0  --1  2--  --3  4--  --5--
##      |              |  |
##
##
## basic connectivity:
##             [0, 3, 4]
##                 |
##     [2, 4, 5]---+---[1, 3, 5]
##                 |
##             [0, 1, 2]
##
##
## connectivity optimization: prune U-turn situations
##   For example, left pattern is 2 and right one is 1.
##   In such situations, the shortcut exists:
##
##      +   +      +---+
##      |   |  =>
##      2---1      b   b
##
##
## extended horizontal connectivity:
##    l\r 1 3 5
##    2     o o
##    4   o   o
##    5   o o o
##
## extended veritcal connectivity:
##    u\d 0 1 2
##    0   o o o
##    3   o   o
##    4   o o
##
##
## corner optimization: patterns 1 and 2 exists only `corner of number'
##   - pattern 1 can be only in the lower right-hand corner of number or 1
##   - pattern 2 can be only in the lower left-hand corner of number or 2
##
##
##      n   +                           +   n
##          |                           |
##      +---1   +                   +   2---+
##              |                   |
##          +---1   +           +   2---+
##                  |           |
##              +---1           2---+
##
## directions:
##   - 0: up
##   - 1: down
##   - 2: left
##   - 3: right
##



require "minisat"
require File.dirname($0) + "/compat18" if RUBY_VERSION < "1.9.0"

$filled = true


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
      line = line.split.map {|x| x[/^\d+$/] && x.to_i }
      width ||= line.size
      unless width == line.size
        error "illegal width: row #{ field.size + 1 }"
      end
      field << line
    end
  end

  h = {}
  field.flatten.compact.sort.each_slice(2) do |x, y|
    error "bad field" if x == 0 || x != y || h[x]
    h[x] = true
  end

  field
end


def define_sat(solver, field)
  w = field.first.size
  h = field.size

  num = field.flatten.compact.uniq.size

  # define variables:
  #  - 4 variables (directions) to each number cell
  #  - 7 (patterns) + n (numbers) variables to each blank cell
  vars = field.map do |line|
    line.map do |c|
      if c
        # number cell
        dirs = (0...4).map { solver.new_var }

        # exact one directions
        exact_one(solver, dirs)

        dirs
      else
        # blank cell
        pats = (0...7).map { solver.new_var }
        nums = (0...num).map { solver.new_var }

        # exact one pattern
        exact_one(solver, pats)

        # zero connected numbers in each blank cell if the cell is blank
        # exact one connected numbers if each blank cell if the cell has a line
        ([pats.last] + nums).combination(2) {|v1, v2| solver << [-v1, -v2] }

        # no blank pattern (if filled solution is required)
        solver << -pats.last if $filled

        [pats, nums]
      end
    end
  end

  # define connection rule
  field.each_with_index do |line, y|
    line.each_with_index do |num, x|
      if num
        number_connectivity(solver, field, vars, x, y, w, h)
      else
        line_connectivity(solver, field, vars, x, y, w, h)
      end
    end
  end

  # corner optimization
  l_corner, r_corner = {}, {}
  field.each_with_index do |line, y|
    line.each_with_index do |num, x|
      if num
        l_corner[[x - 1, y + 1]] = r_corner[[x + 1, y + 1]] = true
      else
        if l_corner[[x, y]]
          l_corner[[x - 1, y + 1]] = true
          if !field[y - 1][x + 1]
            solver << [-vars[y][x].first[2], vars[y - 1][x + 1].first[2]]
          end
        else
          solver << -vars[y][x].first[2]
        end
        if r_corner[[x, y]]
          r_corner[[x + 1, y + 1]] = true
          if !field[y - 1][x - 1]
            solver << [-vars[y][x].first[1], vars[y - 1][x - 1].first[1]]
          end
        else
          solver << -vars[y][x].first[1]
        end
      end
    end
  end

  vars
end


# basic connectivity
    U_CON     =       [0, 3, 4]
L_CON,  R_CON = [2, 4, 5],  [1, 3, 5]
    D_CON     =       [0, 1, 2]


DIR = [[0, -1], [0, 1], [-1, 0], [1, 0]]


def line_connectivity(solver, field, vars, x, y, w, h)
  if x < w - 1 && !field[y][x + 1]
    l_pats, l_nums = vars[y][x]
    r_pats, r_nums = vars[y][x + 1]

    # extended horizontal connectivity
    solver << [-l_pats[2],            r_pats[3], r_pats[5]]
    solver << [-l_pats[4], r_pats[1],            r_pats[5]]
    solver << [-l_pats[5], r_pats[1], r_pats[3], r_pats[5]]
    solver << [-r_pats[1],            l_pats[4], l_pats[5]]
    solver << [-r_pats[3], l_pats[2],            l_pats[5]]
    solver << [-r_pats[5], l_pats[2], l_pats[4], l_pats[5]]

    # the same number if connected
    l_nums.zip(r_nums) do |l_num, r_num|
      L_CON.each do |i|
        solver << [-l_pats[i], -l_num, r_num] << [-l_pats[i], l_num, -r_num]
      end
    end
  end

  if y < h - 1 && !field[y + 1][x]
    u_pats, u_nums = vars[y][x]
    d_pats, d_nums = vars[y + 1][x]

    # extended vartical connectivity
    solver << [-u_pats[0], d_pats[0], d_pats[1], d_pats[2]]
    solver << [-u_pats[3], d_pats[0],            d_pats[2]]
    solver << [-u_pats[4], d_pats[0], d_pats[1]           ]
    solver << [-d_pats[0], u_pats[0], u_pats[3], u_pats[4]]
    solver << [-d_pats[1], u_pats[0],            u_pats[4]]
    solver << [-d_pats[2], u_pats[0], u_pats[3]           ]

    # the same number if connected
    u_nums.zip(d_nums) do |u_num, d_num|
      U_CON.each do |i|
        solver << [-u_pats[i], -u_num, d_num] << [-u_pats[i], u_num, -d_num]
      end
    end
  end

  # edges of field
  R_CON.map {|i| solver << -vars[y][x].first[i] } if x == 0
  L_CON.map {|i| solver << -vars[y][x].first[i] } if x == w - 1
  D_CON.map {|i| solver << -vars[y][x].first[i] } if y == 0
  U_CON.map {|i| solver << -vars[y][x].first[i] } if y == h - 1
end


def number_connectivity(solver, field, vars, x, y, w, h)
  rev = [U_CON, D_CON, L_CON, R_CON].zip(DIR).to_a
  num = field[y][x]

  4.times do |i|
    dir = vars[y][x][i]
    con, (xo, yo) = rev[0]
    x2, y2 = x + xo, y + yo
    if x2 >= 0 && x2 < w && y2 >= 0 && y2 < h && !field[y2][x2]
      pats, nums = vars[y2][x2]
      solver << [-dir, nums[num - 1]]
      solver << [-dir] + con.map {|i| pats[i] }
      (pats - con.map {|i| pats[i] }).each {|v| solver << [-dir, -v] }
      (1..3).each do |j|
        con, (xo, yo) = rev[j]
        x2, y2 = x + xo, y + yo
        if x2 >= 0 && x2 < w && y2 >= 0 && y2 < h && !field[y2][x2]
          pats, nums = vars[y2][x2]
          con.each {|i| solver << [-dir, -pats[i]] }
          solver << [-dir] + (pats - con.map {|i| pats[i] })
        end
      end
    elsif x2 >= 0 && x2 < w && y2 >= 0 && y2 < h && num == field[y2][x2]
      solver << dir
    else
      solver << -dir
    end
    rev << rev.shift
  end
end


def exact_one(solver, vars)
  solver << vars
  vars.combination(2) {|v1, v2| solver << [-v1, -v2] }
end


def make_solution(solver, vars, field)
  field.zip(vars).map do |fline, vline|
    fline.zip(vline).map do |num, vs|
      if num
        (0...4).find {|i| solver[vs[i]] }
      else
        (0...7).find {|i| solver[vs.first[i]] }
      end
    end
  end
end


def add_constraint(solver, vars)
  solver << vars.flatten.map {|v| solver[v] ? -v : v }
end


def output_field(solution, field)
  w = field.first.size
  h = field.size
  ary = (0 ... h).map { (0 ... w).map { nil } }

  solution.each_with_index do |line, y|
    line.each_with_index do |c, x|
      num = field[y][x]
      ary[y][x] = if num
        case c
        when 0 then ["    #{ num }"[-4..-1], "    "]
        when 1 then ["    #{ num }"[-4..-1], "   |"]
        when 2 then ["----#{ num }"[-4..-1], "    "]
        when 3 then ["    #{ num }"[-4..-1], "    "]
        end
      else
        case c
        when 0 then ["   +", "   |"]
        when 1 then ["---+", "    "]
        when 2 then ["   +", "    "]
        when 3 then ["---+", "   |"]
        when 4 then ["   +", "   |"]
        when 5 then ["---+", "    "]
        when 6 then ["    ", "    "]
        end
      end
    end
  end
  ary.map {|line| line.transpose }.flatten(1)[0..-2].each do |line|
    puts line.join.rstrip[1..-1]
  end
end

def find_loops(solution, field)
  solution = solution.map {|line| line.dup }
  field.each_with_index do |line, y|
    line.each_with_index do |num, x|
      next unless num
      xo, yo = DIR[solution[y][x]]
      solution[y][x] = nil
      find_loops_aux(solution, field, x + xo, y + yo)
    end
  end

  loops = []
  solution.each_with_index do |line, y|
    line.each_with_index do |c, x|
      next if !c || c == 6
      loops << find_loops_aux(solution, field, x, y)
    end
  end

  loops
end


def find_loops_aux(solution, field, x, y)
  ary = []
  while !field[y][x]
    num = solution[y][x]
    ary << [x, y, num] if num
    solution[y][x] = nil
    case num
    when 0 then solution[y - 1][x] ? y -= 1 : y += 1
    when 1 then solution[y - 1][x] ? y -= 1 : x -= 1
    when 2 then solution[y - 1][x] ? y -= 1 : x += 1
    when 3 then solution[y + 1][x] ? y += 1 : x -= 1
    when 4 then solution[y + 1][x] ? y += 1 : x += 1
    when 5 then solution[y][x - 1] ? x -= 1 : x += 1
    else break
    end
  end
  ary
end


def add_loop_constraint(solver, vars, loops)
  loops.each do |ary|
    solver << ary.map {|x, y, c| vars[y][x].first[c] }
  end
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

    puts "translating model into solution..."
    solution = make_solution(solver, vars, field)
    loops = find_loops(solution, field)
    add_loop_constraint(solver, vars, loops)

    if loops.empty?
      puts found_msg
      output_field(solution, field)
      puts
      return true
    end
  end
end


if ARGV.first == "-f"
  $filled = true
  ARGV.shift
end
if ARGV.first == "-b"
  $filled = false
  ARGV.shift
end

if ARGV.empty?
  $stderr.puts <<END
usage: numberlink.rb [-f or -b] numberlink.sample
options:
  -f  search only filled solution (any blank cell has line) [default]
  -b  search any solution (blank cell may remain) (slowish)
END
  exit 0
end

ARGV.each do |file|
  field = parse_file(file)

  solver = MiniSat::Solver.new

  puts "defining SAT..."
  vars = define_sat(solver, field)
  puts "variables : #{ solver.var_size }"
  puts

  str = $filled ? "(filled) solution" : "solution"

  prog_msg = "solving SAT"
  found_msg = "#{ str } found."
  not_found_msg = "unsolvable."
  solve(solver, vars, field, prog_msg, found_msg, not_found_msg) or exit 1

  add_constraint(solver, vars)

  prog_msg = "finding different #{ str }"
  found_msg = "different #{ str } found."
  not_found_msg = "different #{ str } not found."
  solve(solver, vars, field, prog_msg, found_msg, not_found_msg) and exit 1
  puts
  puts
end
