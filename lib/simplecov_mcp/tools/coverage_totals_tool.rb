# frozen_string_literal: true

require_relative '../model'
require_relative '../base_tool'
require_relative '../presenters/project_totals_presenter'

module SimpleCovMcp
  module Tools
    class CoverageTotalsTool < BaseTool
      description <<~DESC
        Use this when you want aggregated coverage counts for the entire project.
        It reports covered/total lines, uncovered line counts, and the overall average percentage.
        Inputs: optional project root, alternate .resultset path, staleness mode, tracked_globs, and error mode.
        Output: JSON {"lines":{"total","covered","uncovered"},"percentage":Float,"files":{"total","ok","stale"}}.
        Example: "Give me total/covered/uncovered line counts and the overall coverage percent."
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
          stale: {
            type: 'string',
            description: 'How to handle missing/outdated coverage data. ' \
                         "'off' skips checks; 'error' raises.",
            enum: ['off', 'error'],
            default: 'off'
          },
          tracked_globs: {
            type: 'array',
            description: 'Glob patterns for files that should exist in the coverage report' \
                         '(helps flag new files).',
            items: { type: 'string' }
          },
          error_mode: {
            type: 'string',
            description: "Error handling mode: 'off' (silent), 'on' (log errors), " \
                         "'trace' (verbose).",
            enum: ['off', 'on', 'trace'],
            default: 'on'
          }
        }
      )

      class << self
        def call(root: '.', resultset: nil, stale: 'off', tracked_globs: nil, error_mode: 'on',
          server_context:)
          stale_sym = stale.to_sym
          model = CoverageModel.new(root: root, resultset: resultset, staleness: stale_sym,
            tracked_globs: tracked_globs)
          presenter = Presenters::ProjectTotalsPresenter.new(
            model: model,
            check_stale: (stale_sym == :error),
            tracked_globs: tracked_globs
          )
          respond_json(presenter.relativized_payload, name: 'coverage_totals.json', pretty: true)
        rescue => e
          handle_mcp_error(e, 'CoverageTotalsTool', error_mode: error_mode)
        end
      end
    end
  end
end
