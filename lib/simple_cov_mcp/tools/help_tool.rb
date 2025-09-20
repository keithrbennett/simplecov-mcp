# frozen_string_literal: true

require_relative '../base_tool'

module SimpleCovMcp
  module Tools
    class HelpTool < BaseTool
      description <<~DESC
        Use this when you are unsure which simplecov-mcp tool fits the user’s coverage request.
        Do not use this once you know the correct tool; call that tool directly.
        Inputs: optional query string to filter the list of tools.
        Output: JSON {"tools": [...]} with per-tool "use_when", "avoid_when", "inputs", and "example" guidance.
        Example: "Which tool shows uncovered lines?".
      DESC

      input_schema(
        type: 'object',
        additionalProperties: false,
        properties: {
          query: {
            type: 'string',
            description: 'Optional keywords to filter the help entries (e.g., "uncovered", "summary").'
          }
        }
      )

      TOOL_GUIDE = [
        {
          tool: CoverageSummaryTool,
          label: 'Single-file coverage summary',
          use_when: 'User wants covered/total line counts or percentage for one file.',
          avoid_when: 'User needs repo-wide stats or specific uncovered lines.',
          inputs: ['path (required)', 'root/resultset/stale (optional)'],
          example: 'What is the coverage for lib/simple_cov_mcp/model.rb?'
        },
        {
          tool: UncoveredLinesTool,
          label: 'Uncovered line numbers',
          use_when: 'User asks which lines in a file still lack tests.',
          avoid_when: 'User only wants overall percentages or detailed per-line hit data.',
          inputs: ['path (required)', 'root/resultset/stale (optional)'],
          example: 'List uncovered lines for lib/simple_cov_mcp/tools/coverage_summary_tool.rb.'
        },
        {
          tool: CoverageDetailedTool,
          label: 'Per-line coverage details',
          use_when: 'User needs per-line hit counts for a file.',
          avoid_when: 'User only wants totals or uncovered line numbers.',
          inputs: ['path (required)', 'root/resultset/stale (optional)'],
          example: 'Show detailed coverage for lib/simple_cov_mcp/util.rb.'
        },
        {
          tool: CoverageRawTool,
          label: 'Raw SimpleCov lines array',
          use_when: 'User needs the raw SimpleCov `lines` array for a file.',
          avoid_when: 'User expects human-friendly summaries or explanations.',
          inputs: ['path (required)', 'root/resultset/stale (optional)'],
          example: 'Fetch the raw coverage array for spec/support/helpers.rb.'
        },
        {
          tool: AllFilesCoverageTool,
          label: 'Repo-wide file coverage',
          use_when: 'User wants coverage percentages for every tracked file.',
          avoid_when: 'User asks about a single file.',
          inputs: ['root/resultset (optional)', 'sort_order', 'stale', 'tracked_globs'],
          example: 'List files with the lowest coverage.'
        },
        {
          tool: CoverageTableTool,
          label: 'Formatted coverage table',
          use_when: 'User wants the plain-text table produced by the CLI.',
          avoid_when: 'User needs JSON data for automation.',
          inputs: ['root/resultset (optional)', 'sort_order', 'stale'],
          example: 'Show me the coverage table sorted descending.'
        },
        {
          tool: VersionTool,
          label: 'simplecov-mcp version',
          use_when: 'User needs to confirm the running gem version.',
          avoid_when: 'User is asking for coverage information.',
          inputs: ['(no arguments)'],
          example: 'What version of simplecov-mcp is installed?'
        }
      ].freeze

      class << self
        def call(query: nil, server_context:, **_unused)
          entries = TOOL_GUIDE.map { |guide| format_entry(guide) }
          entries = filter_entries(entries, query) if query && !query.strip.empty?

          data = { query: query, tools: entries }
          ::MCP::Tool::Response.new(
            [{ type: 'json', json: data }],
            meta: { mimeType: 'application/json' }
          )
        rescue => e
          handle_mcp_error(e, 'HelpTool')
        end

        private

        def format_entry(guide)
          {
            'tool' => guide[:tool].tool_name,
            'label' => guide[:label],
            'use_when' => guide[:use_when],
            'avoid_when' => guide[:avoid_when],
            'inputs' => guide[:inputs],
            'example' => guide[:example]
          }
        end

        def filter_entries(entries, query)
          tokens = query.downcase.scan(/\w+/)
          return entries if tokens.empty?

          entries.select do |entry|
            tokens.all? do |token|
              entry.any? { |_, value| value_matches?(value, token) }
            end
          end
        end

        def value_matches?(value, token)
          case value
          when String
            value.downcase.include?(token)
          when Array
            value.any? { |element| element.downcase.include?(token) }
          else
            false
          end
        end
      end
    end
  end
end
