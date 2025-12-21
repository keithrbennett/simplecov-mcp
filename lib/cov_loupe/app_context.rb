# frozen_string_literal: true

require_relative 'logger'
require_relative 'model_cache'

module CovLoupe
  # Encapsulates per-request configuration such as error handling and logging.
  class AppContext
    attr_reader :error_handler, :log_target, :mode, :app_config, :logger, :model_cache

    # @param model_cache [ModelCache] Optional cache used by MCP tools to reuse CoverageModel instances.
    def initialize(error_handler:, log_target: nil, mode: :library, app_config: nil,
      model_cache: nil)
      @error_handler = error_handler
      @log_target = log_target
      @mode = mode
      @app_config = app_config
      @model_cache = model_cache || ModelCache.new
      @logger = Logger.new(target: log_target, mode: mode)
    end

    def with_error_handler(handler)
      self.class.new(error_handler: handler, log_target: log_target, mode: mode,
        app_config: app_config, model_cache: model_cache)
    end

    def with_log_target(target)
      self.class.new(error_handler: error_handler, log_target: target, mode: mode,
        app_config: app_config, model_cache: model_cache)
    end

    def mcp_mode? = mode == :mcp
    def cli_mode? = mode == :cli
    def library_mode? = mode == :library
  end
end
