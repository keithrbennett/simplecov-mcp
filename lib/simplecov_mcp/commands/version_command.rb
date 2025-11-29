# frozen_string_literal: true

require 'json'
require_relative 'base_command'

module SimpleCovMcp
  module Commands
    class VersionCommand < BaseCommand
      def execute(args)
        @gem_root = File.expand_path('../../..', __dir__)

        if config.format == :table
          puts "SimpleCovMcp version #{SimpleCovMcp::VERSION}"
          puts "Gem root: #{@gem_root}"
          puts "\nFor usage help, consult README.md and docs/user/**/*.md " \
               'in the gem root directory.'
        else
          puts SimpleCovMcp::Formatters.format(version_info, config.format)
        end
      end

      private

      def version_info
        {
          version: SimpleCovMcp::VERSION,
          gem_root: @gem_root
        }
      end
    end
  end
end
