$:.push File.expand_path('../lib', __FILE__)

# Maintain your gem's version:
require 'active_record_reader/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = 'active_record_reader'
  spec.version     = ActiveRecordReader::VERSION
  spec.platform    = Gem::Platform::RUBY
  spec.authors     = ['Reid Morrison']
  spec.email       = ['reidmo@gmail.com']
  spec.homepage    = 'https://github.com/rocketjob/active_record_reader'
  spec.summary     = 'Redirect ActiveRecord (Rails) reads to reader databases while ensuring all writes go to the primary database.'
  spec.files       = Dir['lib/**/*', 'LICENSE.txt', 'Rakefile', 'README.md']
  spec.test_files  = Dir['test/**/*']
  spec.license     = 'Apache License V2.0'
  spec.has_rdoc    = true
  spec.add_dependency 'activerecord', '>= 3.0'
end
