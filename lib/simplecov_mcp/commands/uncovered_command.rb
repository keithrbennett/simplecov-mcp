# frozen_string_literal: true

require_relative 'base_command'

module SimpleCovMcp
  module Commands
    class UncoveredCommand < BaseCommand
      def execute(args)
        handle_with_path(args, 'uncovered') do |path|
          data = model.uncovered_for(path)
          break if emit_json_with_optional_source(data, model, path)
          relative_path = model.relativize(data)['file']
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
