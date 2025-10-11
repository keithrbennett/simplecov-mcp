# frozen_string_literal: true

require_relative 'cli_config'
require_relative 'option_parser_builder'
require_relative 'commands/command_factory'
require_relative 'option_parsers/error_helper'
require_relative 'option_parsers/env_options_parser'

module SimpleCovMcp
  class CoverageCLI
    SUBCOMMANDS = %w[list summary raw uncovered detailed version].freeze
    HORIZONTAL_RULE = '-' * 79

    OPTIONS_EXPECTING_ARGUMENT = %w[
      -r --resultset
      -R --root
      -o --sort-order
      -c --source-context
      -S --stale
      -g --tracked-globs
      -l --log-file
      --error-mode
      --success-predicate
    ].freeze

    attr_reader :config

    # Initialize CLI for pure CLI usage only.
    # Always runs as CLI, no mode detection needed.
    def initialize(error_handler: nil)
      @config = CLIConfig.new
      @cmd = nil
      @cmd_args = []
      @custom_error_handler = error_handler  # Store custom handler if provided
      @error_handler = nil  # Will be created after parsing options
    end

    def run(argv)
      context = nil
      # Prepend environment options to command line arguments
      full_argv = parse_env_opts + argv
      # Pre-scan for error-mode to ensure early errors are logged with correct verbosity
      pre_scan_error_mode(full_argv)
      parse_options!(full_argv)

      # Create error handler AFTER parsing options to respect user's --error-mode choice
      ensure_error_handler

      context = SimpleCovMcp.create_context(
        error_handler: @error_handler,
        log_target: config.log_file.nil? ? SimpleCovMcp.context.log_target : config.log_file,
        mode: :cli
      )

      SimpleCovMcp.with_context(context) do
        # If success predicate specified, run it and exit
        if config.success_predicate
          run_success_predicate
          next
        end

        if @cmd
          run_subcommand(@cmd, @cmd_args)
        else
          show_default_report(sort_order: config.sort_order)
        end
      end
    rescue OptionParser::ParseError => e
      # Handle any option parsing errors (invalid option/argument) without relying on
      # @error_handler, which is not guaranteed to be initialized yet.
      with_context_if_available(context) { handle_option_parser_error(e, argv: full_argv) }
    rescue SimpleCovMcp::Error => e
      with_context_if_available(context) { handle_user_facing_error(e) }
    end

    def show_default_report(sort_order: :ascending, output: $stdout)
      model = CoverageModel.new(**config.model_options)
      rows = model.all_files(sort_order: sort_order, check_stale: (config.stale_mode == :error), tracked_globs: config.tracked_globs)

      if config.json
        files = model.relativize(rows)
        total = files.length
        stale_count = files.count { |f| f['stale'] }
        ok_count = total - stale_count
        output.puts JSON.pretty_generate({ files: files, counts: { total: total, ok: ok_count, stale: stale_count } })
        return
      end

      file_summaries = model.relativize(rows)
      # Delegate to model for consistent formatting and avoid duplicate logic
      output.puts model.format_table(file_summaries, sort_order: sort_order, check_stale: (config.stale_mode == :error), tracked_globs: config.tracked_globs)
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
      # Environment options (e.g., from SIMPLECOV_MCP_OPTS) may precede the subcommand.
      # Walk the array so we can skip over any option/argument pairs before
      # we decide what the first meaningful token is.
      return if argv.empty?

      first_unknown = nil
      pending_option = nil

      argv.each_with_index do |token, index|

        # skip the argument that belongs to the previous option
        if pending_option
          pending_option = nil
          next
        end

        if token.start_with?('-')
          # CLI options (and --foo=value forms) start with '-'; values beginning with '-' are skipped via pending_option
          # Remember options that expect a following argument so we can skip
          # that value on the next iteration.
          pending_option = expects_argument?(token) && !token.include?('=') ? token : nil
          next
        elsif SUBCOMMANDS.include?(token)
          # Found the real subcommand; pluck it out so option parsing sees the
          # remaining args in their original order.
          @cmd = token
          argv.delete_at(index)
          return
        else
          first_unknown ||= token
        end
      end

      if first_unknown
        raise UsageError.new("Unknown subcommand: '#{first_unknown}'. Valid subcommands: #{SUBCOMMANDS.join(', ')}")
      end
    end

    def expects_argument?(option)
      OPTIONS_EXPECTING_ARGUMENT.include?(option)
    end

    def ensure_error_handler
      @error_handler ||= @custom_error_handler || ErrorHandlerFactory.for_cli(error_mode: config.error_mode)
    end

    def parse_env_opts
      @env_parser ||= OptionParsers::EnvOptionsParser.new
      @env_parser.parse_env_opts
    end

    def pre_scan_error_mode(argv)
      @env_parser ||= OptionParsers::EnvOptionsParser.new
      config.error_mode = @env_parser.pre_scan_error_mode(argv) || :on
    end

    def build_option_parser
      builder = OptionParserBuilder.new(config)
      builder.build_option_parser
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

    
    def run_success_predicate
      predicate = load_success_predicate(config.success_predicate)
      model = CoverageModel.new(**config.model_options)

      result = predicate.call(model)
      exit(result ? 0 : 1)
    rescue => e
      warn "Success predicate error: #{e.message}"
      warn e.backtrace.first(5).join("\n") if config.error_mode == :on_with_trace
      exit 2  # Exit code 2 for predicate errors
    end

    def load_success_predicate(path)
      unless File.exist?(path)
        raise "Success predicate file not found: #{path}"
      end

      content = File.read(path)

      # WARNING: The predicate code executes with full Ruby privileges.
      # It has unrestricted access to the file system, network, and system commands.
      # Only use predicate files from trusted sources.
      #
      # We evaluate in a fresh Object context to prevent accidental access to
      # CLI internals, but this provides NO security isolation.
      evaluation_context = Object.new
      predicate = evaluation_context.instance_eval(content, path, 1)

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
