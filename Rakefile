# Setup bundler to avoid having to run bundle exec all the time.
require 'rubygems'
require 'bundler/setup'

require 'rake/testtask'
require_relative 'lib/active_record_reader/version'

task :gem do
  system "gem build active_record_reader.gemspec"
end

task :publish => :gem do
  system "git tag -a v#{ActiveRecordReader::VERSION} -m 'Tagging #{ActiveRecordReader::VERSION}'"
  system "git push --tags"
  system "gem push active_record_reader-#{ActiveRecordReader::VERSION}.gem"
  system "rm active_record_reader-#{ActiveRecordReader::VERSION}.gem"
end

Rake::TestTask.new(:test) do |t|
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
  t.warning = false
end

# By default run tests against all appraisals
if !ENV["APPRAISAL_INITIALIZED"] && !ENV["TRAVIS"]
  require 'appraisal'
  task default: :appraisal
else
  task default: :test
end
