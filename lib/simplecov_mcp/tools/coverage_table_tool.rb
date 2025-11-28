# frozen_string_literal: true


require_relative '../base_tool'
require_relative '../presenters/project_coverage_presenter'

module SimpleCovMcp
  module Tools
    class CoverageTableTool < BaseTool
      description <<~DESC
        Use this when a user wants the plain text coverage table exactly like `simplecov-mcp --table` would print (no ANSI colors).
        Do not use this for machine-readable data; coverage.all_files returns structured JSON.
        Inputs: optional project root/resultset path/sort order/staleness mode matching the CLI flags.
        Output: text block containing the formatted coverage table with headers and percentages.
        Example: "Show me the CLI coverage table sorted descending".
      DESC
      input_schema(
        type: 'object',
        additionalProperties: false,
        properties: {
          root: {
            type: 'string',
            description: 'Project root used to resolve relative inputs.',
            default: '.'
          },
          resultset: {
            type: 'string',
            description: 'Path to the SimpleCov .resultset.json file.'
          },
          sort_order: {
            type: 'string',
            description: 'Sort order for the printed coverage table (ascending or descending).',
            default: 'ascending',
            enum: ['ascending', 'descending']
          },
          stale: {
            type: 'string',
            description: 'How to handle missing/outdated coverage data. ' \
                         "'off' skips checks; 'error' raises.",
            enum: ['off', 'error'],
            default: 'off'
          },
          tracked_globs: {
            type: 'array',
            description: 'Glob patterns for files that should exist in the coverage report ' \
                         '(helps flag new files).',
            items: { type: 'string' }
          },
          error_mode: {
            type: 'string',
            description:
              "Error handling mode: 'off' (silent), 'on' (log errors), 'trace' (verbose).",
            enum: ['off', 'on', 'trace'],
            default: 'on'
          }
        }
      )

      class << self
        def call(root: '.', resultset: nil, sort_order: 'ascending', stale: :off,
          tracked_globs: nil, error_mode: 'on', server_context:)
          with_error_handling('CoverageTableTool', error_mode: error_mode) do
            model = CoverageModel.new(root: root, resultset: resultset, staleness: stale,
              tracked_globs: tracked_globs)
            table = model.format_table(
              sort_order: sort_order,
              check_stale: (stale.to_s == 'error'),
              tracked_globs: tracked_globs
            )
            # Return text response
            ::MCP::Tool::Response.new([{ type: 'text', text: table }])
          end
        end
      end
    end
  end
end
