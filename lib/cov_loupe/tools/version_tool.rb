# frozen_string_literal: true

require_relative '../base_tool'

module CovLoupe
  module Tools
    class VersionTool < BaseTool
      description <<~DESC
        Use this when the user or client needs to confirm which version of cov-loupe is running.
        This tool takes no arguments and only returns the version string; avoid it for coverage data.
        Output: plain text line "CovLoupe version: x.y.z".
        Example: "What version of cov-loupe is installed?".
      DESC
      input_schema(
        type: 'object',
        additionalProperties: false,
        properties: {
          error_mode: ERROR_MODE_PROPERTY
        }
      )
      class << self
        def call(error_mode: 'log', server_context: nil, **_args)
          with_error_handling('VersionTool', error_mode: error_mode) do
            ::MCP::Tool::Response.new([
              { 'type' => 'text', 'text' => "CovLoupe version: #{CovLoupe::VERSION}" }
            ])
          end
        end
      end
    end
  end
end
