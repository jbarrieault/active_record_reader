require 'active_record'
require 'active_record/base'
require 'active_record_reader/version'
require 'active_record_reader/reader'
require 'active_record_reader/instance_methods'
require 'active_record_reader/active_record_reader'

if defined?(Rails)
  require 'active_record_reader/railtie'
end
