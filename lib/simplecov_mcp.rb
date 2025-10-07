# frozen_string_literal: true

require 'json'
require 'time'
require 'pathname'
require 'mcp'
require 'mcp/server/transports/stdio_transport'

require_relative 'simplecov_mcp/version'
require_relative 'simplecov_mcp/util'
require_relative 'simplecov_mcp/errors'
require_relative 'simplecov_mcp/error_handler'
require_relative 'simplecov_mcp/error_handler_factory'
require_relative 'simplecov_mcp/path_relativizer'
require_relative 'simplecov_mcp/mode_detector'
require_relative 'simplecov_mcp/model'
require_relative 'simplecov_mcp/base_tool'
require_relative 'simplecov_mcp/tools/coverage_raw_tool'
require_relative 'simplecov_mcp/tools/coverage_summary_tool'
require_relative 'simplecov_mcp/tools/uncovered_lines_tool'
require_relative 'simplecov_mcp/tools/coverage_detailed_tool'
require_relative 'simplecov_mcp/tools/all_files_coverage_tool'
require_relative 'simplecov_mcp/tools/coverage_table_tool'
require_relative 'simplecov_mcp/tools/version_tool'
require_relative 'simplecov_mcp/tools/help_tool'
require_relative 'simplecov_mcp/mcp_server'
require_relative 'simplecov_mcp/cli'

module SimpleCovMcp
  class << self
    attr_accessor :log_file
  end

  def self.run(argv)
    # Parse environment options for mode detection
    env_opts = parse_env_opts_for_mode_detection
    full_argv = env_opts + argv

    # Determine whether to run CLI or MCP server based on arguments and environment
    if ModeDetector.cli_mode?(full_argv)
      CoverageCLI.new.run(argv)  # CLI will re-parse env opts internally
    else
      MCPServer.new.run
    end
  end

  # For library usage, allow configuration of error handling.
  # This method is intended for applications that want to embed simplecov-mcp
  # functionality without the CLI behavior of showing friendly error messages
  # and exiting. Instead, it raises custom exceptions that can be caught.
  #
  # Usage:
  #   # Basic usage - raises custom exceptions on errors
  #   SimpleCovMcp.run_as_library(['summary', 'lib/foo.rb'])
  #
  #   # With custom error handler (e.g., disable logging)
  #   handler = SimpleCovMcp::ErrorHandler.new(log_errors: false)
  #   SimpleCovMcp.run_as_library(['summary', 'lib/foo.rb'], error_handler: handler)
  #
  #   # Exception handling
  #   begin
  #     SimpleCovMcp.run_as_library(['summary', 'missing.rb'])
  #   rescue SimpleCovMcp::FileError => e
  #     puts "File not found: #{e.user_friendly_message}"
  #   rescue SimpleCovMcp::CoverageDataError => e
  #     puts "Coverage issue: #{e.user_friendly_message}"
  #   end
  def self.run_as_library(argv, error_handler: nil)
    # Set global error handler for library usage (affects shared components like MCP tools)
    SimpleCovMcp.error_handler = error_handler || ErrorHandlerFactory.for_library

    model = CoverageModel.new
    execute_library_command(model, argv)
  rescue SimpleCovMcp::Error => e
    raise e  # Re-raise custom errors for library users to catch
  rescue => e
    SimpleCovMcp.error_handler.handle_error(e, context: 'library execution')
    raise e  # Re-raise for library users to handle
  end

  private

  def self.execute_library_command(model, argv)
    return model.all_files if argv.empty?

    unless argv.length >= 2
      raise UsageError.new("Invalid arguments. Use: [] for all files, or [command, path] for specific file")
    end

    command, path = argv[0], argv[1]
    case command
    when 'summary'   then model.summary_for(path)
    when 'raw'       then model.raw_for(path)
    when 'uncovered' then model.uncovered_for(path)
    when 'detailed'  then model.detailed_for(path)
    else
      raise UsageError.new("Unknown command: #{command}. Use: summary, raw, uncovered, or detailed")
    end
  end

  def self.parse_env_opts_for_mode_detection
    require 'shellwords'
    opts_string = ENV['SIMPLECOV_MCP_OPTS']
    return [] unless opts_string && !opts_string.empty?

    begin
      Shellwords.split(opts_string)
    rescue ArgumentError
      []  # Ignore parsing errors for mode detection
    end
  end
end
