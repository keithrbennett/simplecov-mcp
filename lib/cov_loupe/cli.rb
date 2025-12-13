# frozen_string_literal: true

require 'json'
require_relative 'app_config'
require_relative 'option_parser_builder'
require_relative 'commands/command_factory'
require_relative 'option_parsers/error_helper'
require_relative 'option_parsers/env_options_parser'
require_relative 'constants'
require_relative 'presenters/project_coverage_presenter'

module CovLoupe
  class CoverageCLI
    SUBCOMMANDS = %w[list summary raw uncovered detailed totals validate version].freeze
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

      context = CovLoupe.create_context(
        error_handler: error_handler, # construct after options to respect --error-mode
        log_target: config.log_file.nil? ? CovLoupe.context.log_target : config.log_file,
        mode: :cli
      )

      CovLoupe.with_context(context) do
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
    rescue CovLoupe::Error => e
      with_context_if_available(context) { handle_user_facing_error(e) }
    end

    def show_default_report(sort_order: :descending, output: $stdout)
      model = CoverageModel.new(**config.model_options)
      presenter = Presenters::ProjectCoveragePresenter.new(
        model: model,
        sort_order: sort_order,
        raise_on_stale: config.raise_on_stale,
        tracked_globs: config.tracked_globs
      )

      if config.format != :table
        require_relative 'formatters'
        output.puts Formatters.format(presenter.relativized_payload, config.format)
        return
      end

      file_summaries = presenter.relative_files
      output.puts model.format_table(
        file_summaries,
        sort_order: sort_order,
        raise_on_stale: config.raise_on_stale,
        tracked_globs: nil
      )
    end

    private def parse_options!(argv)
      require 'optparse'
      parser = build_option_parser

      # order! parses global options (updating config) and removes them from argv.
      # It stops cleanly at the first subcommand (e.g., 'list', 'summary') or unknown option.
      # If it stops at an unknown option, it raises OptionParser::InvalidOption.
      parser.order!(argv)

      # The first remaining argument is the subcommand
      @cmd = argv.shift

      # Verify it's a valid subcommand if present
      if @cmd && !SUBCOMMANDS.include?(@cmd)
        raise UsageError, "Unknown subcommand: '#{@cmd}'. Valid subcommands: #{SUBCOMMANDS.join(', ')}"
      end

      # Any remaining arguments belong to the subcommand
      @cmd_args = argv
    end

    private def error_handler
      @error_handler ||= @custom_error_handler ||
                         ErrorHandlerFactory.for_cli(error_mode: config.error_mode)
    end

    private def pre_scan_error_mode(argv)
      env_parser = OptionParsers::EnvOptionsParser.new
      config.error_mode = env_parser.pre_scan_error_mode(argv) || :log
    end

    private def build_option_parser
      builder = OptionParserBuilder.new(config)
      builder.build_option_parser
    end

    # Converts the -v/--version flags into the version subcommand.
    # When the user passes -v or --version, config.show_version is set to true during option parsing.
    # This method intercepts that flag and redirects execution to the 'version' subcommand,
    # ensuring consistent version display regardless of whether the user runs
    # `cov-loupe -v`, `cov-loupe --version`, or `cov-loupe version`.
    private def enforce_version_subcommand_if_requested
      @cmd = 'version' if config.show_version
    end

    private def with_context_if_available(ctx, &block)
      if ctx
        CovLoupe.with_context(ctx, &block)
      else
        block.call
      end
    end

    private def run_subcommand(cmd, args)
      # Check if user mistakenly placed global options after the subcommand
      check_for_misplaced_global_options(cmd, args)

      command = Commands::CommandFactory.create(cmd, self)
      command.execute(args)
    rescue CovLoupe::Error => e
      handle_user_facing_error(e)
    rescue => e
      error_handler.handle_error(e, context: "subcommand '#{cmd}'")
    end

    private def handle_option_parser_error(error, argv: [])
      @error_helper ||= OptionParsers::ErrorHelper.new(SUBCOMMANDS)
      @error_helper.handle_option_parser_error(error, argv: argv)
    end

    private def check_for_misplaced_global_options(cmd, args)
      # Global options that users commonly place after subcommands by mistake
      global_options = %w[-r --resultset -R --root -f --format -o --sort-order -s --source
                          -c --context-lines -S --raise-on-stale -g --tracked-globs
                          -l --log-file --error-mode --color]

      misplaced = args.select { |arg| global_options.include?(arg) }
      return if misplaced.empty?

      option_list = misplaced.join(', ')
      raise UsageError, "Global option(s) must come BEFORE the subcommand.\n" \
        "You used: #{cmd} #{option_list}\n" \
        "Correct: #{option_list} #{cmd}\n\n" \
        "Example: cov-loupe --format json #{cmd}"
    end

    private def handle_user_facing_error(error)
      error_handler.handle_error(error, context: 'CLI', reraise: false)
      warn error.user_friendly_message
      warn error.backtrace.first(5).join("\n") if config.error_mode == :debug && error.backtrace
      exit 1
    end
  end
end
