require 'rake'
require 'yard'

begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec)
rescue LoadError
end

YARD::Rake::YardocTask.new do |t|
  t.files   = ['lib/**/*.rb']   # optional
end
