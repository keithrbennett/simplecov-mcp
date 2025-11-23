# frozen_string_literal: true

require 'json'
require 'time'
require 'pathname'
require 'optparse'
require 'mcp'
require 'mcp/server/transports/stdio_transport'

require_relative 'simplecov_mcp/version'
require_relative 'simplecov_mcp/app_context'
require_relative 'simplecov_mcp/util'
require_relative 'simplecov_mcp/errors'
require_relative 'simplecov_mcp/error_handler'
require_relative 'simplecov_mcp/error_handler_factory'
require_relative 'simplecov_mcp/path_relativizer'
require_relative 'simplecov_mcp/resultset_loader'
require_relative 'simplecov_mcp/mode_detector'
require_relative 'simplecov_mcp/model'
require_relative 'simplecov_mcp/coverage_reporter'
require_relative 'simplecov_mcp/base_tool'
require_relative 'simplecov_mcp/tools/coverage_raw_tool'
require_relative 'simplecov_mcp/tools/coverage_summary_tool'
require_relative 'simplecov_mcp/tools/uncovered_lines_tool'
require_relative 'simplecov_mcp/tools/coverage_detailed_tool'
require_relative 'simplecov_mcp/tools/all_files_coverage_tool'
require_relative 'simplecov_mcp/tools/coverage_totals_tool'
require_relative 'simplecov_mcp/tools/coverage_table_tool'
require_relative 'simplecov_mcp/tools/version_tool'
require_relative 'simplecov_mcp/tools/help_tool'
require_relative 'simplecov_mcp/mcp_server'
require_relative 'simplecov_mcp/cli'

module SimpleCovMcp
  class << self
    THREAD_CONTEXT_KEY = :simplecov_mcp_context

    def run(argv)
      # Prepend environment options once at entry point
      full_argv = extract_env_opts + argv

      if ModeDetector.cli_mode?(full_argv)
        # CLI mode: pass merged argv to CoverageCLI
        CoverageCLI.new.run(full_argv)
      else
        # MCP server mode: parse config once from full_argv
        require_relative 'simplecov_mcp/config_parser'
        config = ConfigParser.parse(full_argv)

        if config.log_file == 'stdout'
          raise ConfigurationError,
            'Logging to stdout is not permitted in MCP server mode as it interferes with ' \
            "the JSON-RPC protocol. Please use 'stderr' or a file path."
        end

        handler = ErrorHandlerFactory.for_mcp_server(error_mode: config.error_mode)
        context = create_context(error_handler: handler, log_target: config.log_file, mode: :mcp_server)
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
      value
    end

    def active_log_file
      context.log_target
    end

    def active_log_file=(value)
      current = Thread.current[THREAD_CONTEXT_KEY]
      if current
        Thread.current[THREAD_CONTEXT_KEY] = current.with_log_target(value)
      else
        Thread.current[THREAD_CONTEXT_KEY] = default_context.with_log_target(value)
      end
      value
    end

    def error_handler
      context.error_handler
    end

    def error_handler=(handler)
      @default_context = default_context.with_error_handler(handler)
    end

    private

    def default_context
      @default_context ||= AppContext.new(
        error_handler: ErrorHandlerFactory.for_cli,
        log_target: nil
      )
    end

    def extract_env_opts
      require 'shellwords'
      opts_string = ENV['SIMPLECOV_MCP_OPTS']
      return [] unless opts_string && !opts_string.empty?

      begin
        Shellwords.split(opts_string)
      rescue ArgumentError
        [] # Ignore parsing errors
      end
    end
  end
end
