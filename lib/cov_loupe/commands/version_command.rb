# frozen_string_literal: true

require 'json'
require_relative 'base_command'
require_relative '../formatters/table_formatter'

module CovLoupe
  module Commands
    class VersionCommand < BaseCommand
      def execute(args)
        reject_extra_args(args, 'version')
        @gem_root = File.expand_path('../../..', __dir__)

        if config.format == :table
          data = {
            'Version' => CovLoupe::VERSION,
            'Gem Root' => @gem_root,
            'Documentation' => 'README.md and docs/user/**/*.md in gem root'
          }
          puts TableFormatter.format_vertical(data, output_chars: config.output_chars)
        else
          puts CovLoupe::Formatters.format(version_info, config.format,
            output_chars: config.output_chars)
        end
      end

      private def version_info
        {
          version: CovLoupe::VERSION,
          gem_root: @gem_root
        }
      end
    end
  end
end
