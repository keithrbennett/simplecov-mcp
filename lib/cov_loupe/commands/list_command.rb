# frozen_string_literal: true

require_relative 'base_command'

module CovLoupe
  module Commands
    class ListCommand < BaseCommand
      def execute(_args)
        cli.send(:show_default_report, sort_order: config.sort_order)
      end
    end
  end
end
