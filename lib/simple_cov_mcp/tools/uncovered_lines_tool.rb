# frozen_string_literal: true

require_relative '../base_tool'
require_relative '../model'

module SimpleCovMcp
  class UncoveredLinesTool < BaseTool
      description 'Return only uncovered executable line numbers plus a summary'
      input_schema(**input_schema_def)
      class << self
        def call(path:, root: '.', resultset: nil, server_context:)
          model = CoverageModel.new(root: root, resultset: resultset)
          data = model.uncovered_for(path)
          ::MCP::Tool::Response.new([{ type: 'json', json: data }],
                              meta: { mimeType: 'application/json' })
        rescue => e
          handle_mcp_error(e, 'UncoveredLinesTool')
        end
      end
  end
end
