# frozen_string_literal: true

require_relative '../base_tool'
require_relative '../model'
require_relative '../presenters/coverage_payload_presenter'

module CovLoupe
  module Tools
    class UncoveredLinesTool < BaseTool
      description <<~DESC
        Use this when the user wants to know which lines in a file still lack coverage.
        Do not use this for overall percentages; coverage.summary is faster when counts are enough.
        Inputs: file path (required) plus optional root/resultset/raise_on_stale flag inherited from BaseTool.
        Output: JSON object with keys "file", "uncovered" (array of integers), "summary" {"covered","total","percentage"}, and "stale" status.
        Example: "List uncovered lines for lib/cov_loupe/tools/coverage_summary_tool.rb".
      DESC
      input_schema(**input_schema_def)
      class << self
        def call(path:, root: nil, resultset: nil, raise_on_stale: nil, error_mode: 'log',
          server_context:)
          call_with_file_payload(
            path: path,
            error_mode: error_mode,
            server_context: server_context,
            root: root,
            resultset: resultset,
            raise_on_stale: raise_on_stale
          )
        end
      end
    end
  end
end
