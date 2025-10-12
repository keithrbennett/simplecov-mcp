# frozen_string_literal: true

require_relative '../base_tool'
require_relative '../model'
require_relative '../presenters/coverage_summary_presenter'

module SimpleCovMcp
  module Tools
    class CoverageSummaryTool < BaseTool
      description <<~DESC
        Use this when the user asks for the covered/total line counts and percentage for a specific file.
        Do not use this for multi-file reports; coverage.all_files or coverage.table handle those.
        Inputs: file path (required) plus optional root/resultset/stale mode inherited from BaseTool.
        Output: JSON object {"file": String, "summary": {"covered": Integer, "total": Integer, "pct": Float}, "stale": String|False}.
        Examples: "What is the coverage for lib/simple_cov_mcp/tools/all_files_coverage_tool.rb?".
      DESC
      input_schema(**input_schema_def)
      class << self
        def call(path:, root: '.', resultset: nil, stale: 'off', error_mode: 'on', server_context:)
          model = CoverageModel.new(root: root, resultset: resultset, staleness: stale)
          presenter = Presenters::CoverageSummaryPresenter.new(model: model, path: path)
          respond_json(presenter.relativized_payload, name: 'coverage_summary.json', pretty: true)
        rescue => e
          handle_mcp_error(e, 'CoverageSummaryTool', error_mode: error_mode)
        end
      end
    end
  end
end
