# frozen_string_literal: true

require_relative '../base_tool'
require_relative '../model'
require_relative '../predicate_evaluator'

module SimpleCovMcp
  module Tools
    class ValidateTool < BaseTool
      description <<~DESC
        Validates coverage data against a predicate (Ruby code that evaluates to true/false).
        Use this to enforce coverage policies programmatically.
        Inputs: Either 'code' (Ruby string) OR 'file' (path to Ruby file), plus optional root/resultset/stale/error_mode.
        Output: JSON object {"result": Boolean} where true means policy passed, false means failed.
        On error (syntax error, file not found, etc.), returns an MCP error response.
        Security Warning: Predicates execute as arbitrary Ruby code with full system privileges.
        Examples:
        - "Check if all files have at least 80% coverage" → {"code": "->(m) { m.all_files.all? { |f| f['percentage'] >= 80 } }"}
        - "Run coverage policy from file" → {"file": "coverage_policy.rb"}
      DESC

      # Custom input schema for validate tool
      VALIDATE_INPUT_SCHEMA = {
        type: 'object',
        additionalProperties: false,
        properties: {
          code: {
            type: 'string',
            description: 'Ruby code string that returns a callable predicate. ' \
                         'Must evaluate to a lambda, proc, or object with #call method.'
          },
          file: {
            type: 'string',
            description:
              'Path to Ruby file containing predicate code (absolute or relative to root).'
          },
          root: {
            type: 'string',
            description:
              'Project root used to resolve relative paths (defaults to current workspace).',
            default: '.'
          },
          resultset: {
            type: 'string',
            description:
              'Path to the SimpleCov .resultset.json file (absolute or relative to root).'
          },
          stale: {
            type: 'string',
            description:
              "How to handle missing/outdated coverage data. 'off' skips checks; 'error' raises.",
            enum: ['off', 'error'],
            default: 'off'
          },
          error_mode: {
            type: 'string',
            description:
              "Error handling mode: 'off' (silent), 'on' (log errors), 'trace' (verbose).",
            enum: ['off', 'on', 'trace'],
            default: 'on'
          }
        },
        oneOf: [
          { required: ['code'] },
          { required: ['file'] }
        ]
      }.freeze

      input_schema(**VALIDATE_INPUT_SCHEMA)

      class << self
        def call(
          code: nil, file: nil, root: '.', resultset: nil, stale: :off,
          error_mode: 'on', server_context:
        )
          with_error_handling('ValidateTool', error_mode: error_mode) do
            # Re-use logic from ValidateCommand, but adapt for MCP return format
            require_relative '../cli'

            # Create a minimal CLI shim to reuse command logic
            cli = CoverageCLI.new
            cli.config.root = root
            cli.config.resultset = resultset
            cli.config.staleness = stale
            cli.config.error_mode = error_mode.to_sym

            # We need to capture the boolean result instead of letting it exit
            # Commands::ValidateCommand is designed to exit, so we'll use the model and evaluator directly
            # This duplicates some logic from ValidateCommand#execute but avoids the exit(status) call

            model = CoverageModel.new(**cli.config.model_options)

            result = if code
              PredicateEvaluator.evaluate_code(code, model)
            elsif file
              # Resolve file path relative to root if needed
              predicate_path = File.expand_path(file, root)
              PredicateEvaluator.evaluate_file(predicate_path, model)
            else
              raise UsageError, "Either 'code' or 'file' must be provided"
            end

            respond_json({ result: result }, name: 'validate_result.json', pretty: true)
          end
        end
      end
    end
  end
end
