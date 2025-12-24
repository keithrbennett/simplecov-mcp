# frozen_string_literal: true

require_relative '../model'
require_relative '../base_tool'
require_relative '../presenters/project_coverage_presenter'

module CovLoupe
  module Tools
    class ListTool < BaseTool
      description <<~DESC
        Use this when the user wants coverage percentages for every tracked file in the project.
        Do not use this for single-file stats; prefer coverage.summary or coverage.uncovered_lines for that.
        Inputs: optional project root, alternate .resultset path, sort order, raise_on_stale flag, and tracked_globs to alert on new files.
        Output: JSON {"files": [{"file","covered","total","percentage","stale"}, ...], "counts": {"total", "ok", "stale"}} sorted as requested. "stale" is a string ('M', 'T', 'L') or false.
        Examples: "List files with the lowest coverage"; "Show repo coverage sorted descending".
      DESC
      input_schema(**coverage_schema(
        additional_properties: {
          sort_order: {
            type: 'string',
            description: 'Sort order for coverage percentages. ' \
                         "'descending' (default) lists highest coverage first.",
            default: 'descending',
            enum: ['ascending', 'descending']
          },
          tracked_globs: TRACKED_GLOBS_PROPERTY
        }
      ))
      class << self
        def call(root: nil, resultset: nil, sort_order: nil, raise_on_stale: nil,
          tracked_globs: nil, error_mode: 'log', server_context:)
          with_error_handling('ListTool', error_mode: error_mode) do
            model, config = create_configured_model(
              server_context: server_context,
              root: root,
              resultset: resultset,
              raise_on_stale: raise_on_stale,
              tracked_globs: tracked_globs
            )

            # Convert string inputs from MCP to symbols for internal use
            sort_order_sym = (sort_order || 'descending').to_sym

            presenter = Presenters::ProjectCoveragePresenter.new(
              model: model,
              sort_order: sort_order_sym,
              raise_on_stale: config[:raise_on_stale],
              tracked_globs: config[:tracked_globs]
            )
            respond_json(presenter.relativized_payload, name: 'list_coverage.json')
          end
        end
      end
    end
  end
end
