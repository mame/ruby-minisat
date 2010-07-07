#!/usr/bin/env ruby

# ruby-minisat example -- lonely7.rb


require "minisat"
require File.dirname($0) + "/compat18" if RUBY_VERSION < "1.9.0"


###############################################################################


class Digit
  def initialize
    @vars = (0..9).map { $solver.new_var }
    $solver << vars
    vars.combination(2) {|v1, v2| $solver << [-v1, -v2] }
  end

  attr_reader :vars

  def is(n)
    case n
    when Digit
      vars.zip(n.vars) {|v1, v2| $solver << [v1, -v2] << [-v1, v2] }
    when Numeric
      $solver << vars[n]
    else raise TypeError
    end
  end

  def is_not(n)
    case n
    when Digit
      vars.zip(n.vars) {|v1, v2| $solver << [-v1, -v2] }
    when Numeric
      $solver << -vars[n]
    else raise TypeError
    end
  end

  def sum(a, b, f = nil)
    sumdiff(a, b, f) {|na, nb| na + nb }
  end

  def diff(a, b, f = nil)
    sumdiff(a, b, f) {|na, nb| na - nb }
  end

  def sumdiff(a, b, f = nil)
    c = f ? Digit.new : self
    f2 = pair(a, b, c) {|na, nb| n = yield(na, nb); [n % 10, n % 10 != n] }
    f ? flag(c, f, f2) {|n| n = yield(n, 1); [n % 10, n % 10 != n] } : f2
  end

  def prod(a, b, d)
    if b.is_a?(Numeric)
      b2 = Digit.new
      b2.is b
      b = b2
    end
    a.vars.each_with_index do |va, na|
      b.vars.each_with_index do |vb, nb|
        nd, nc = (na * nb).divmod(10)
        $solver << [-va, -vb, vars[nc]] << [-va, -vb, d.vars[nd]]
      end
    end
  end

  def less(b, f)
    fs = (0..9).map { $solver.new_var }
    fr = $solver.new_var
    b.vars.each_with_index do |vb, nb|
      va = vars[nb]
      vf = fs[nb]
      $solver << [-f, -vb] + vars[0..nb]
      $solver << [-vb, -va, vf] << [-vf, va] << [-vf, vb] << [-vf, fr]
    end
    $solver << [-fr, f] << [-fr] + fs
    fr
  end

  def pair(a, b, c)
    f = $solver.new_var
    a.vars.each_with_index do |va, na|
      b.vars.each_with_index do |vb, nb|
        nc, f2 = yield(na, nb)
        $solver << [-va, -vb, c.vars[nc]] << [-va, -vb, f2 ? f : -f]
      end
    end
    f
  end

  def flag(a, f0, f1)
    f2 = $solver.new_var
    $solver << [f0, -f2]
    a.vars.each_with_index do |v, n|
      $solver << [-v, f0, vars[n]]
      n2, f = yield n
      $solver << [-v, -f0, vars[n2]] << [-v, -f0, f ? f2 : -f2]
    end

    f3 = $solver.new_var
    $solver << [-f1, f3] << [-f2, f3] << [-f3, f1, f2]
    f3
  end

  def to_i
    (0..9).find {|n| $solver[vars[n]] }.to_i
  end
end

