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

# Shared test helpers
module TestIOHelpers
  # Suppress stdout/stderr within the given block, yielding the StringIOs
  def silence_output
    original_stdout = $stdout
    original_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
    yield $stdout, $stderr
  ensure
    $stdout = original_stdout
    $stderr = original_stderr
  end
end

# CLI test helpers
module CLITestHelpers
  # Run CLI with the given arguments and return [stdout, stderr, exit_status]
  def run_cli_with_status(*argv)
    cli = SimpleCovMcp::CoverageCLI.new
    status = nil
    out_str = err_str = nil
    silence_output do |out, err|
      begin
        cli.run(argv.flatten)
        status = 0
      rescue SystemExit => e
        status = e.status
      end
      out_str = out.string
      err_str = err.string
    end
    [out_str, err_str, status]
  end
end

RSpec.configure do |config|
  config.include TestIOHelpers
  config.include CLITestHelpers
end
