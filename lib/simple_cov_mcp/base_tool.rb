# frozen_string_literal: true

require 'mcp'
require_relative 'errors'
require_relative 'error_handler'

module SimpleCovMcp
  class BaseTool < ::MCP::Tool
      INPUT_SCHEMA = {
        type: 'object',
        properties: {
          path: { type: 'string', description: 'Absolute or project-relative file path' },
          root: { type: 'string', description: 'Project root for resolution', default: '.' },
          resultset: { type: 'string', description: 'Path to .resultset.json (absolute or relative to root)' }
        },
        required: ['path']
      }
      def self.input_schema_def = INPUT_SCHEMA

      # Handle errors consistently across all MCP tools
      # Returns an MCP::Tool::Response with appropriate error message
      def self.handle_mcp_error(error, tool_name)
        case error
        when SimpleCovMcp::Error
          # Custom errors already have user-friendly messages
          log_mcp_error(error, tool_name)
          ::MCP::Tool::Response.new([{ type: 'text', text: "Error: #{error.user_friendly_message}" }])
        else
          # Convert and handle standard errors through global error handler
          converted = SimpleCovMcp.error_handler.convert_standard_error(error)
          log_mcp_error(converted, tool_name)
          ::MCP::Tool::Response.new([{ type: 'text', text: "Error: #{converted.user_friendly_message}" }])
        end
      end

      private

      def self.log_mcp_error(error, tool_name)
        # Access the error handler's log_error method via send to bypass visibility
        SimpleCovMcp.error_handler.send(:log_error, error, tool_name)
      end
  end
end