class Digits
  def initialize(n)
    @digits = n.is_a?(Numeric) ? (0...n).map { Digit.new } : n
  end

  attr_reader :digits

  def is(num)
    case num
    when Adder, Subtracter
      f = nil
      z = zero
      ms = [num.left, num.right, self].
        max {|x, y| x.digits.size <=> y.digits.size }
      as = ms.extend(num.left.digits, z)
      bs = ms.extend(num.right.digits, z)
      cs = ms.extend(digits, z)
      as.zip(bs, cs) do |a, b, c|
        f = num.is_a?(Adder) ? c.sum(a, b, f) : c.diff(a, b, f)
      end
      $solver << -f
    when Multiplier
      f = d = nil
      b = num.right
      as = extend(num.left.digits, zero)
      as.zip(digits) do |a, c|
        c2 = d ? Digit.new : c
        d2 = Digit.new
        c2.prod(a, b, d2)
        f = c.sum(c2, d, f) if d
        d = d2
      end
      $solver << -f
      d.is 0
    end
  end

  def less(b)
    z = zero
    bs = extend(b.digits, z)
    as = b.extend(digits, z)
    f = $solver.new_var
    $solver << f
    as.reverse.zip(bs.reverse).each do |a, b|
      f = a.less(b, f)
    end
    $solver << -f
  end

  def extend(as, z)
    digits.size > as.size ? as + [z] * (digits.size - as.size) : as
  end

  def top
    digits.last
  end

  def *(d); Multiplier.new(self, d); end
  def -(d); Subtracter.new(self, d); end
  def +(d); Adder.new(self, d); end

  def [](*arg)
    case arg.size
    when 1 then digits.reverse[arg.first]
    when 2 then Digits.new(digits.reverse[arg.first, arg.last].reverse)
    end
  end

  def to_i
    digits.map {|v| v.to_i }.reverse.inject(0) {|z, x| z * 10 + x }
  end

  Adder = Struct.new(:left, :right)
  Subtracter = Struct.new(:left, :right)
  Multiplier = Struct.new(:left, :right)
end

def zero
  d = Digit.new
  d.is 0
  d
end


###############################################################################


$solver = MiniSat::Solver.new

str = <<END
          x7yzw
      ---------
  aaa )bbbbbbbb
       cccc
       -----
         ddd
         eee
         ----
         ffff
          ggg
          -----
           hhhh
           hhhh
           ----
              0
END

puts "problem:"
puts str.gsub(/[a-z]/m, "#")

a = Digits.new(3); a.top.is_not 0
b = Digits.new(8); b.top.is_not 0
c = Digits.new(4); c.top.is_not 0
d = Digits.new(3); d.top.is_not 0
e = Digits.new(3); e.top.is_not 0
f = Digits.new(4); f.top.is_not 0
g = Digits.new(3); g.top.is_not 0
h = Digits.new(4); h.top.is_not 0
i = Digits.new(3)
j = Digits.new(4)
x, y, z, w = (0..3).map { Digit.new }
x.is_not 0

c.is a * x;               d[0, 2].is b[0, 4] - c; d[0, 2].less a
e.is a * 7; d[2].is b[4]; f[0, 3].is d       - e; f[0, 3].less a
g.is a * y; f[3].is b[5]; h[0, 2].is f       - g; h[0, 2].less a
z.is 0;                                           h[0, 3].less a
h.is a * w; h[2].is b[6]; h[3].is b[7]

$solver.solve

puts "answer:"
puts str.
  gsub(/a+/, a.to_i.to_s).
  gsub(/b+/, b.to_i.to_s).
  gsub(/c+/, c.to_i.to_s).
  gsub(/d+/, d.to_i.to_s).
  gsub(/e+/, e.to_i.to_s).
  gsub(/f+/, f.to_i.to_s).
  gsub(/g+/, g.to_i.to_s).
  gsub(/h+/, h.to_i.to_s).
  gsub(/x+/, x.to_i.to_s).
  gsub(/y+/, y.to_i.to_s).
  gsub(/z+/, z.to_i.to_s).
  gsub(/w+/, w.to_i.to_s)
puts
puts


###############################################################################


$solver = MiniSat::Solver.new

str = <<END
  send
+ more
------
 money
END
puts "problem:"
puts str
puts

as = Digits.new(4); as.top.is_not 0
bs = Digits.new(4); bs.top.is_not 0
cs = Digits.new(5); cs.top.is_not 0

h = {}

as.digits.reverse.zip(%w(s e n d)) {|d, c| (h[c] ||= []) << d }
bs.digits.reverse.zip(%w(m o r e)) {|d, c| (h[c] ||= []) << d }
cs.digits.reverse.zip(%w(m o n e y)) {|d, c| (h[c] ||= []) << d }
cs.is as + bs

h.each do |c, ds|
  ds[1..-1].each {|d| ds.first.is d }
  h.each do |c2, ds2|
    next if c == c2
    ds2.each {|d2| ds.first.is_not d2 }
  end
end

$solver.solve

puts "answer:"
h.each {|c, d| str = str.gsub(c) { d.first.to_i } }
puts str
puts
puts
