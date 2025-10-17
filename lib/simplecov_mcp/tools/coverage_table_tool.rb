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
            description: 'How to handle missing/outdated coverage data. '\
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
            description: \
              "Error handling mode: 'off' (silent), 'on' (log errors), 'trace' (verbose).",
            enum: ['off', 'on', 'trace'],
            default: 'on'
          }
        }
      )

      class << self
        def call(root: '.', resultset: nil, sort_order: 'ascending', stale: 'off',
          tracked_globs: nil, error_mode: 'on', server_context:)
          # Capture the output of the CLI's table report while honoring CLI options
          # Convert string inputs from MCP to symbols for internal use
          sort_order_sym = sort_order.to_sym
          stale_sym = stale.to_sym
          check_stale = (stale_sym == :error)

          model = CoverageModel.new(root: root, resultset: resultset, staleness: stale_sym,
            tracked_globs: tracked_globs)
          presenter = Presenters::ProjectCoveragePresenter.new(
            model: model,
            sort_order: sort_order_sym,
            check_stale: check_stale,
            tracked_globs: tracked_globs
          )
          relativized = presenter.relative_files
          table = model.format_table(
            relativized,
            sort_order: sort_order_sym,
            check_stale: check_stale,
            tracked_globs: nil # rows already filtered via all_files
          )
          ::MCP::Tool::Response.new([{ type: 'text', text: table }])
        rescue => e
          handle_mcp_error(e, 'CoverageTableTool', error_mode: error_mode)
        end
      end
    end
  end
end
