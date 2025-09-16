# frozen_string_literal: true

require_relative '../base_tool'
require_relative '../model'

module SimpleCov
  module Mcp
    class CoverageSummaryTool < BaseTool
      description 'Return {covered,total,pct} for a file'
      input_schema(**input_schema_def)
      class << self
        def call(path:, root: '.', resultset: nil, server_context:)
          model = CoverageModel.new(root: root, resultset: resultset)
          data = model.summary_for(path)
          ::MCP::Tool::Response.new([{ type: 'json', json: data }],
                              meta: { mimeType: 'application/json' })
        rescue => e
          handle_mcp_error(e, 'CoverageSummaryTool')
        end
      end
    end
  end
end
