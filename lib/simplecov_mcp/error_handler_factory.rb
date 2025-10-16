# frozen_string_literal: true

require_relative 'error_handler'

module SimpleCovMcp
  module ErrorHandlerFactory
      # Error handler for CLI usage
      # - Logs errors for debugging
      # - Shows stack traces only when explicitly requested
      # - Suitable for user-facing command line interface
    def self.for_cli(error_mode: :on)
      ErrorHandler.new(error_mode: error_mode)
    end

      # Error handler for library usage
      # - No logging by default (avoids side effects in consuming applications)
      # - No stack traces (libraries should let consumers handle error display)
      # - Suitable for embedding in other applications
    def self.for_library(error_mode: :off)
      ErrorHandler.new(error_mode: error_mode)
    end

      # Error handler for MCP server usage
      # - Logs errors for server debugging
      # - Shows stack traces only when explicitly requested
      # - Suitable for long-running server processes
    def self.for_mcp_server(error_mode: :on)
      ErrorHandler.new(error_mode: error_mode)
    end
  end
end
