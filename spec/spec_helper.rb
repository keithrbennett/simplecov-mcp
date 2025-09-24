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

FIXTURES_DIR = Pathname.new(File.expand_path('fixtures', __dir__))

# Test timestamp constants for consistent and documented test data
# Main fixture coverage timestamp: 1720000000 = 2024-07-03 16:26:40 UTC
# This represents when the coverage data in spec/fixtures/project1/coverage/.resultset.json was "generated"
FIXTURE_COVERAGE_TIMESTAMP = 1_720_000_000

# Very old timestamp: 0 = 1970-01-01 00:00:00 UTC (Unix epoch)
# Used in tests to simulate stale coverage (much older than any real file)
VERY_OLD_TIMESTAMP = 0

# Test timestamps for stale error formatting tests
# 1000 = 1970-01-01 00:16:40 UTC (16 minutes and 40 seconds after epoch)
TEST_FILE_TIMESTAMP = 1_000

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

# MCP Tool shared examples and helpers
module MCPToolTestHelpers
  def setup_mcp_response_stub
    # Standardized MCP::Tool::Response stub that works for all tools
    response_class = Class.new do
      attr_reader :payload, :meta
      def initialize(payload, meta: nil)
        @payload = payload
        @meta = meta
      end
    end
    stub_const('MCP::Tool::Response', response_class)
  end
  
  def expect_mcp_json_resource(response, expected_keys: [])
    item = response.payload.first
    
    # Standard MCP resource structure
    expect(item['type']).to eq('resource')
    expect(item['resource']).to include('mimeType' => 'application/json')
    expect(item['resource']).to have_key('name')
    expect(item['resource']).to have_key('text')
    
    # Parse and validate JSON content
    data = JSON.parse(item['resource']['text'])
    
    # Check for expected keys
    expected_keys.each do |key|
      expect(data).to have_key(key)
    end
    
    [data, item] # Return for additional custom assertions
  end
end

RSpec.shared_examples 'an MCP tool that returns JSON resource' do
  let(:server_context) { instance_double('ServerContext').as_null_object }
  
  before do
    setup_mcp_response_stub
  end
  
  it 'returns a properly structured MCP JSON resource' do
    response = subject
    expect_mcp_json_resource(response)
  end
end

RSpec.configure do |config|
  config.include TestIOHelpers
  config.include CLITestHelpers
  config.include MCPToolTestHelpers
end

# Custom matchers
RSpec::Matchers.define :show_source_table_or_fallback do
  match do |output|
    has_table_header = output.match?(/(^|\n)\s*Line\s+\|\s+Source/)
    has_fallback = output.include?('[source not available]')
    has_table_header || has_fallback
  end

  failure_message do |output|
    "expected output to include a source table header (e.g., 'Line | Source') or the fallback '[source not available]'"
  end
end
