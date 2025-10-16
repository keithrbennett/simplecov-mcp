# frozen_string_literal: true

require_relative 'base_command'
require_relative '../presenters/coverage_uncovered_presenter'

module SimpleCovMcp
  module Commands
    class UncoveredCommand < BaseCommand
      def execute(args)
        handle_with_path(args, 'uncovered') do |path|
          presenter = Presenters::CoverageUncoveredPresenter.new(model: model, path: path)
          data = presenter.absolute_payload
          break if emit_json_with_optional_source(data, model, path)

          relative_path = presenter.relative_path
          puts "File:            #{relative_path}"
          puts "Uncovered lines: #{data['uncovered'].join(', ')}"
          summary = data['summary']
          printf "Summary:      %8.2f%%  %6d/%-6d\n\n", summary['pct'], summary['covered'], summary['total']
          print_source_for(model, path) if config.source_mode
        end
      end
    end
  end
end
