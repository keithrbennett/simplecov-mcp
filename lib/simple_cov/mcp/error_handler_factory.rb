# frozen_string_literal: true

module SimpleCov
  module Mcp
    module ErrorHandlerFactory
      # Error handler for CLI usage
      # - Logs errors for debugging
      # - Shows stack traces only in debug mode
      # - Suitable for user-facing command line interface
      def self.for_cli
        ErrorHandler.new(
          log_errors: true,
          show_stack_traces: ENV['SIMPLECOV_MCP_DEBUG'] == '1'
        )
      end

      # Error handler for library usage
      # - No logging by default (avoids side effects in consuming applications)
      # - No stack traces (libraries should let consumers handle error display)
      # - Suitable for embedding in other applications
      def self.for_library
        ErrorHandler.new(
          log_errors: false,
          show_stack_traces: false
        )
      end

      # Error handler for MCP server usage
      # - Logs errors for server debugging
      # - Shows stack traces only in debug mode
      # - Suitable for long-running server processes
      def self.for_mcp_server
        ErrorHandler.new(
          log_errors: true,
          show_stack_traces: ENV['SIMPLECOV_MCP_DEBUG'] == '1'
        )
      end
    end
  end
end