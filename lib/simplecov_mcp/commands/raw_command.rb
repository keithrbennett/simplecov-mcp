# frozen_string_literal: true

require_relative 'base_command'

module SimpleCovMcp
  module Commands
    class RawCommand < BaseCommand
      def execute(args)
        handle_with_path(args, 'raw') do |path|
          data = model.raw_for(path)
          break if maybe_output_json(data, model)
          relative_path = model.relativize(data)['file']
          puts "File: #{relative_path}"
          puts data['lines'].inspect
        end
      end
    end
  end
end
