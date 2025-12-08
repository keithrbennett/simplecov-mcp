# frozen_string_literal: true

require 'mcp'
require 'json'
require_relative 'errors'
require_relative 'error_handler'

module CovLoupe
  class BaseTool < ::MCP::Tool
    COMMON_PROPERTIES = {
      root: {
        type: 'string',
        description: 'Project root used to resolve relative paths ' \
                     '(defaults to current workspace).',
        default: '.'
      },
      resultset: {
        type: 'string',
        description: 'Path to the SimpleCov .resultset.json file (absolute or relative to root).'
      },
      staleness: {
        type: 'string',
        description: 'How to handle missing/outdated coverage data. ' \
                     "'off' skips checks; 'error' raises.",
        enum: [:off, :error],
        default: :off
      },
      error_mode: {
        type: 'string',
        description: "Error handling mode: 'off' (silent), 'log' (log errors), " \
            "'debug' (verbose with backtraces).",
        enum: %w[off log debug],
        default: 'log'
      }
    }.freeze

    ERROR_MODE_PROPERTY = COMMON_PROPERTIES[:error_mode].freeze

    TRACKED_GLOBS_PROPERTY = {
      type: 'array',
      description: 'Glob patterns for files that should exist in the coverage report' \
                   '(helps flag new files).',
      items: { type: 'string' }
    }.freeze

    PATH_PROPERTY = {
      type: 'string',
      description: 'Repo-relative or absolute path to the file whose coverage data you need.',
      examples: ['lib/simple_cov_mcp/model.rb']
    }.freeze

    def self.coverage_schema(additional_properties: {}, required: [])
      {
        type: 'object',
        additionalProperties: false,
        properties: COMMON_PROPERTIES.merge(additional_properties),
        required: required
      }.freeze
    end

    FILE_INPUT_SCHEMA = coverage_schema(
      additional_properties: { path: PATH_PROPERTY },
      required: ['path']
    )
    def self.input_schema_def = FILE_INPUT_SCHEMA

    # Wrap tool execution with consistent error handling.
    # Yields to the block and rescues any error, delegating to handle_mcp_error.
    # This eliminates duplicate rescue blocks across all tools.
    def self.with_error_handling(tool_name, error_mode:)
      yield
    rescue => e
      handle_mcp_error(e, tool_name, error_mode: error_mode)
    end

    # Handle errors consistently across all MCP tools
    # Returns an MCP::Tool::Response with appropriate error message
    def self.handle_mcp_error(error, tool_name, error_mode: :log)
      # Create error handler with the specified mode
      error_handler = ErrorHandlerFactory.for_mcp_server(error_mode: error_mode.to_sym)

      # Normalize to a CovLoupe::Error so we can handle/log uniformly
      normalized = error.is_a?(CovLoupe::Error) \
        ? error : error_handler.convert_standard_error(error)
      log_mcp_error(normalized, tool_name, error_handler)
      ::MCP::Tool::Response.new([{ 'type' => 'text', 'text' => "Error: #{normalized.user_friendly_message}" }])
    end

    # Respond with JSON as a resource to avoid clients mutating content types.
    # The resource embeds the JSON string with a clear MIME type.
    def self.respond_json(payload, name: 'data.json', pretty: false)
      json = pretty ? JSON.pretty_generate(payload) : JSON.generate(payload)
      ::MCP::Tool::Response.new([{ 'type' => 'text', 'text' => json }])
    end

    def self.log_mcp_error(error, tool_name, error_handler)
      # Use the provided error handler for logging
      error_handler.send(:log_error, error, tool_name)
    end
    private_class_method :log_mcp_error
  end
end
