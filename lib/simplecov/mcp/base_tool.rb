# frozen_string_literal: true

module Simplecov
  module Mcp
    class BaseTool < ::MCP::Tool
      INPUT_SCHEMA = {
        type: "object",
        properties: {
          path: { type: "string", description: "Absolute or project-relative file path" },
          root: { type: "string", description: "Project root for resolution", default: "." }
        },
        required: ["path"]
      }
      def self.input_schema_def = INPUT_SCHEMA
    end
  end
end

