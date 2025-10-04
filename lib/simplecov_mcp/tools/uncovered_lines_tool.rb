# frozen_string_literal: true

require_relative '../base_tool'
require_relative '../model'

module SimpleCovMcp
  module Tools
    class UncoveredLinesTool < BaseTool
      description <<~DESC
        Use this when the user wants to know which lines in a file still lack coverage.
        Do not use this for overall percentages; coverage.summary is faster when counts are enough.
        Inputs: file path (required) plus optional root/resultset/stale mode inherited from BaseTool.
        Output: JSON object with keys "file", "uncovered" (array of integers), and "summary" {"covered","total","pct"}.
        Example: "List uncovered lines for lib/simple_cov_mcp/tools/coverage_summary_tool.rb".
      DESC
      input_schema(**input_schema_def)
      class << self
        def call(path:, root: '.', resultset: nil, stale: 'off', error_mode: 'on', server_context:)
          mode = stale
          model = CoverageModel.new(root: root, resultset: resultset, staleness: mode)
          data = model.uncovered_for(path)
          respond_json(model.relativize(data), name: 'uncovered_lines.json', pretty: true)
        rescue => e
          handle_mcp_error(e, 'UncoveredLinesTool', error_mode: error_mode)
        end
      end
    end
  end
end
