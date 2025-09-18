# frozen_string_literal: true

require 'stringio'
require_relative '../cli'
require_relative '../base_tool'

module SimpleCovMcp
  module Tools
    class CoverageTableTool < BaseTool
      description <<~DESC
        Use this when a user wants the plain text coverage table exactly like `simplecov-mcp --table` would print (no ANSI colors).
        Do not use this for machine-readable data; coverage.all_files returns structured JSON.
        Inputs: optional project root/resultset path/sort order/staleness mode matching the CLI flags.
        Output: text block containing the formatted coverage table with headers and percentages.
        Example: "Show me the CLI coverage table sorted descending".
      DESC
      input_schema(
        type: 'object',
        additionalProperties: false,
        properties: {
          root: {
            type: 'string',
            description: 'Project root used to resolve relative inputs.',
            default: '.'
          },
          resultset: {
            type: 'string',
            description: 'Path to the SimpleCov .resultset.json file.'
          },
          sort_order: {
            type: 'string',
            description: "Sort order for the printed coverage table (ascending or descending).",
            default: 'ascending',
            enum: ['ascending', 'descending']
          },
          stale: {
            type: 'string',
            description: "How to handle missing/outdated coverage data. 'off' skips checks; 'error' raises.",
            enum: ['off', 'error'],
            default: 'off'
          }
        }
      )

      class << self
        def call(root: '.', resultset: nil, sort_order: 'ascending', stale: 'off', server_context:)
          # Capture the output of the CLI's table report while honoring CLI options
          output = StringIO.new
          cli = CoverageCLI.new
          cli.instance_variable_set(:@root, root || '.')
          cli.instance_variable_set(:@resultset, resultset)
          cli.instance_variable_set(:@stale_mode, (stale || 'off').to_s)
          cli.show_default_report(sort_order: sort_order.to_sym, output: output)
          ::MCP::Tool::Response.new([{ type: 'text', text: output.string }])
        rescue => e
          handle_mcp_error(e, 'CoverageTableTool')
        end
      end
    end
  end
end
