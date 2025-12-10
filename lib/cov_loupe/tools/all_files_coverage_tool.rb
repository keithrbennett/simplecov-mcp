# frozen_string_literal: true

require_relative '../model'
require_relative '../base_tool'
require_relative '../presenters/project_coverage_presenter'

module CovLoupe
  module Tools
    class AllFilesCoverageTool < BaseTool
      description <<~DESC
        Use this when the user wants coverage percentages for every tracked file in the project.
        Do not use this for single-file stats; prefer coverage.summary or coverage.uncovered_lines for that.
        Inputs: optional project root, alternate .resultset path, sort order, staleness mode, and tracked_globs to alert on new files.
        Output: JSON {"files": [{"file","covered","total","percentage","stale"}, ...], "counts": {"total", "ok", "stale"}} sorted as requested. "stale" is a string ('M', 'T', 'L') or false.
        Examples: "List files with the lowest coverage"; "Show repo coverage sorted descending".
      DESC
      input_schema(**coverage_schema(
        additional_properties: {
          sort_order: {
            type: 'string',
            description: 'Sort order for coverage percentages.' \
                         "'ascending' highlights the riskiest files first.",
            default: 'ascending',
            enum: ['ascending', 'descending']
          },
          tracked_globs: TRACKED_GLOBS_PROPERTY
        }
      ))
      class << self
        def call(root: nil, resultset: nil, sort_order: nil, staleness: nil,
          tracked_globs: nil, error_mode: 'log', server_context:)
          with_error_handling('AllFilesCoverageTool', error_mode: error_mode) do
            config = model_config_for(
              server_context: server_context,
              root: root,
              resultset: resultset,
              staleness: staleness&.to_sym,
              tracked_globs: tracked_globs
            )
            model = CoverageModel.new(**config)

            # Convert string inputs from MCP to symbols for internal use
            sort_order_sym = (sort_order || 'ascending').to_sym
            staleness_sym = config[:staleness]

            presenter = Presenters::ProjectCoveragePresenter.new(
              model: model,
              sort_order: sort_order_sym,
              check_stale: (staleness_sym == :error),
              tracked_globs: config[:tracked_globs]
            )
            respond_json(presenter.relativized_payload, name: 'all_files_coverage.json')
          end
        end
      end
    end
  end
end
