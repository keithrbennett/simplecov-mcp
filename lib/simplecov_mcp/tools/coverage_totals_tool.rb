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

      input_schema(**coverage_schema(
        additional_properties: {
          tracked_globs: TRACKED_GLOBS_PROPERTY
        }
      ))

      class << self
        def call(root: '.', resultset: nil, staleness: :off, tracked_globs: nil,
          error_mode: 'log', server_context:)
          with_error_handling('CoverageTotalsTool', error_mode: error_mode) do
            # Convert string inputs from MCP to symbols for internal use
            staleness_sym = staleness.to_sym

            model = CoverageModel.new(root: root, resultset: resultset, staleness: staleness_sym,
              tracked_globs: tracked_globs)
            presenter = Presenters::ProjectTotalsPresenter.new(
              model: model,
              check_stale: (staleness_sym == :error),
              tracked_globs: tracked_globs
            )
            respond_json(presenter.relativized_payload, name: 'coverage_totals.json', pretty: true)
          end
        end
      end
    end
  end
end
