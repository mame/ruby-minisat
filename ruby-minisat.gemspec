# coding: utf-8
Gem::Specification.new do |spec|
  spec.name          = "ruby-minisat"
  spec.version       = "2.2.0"
  spec.authors       = ["Yusuke Endoh"]
  spec.email         = ["mame@tsg.ne.jp"]
  spec.description   = %q{ruby binding for MiniSat, an open-source SAT solver}
  spec.summary       = %q{ruby binding for MiniSat, an open-source SAT solver}
  spec.homepage      = "http://github.com/mame/ruby-minisat"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.extensions << 'ext/minisat/extconf.rb'
  spec.require_paths = ["ext/minisat/"]
  spec.rdoc_options = %w[--exclude .*\.o --exclude minisat.so]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end
