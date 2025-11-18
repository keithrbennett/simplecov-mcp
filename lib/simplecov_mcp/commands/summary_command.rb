# frozen_string_literal: true

require_relative 'base_command'
require_relative '../presenters/coverage_summary_presenter'

module SimpleCovMcp
  module Commands
    class SummaryCommand < BaseCommand
      def execute(args)
        handle_with_path(args, 'summary') do |path|
          presenter = Presenters::CoverageSummaryPresenter.new(model: model, path: path)
          data = presenter.absolute_payload
          break if emit_json_with_optional_source(data, model, path)

          relative_path = presenter.relative_path
          summary = data['summary']
          printf "%8.2f%%  %6d/%-6d  %s\n\n", summary['percentage'], summary['covered'], summary['total'],
            relative_path
          print_source_for(model, path) if config.source_mode
        end
      end
    end
  end
end
