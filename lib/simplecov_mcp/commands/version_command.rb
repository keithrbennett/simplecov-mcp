# frozen_string_literal: true

require 'json'
require_relative 'base_command'
require_relative '../table_formatter'

module SimpleCovMcp
  module Commands
    class VersionCommand < BaseCommand
      def execute(_args)
        @gem_root = File.expand_path('../../..', __dir__)

        if config.format == :table
          data = {
            'Version' => SimpleCovMcp::VERSION,
            'Gem Root' => @gem_root,
            'Documentation' => 'README.md and docs/user/**/*.md in gem root'
          }
          puts TableFormatter.format_vertical(data)
        else
          puts SimpleCovMcp::Formatters.format(version_info, config.format)
        end
      end

      private def version_info
        {
          version: SimpleCovMcp::VERSION,
          gem_root: @gem_root
        }
      end
    end
  end
end
