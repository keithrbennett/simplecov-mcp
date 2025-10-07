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
          },
          error_mode: {
            type: 'string',
            description: "Error handling mode: 'off' (silent), 'on' (log errors), 'on_with_trace' (verbose).",
            enum: ['off', 'on', 'on_with_trace'],
            default: 'on'
          }
        }
      )

      class << self
        def call(root: '.', resultset: nil, sort_order: 'ascending', stale: 'off', error_mode: 'on', server_context:)
          # Capture the output of the CLI's table report while honoring CLI options
          # Convert string inputs from MCP to symbols for internal use
          sort_order_sym = sort_order.to_sym
          stale_sym = stale.to_sym

          output = StringIO.new
          cli = CoverageCLI.new
          cli.config.root = root || '.'
          cli.config.resultset = resultset
          cli.config.stale_mode = stale_sym
          cli.show_default_report(sort_order: sort_order_sym, output: output)
          ::MCP::Tool::Response.new([{ type: 'text', text: output.string }])
        rescue => e
          handle_mcp_error(e, 'CoverageTableTool', error_mode: error_mode)
        end
      end
    end
  end
end
