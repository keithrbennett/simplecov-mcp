# frozen_string_literal: true

require_relative 'base_command'
require_relative '../presenters/project_totals_presenter'

module SimpleCovMcp
  module Commands
    class TotalCommand < BaseCommand
      def execute(args)
        unless args.empty?
          raise UsageError.for_subcommand('total')
        end

        presenter = Presenters::ProjectTotalsPresenter.new(
          model: model,
          check_stale: (config.staleness == :error),
          tracked_globs: config.tracked_globs
        )
        payload = presenter.absolute_payload
        return if maybe_output_json(payload, model)

        lines = payload['lines']
        files = payload['files']

        printf "Lines: total %-8d covered %-8d uncovered %-8d\n",
          lines['total'], lines['covered'], lines['uncovered']
        printf "Average coverage: %6.2f%% across %d files (ok: %d, stale: %d)\n",
          payload['percentage'], files['total'], files['ok'], files['stale']
      end
    end
  end
end
