# frozen_string_literal: true

require 'json'
require 'time'
require 'pathname'
require 'set' # rubocop:disable Lint/RedundantRequireStatement -- Ruby >= 3.4 requires explicit require for set; RuboCop targets 3.2

require_relative 'cov_loupe/version'
require_relative 'cov_loupe/app_context'
require_relative 'cov_loupe/errors'
require_relative 'cov_loupe/error_handler'
require_relative 'cov_loupe/error_handler_factory'
require_relative 'cov_loupe/path_relativizer'
require_relative 'cov_loupe/resultset_loader'
require_relative 'cov_loupe/model'
require_relative 'cov_loupe/coverage_reporter'

module CovLoupe
  class << self
    THREAD_CONTEXT_KEY = :cov_loupe_context

    def run(argv)
      # Prepend environment options once at entry point
      full_argv = extract_env_opts + argv

      # Parse config to determine mode
      require_relative 'cov_loupe/config_parser'
      config = ConfigParser.parse(full_argv.dup)

      if config.mode == :cli
        # CLI mode: load CLI components only
        require_relative 'cov_loupe/all_cli'
        CoverageCLI.new.run(full_argv)
      else
        # MCP server mode: load MCP server components only
        require_relative 'cov_loupe/all_mcp'

        if config.log_file == 'stdout'
          raise ConfigurationError,
            'Logging to stdout is not permitted in MCP server mode as it interferes with ' \
            "the JSON-RPC protocol. Please use 'stderr' or a file path."
        end

        handler = ErrorHandlerFactory.for_mcp_server(error_mode: config.error_mode)
        context = create_context(error_handler: handler, log_target: config.log_file,
          mode: :mcp, app_config: config)
        with_context(context) { MCPServer.new(context: context).run }
      end
    end

    def with_context(context)
      previous = Thread.current[THREAD_CONTEXT_KEY]
      Thread.current[THREAD_CONTEXT_KEY] = context
      yield
    ensure
      Thread.current[THREAD_CONTEXT_KEY] = previous
    end

    def context
      Thread.current[THREAD_CONTEXT_KEY] || default_context
    end

    def create_context(error_handler:, log_target: nil, mode: :library, app_config: nil)
      AppContext.new(
        error_handler: error_handler,
        log_target: log_target.nil? ? default_context.log_target : log_target,
        mode: mode,
        app_config: app_config
      )
    end

    def default_log_file
      default_context.log_target
    end

    def default_log_file=(value)
      previous_default = default_context
      @default_context = previous_default.with_log_target(value)
      active = Thread.current[THREAD_CONTEXT_KEY]
      if active.nil? || active.log_target == previous_default.log_target
        Thread.current[THREAD_CONTEXT_KEY] = @default_context
      end
      value # rubocop:disable Lint/Void -- return assigned log target for symmetry
    end

    def active_log_file
      context.log_target
    end

    def active_log_file=(value)
      current = Thread.current[THREAD_CONTEXT_KEY]
      Thread.current[THREAD_CONTEXT_KEY] = if current
        current.with_log_target(value)
      else
        default_context.with_log_target(value)
      end
      value # rubocop:disable Lint/Void -- return assigned log target for symmetry
    end

    def error_handler
      context.error_handler
    end

    def error_handler=(handler)
      @default_context = default_context.with_error_handler(handler)
    end

    def logger
      context.logger
    end

    private def default_context
      @default_context ||= AppContext.new(
        error_handler: ErrorHandlerFactory.for_cli,
        log_target: nil
      )
    end

    private def extract_env_opts
      require 'shellwords'
      opts_string = ENV['COV_LOUPE_OPTS']
      return [] unless opts_string && !opts_string.empty?

      begin
        Shellwords.split(opts_string)
      rescue ArgumentError
        [] # Ignore parsing errors
      end
    end
  end
end
