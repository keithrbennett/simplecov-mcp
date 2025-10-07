# frozen_string_literal: true

require_relative 'base_command'

module SimpleCovMcp
  module Commands
    class ListCommand < BaseCommand
      def execute(args)
        cli.send(:show_default_report, sort_order: config.sort_order)
      end
    end
  end
end