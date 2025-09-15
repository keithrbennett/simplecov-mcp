# frozen_string_literal: true

module Simplecov
  module Mcp
    class CoverageSummary < BaseTool
      description "Return {covered,total,pct} for a file"
      input_schema(**input_schema_def)
      class << self
        def call(path:, root: ".", resultset: nil, server_context:)
          model = CoverageModel.new(root: root, resultset: resultset)
          data = model.summary_for(path)
          ::MCP::Tool::Response.new([{ type: "json", json: data }],
                              meta: { mimeType: "application/json" })
        rescue => e
          CovUtil.log("CoverageSummary error: #{e.class}: #{e.message}")
          ::MCP::Tool::Response.new([{ type: "text", text: "Error: #{e.class}: #{e.message}" }])
        end
      end
    end
  end
end
