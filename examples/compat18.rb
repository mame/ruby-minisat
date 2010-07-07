if RUBY_VERSION < "1.9.0"
  require "enumerator"
  class Array
    def permutation(n = nil, ary = [])
      n = size unless n
      if n == 0
        yield ary
      else
        each_with_index do |x, i|
          (self[0 ... i] + self[i + 1 .. -1]).
            permutation(n - 1, ary + [x]) {|r| yield r }
        end
      end
    end
    def combination(n)
      if n == 0
        yield []
      else
        (0 .. size - n).each do |i|
          self[i + 1 ... size].combination(n - 1) do |ary|
            yield [self[i]] + ary
          end
        end
      end
    end
    def product(ary)
      result = []
      self.each do |i|
        ary.each do |j|
          result << [i, j]
        end
      end
      result
    end
    alias flatten_org flatten
    def flatten(i = nil)
      if i
        a = self
        i.times do
          r = []
          a.each do |x|
            x.is_a?(Array) ? r += x : r << x
          end
          a = r
        end
        a
      else
        flatten_org
      end
    end
  end

  class Range
    alias step_org step
    def step(s)
      if block_given?
        step_org(s) {|x| yield x }
      else
        a = []
        step_org(s) {|x| a << x }
        a
      end
    end
  end
end
