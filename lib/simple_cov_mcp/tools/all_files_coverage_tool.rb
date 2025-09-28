# frozen_string_literal: true

require_relative '../model'
require_relative '../base_tool'

module SimpleCovMcp
  module Tools
    class AllFilesCoverageTool < BaseTool
      description <<~DESC
        Use this when the user wants coverage percentages for every tracked file in the project.
        Do not use this for single-file stats; prefer coverage.summary or coverage.uncovered_lines for that.
        Inputs: optional project root, alternate .resultset path, sort order, staleness mode, and tracked_globs to alert on new files.
        Output: JSON {"files": [{"file","covered","total","percentage","stale"}, ...], "counts": {"total", "ok", "stale"}} sorted as requested. "stale" is a boolean.
        Examples: "List files with the lowest coverage"; "Show repo coverage sorted descending".
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
            description: "Sort order for coverage percentages. 'ascending' highlights the riskiest files first.",
            default: 'ascending',
            enum: ['ascending', 'descending']
          },
          stale: {
            type: 'string',
            description: "How to handle missing/outdated coverage data. 'off' skips checks; 'error' raises.",
            enum: ['off', 'error'],
            default: 'off'
          },
          tracked_globs: {
            type: 'array',
            description: 'Glob patterns for files that should exist in the coverage report (helps flag new files).',
            items: { type: 'string' }
          },
          error_mode: {
            type: 'string',
            description: "Error handling mode: 'off' (silent), 'on' (log errors), 'on_with_trace' (verbose).",
            enum: ['off', 'on', 'on_with_trace'],
            default: 'on'
          }
        }
      )
      class << self
        def call(root: '.', resultset: nil, sort_order: 'ascending', stale: 'off', tracked_globs: nil, error_mode: 'on', server_context:)
          model = CoverageModel.new(root: root, resultset: resultset, staleness: stale, tracked_globs: tracked_globs)
          files = model.all_files(sort_order: sort_order, check_stale: (stale.to_s == 'error'), tracked_globs: tracked_globs)
          total = files.length
          stale_count = files.count { |f| f['stale'] }
          ok_count = total - stale_count
          payload = { files: files, counts: { total: total, ok: ok_count, stale: stale_count } }
          respond_json(payload, name: 'all_files_coverage.json')
        rescue => e
          handle_mcp_error(e, 'AllFilesCoverageTool', error_mode: error_mode)
        end
      end
    end
  end
end
