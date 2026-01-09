# frozen_string_literal: true

require_relative '../model/model'
require_relative '../base_tool'
require_relative '../presenters/project_totals_presenter'

module CovLoupe
  module Tools
    class CoverageTotalsTool < BaseTool
      description <<~DESC
        Use this when you want aggregated coverage counts for the entire project.
        It reports covered/total lines, uncovered line counts, and the overall average percentage.
        Inputs: optional project root, alternate .resultset path, raise_on_stale flag, tracked_globs, and error mode.
        Output: JSON {"lines":{"total","covered","uncovered","percent_covered"},"tracking":{"enabled","globs"},"files":{"total","with_coverage","without_coverage"}}.
        When raise_on_stale is enabled, the tool will raise an error immediately if any files have coverage data errors or staleness issues.
        Example: "Give me total/covered/uncovered line counts and the overall coverage percent."
      DESC

      input_schema(**coverage_schema(
        additional_properties: {
          tracked_globs: TRACKED_GLOBS_PROPERTY
        }
      ))

      class << self
        def call(root: nil, resultset: nil, raise_on_stale: nil, tracked_globs: nil,
          error_mode: 'log', server_context:)
          with_error_handling('CoverageTotalsTool', error_mode: error_mode) do
            model, config = create_configured_model(
              server_context: server_context,
              root: root,
              resultset: resultset,
              raise_on_stale: raise_on_stale,
              tracked_globs: tracked_globs
            )

            presenter = Presenters::ProjectTotalsPresenter.new(
              model: model,
              raise_on_stale: config[:raise_on_stale],
              tracked_globs: config[:tracked_globs]
            )
            respond_json(presenter.relativized_payload, name: 'coverage_totals.json', pretty: true)
          end
        end
      end
    end
  end
end
