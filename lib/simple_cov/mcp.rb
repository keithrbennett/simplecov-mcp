# frozen_string_literal: true

require 'json'
require 'time'
require 'pathname'
require 'mcp'
require 'mcp/server/transports/stdio_transport'
require 'awesome_print'

require_relative 'mcp/version'
require_relative 'mcp/util'
require_relative 'mcp/errors'
require_relative 'mcp/error_handler'
require_relative 'mcp/model'
require_relative 'mcp/base_tool'
require_relative 'mcp/tools/coverage_raw'
require_relative 'mcp/tools/coverage_summary'
require_relative 'mcp/tools/uncovered_lines'
require_relative 'mcp/tools/coverage_detailed'
require_relative 'mcp/tools/all_files_coverage'
require_relative 'mcp/cli'

module SimpleCov
  module Mcp
    def self.run(argv)
      # For CLI usage, override the default library error handler
      cli_error_handler = ErrorHandler.new(
        log_errors: true,
        show_stack_traces: ENV['SIMPLECOV_MCP_DEBUG'] == '1'
      )
      configure_error_handling { |h| h.log_errors = true; h.show_stack_traces = ENV['SIMPLECOV_MCP_DEBUG'] == '1' }

      CoverageCLI.new(error_handler: cli_error_handler).run(argv)
    end

    # For library usage, allow configuration of error handling.
    # This method is intended for applications that want to embed simplecov-mcp
    # functionality without the CLI behavior of showing friendly error messages
    # and exiting. Instead, it raises custom exceptions that can be caught.
    #
    # Usage:
    #   # Basic usage - raises custom exceptions on errors
    #   SimpleCov::Mcp.run_as_library(['summary', 'lib/foo.rb'])
    #
    #   # With custom error handler (e.g., disable logging)
    #   handler = SimpleCov::Mcp::ErrorHandler.new(log_errors: false)
    #   SimpleCov::Mcp.run_as_library(['summary', 'lib/foo.rb'], error_handler: handler)
    #
    #   # Exception handling
    #   begin
    #     SimpleCov::Mcp.run_as_library(['summary', 'missing.rb'])
    #   rescue SimpleCov::Mcp::FileError => e
    #     puts "File not found: #{e.user_friendly_message}"
    #   rescue SimpleCov::Mcp::CoverageDataError => e
    #     puts "Coverage issue: #{e.user_friendly_message}"
    #   end
    def self.run_as_library(argv, error_handler: nil)
      cli = CoverageCLI.new(error_handler: error_handler)
      cli.run(argv)
    end
  end
end

