# frozen_string_literal: true

require 'json'
require 'time'
require 'pathname'
require 'set' # rubocop:disable Lint/RedundantRequireStatement -- Ruby >= 3.4 requires explicit require for set; RuboCop targets 3.2

require_relative 'cov_loupe/config/version'
require_relative 'cov_loupe/config/app_context'
require_relative 'cov_loupe/errors/errors'
require_relative 'cov_loupe/errors/error_handler'
require_relative 'cov_loupe/errors/error_handler_factory'
require_relative 'cov_loupe/paths/path_relativizer'
require_relative 'cov_loupe/loaders/resultset_loader'
require_relative 'cov_loupe/model/model'
require_relative 'cov_loupe/coverage/coverage_reporter'

module CovLoupe
  class << self
    # === Context Management and Thread Safety ===
    #
    # CovLoupe manages configuration (logging, error handling) via `AppContext` objects.
    # The resolution strategy is:
    # 1. Thread-local: Use `Thread.current[:cov_loupe_context]` if set.
    # 2. Global default: Fall back to `@internal_default_context`.
    #
    # This design supports both simple CLI usage (one global context) and multi-threaded
    # library usage (per-thread contexts).
    #
    # Thread Safety:
    # - `mutex` protects all reads/writes to `@internal_default_context`.
    # - `default_log_file=` atomically updates the global default. Threads using the
    #   default (nil thread-local context) will immediately see the new value.
    # - `active_log_file=` creates or updates a *thread-local* context, isolating
    #   changes to the current thread.
    #
    # This separation ensures that changing the global default is safe and predictable,
    # while allowing threads to diverge when necessary without race conditions.

    THREAD_CONTEXT_KEY = :cov_loupe_context
    private_constant :THREAD_CONTEXT_KEY

    def run(argv)
      # Prepend environment options once at entry point
      full_argv = extract_env_opts + argv

      # Parse config to determine mode
      require_relative 'cov_loupe/config/config_parser'
      begin
        config = ConfigParser.parse(full_argv.dup)
      rescue OptionParser::ParseError, ConfigurationError => e
        warn "Error: #{e.message}"
        warn "Run 'cov-loupe --help' for usage information."
        exit 2
      end

      if config.mode == :cli
        # CLI mode: load CLI components only
        require_relative 'cov_loupe/loaders/all_cli'
        CoverageCLI.new.run(full_argv)
      else
        # MCP server mode: load MCP server components only
        require_relative 'cov_loupe/loaders/all_mcp'

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
      mutex.synchronize do
        previous_default = internal_default_context
        @internal_default_context = previous_default.with(log_target: value)
      end
      value # rubocop:disable Lint/Void -- Setter should return assigned value for direct calls.
    end

    def active_log_file
      context.log_target
    end

    def active_log_file=(value)
      current = Thread.current[THREAD_CONTEXT_KEY]
      Thread.current[THREAD_CONTEXT_KEY] = if current
        current.with(log_target: value)
      else
        base = mutex.synchronize { internal_default_context }
        base.with(log_target: value)
      end
    end

    def error_handler
      context.error_handler
    end

    def error_handler=(handler)
      mutex.synchronize do
        previous_default = internal_default_context
        @internal_default_context = previous_default.with(error_handler: handler)
      end
    end

    def logger
      context.logger
    end

    # Returns true if running on Windows (mingw, mswin, cygwin).
    def windows?
      return @windows if defined?(@windows)

      @windows = RUBY_PLATFORM.match?(/mingw|mswin|cygwin/)
    end

    private def mutex
      @mutex ||= Mutex.new
    end

    private def default_context
      mutex.synchronize { internal_default_context }
    end

    private def internal_default_context
      @internal_default_context ||= AppContext.new(
        error_handler: ErrorHandlerFactory.for_cli,
        log_target: nil
      )
    end

    private def extract_env_opts
      require_relative 'cov_loupe/option_parsers/env_options_parser'
      OptionParsers::EnvOptionsParser.new.parse_env_opts
    end
  end
end
