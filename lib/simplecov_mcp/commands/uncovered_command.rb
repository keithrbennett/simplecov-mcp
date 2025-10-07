# frozen_string_literal: true

require_relative 'base_command'

module SimpleCovMcp
  module Commands
    class UncoveredCommand < BaseCommand
      def execute(args)
        handle_with_path(args, 'uncovered') do |path|
          data = model.uncovered_for(path)
          break if emit_json_with_optional_source(data, model, path)
          rel = model.relativize(data)['file']
          puts "File:            #{rel}"
          puts "Uncovered lines: #{data['uncovered'].join(', ')}"
          s = data['summary']
          printf "Summary:      %8.2f%%  %6d/%-6d\n\n", s['pct'], s['covered'], s['total']
          print_source_for(model, path) if config.source_mode
        end
      end
    end
  end
end