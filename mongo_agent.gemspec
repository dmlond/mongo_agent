Gem::Specification.new do |s|
  s.name        = 'mongo_agent'
  s.version     = '0.0.2'
  s.date        = '2014-11-20'
  s.summary     = "MongoAgent is a framework for creating distributed pipelines across many different servers, each using the same MongoDB as a control panel."
  s.description = <<-EOF
MongoAgent is a framework for creating distributed pipelines across many
different servers. It is extensible, and flexible. It does not specify what goals
should be processed.  It simply provides the foundation for using a MongoDB as
a messaging queue between many different agents processing tasks defined in the
same queue. It is designed from the beginning to support the creation of simple
human-computational workflows.
EOF
  s.author     = "Darin London"
  s.license    = "MIT"
  s.email       = 'darin.london@duke.edu'
  s.files       = ["Gemfile", ".rspec", "Rakefile"] + Dir["lib/**/*"] + Dir["spec/**/*"]
  s.test_files = Dir["spec/*.rb"]
  s.homepage    =    'http://rubygems.org/gems/mongo_agent'
end
