# frozen_string_literal: true

require 'json'
require_relative 'app_config'
require_relative 'option_parser_builder'
require_relative 'commands/command_factory'
require_relative 'option_parsers/error_helper'
require_relative 'option_parsers/env_options_parser'
require_relative 'constants'
require_relative 'presenters/project_coverage_presenter'

module SimpleCovMcp
  class CoverageCLI
    SUBCOMMANDS = %w[list summary raw uncovered detailed total validate version].freeze
    HORIZONTAL_RULE = '-' * 79

    # Reference shared constant to avoid duplication with ModeDetector
    OPTIONS_EXPECTING_ARGUMENT = Constants::OPTIONS_EXPECTING_ARGUMENT

    attr_reader :config

    # Initialize CLI for pure CLI usage only.
    # Always runs as CLI, no mode detection needed.
    def initialize(error_handler: nil)
      @config = AppConfig.new
      @cmd = nil
      @cmd_args = []
      @custom_error_handler = error_handler # Store custom handler if provided
      @error_handler = nil # Will be created after parsing options
    end

    def run(argv)
      context = nil
      # argv should already include environment options (merged by caller)
      # Pre-scan for error-mode to ensure early errors are logged with correct verbosity
      pre_scan_error_mode(argv)
      parse_options!(argv)
      enforce_version_subcommand_if_requested

      # Create error handler AFTER parsing options to respect user's --error-mode choice
      ensure_error_handler

      context = SimpleCovMcp.create_context(
        error_handler: @error_handler,
        log_target: config.log_file.nil? ? SimpleCovMcp.context.log_target : config.log_file,
        mode: :cli
      )

      SimpleCovMcp.with_context(context) do
        if @cmd
          run_subcommand(@cmd, @cmd_args)
        else
          show_default_report(sort_order: config.sort_order)
        end
      end
    rescue OptionParser::ParseError => e
      # Handle any option parsing errors (invalid option/argument) without relying on
      # @error_handler, which is not guaranteed to be initialized yet.
      with_context_if_available(context) { handle_option_parser_error(e, argv: argv) }
    rescue SimpleCovMcp::Error => e
      with_context_if_available(context) { handle_user_facing_error(e) }
    end

    def show_default_report(sort_order: :ascending, output: $stdout)
      model = CoverageModel.new(**config.model_options)
      presenter = Presenters::ProjectCoveragePresenter.new(
        model: model,
        sort_order: sort_order,
        check_stale: (config.stale_mode == :error),
        tracked_globs: config.tracked_globs
      )

      if config.json
        output.puts JSON.pretty_generate(presenter.relativized_payload)
        return
      end

      file_summaries = presenter.relative_files
      output.puts model.format_table(
        file_summaries,
        sort_order: sort_order,
        check_stale: (config.stale_mode == :error),
        tracked_globs: nil
      )
    end

    private

    def parse_options!(argv)
      require 'optparse'
      global_opts, subcommand_args = extract_subcommand_and_split!(argv)
      parser = build_option_parser
      parser.parse!(global_opts)
      @cmd_args = subcommand_args
    end

    def extract_subcommand_and_split!(argv)
      # Environment options (e.g., from SIMPLECOV_MCP_OPTS) may precede the subcommand.
      # Walk the array to find the subcommand and split argv into:
      # - global_opts: options before the subcommand
      # - subcommand_args: args after the subcommand
      return [argv, []] if argv.empty?

      first_unknown = nil
      pending_option = nil
      global_opts = []
      subcommand_index = nil

      argv.each_with_index do |token, index|
        # skip the argument that belongs to the previous option
        if pending_option
          global_opts << token
          pending_option = nil
          next
        end

        if token.start_with?('-')
          # CLI options (and --foo=value forms) start with '-'; values beginning with '-' are skipped via pending_option
          # Remember options that expect a following argument so we can skip
          # that value on the next iteration.
          global_opts << token
          pending_option = expects_argument?(token) && !token.include?('=') ? token : nil
          next
        elsif SUBCOMMANDS.include?(token)
          # Found the real subcommand
          @cmd = token
          subcommand_index = index
          break
        else
          first_unknown ||= token
        end
      end

      if first_unknown && !subcommand_index
        raise UsageError.new("Unknown subcommand: '#{first_unknown}'. Valid subcommands: #{SUBCOMMANDS.join(', ')}")
      end

      # Return global options and subcommand args (everything after the subcommand)
      if subcommand_index
        subcommand_args = argv[(subcommand_index + 1)..]
        [global_opts, subcommand_args]
      else
        [global_opts, []]
      end
    end

    def expects_argument?(option)
      OPTIONS_EXPECTING_ARGUMENT.include?(option)
    end

    def ensure_error_handler
      @error_handler ||=
        @custom_error_handler || ErrorHandlerFactory.for_cli(error_mode: config.error_mode)
    end

    def pre_scan_error_mode(argv)
      env_parser = OptionParsers::EnvOptionsParser.new
      config.error_mode = env_parser.pre_scan_error_mode(argv) || :on
    end

    def build_option_parser
      builder = OptionParserBuilder.new(config)
      builder.build_option_parser
    end

    # Converts the -v/--version flags into the version subcommand.
    # When the user passes -v or --version, config.show_version is set to true during option parsing.
    # This method intercepts that flag and redirects execution to the 'version' subcommand,
    # ensuring consistent version display regardless of whether the user runs
    # `simplecov-mcp -v`, `simplecov-mcp --version`, or `simplecov-mcp version`.
    def enforce_version_subcommand_if_requested
      @cmd = 'version' if config.show_version
    end

    def with_context_if_available(ctx)
      if ctx
        SimpleCovMcp.with_context(ctx) { yield }
      else
        yield
      end
    end

    def run_subcommand(cmd, args)
      command = Commands::CommandFactory.create(cmd, self)
      command.execute(args)
    rescue SimpleCovMcp::Error => e
      handle_user_facing_error(e)
    rescue => e
      @error_handler.handle_error(e, context: "subcommand '#{cmd}'")
    end

    def handle_option_parser_error(error, argv: [])
      @error_helper ||= OptionParsers::ErrorHelper.new(SUBCOMMANDS)
      @error_helper.handle_option_parser_error(error, argv: argv)
    end

    def handle_user_facing_error(error)
      # Ensure error handler exists (may not be initialized if error occurs during option parsing)
      ensure_error_handler
      # Log the error if error_mode allows it
      @error_handler.handle_error(error, context: 'CLI', reraise: false)
      # Show user-friendly message
      warn error.user_friendly_message
      # Show stack trace in trace mode
      warn error.backtrace.first(5).join("\n") if config.error_mode == :trace && error.backtrace
      exit 1
    end
  end
end
