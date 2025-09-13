# frozen_string_literal: true

module Simplecov
  module Mcp
    class AllFilesCoverage < ::MCP::Tool
      description "Return coverage percentage for all files in the project"
      input_schema(
        type: "object",
        properties: {
          root: { type: "string", description: "Project root for resolution", default: "." },
          sort_order: { type: "string", description: "Sort order for coverage percentage: ascending or descending", default: "ascending", enum: ["ascending", "descending"] }
        }
      )
      class << self
        def call(root: ".", sort_order: "ascending", server_context:)
          model = CoverageModel.new(root: root)
          files = model.all_files(sort_order: sort_order)
          ::MCP::Tool::Response.new([{ type: "json", json: { files: files } }],
                              meta: { mimeType: "application/json" })
        rescue => e
          CovUtil.log("AllFilesCoverage error: #{e.class}: #{e.message}")
          ::MCP::Tool::Response.new([{ type: "text", text: "Error: #{e.class}: #{e.message}" }])
        end
      end
    end
  end
end

