# frozen_string_literal: true

require_relative '../base_tool'
require_relative '../model'

module SimpleCovMcp
  class CoverageRawTool < BaseTool
      description "Return the original SimpleCov 'lines' array for a file"
      input_schema(**input_schema_def)
      class << self
        def call(path:, root: '.', resultset: nil, strict_staleness: nil, server_context:)
          strict = strict_staleness.nil? ? (ENV['SIMPLECOV_MCP_STRICT_STALENESS'] == '1') : strict_staleness
          model = CoverageModel.new(root: root, resultset: resultset, strict_staleness: strict)
          data = model.raw_for(path)
          ::MCP::Tool::Response.new([{ type: 'json', json: data }],
                              meta: { mimeType: 'application/json' })
        rescue => e
          handle_mcp_error(e, 'CoverageRawTool')
        end
      end
  end
end
