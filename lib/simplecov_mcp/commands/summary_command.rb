# frozen_string_literal: true

require_relative 'base_command'

module SimpleCovMcp
  module Commands
    class SummaryCommand < BaseCommand
      def execute(args)
        handle_with_path(args, 'summary') do |path|
          data = model.summary_for(path)
          break if emit_json_with_optional_source(data, model, path)
          rel = model.relativize(data)['file']
          s = data['summary']
          printf "%8.2f%%  %6d/%-6d  %s\n\n", s['pct'], s['covered'], s['total'], rel
          print_source_for(model, path) if cli.instance_variable_get(:@source_mode)
        end
      end
    end
  end
end