# frozen_string_literal: true

require_relative 'base_command'
require_relative '../predicate_evaluator'

module SimpleCovMcp
  module Commands
    # Validates coverage data against a predicate.
    # Exits with code 0 (pass), 1 (fail), or 2 (error).
    #
    # Usage:
    #   simplecov-mcp validate policy.rb                # File mode
    #   simplecov-mcp validate -i '->(m) { ... }'       # Inline mode
    class ValidateCommand < BaseCommand
      def execute(args)
        # Parse command-specific options
        inline_mode = false
        code = nil

        # Simple option parsing for -i/--inline flag
        while args.first&.start_with?('-')
          case args.first
          when '-i', '--inline'
            inline_mode = true
            args.shift
            code = args.shift or raise UsageError.for_subcommand('validate -i <code>')
          else
            raise UsageError, "Unknown option for validate: #{args.first}"
          end
        end

        # If not inline mode, expect a file path as positional argument
        unless inline_mode
          file_path = args.shift or raise UsageError.for_subcommand('validate <file> | -i <code>')
          code = file_path
        end

        # Evaluate the predicate
        result = if inline_mode
          PredicateEvaluator.evaluate_code(code, model)
        else
          PredicateEvaluator.evaluate_file(code, model)
        end

        exit(result ? 0 : 1)
      rescue UsageError
        # Usage errors should exit with code 1, not 2
        raise
      rescue => e
        handle_predicate_error(e)
      end

      private

      def handle_predicate_error(error)
        warn "Predicate error: #{error.message}"
        warn error.backtrace.first(5).join("\n") if config.error_mode == :trace
        exit 2
      end
    end
  end
end
