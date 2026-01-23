# frozen_string_literal: true

require_relative '../base_tool'
require_relative '../model/model'
require_relative '../presenters/coverage_payload_presenter'

module CovLoupe
  module Tools
    class CoverageSummaryTool < BaseTool
      description <<~DESC
        Use this when the user asks for the covered/total line counts and percentage for a specific file.
        Do not use this for multi-file reports; coverage.list or coverage.table handle those.
        Inputs: file path (required) plus optional root/resultset/raise_on_stale flag inherited from BaseTool.
        Output: JSON object {"file": String, "summary": {"covered": Integer, "total": Integer, "percentage": Float}, "stale": String|False}.
        Examples: "What is the coverage for lib/cov_loupe/tools/list_tool.rb?".
      DESC
      input_schema(**input_schema_def)
      class << self
        def call(path:, root: nil, resultset: nil, raise_on_stale: nil, error_mode: 'log',
          output_chars: nil, server_context:)
          call_with_file_payload(
            path: path,
            error_mode: error_mode,
            output_chars: output_chars,
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
