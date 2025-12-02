# frozen_string_literal: true

# Enable SimpleCov for this project (coverage output in ./coverage)
begin
  require 'simplecov'
  SimpleCov.start do
    enable_coverage :branch if SimpleCov.respond_to?(:enable_coverage)
    add_filter(/^\/spec\//)
    track_files 'lib/**/*.rb'
  end

  # Report lowest coverage files at the end of the test run
  SimpleCov.at_exit do
    SimpleCov.result.format!
    require 'simplecov_mcp'
    report = SimpleCovMcp::CoverageReporter.report(threshold: 80, count: 5)
    puts report if report
  end
rescue LoadError
  warn 'SimpleCov not available; skipping coverage'
end


require 'rspec'
require 'pathname'
require 'json'

require 'simplecov_mcp'

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

# Regex pattern for matching ISO 8601 timestamps with brackets in log output
# Used to verify log timestamps in tests
TIMESTAMP_REGEX = /\[\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2}\]/

# Helper method to mock resultset file reading with fake coverage data
# @param root [String] The test root directory
# @param timestamp [Integer] The timestamp to use in the fake resultset
# @param coverage [Hash] Optional custom coverage data (default: basic foo.rb and bar.rb)
def mock_resultset_with_timestamp(root, timestamp, coverage: nil)
  mock_resultset_with_metadata(root, { 'timestamp' => timestamp }, coverage: coverage)
end

def mock_resultset_with_created_at(root, created_at, coverage: nil)
  mock_resultset_with_metadata(root, { 'created_at' => created_at }, coverage: coverage)
end

def mock_resultset_with_metadata(root, metadata, coverage: nil)
  abs_root = File.absolute_path(root)
  default_coverage = {
    File.join(root, 'lib', 'foo.rb') => { 'lines' => [1, 0, nil, 2] },
    File.join(root, 'lib', 'bar.rb') => { 'lines' => [0, 0, 1] }
  }

  fake_resultset_hash = {
    'RSpec' => {
      'coverage' => coverage || default_coverage
    }.merge(metadata)
  }

  allow(JSON).to receive(:load_file).and_call_original # Allow real JSON.load_file for other calls

  allow(JSON).to receive(:load_file).with(end_with('.resultset.json'))
    .and_return(fake_resultset_hash)
  allow(SimpleCovMcp::CovUtil).to receive(:find_resultset)
    .and_wrap_original do |method, search_root, resultset: nil|
    if File.absolute_path(search_root) == abs_root && (resultset.nil? || resultset.to_s.empty?)
      File.join(abs_root, 'coverage', '.resultset.json')
    else
      method.call(search_root, resultset: resultset)
    end
  end
end

# Automatically require all files in spec/support and spec/shared_examples
Dir[File.join(__dir__, 'support', '**', '*.rb')].each { |f| require f }
Dir[File.join(__dir__, 'shared_examples', '**', '*.rb')].each { |f| require f }

RSpec.configure do |config|
  config.example_status_persistence_file_path = '.rspec_status'
  config.disable_monkey_patching!
  config.order = :defined
  Kernel.srand config.seed

  # Suppress logging during tests by redirecting to /dev/null
  # This is cheap and doesn't break tests that verify logging behavior
  SimpleCovMcp.default_log_file = 'stderr'
  SimpleCovMcp.active_log_file = 'stderr'

  # Reset log file after each test to ensure tests that change it don't pollute others
  config.after do
    SimpleCovMcp.active_log_file = File::NULL
  end
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

  # Execute a block that's expected to call exit() without terminating the test.
  # Useful for testing CLI commands that normally exit.
  # Returns the exit status code if exit was called, otherwise returns the block's value.
  #
  # Examples:
  #   status = swallow_system_exit { cli.run(['--help']) }
  #   expect(status).to eq(0)  # --help calls exit(0)
  #
  #   result = swallow_system_exit { some_computation }
  #   expect(result).to eq(expected_value)  # no exit, returns block value
  def swallow_system_exit
    yield
  rescue SystemExit => e
    e.status
  end

  # Stub staleness checking to return a specific value
  # @param value [String, false] The staleness value to return ('L', 'T', 'M', or false)
  def stub_staleness_check(value)
    checker_double = instance_double(SimpleCovMcp::StalenessChecker)
    allow(checker_double).to receive_messages(
      stale_for_file?: value,
      off?: false
    )
    allow(checker_double).to receive(:check_file!)
    allow(SimpleCovMcp::StalenessChecker).to receive(:new).and_return(checker_double)
  end

  # Stub a presenter with specific payload data
  # @param presenter_class [Class] The presenter class to stub (e.g., SimpleCovMcp::Presenters::CoverageRawPresenter)
  # @param absolute_payload [Hash] The data hash to return from #absolute_payload
  # @param relative_path [String] The path to return from #relative_path
  def mock_presenter(presenter_class, absolute_payload:, relative_path:)
    presenter_double = instance_double(presenter_class)
    allow(presenter_double).to receive_messages(
      absolute_payload: absolute_payload,
      relative_path: relative_path
    )
    allow(presenter_class).to receive(:new).and_return(presenter_double)
    presenter_double
  end

  # Capture the output of a command execution
  # @param command [SimpleCovMcp::Commands::BaseCommand] The command instance to execute
  # @param args [Array] The arguments to pass to execute
  # @return [String] The captured output
  def capture_command_output(command, args)
    output = nil
    silence_output do |stdout, _stderr|
      command.execute(args.dup)
      output = stdout.string
    end
    output
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

  def expect_mcp_text_json(response, expected_keys: [])
    item = response.payload.first

    # Check for a 'text' part
    expect(item['type']).to eq('text')
    expect(item).to have_key('text')

    # Parse and validate JSON content
    data = JSON.parse(item['text'])

    # Check for expected keys
    expected_keys.each do |key|
      expect(data).to have_key(key)
    end

    [data, item] # Return for additional custom assertions
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

  failure_message do |_output|
    "expected output to include a source table header (e.g., 'Line | Source') " \
      "or the fallback '[source not available]'"
  end
end
