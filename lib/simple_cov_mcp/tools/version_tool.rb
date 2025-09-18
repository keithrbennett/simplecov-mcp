# frozen_string_literal: true

require_relative '../base_tool'

module SimpleCovMcp
  module Tools
    class VersionTool < BaseTool
      description <<~DESC
        Use this when the user or client needs to confirm which version of simplecov-mcp is running.
        This tool takes no arguments and only returns the version string; avoid it for coverage data.
        Output: plain text line "SimpleCovMcp version: x.y.z".
        Example: "What version of simplecov-mcp is installed?".
      DESC
      input_schema(
        type: 'object',
        additionalProperties: false,
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
