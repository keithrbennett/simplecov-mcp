# frozen_string_literal: true

require_relative '../base_tool'
require_relative '../model'
require_relative '../presenters/coverage_summary_presenter'

module CovLoupe
  module Tools
    class CoverageSummaryTool < BaseTool
      description <<~DESC
        Use this when the user asks for the covered/total line counts and percentage for a specific file.
        Do not use this for multi-file reports; coverage.all_files or coverage.table handle those.
        Inputs: file path (required) plus optional root/resultset/staleness mode inherited from BaseTool.
        Output: JSON object {"file": String, "summary": {"covered": Integer, "total": Integer, "percentage": Float}, "stale": String|False}.
        Examples: "What is the coverage for lib/cov_loupe/tools/all_files_coverage_tool.rb?".
      DESC
      input_schema(**input_schema_def)
      class << self
        def call(path:, root: nil, resultset: nil, staleness: nil, error_mode: 'log',
          server_context:)
          with_error_handling('CoverageSummaryTool', error_mode: error_mode) do
            config = model_config_for(
              server_context: server_context,
              root: root,
              resultset: resultset,
              staleness: staleness&.to_sym
            )
            model = CoverageModel.new(**config)
            presenter = Presenters::CoverageSummaryPresenter.new(model: model, path: path)
            respond_json(presenter.relativized_payload, name: 'coverage_summary.json', pretty: true)
          end
        end
      end
    end
  end
end
