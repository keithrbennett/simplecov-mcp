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
        Inputs: file path (required) plus optional root/resultset/raise_on_stale flag inherited from BaseTool.
        Output: JSON object with "file", "lines" => [{"line": 12, "hits": 0, "covered": false}], plus "summary" with totals and "stale" status.
        Example: "Show detailed coverage for lib/cov_loupe/model.rb".
      DESC
      input_schema(**input_schema_def)
      class << self
        def call(path:, root: nil, resultset: nil, raise_on_stale: nil, error_mode: 'log',
          server_context:)
          call_with_file_presenter(
            presenter_class: Presenters::CoverageDetailedPresenter,
            path: path,
            tool_name: 'CoverageDetailedTool',
            error_mode: error_mode,
            server_context: server_context,
            json_name: 'coverage_detailed.json',
            root: root,
            resultset: resultset,
            raise_on_stale: raise_on_stale
          )
        end
      end
    end
  end
end
