# frozen_string_literal: true

require_relative 'base_command'

module SimpleCovMcp
  module Commands
    class VersionCommand < BaseCommand
      def execute(args)
        if cli.instance_variable_get(:@json)
          puts JSON.pretty_generate({ version: SimpleCovMcp::VERSION })
        else
          puts "SimpleCovMcp version #{SimpleCovMcp::VERSION}"
        end
      end
    end
  end
end