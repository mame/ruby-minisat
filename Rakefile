require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  jeweler_tasks = Jeweler::Tasks.new do |gem|
    gem.name = "ruby-minisat"
    gem.summary = %Q{ruby binding for MiniSat, which is an open-source SAT solver}
    gem.description = gem.summary
    gem.email = "mame@tsg.ne.jp"
    gem.homepage = "http://github.com/mame/ruby-minisat"
    gem.authors = ["Yusuke Endoh"]
    gem.extensions = FileList['ext/**/extconf.rb']
    gem.files.include FileList['ext/**/*', 'minisat/**/*/**']
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

task :test => :check_dependencies

task :default => :test

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "ruby-minisat #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('ext/**/*.c')
end

begin
  require 'rake/extensiontask'
  require 'rake/extensiontesttask'

  Rake::ExtensionTask.new('minisat', jeweler_tasks.gemspec)
rescue LoadError
end
