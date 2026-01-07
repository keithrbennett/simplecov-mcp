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
        Output: text block containing the formatted coverage table with headers and percentages, plus
        any exclusions summary (missing/stale/deleted files) and skipped row warnings, exactly as the CLI displays.
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

            # Create presenter to access file summaries and exclusion data
            presenter = Presenters::ProjectCoveragePresenter.new(
              model: model,
              sort_order: sort_order_sym,
              raise_on_stale: config[:raise_on_stale],
              tracked_globs: config[:tracked_globs]
            )

            # Format the table with file summaries
            file_summaries = presenter.relative_files
            table = model.format_table(
              file_summaries,
              sort_order: sort_order_sym,
              raise_on_stale: config[:raise_on_stale],
              tracked_globs: nil
            )

            # Append exclusions summary (matching CLI behavior)
            exclusions = format_exclusions_summary(presenter)
            table += exclusions unless exclusions.empty?

            # Append skipped rows warning (matching CLI behavior)
            skipped_warning = format_skipped_rows_warning(model)
            table += skipped_warning unless skipped_warning.empty?

            # Return text response
            ::MCP::Tool::Response.new([{ 'type' => 'text', 'text' => table }])
          end
        end

        private def format_exclusions_summary(presenter)
          missing = presenter.relative_missing_tracked_files
          newer = presenter.relative_newer_files
          deleted = presenter.relative_deleted_files
          length_mismatch = presenter.relative_length_mismatch_files
          unreadable = presenter.relative_unreadable_files
          skipped = presenter.relative_skipped_files

          # Only format if there are any exclusions
          return '' if missing.empty? && newer.empty? && deleted.empty? &&
                       length_mismatch.empty? && unreadable.empty? && skipped.empty?

          output = ["\nFiles excluded from coverage:"]

          unless missing.empty?
            output << "\nMissing tracked files (#{missing.length}):"
            missing.each { |file| output << "  - #{file}" }
          end

          unless newer.empty?
            output << "\nFiles newer than coverage (#{newer.length}):"
            newer.each { |file| output << "  - #{file}" }
          end

          unless deleted.empty?
            output << "\nDeleted files with coverage (#{deleted.length}):"
            deleted.each { |file| output << "  - #{file}" }
          end

          unless length_mismatch.empty?
            output << "\nLine count mismatches (#{length_mismatch.length}):"
            length_mismatch.each { |file| output << "  - #{file}" }
          end

          unless unreadable.empty?
            output << "\nUnreadable files (#{unreadable.length}):"
            unreadable.each { |file| output << "  - #{file}" }
          end

          unless skipped.empty?
            output << "\nFiles skipped due to errors (#{skipped.length}):"
            skipped.each do |row|
              output << "  - #{row['file']}: #{row['error']}"
            end
          end

          output << "\nRun with --raise-on-stale to exit when files are excluded."
          output.join("\n")
        end

        # Formats the skipped rows warning matching CLI warn_skipped_rows behavior
        private def format_skipped_rows_warning(model)
          skipped = model.skipped_rows
          return '' if skipped.nil? || skipped.empty?

          count = skipped.length
          output = [
            '',
            "WARNING: #{count} coverage row#{count == 1 ? '' : 's'} skipped due to errors:"
          ]
          skipped.each do |row|
            relative_path = model.relativizer.relativize_path(row['file'])
            output << "  - #{relative_path}: #{row['error']}"
          end
          output << 'Run again with --raise-on-stale to exit when rows are skipped.'
          output.join("\n")
        end
      end
    end
  end
end
