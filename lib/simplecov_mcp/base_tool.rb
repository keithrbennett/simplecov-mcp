# frozen_string_literal: true

require 'mcp'
require 'json'
require_relative 'errors'
require_relative 'error_handler'

module SimpleCovMcp
  class BaseTool < ::MCP::Tool
    INPUT_SCHEMA = {
      type: 'object',
      additionalProperties: false,
      properties: {
        path: {
          type: 'string',
          description: 'Repo-relative or absolute path to the file whose coverage data you need.',
          examples: ['lib/simple_cov_mcp/model.rb']
        },
        root: {
          type: 'string',
          description: 'Project root used to resolve relative paths (defaults to current workspace).',
          default: '.'
        },
        resultset: {
          type: 'string',
          description: 'Path to the SimpleCov .resultset.json file (absolute or relative to root).'
        },
        stale: {
          type: 'string',
          description: "How to handle missing/outdated coverage data. 'off' skips checks; 'error' raises.",
          enum: %w[off error],
          default: 'off'
        },
        error_mode: {
          type: 'string',
          description: "Error handling mode: 'off' (silent), 'on' (log errors), 'trace' (verbose).",
          enum: %w[off on trace],
          default: 'on'
        }
      },
      required: ['path']
    }
    def self.input_schema_def = INPUT_SCHEMA

    # Handle errors consistently across all MCP tools
    # Returns an MCP::Tool::Response with appropriate error message
    def self.handle_mcp_error(error, tool_name, error_mode: :on)
      # Create error handler with the specified mode
      error_handler = ErrorHandlerFactory.for_mcp_server(error_mode: error_mode.to_sym)

      # Normalize to a SimpleCovMcp::Error so we can handle/log uniformly
      normalized = error.is_a?(SimpleCovMcp::Error) ? error : error_handler.convert_standard_error(error)
      log_mcp_error(normalized, tool_name, error_handler)
      ::MCP::Tool::Response.new([{ type: 'text', text: "Error: #{normalized.user_friendly_message}" }])
    end

    # Respond with JSON as a resource to avoid clients mutating content types.
    # The resource embeds the JSON string with a clear MIME type.
    def self.respond_json(payload, name: 'data.json', pretty: false)
      json = pretty ? JSON.pretty_generate(payload) : JSON.generate(payload)
      ::MCP::Tool::Response.new([{ 'type' => 'text', 'text' => json }])
    end

    private

    def self.log_mcp_error(error, tool_name, error_handler)
      # Use the provided error handler for logging
      error_handler.send(:log_error, error, tool_name)
    end
  end
end
