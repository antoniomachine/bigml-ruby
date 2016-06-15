begin
require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.pattern = 'test/test_*.rb'
  #t.verbose = true
end

desc "Run tests"
task :default => :test
end
