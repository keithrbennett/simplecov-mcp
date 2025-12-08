# frozen_string_literal: true

require_relative '../base_tool'
require_relative '../model'
require_relative '../presenters/coverage_detailed_presenter'

module CovLoupe
  module Tools
    class CoverageDetailedTool < BaseTool
      description <<~DESC
        Use this when the user needs per-line coverage data for a single file.
        Do not use this for high-level counts; coverage.summary is cheaper for aggregate numbers.
        Inputs: file path (required) plus optional root/resultset/staleness mode inherited from BaseTool.
        Output: JSON object with "file", "lines" => [{"line": 12, "hits": 0, "covered": false}], plus "summary" with totals and "stale" status.
        Example: "Show detailed coverage for lib/simple_cov_mcp/model.rb".
      DESC
      input_schema(**input_schema_def)
      class << self
        def call(path:, root: '.', resultset: nil, staleness: :off, error_mode: 'log',
          server_context:)
          with_error_handling('CoverageDetailedTool', error_mode: error_mode) do
            model = CoverageModel.new(
              root: root,
              resultset: resultset,
              staleness: staleness.to_sym
            )
            presenter = Presenters::CoverageDetailedPresenter.new(model: model, path: path)
            respond_json(presenter.relativized_payload, name: 'coverage_detailed.json',
              pretty: true)
          end
        end
      end
    end
  end
end
