# frozen_string_literal: true

require_relative '../base_tool'
require_relative '../model'
require_relative '../presenters/coverage_uncovered_presenter'

module SimpleCovMcp
  module Tools
    class UncoveredLinesTool < BaseTool
      description <<~DESC
        Use this when the user wants to know which lines in a file still lack coverage.
        Do not use this for overall percentages; coverage.summary is faster when counts are enough.
        Inputs: file path (required) plus optional root/resultset/stale mode inherited from BaseTool.
        Output: JSON object with keys "file", "uncovered" (array of integers), "summary" {"covered","total","percentage"}, and "stale" status.
        Example: "List uncovered lines for lib/simple_cov_mcp/tools/coverage_summary_tool.rb".
      DESC
      input_schema(**input_schema_def)
      class << self
        def call(path:, root: '.', resultset: nil, stale: 'off', error_mode: 'on', server_context:)
          with_error_handling('UncoveredLinesTool', error_mode: error_mode) do
            model = CoverageModel.new(root: root, resultset: resultset, staleness: stale)
            presenter = Presenters::CoverageUncoveredPresenter.new(model: model, path: path)
            respond_json(presenter.relativized_payload, name: 'uncovered_lines.json', pretty: true)
          end
        end
      end
    end
  end
end
