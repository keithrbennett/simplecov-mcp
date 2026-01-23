# frozen_string_literal: true

require_relative '../model/model'
require_relative '../base_tool'
require_relative '../presenters/project_coverage_presenter'
require_relative '../config/option_normalizers'

module CovLoupe
  module Tools
    class ListTool < BaseTool
      description <<~DESC
        Use this when the user wants coverage percentages for every tracked file in the project.
        Do not use this for single-file stats; prefer coverage.summary or coverage.uncovered_lines for that.
        Inputs: optional project root, alternate .resultset path, sort order, raise_on_stale flag, and tracked_globs to alert on new files.
        Output: JSON {"files": [{"file","covered","total","percentage","stale"}, ...], "counts": {"total", "ok", "stale"}, "skipped_files": [...], "missing_tracked_files": [...], "newer_files": [...], "deleted_files": [...], "length_mismatch_files": [...], "unreadable_files": [...], "timestamp_status": "ok"|"missing", "warnings": [string, ...]} sorted as requested. "stale" is "ok", "missing", "newer", "length_mismatch", or "error". "timestamp_status" indicates whether coverage timestamps are available for time-based staleness checks. "warnings" array is present when timestamp_status is "missing".
        Examples: "List files with the lowest coverage"; "Show repo coverage sorted descending".
      DESC
      input_schema(**coverage_schema(
        additional_properties: {
          sort_order: SORT_ORDER_PROPERTY,
          tracked_globs: TRACKED_GLOBS_PROPERTY
        }
      ))
      class << self
        def call(root: nil, resultset: nil, sort_order: nil, raise_on_stale: nil,
          tracked_globs: nil, error_mode: 'log', output_chars: nil, server_context:)
          output_chars_sym = resolve_output_chars(output_chars, server_context)
          with_error_handling('ListTool', error_mode: error_mode, output_chars: output_chars_sym) do
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

            presenter = Presenters::ProjectCoveragePresenter.new(
              model: model,
              sort_order: sort_order_sym,
              raise_on_stale: config[:raise_on_stale],
              tracked_globs: config[:tracked_globs]
            )
            payload = presenter.relativized_payload

            # Add warnings array if timestamp_status is missing
            if payload['timestamp_status'] == 'missing'
              payload['warnings'] = [
                'Coverage timestamps are missing. Time-based staleness checks were skipped.',
                'Files may appear "ok" even if source code is newer than the coverage data.',
                'Check your coverage tool configuration to ensure timestamps are recorded.'
              ]
            end

            respond_json(payload, name: 'list_coverage.json', output_chars: output_chars_sym)
          end
        end
      end
    end
  end
end
