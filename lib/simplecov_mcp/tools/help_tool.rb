# frozen_string_literal: true

require_relative '../base_tool'

module SimpleCovMcp
  module Tools
    class HelpTool < BaseTool
      description <<~DESC
        Returns help containing descriptions of all tools, including: use_when, avoid_when, inputs.
      DESC

      input_schema(
        type: 'object',
        additionalProperties: false,
        properties: {
          error_mode: {
            type: 'string',
            description:
              "Error handling mode: 'off' (silent), 'on' (log errors), 'trace' (verbose).",
            enum: ['off', 'on', 'trace'],
            default: 'on'
          }
        }
      )

      TOOL_GUIDE = [
        {
          tool: CoverageSummaryTool,
          label: 'Single-file coverage summary',
          use_when: 'User wants covered/total line counts or percentage for one file.',
          avoid_when: 'User needs repo-wide stats or specific uncovered lines.',
          inputs: ['path (required)', 'root/resultset/staleness (optional)']
        },
        {
          tool: UncoveredLinesTool,
          label: 'Uncovered line numbers',
          use_when: 'User asks which lines in a file still lack tests.',
          avoid_when: 'User only wants overall percentages or detailed per-line hit data.',
          inputs: ['path (required)', 'root/resultset/staleness (optional)']
        },
        {
          tool: CoverageDetailedTool,
          label: 'Per-line coverage details',
          use_when: 'User needs per-line hit counts for a file.',
          avoid_when: 'User only wants totals or uncovered line numbers.',
          inputs: ['path (required)', 'root/resultset/staleness (optional)']
        },
        {
          tool: CoverageRawTool,
          label: 'Raw SimpleCov lines array',
          use_when: 'User needs the raw SimpleCov `lines` array for a file.',
          avoid_when: 'User expects human-friendly summaries or explanations.',
          inputs: ['path (required)', 'root/resultset/staleness (optional)']
        },
        {
          tool: AllFilesCoverageTool,
          label: 'Repo-wide file coverage',
          use_when: 'User wants coverage percentages for every tracked file.',
          avoid_when: 'User asks about a single file.',
          inputs: ['root/resultset (optional)', 'sort_order', 'staleness', 'tracked_globs']
        },
        {
          tool: CoverageTotalsTool,
          label: 'Project coverage totals',
          use_when: 'User wants total/covered/uncovered line counts or the average percent.',
          avoid_when: 'User needs per-file breakdowns.',
          inputs: ['root/resultset (optional)', 'staleness', 'tracked_globs']
        },
        {
          tool: CoverageTableTool,
          label: 'Formatted coverage table',
          use_when: 'User wants the plain-text table produced by the CLI.',
          avoid_when: 'User needs JSON data for automation.',
          inputs: ['root/resultset (optional)', 'sort_order', 'staleness']
        },
        {
          tool: ValidateTool,
          label: 'Validate coverage policy',
          use_when: 'User needs to enforce coverage rules (e.g., minimum percentage) in CI.',
          avoid_when: 'User just wants to view coverage data.',
          inputs: ['path (required)', 'root/resultset (optional)']
        },
        {
          tool: VersionTool,
          label: 'simplecov-mcp version',
          use_when: 'User needs to confirm the running gem version.',
          avoid_when: 'User is asking for coverage information.',
          inputs: ['(no arguments)']
        }
      ].freeze

      class << self
        def call(error_mode: 'on', server_context:, **_unused)
          with_error_handling('HelpTool', error_mode: error_mode) do
            entries = TOOL_GUIDE.map { |guide| format_entry(guide) }

            data = { tools: entries }
            respond_json(data, name: 'tools_help.json')
          end
        end

        private

        def format_entry(guide)
          {
            'tool' => guide[:tool].tool_name,
            'label' => guide[:label],
            'use_when' => guide[:use_when],
            'avoid_when' => guide[:avoid_when],
            'inputs' => guide[:inputs]
          }
        end
      end
    end
  end
end
