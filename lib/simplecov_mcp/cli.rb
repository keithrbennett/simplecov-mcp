# frozen_string_literal: true

require_relative 'option_parser_builder'
require_relative 'commands/command_factory'
require_relative 'option_parsers/error_helper'
require_relative 'option_parsers/env_options_parser'

module SimpleCovMcp
  class CoverageCLI
    SUBCOMMANDS = %w[list summary raw uncovered detailed version].freeze
    HORIZONTAL_RULE = '-' * 79

      # Initialize CLI for pure CLI usage only.
      # Always runs as CLI, no mode detection needed.
    def initialize(error_handler: nil)
      @root = '.'
      @resultset = nil
      @json = false
      @sort_order = 'ascending'
      @cmd = nil
      @cmd_args = []
      @source_mode = nil   # nil, 'full', or 'uncovered'
      @source_context = 2  # lines of context for uncovered mode
      @color = STDOUT.tty?
      @error_mode = :on
      @custom_error_handler = error_handler  # Store custom handler if provided
      @error_handler = nil  # Will be created after parsing options
      @stale_mode = 'off'
      @tracked_globs = nil
      @log_file = nil
      @success_predicate = nil
    end

    def run(argv)
      # Prepend environment options to command line arguments
      full_argv = parse_env_opts + argv
      # Pre-scan for error-mode to ensure early errors are logged with correct verbosity
      pre_scan_error_mode(full_argv)
      parse_options!(full_argv)

      # Create error handler AFTER parsing options to respect user's --error-mode choice
      ensure_error_handler

      # Set global log file if specified
      SimpleCovMcp.log_file = @log_file if @log_file

      # If success predicate specified, run it and exit
      if @success_predicate
        run_success_predicate
        return
      end

      if @cmd
        run_subcommand(@cmd, @cmd_args)
      else
        show_default_report(sort_order: @sort_order)
      end
    rescue OptionParser::ParseError => e
      # Handle any option parsing errors (invalid option/argument) without relying on
      # @error_handler, which is not guaranteed to be initialized yet.
      handle_option_parser_error(e, argv: full_argv)
    rescue SimpleCovMcp::Error => e
      handle_user_facing_error(e)
    rescue => e
      @error_handler.handle_error(e, context: 'CLI execution')
    end

    def show_default_report(sort_order: :ascending, output: $stdout)
      model = CoverageModel.new(root: @root, resultset: @resultset, staleness: @stale_mode, tracked_globs: @tracked_globs)
      rows = model.all_files(sort_order: sort_order, check_stale: (@stale_mode == 'error'), tracked_globs: @tracked_globs)

      if @json
        files = model.relativize(rows)
        total = files.length
        stale_count = files.count { |f| f['stale'] }
        ok_count = total - stale_count
        output.puts JSON.pretty_generate({ files: files, counts: { total: total, ok: ok_count, stale: stale_count } })
        return
      end

      file_summaries = model.relativize(rows)
      # Delegate to model for consistent formatting and avoid duplicate logic
      output.puts model.format_table(file_summaries, sort_order: sort_order, check_stale: (@stale_mode == 'error'), tracked_globs: @tracked_globs)
    end

      private

    def parse_options!(argv)
      require 'optparse'
      extract_subcommand!(argv)
      parser = build_option_parser
      parser.parse!(argv)
      @cmd_args = argv
    end

    def extract_subcommand!(argv)
      return if argv.empty?

      first_arg = argv[0]

      # If it's a flag/option, no subcommand
      return if first_arg.start_with?('-')

      # If it's a valid subcommand, extract it
      if SUBCOMMANDS.include?(first_arg)
        @cmd = argv.shift
      else
        # It's not a flag and not a valid subcommand - likely a typo
        raise UsageError.new("Unknown subcommand: '#{first_arg}'. Valid subcommands: #{SUBCOMMANDS.join(', ')}")
      end
    end

    def ensure_error_handler
      @error_handler ||= @custom_error_handler || ErrorHandlerFactory.for_cli(error_mode: @error_mode)
    end

    def parse_env_opts
      @env_parser ||= OptionParsers::EnvOptionsParser.new
      @env_parser.parse_env_opts
    end

    def pre_scan_error_mode(argv)
      @env_parser ||= OptionParsers::EnvOptionsParser.new
      @error_mode = @env_parser.pre_scan_error_mode(argv)
      @error_mode ||= :on  # Default if not found
    end

    def build_option_parser
      builder = OptionParserBuilder.new(self)
      builder.build_option_parser
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

    
    def run_success_predicate
      predicate = load_success_predicate(@success_predicate)
      model = CoverageModel.new(root: @root, resultset: @resultset, staleness: @stale_mode, tracked_globs: @tracked_globs)

      result = predicate.call(model)
      exit(result ? 0 : 1)
    rescue => e
      warn "Success predicate error: #{e.message}"
      warn e.backtrace.first(5).join("\n") if @error_mode == :on_with_trace
      exit 2  # Exit code 2 for predicate errors
    end

    def load_success_predicate(path)
      unless File.exist?(path)
        raise "Success predicate file not found: #{path}"
      end

      content = File.read(path)
      predicate = eval(content, binding, path)

      unless predicate.respond_to?(:call)
        raise "Success predicate must be callable (lambda, proc, or object with #call method)"
      end

      predicate
    rescue SyntaxError => e
      raise "Syntax error in success predicate file: #{e.message}"
    end

    def handle_user_facing_error(error)
      # Ensure error handler exists (may not be initialized if error occurs during option parsing)
      ensure_error_handler
      # Log the error if error_mode allows it
      @error_handler.handle_error(error, context: 'CLI', reraise: false)
      # Show user-friendly message
      warn error.user_friendly_message
      exit 1
    end
  end
end
