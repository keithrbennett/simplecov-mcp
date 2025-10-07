# frozen_string_literal: true

require_relative 'base_command'
require_relative '../formatters/source_formatter'

module SimpleCovMcp
  module Commands
    class DetailedCommand < BaseCommand
      def execute(args)
        handle_with_path(args, 'detailed') do |path|
          data = model.detailed_for(path)
          break if emit_json_with_optional_source(data, model, path)
          rel = model.relativize(data)['file']
          puts "File: #{rel}"
          puts source_formatter.format_detailed_rows(data['lines'])
          print_source_for(model, path) if config.source_mode
        end
      end

      private

      def source_formatter
        @source_formatter ||= Formatters::SourceFormatter.new(
          color_enabled: config.color
        )
      end
    end
  end
end