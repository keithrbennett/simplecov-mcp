# frozen_string_literal: true

require 'stringio'
require_relative '../cli'
require_relative '../base_tool'

module SimpleCovMcp
  module Tools
    class CoverageTableTool < BaseTool
      description 'Returns the coverage summary table as a formatted string'
      input_schema(
        type: 'object',
        properties: {
          root: { type: 'string', description: 'Project root for resolution', default: '.' },
          resultset: { type: 'string', description: 'Path to .resultset.json (absolute or relative to root)' },
          sort_order: { type: 'string', description: 'Sort order for coverage percentage: ascending or descending', default: 'ascending', enum: ['ascending', 'descending'] },
          stale: { type: 'string', description: 'Staleness mode: off|error', enum: ['off', 'error'] }
        }
      )

      class << self
        def call(root: '.', resultset: nil, sort_order: 'ascending', stale: 'off', server_context:)
          # Capture the output of the CLI's table report
          output = StringIO.new
          cli = CoverageCLI.new
          cli.show_default_report(sort_order: sort_order.to_sym, output: output)
          ::MCP::Tool::Response.new([{ type: 'text', text: output.string }])
        rescue => e
          handle_mcp_error(e, 'CoverageTableTool')
        end
      end
    end
  end
end