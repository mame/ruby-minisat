# Minisat

ruby-minisat is ruby binding for MiniSat, an open-source SAT solver.

## Installation

    $ gem install ruby-minisat

## Usage

A brief example that solves a simple SAT problem:

    # solve (a or b) and (not a or b) and (a or not b)

    require "minisat"
    solver = MiniSat::Solver.new
    
    a = solver.new_var
    b = solver.new_var
    
    solver << [a, b] << [-a, b] << [a, -b]
    
    p solver.solve  #=> true (satisfiable)
    
    p solver[a]  #=> true
    p solver[b]  #=> true

For more examples, see the examples directory in the distribution.

## Copyright

ruby-minisat is covered under the MIT License.
This package includes MiniSat in the directory `minisat` which is also
distributed under the MIT License.  See `minisat/minisat/LICENSE`.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
