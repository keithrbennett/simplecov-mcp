# frozen_string_literal: true

require 'mcp'
require 'json'
require_relative 'errors'
require_relative 'error_handler'
require_relative 'model_cache'
require_relative 'model'
require_relative 'presenters/coverage_payload_presenter'

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

    DEFAULT_SORT_ORDER = CoverageModel::DEFAULT_SORT_ORDER.to_s

    SORT_ORDER_PROPERTY = {
      type: 'string',
      description: 'Sort order for coverage percentages. ' \
                   "'#{DEFAULT_SORT_ORDER}' (default) lists highest coverage first. " \
                   'Accepts: a[scending], d[escending].',
      default: DEFAULT_SORT_ORDER,
      enum: %w[ascending descending a d]
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
      # Safely normalize error_mode to a symbol, defaulting to :log for invalid inputs
      # This prevents crashes when MCP clients send invalid types (null, numbers, objects, etc.)
      safe_mode = case error_mode
                  when Symbol then error_mode
                  when String then error_mode.to_sym
                  else :log
      end

      # Create error handler with the specified mode
      error_handler = ErrorHandlerFactory.for_mcp_server(error_mode: safe_mode)

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
    # @param model_option_overrides [Hash] Tool call parameters that override model defaults
    # @return [Hash] Merged configuration for CoverageModel initialization
    def self.model_config_for(server_context:, **model_option_overrides)
      # Start with config from context (CLI flags) or hardcoded defaults
      base = server_context.app_config&.model_options || default_model_options

      # Merge explicit params from JSON, removing nils
      # (nil means "not provided", so use base config)
      base.merge(model_option_overrides.compact)
    end

    # Creates and configures a CoverageModel instance.
    # Encapsulates the common pattern of merging config and initializing the model.
    # @param server_context [AppContext] The server context
    # @param model_option_overrides [Hash] Tool call parameters that override model defaults
    # @return [CoverageModel] The configured model
    def self.create_model(server_context:, **model_option_overrides)
      model, _config = create_configured_model(server_context: server_context,
        **model_option_overrides)
      model
    end

    # Creates and configures a CoverageModel instance, returning both the model and the configuration.
    # Useful when the tool needs access to the resolved configuration (e.g., root, raise_on_stale).
    # @param server_context [AppContext] The server context
    # @param model_option_overrides [Hash] Tool call parameters that override model defaults
    # @return [Array<CoverageModel, Hash>] The configured model and the configuration hash
    # Creates a CoverageModel and returns it with the resolved config.
    # In MCP mode, reuses a cached model if the resultset file has not changed.
    def self.create_configured_model(server_context:, **model_option_overrides)
      config = model_config_for(server_context: server_context, **model_option_overrides)
      cached_model = cached_model_for(server_context, config)
      return [cached_model, config] if cached_model

      model = CoverageModel.new(**config)
      store_cached_model(server_context, config, model)
      [model, config]
    end

    # Default configuration when no context or explicit params are provided
    def self.default_model_options
      { root: '.', resultset: nil, raise_on_stale: false, tracked_globs: nil }
    end

    # Runs a file-based tool request by deriving payload method and JSON name from the tool class.
    # @param path [String] File path to analyze
    # @param error_mode [String] Error handling mode
    # @param server_context [AppContext] Server context
    # @param model_option_overrides [Hash] Tool call parameters that override model defaults
    # @return [MCP::Tool::Response] JSON response
    def self.call_with_file_payload(path:, error_mode:, server_context:,
      **model_option_overrides)
      tool_name = name.split('::').last

      with_error_handling(tool_name, error_mode: error_mode) do
        model, config = create_configured_model(server_context: server_context,
          **model_option_overrides)
        presenter = Presenters::CoveragePayloadPresenter.new(
          model: model,
          path: path,
          payload_method: payload_method_for(tool_name),
          raise_on_stale: config[:raise_on_stale]
        )
        respond_json(presenter.relativized_payload, name: json_name_for(tool_name), pretty: true)
      end
    end

    # Infer CoverageModel method name from a tool class name.
    # CoverageSummaryTool -> :summary_for, CoverageRawTool -> :raw_for,
    # CoverageDetailedTool -> :detailed_for, UncoveredLinesTool -> :uncovered_for.
    def self.payload_method_for(tool_name)
      base = tool_name.sub(/Tool\z/, '')
      underscored = underscore(base).sub(/\Acoverage_/, '').sub(/_lines\z/, '')
      :"#{underscored}_for"
    end

    # Infer the MCP JSON resource name from a tool class name.
    # CoverageSummaryTool -> coverage_summary.json, UncoveredLinesTool -> uncovered_lines.json.
    def self.json_name_for(tool_name)
      "#{underscore(tool_name.sub(/Tool\z/, ''))}.json"
    end

    # Minimal underscore helper to avoid pulling in ActiveSupport.
    def self.underscore(value)
      value
        .gsub(/([A-Z]+)([A-Z][a-z])/, '\\1_\\2')
        .gsub(/([a-z\\d])([A-Z])/, '\\1_\\2')
        .downcase
    end
    private_class_method :payload_method_for, :json_name_for, :underscore

    # Returns a cached model if it is safe to reuse for the current config.
    def self.cached_model_for(server_context, config)
      return unless server_context&.mcp_mode?

      cache = server_context.model_cache
      return if cache.nil?

      cache.fetch(config)
    end
    private_class_method :cached_model_for

    # Stores the model alongside the resultset mtime so we can invalidate on change.
    def self.store_cached_model(server_context, config, model)
      return unless server_context&.mcp_mode?

      cache = server_context.model_cache
      return if cache.nil?

      cache.store(config, model)
    end
    private_class_method :store_cached_model
  end
end
