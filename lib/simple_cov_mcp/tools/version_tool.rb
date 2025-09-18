# frozen_string_literal: true

require_relative '../base_tool'

module SimpleCovMcp
  module Tools
    class VersionTool < BaseTool
      description 'Get the SimpleCovMcp version'
      input_schema(
        type: 'object',
        properties: {}
      )

      class << self
        def call(server_context: nil, **_args)
          ::MCP::Tool::Response.new([
            { type: 'text', text: "SimpleCovMcp version: #{SimpleCovMcp::VERSION}" }
          ])
        rescue => error
          handle_mcp_error(error, 'version_tool')
        end
      end
    end
  end
end
