# frozen_string_literal: true


require_relative '../base_tool'
require_relative '../presenters/project_coverage_presenter'
require_relative '../option_normalizers'

module CovLoupe
  module Tools
    class CoverageTableTool < BaseTool
      description <<~DESC
        Use this when a user wants the plain text coverage table exactly like `cov-loupe --table` would print (no ANSI colors).
        Do not use this for machine-readable data; coverage.list returns structured JSON.
        Inputs: optional project root/resultset path/sort order/raise_on_stale flag matching the CLI flags.
        Output: text block containing the formatted coverage table with headers and percentages.
        Example: "Show me the CLI coverage table sorted descending".
      DESC
      input_schema(**coverage_schema(
        additional_properties: {
          sort_order: SORT_ORDER_PROPERTY,
          tracked_globs: TRACKED_GLOBS_PROPERTY
        }
      ))
      class << self
        def call(root: nil, resultset: nil, sort_order: nil, raise_on_stale: nil,
          tracked_globs: nil, error_mode: 'log', server_context:)
          with_error_handling('CoverageTableTool', error_mode: error_mode) do
            model, config = create_configured_model(
              server_context: server_context,
              root: root,
              resultset: resultset,
              raise_on_stale: raise_on_stale,
              tracked_globs: tracked_globs
            )

            # Normalize and validate sort_order (supports 'a'/'d' abbreviations)
            sort_order_sym = OptionNormalizers.normalize_sort_order(
              sort_order || BaseTool::DEFAULT_SORT_ORDER, strict: true
            )

            table = model.format_table(
              sort_order: sort_order_sym,
              raise_on_stale: config[:raise_on_stale],
              tracked_globs: config[:tracked_globs]
            )
            # Return text response
            ::MCP::Tool::Response.new([{ 'type' => 'text', 'text' => table }])
          end
        end
      end
    end
  end
end
