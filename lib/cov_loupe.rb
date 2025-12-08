# frozen_string_literal: true

require 'json'
require 'time'
require 'pathname'
require 'set' # rubocop:disable Lint/RedundantRequireStatement -- Ruby >= 3.4 requires explicit require for set; RuboCop targets 3.2
require 'optparse'
require 'mcp'
require 'mcp/server/transports/stdio_transport'

require_relative 'cov_loupe/version'
require_relative 'cov_loupe/app_context'
require_relative 'cov_loupe/util'
require_relative 'cov_loupe/errors'
require_relative 'cov_loupe/error_handler'
require_relative 'cov_loupe/error_handler_factory'
require_relative 'cov_loupe/path_relativizer'
require_relative 'cov_loupe/resultset_loader'
require_relative 'cov_loupe/mode_detector'
require_relative 'cov_loupe/model'
require_relative 'cov_loupe/coverage_reporter'
require_relative 'cov_loupe/base_tool'
require_relative 'cov_loupe/tools/coverage_raw_tool'
require_relative 'cov_loupe/tools/coverage_summary_tool'
require_relative 'cov_loupe/tools/uncovered_lines_tool'
require_relative 'cov_loupe/tools/coverage_detailed_tool'
require_relative 'cov_loupe/tools/all_files_coverage_tool'
require_relative 'cov_loupe/tools/coverage_totals_tool'
require_relative 'cov_loupe/tools/coverage_table_tool'
require_relative 'cov_loupe/tools/validate_tool'
require_relative 'cov_loupe/tools/version_tool'
require_relative 'cov_loupe/tools/help_tool'
require_relative 'cov_loupe/mcp_server'
require_relative 'cov_loupe/cli'

module CovLoupe
  class << self
    THREAD_CONTEXT_KEY = :cov_loupe_context

    def run(argv)
      # Prepend environment options once at entry point
      full_argv = extract_env_opts + argv

      if ModeDetector.cli_mode?(full_argv)
        # CLI mode: pass merged argv to CoverageCLI
        CoverageCLI.new.run(full_argv)
      else
        # MCP server mode: parse config once from full_argv
        require_relative 'cov_loupe/config_parser'
        config = ConfigParser.parse(full_argv)

        if config.log_file == 'stdout'
          raise ConfigurationError,
            'Logging to stdout is not permitted in MCP server mode as it interferes with ' \
            "the JSON-RPC protocol. Please use 'stderr' or a file path."
        end

        handler = ErrorHandlerFactory.for_mcp_server(error_mode: config.error_mode)
        context = create_context(error_handler: handler, log_target: config.log_file,
          mode: :mcp)
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

    def create_context(error_handler:, log_target: nil, mode: :library)
      AppContext.new(
        error_handler: error_handler,
        log_target: log_target.nil? ? default_context.log_target : log_target,
        mode: mode
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
