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
      raise_on_stale: {
        type: 'boolean',
        description: 'If true, raise error if coverage data is stale (missing files, ' \
          'timestamp mismatch). Defaults to false.',
        default: false
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
      examples: ['lib/cov_loupe/model.rb']
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

    # Merges configuration from server context (CLI flags) with explicit tool parameters (JSON).
    # Explicit parameters take precedence over context config, which takes precedence over defaults.
    # @param server_context [AppContext] The server context containing app_config from CLI
    # @param explicit_params [Hash] Parameters explicitly passed in the JSON tool call
    # @return [Hash] Merged configuration for CoverageModel initialization
    def self.model_config_for(server_context:, **explicit_params)
      # Start with config from context (CLI flags) or hardcoded defaults
      base = server_context.app_config&.model_options || default_model_options

      # Merge explicit params from JSON, removing nils
      # (nil means "not provided", so use base config)
      base.merge(explicit_params.compact)
    end

    # Default configuration when no context or explicit params are provided
    def self.default_model_options
      { root: '.', resultset: nil, raise_on_stale: false, tracked_globs: nil }
    end
  end
end
