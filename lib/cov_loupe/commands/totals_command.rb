# frozen_string_literal: true

require_relative 'base_command'
require_relative '../presenters/project_totals_presenter'
require_relative '../formatters/table_formatter'

module CovLoupe
  module Commands
    class TotalsCommand < BaseCommand
      def execute(args)
        reject_extra_args(args, 'totals')

        presenter = Presenters::ProjectTotalsPresenter.new(
          model: model,
          raise_on_stale: config.raise_on_stale,
          tracked_globs: config.tracked_globs
        )
        payload = presenter.absolute_payload
        return if maybe_output_structured_format?(payload, model)

        lines = payload['lines']
        files = payload['files']
        tracking = payload['tracking']
        with_coverage = files['with_coverage']
        without_coverage = files['without_coverage']

        if tracking && tracking['enabled']
          puts 'Tracked globs:'
          tracking['globs'].each { |glob| puts "  - #{glob}" }
        else
          puts 'Tracked globs: (tracking disabled)'
        end
        puts

        puts 'Totals'
        headers = ['Metric', 'Total', 'Covered', 'Uncovered', '%']
        file_ok = with_coverage['ok']
        file_uncovered = files['total'] - file_ok
        percent_display = lines['percent_covered'].nil? ? 'n/a' : format('%.2f%%', lines['percent_covered'])
        rows = [
          [
            'Lines',
            lines['total'].to_s,
            lines['covered'].to_s,
            lines['uncovered'].to_s,
            percent_display
          ],
          [
            'Files',
            files['total'].to_s,
            file_ok.to_s,
            file_uncovered.to_s,
            ''
          ]
        ]

        puts TableFormatter.format(
          headers: headers,
          rows: rows,
          alignments: [:left, :right, :right, :right, :right],
          output_chars: config.output_chars
        )
        with_coverage_line = format_with_coverage_line(with_coverage)
        stale_line = format_stale_breakdown(with_coverage['stale']['by_type'])
        without_coverage_line, without_breakdown_line =
          format_without_coverage_lines(without_coverage)

        puts <<~BREAKDOWN

          File breakdown:
          #{with_coverage_line}
          #{stale_line}
          #{without_coverage_line}
          #{without_breakdown_line}
        BREAKDOWN

        warn_missing_timestamps(presenter)
      end

      private def format_with_coverage_line(with_coverage)
        stale = with_coverage['stale']
        "  With coverage: #{with_coverage['total']} total, #{with_coverage['ok']} ok, #{stale['total']} stale"
      end

      private def format_stale_breakdown(stale_by_type)
        '    Stale: missing on disk = ' \
          "#{stale_by_type['missing_from_disk']}, " \
          "newer than coverage = #{stale_by_type['newer']}, " \
          "line mismatch = #{stale_by_type['length_mismatch']}, " \
          "unreadable = #{stale_by_type['unreadable']}"
      end

      private def format_without_coverage_lines(without_coverage)
        return [nil, nil] unless without_coverage

        without_by_type = without_coverage['by_type']
        without_coverage_line = "  Without coverage: #{without_coverage['total']} total"
        without_breakdown_line = '    Missing from coverage = ' \
          "#{without_by_type['missing_from_coverage']}, " \
          "unreadable = #{without_by_type['unreadable']}, " \
          "skipped (errors) = #{without_by_type['skipped']}"
        [without_coverage_line, without_breakdown_line]
      end

      private def warn_missing_timestamps(presenter)
        return unless presenter.timestamp_status == 'missing'

        warn <<~WARNING

          WARNING: Coverage timestamps are missing. Time-based staleness checks were skipped.
          Files may appear "ok" even if source code is newer than the coverage data.
          Check your coverage tool configuration to ensure timestamps are recorded.
        WARNING
      end
    end
  end
end
