# frozen_string_literal: true

require_relative 'base_command'
require_relative '../presenters/coverage_raw_presenter'

module SimpleCovMcp
  module Commands
    class RawCommand < BaseCommand
      def execute(args)
        handle_with_path(args, 'raw') do |path|
          presenter = Presenters::CoverageRawPresenter.new(model: model, path: path)
          data = presenter.absolute_payload
          break if maybe_output_json(data, model)
          relative_path = presenter.relative_path
          puts "File: #{relative_path}"
          puts data['lines'].inspect
        end
      end
    end
  end
end
