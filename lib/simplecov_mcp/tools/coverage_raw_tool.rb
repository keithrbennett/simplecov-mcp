# frozen_string_literal: true

require_relative '../base_tool'
require_relative '../model'

module SimpleCovMcp
  module Tools
    class CoverageRawTool < BaseTool
      description <<~DESC
        Use this when you need the raw SimpleCov `lines` array for a file exactly as stored on disk.
        Do not use this for human-friendly explanations; choose coverage.detailed or coverage.summary instead.
        Inputs: file path (required) plus optional root/resultset/stale mode inherited from BaseTool.
        Output: JSON object with "file" and "lines" (array of integers/nulls) mirroring SimpleCov's native structure, plus "stale" status.
        Example: "Fetch the raw coverage array for spec/support/foo_helper.rb".
      DESC
      input_schema(**input_schema_def)
      class << self
        def call(path:, root: '.', resultset: nil, stale: 'off', error_mode: 'on', server_context:)
          mode = stale
          model = CoverageModel.new(root: root, resultset: resultset, staleness: mode)
          data = model.raw_for(path)
          data['stale'] = model.staleness_for(path)
          respond_json(model.relativize(data), name: 'coverage_raw.json', pretty: true)
        rescue => e
          handle_mcp_error(e, 'CoverageRawTool', error_mode: error_mode)
        end
      end
    end
  end
end
