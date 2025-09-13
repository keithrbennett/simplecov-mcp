# frozen_string_literal: true

ENV.delete("SIMPLECOV_RESULTSET")

require "rspec"
require "pathname"
require "json"

require "simplecov/mcp"

FIXTURES = Pathname.new(File.expand_path("fixtures", __dir__))

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end

