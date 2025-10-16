# frozen_string_literal: true

require_relative 'base_command'
require_relative '../formatters/source_formatter'
require_relative '../presenters/coverage_detailed_presenter'

module SimpleCovMcp
  module Commands
    class DetailedCommand < BaseCommand
      def execute(args)
        handle_with_path(args, 'detailed') do |path|
          presenter = Presenters::CoverageDetailedPresenter.new(model: model, path: path)
          data = presenter.absolute_payload
          break if emit_json_with_optional_source(data, model, path)

          relative_path = presenter.relative_path
          puts "File: #{relative_path}"
          puts source_formatter.format_detailed_rows(data['lines'])
          print_source_for(model, path) if config.source_mode
        end
      end
    end
  end
end
