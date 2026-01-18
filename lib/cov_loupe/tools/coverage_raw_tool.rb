# frozen_string_literal: true

require_relative '../base_tool'
require_relative '../model/model'
require_relative '../presenters/coverage_payload_presenter'

module CovLoupe
  module Tools
    class CoverageRawTool < BaseTool
      description <<~DESC
        Use this when you need the raw SimpleCov `lines` array for a file exactly as stored on disk.
        Do not use this for human-friendly explanations; choose coverage.detailed or coverage.summary instead.
        Inputs: file path (required) plus optional root/resultset/raise_on_stale flag inherited from BaseTool.
        Output: JSON object with "file" and "lines" (array of integers/nulls) mirroring SimpleCov's native structure, plus "stale" status.
        Example: "Fetch the raw coverage array for spec/support/foo_helper.rb".
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
