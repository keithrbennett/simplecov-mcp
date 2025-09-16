# frozen_string_literal: true

require_relative '../base_tool'
require_relative '../model'

module SimpleCov
  module Mcp
    class CoverageDetailed < BaseTool
      description 'Verbose per-line objects [{line,hits,covered}] (token-heavy)'
      input_schema(**input_schema_def)
      class << self
        def call(path:, root: '.', resultset: nil, server_context:)
          model = CoverageModel.new(root: root, resultset: resultset)
          data = model.detailed_for(path)
          ::MCP::Tool::Response.new([{ type: 'json', json: data }],
                              meta: { mimeType: 'application/json' })
        rescue => e
          handle_mcp_error(e, 'CoverageDetailed')
        end
      end
    end
  end
end
