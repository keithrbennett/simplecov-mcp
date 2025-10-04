# frozen_string_literal: true

require_relative '../base_tool'
require_relative '../model'

module SimpleCovMcp
  module Tools
    class CoverageDetailedTool < BaseTool
      description <<~DESC
        Use this when the user needs per-line coverage data for a single file.
        Do not use this for high-level counts; coverage.summary is cheaper for aggregate numbers.
        Inputs: file path (required) plus optional root/resultset/stale mode inherited from BaseTool.
        Output: JSON object with "file", "lines" => [{"line": 12, "hits": 0, "covered": false}], plus "summary" with totals.
        Example: "Show detailed coverage for lib/simple_cov_mcp/model.rb".
      DESC
      input_schema(**input_schema_def)
      class << self
        def call(path:, root: '.', resultset: nil, stale: 'off', error_mode: 'on', server_context:)
          mode = stale
          model = CoverageModel.new(root: root, resultset: resultset, staleness: mode)
          data = model.detailed_for(path)
          respond_json(model.relativize(data), name: 'coverage_detailed.json', pretty: true)
        rescue => e
          handle_mcp_error(e, 'CoverageDetailedTool', error_mode: error_mode)
        end
      end
    end
  end
end
