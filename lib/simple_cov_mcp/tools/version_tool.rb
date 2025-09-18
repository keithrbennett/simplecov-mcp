# frozen_string_literal: true

require_relative '../base_tool'

module SimpleCovMcp
  module Tools
    class VersionTool < BaseTool
      def self.name = 'version_tool'
      def self.description = 'Get the SimpleCovMcp version'

      def self.input_schema_def
        {
          type: 'object',
          properties: {},
          required: []
        }
      end

      input_schema(**input_schema_def)

      def self.call(server_context: nil, **_args)
        ::MCP::Tool::Response.new([
          { type: 'text', text: "SimpleCovMcp version: #{SimpleCovMcp::VERSION}" }
        ])
      rescue => error
        handle_mcp_error(error, 'version')
      end
    end
  end
end
