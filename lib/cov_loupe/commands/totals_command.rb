# frozen_string_literal: true

require_relative 'base_command'
require_relative '../presenters/project_totals_presenter'
require_relative '../table_formatter'

module CovLoupe
  module Commands
    class TotalsCommand < BaseCommand
      def execute(args)
        unless args.empty?
          raise UsageError.for_subcommand('totals')
        end

        presenter = Presenters::ProjectTotalsPresenter.new(
          model: model,
          raise_on_stale: config.raise_on_stale,
          tracked_globs: config.tracked_globs
        )
        payload = presenter.absolute_payload
        return if maybe_output_structured_format?(payload, model)

        lines = payload['lines']
        files = payload['files']
        excluded = payload['excluded_files']

        # Table format
        headers = ['Metric', 'Total', 'Covered', 'Uncovered', '%']
        rows = [
          [
            'Lines',
            lines['total'].to_s,
            lines['covered'].to_s,
            lines['uncovered'].to_s,
            format('%.2f%%', payload['percentage'])
          ],
          [
            'Files',
            files['total'].to_s,
            files['ok'].to_s,
            files['stale'].to_s,
            ''
          ]
        ]

        # Add excluded files rows if any exclusions exist
        total_excluded = excluded.values.sum
        if total_excluded > 0
          rows << [
            'Excluded',
            total_excluded.to_s,
            '',
            '',
            ''
          ]

          # Add breakdown rows for each exclusion type with non-zero count
          [
            ['  Skipped', excluded['skipped']],
            ['  Missing', excluded['missing_tracked']],
            ['  Newer', excluded['newer']],
            ['  Deleted', excluded['deleted']]
          ].each do |label, count|
            rows << [label, count.to_s, '', '', ''] if count > 0
          end
        end

        puts TableFormatter.format(
          headers: headers,
          rows: rows,
          alignments: [:left, :right, :right, :right, :right]
        )
      end
    end
  end
end
