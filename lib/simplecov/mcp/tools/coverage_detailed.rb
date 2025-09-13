# frozen_string_literal: true

module Simplecov
  module Mcp
    class CoverageDetailed < BaseTool
      description "Verbose per-line objects [{line,hits,covered}] (token-heavy)"
      input_schema(**input_schema_def)
      class << self
        def call(path:, root: ".", server_context:)
          model = CoverageModel.new(root: root)
          data = model.detailed_for(path)
          ::MCP::Tool::Response.new([{ type: "json", json: data }],
                              meta: { mimeType: "application/json" })
        rescue => e
          CovUtil.log("CoverageDetailed error: #{e.class}: #{e.message}")
          ::MCP::Tool::Response.new([{ type: "text", text: "Error: #{e.class}: #{e.message}" }])
        end
      end
    end
  end
end

