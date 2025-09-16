# frozen_string_literal: true

# Enable SimpleCov for this project (coverage output in ./coverage)
begin
  require 'simplecov'
  SimpleCov.start do
    enable_coverage :branch if SimpleCov.respond_to?(:enable_coverage)
    add_filter %r{^/spec/}
    track_files 'lib/**/*.rb'
  end
rescue LoadError
  warn 'SimpleCov not available; skipping coverage'
end

ENV.delete('SIMPLECOV_RESULTSET')

require 'rspec'
require 'pathname'
require 'json'

require 'simple_cov_mcp'

FIXTURES = Pathname.new(File.expand_path('fixtures', __dir__))

RSpec.configure do |config|
  config.example_status_persistence_file_path = '.rspec_status'
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end
