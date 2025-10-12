# frozen_string_literal: true

require 'json'
require_relative 'base_command'

module SimpleCovMcp
  module Commands
    class VersionCommand < BaseCommand
      def execute(args)
        if config.json
          puts JSON.pretty_generate({ version: SimpleCovMcp::VERSION })
        else
          puts "SimpleCovMcp version #{SimpleCovMcp::VERSION}"
        end
      end
    end
  end
end