# frozen_string_literal: true

require_relative 'base_command'
require_relative '../presenters/project_totals_presenter'
require_relative '../table_formatter'

module SimpleCovMcp
  module Commands
    class TotalsCommand < BaseCommand
      def execute(args)
        unless args.empty?
          raise UsageError.for_subcommand('totals')
        end

        presenter = Presenters::ProjectTotalsPresenter.new(
          model: model,
          check_stale: (config.staleness == :error),
          tracked_globs: config.tracked_globs
        )
        payload = presenter.absolute_payload
        return if maybe_output_structured_format?(payload, model)

        lines = payload['lines']
        files = payload['files']

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

        puts TableFormatter.format(
          headers: headers,
          rows: rows,
          alignments: [:left, :right, :right, :right, :right]
        )
      end
    end
  end
end
