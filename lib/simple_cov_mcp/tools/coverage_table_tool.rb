# frozen_string_literal: true

require 'stringio'
require_relative '../cli'

module SimpleCovMcp
  module Tools
    class CoverageTableTool < BaseTool
      def self.description
        'Returns the coverage summary table as a formatted string'
      end

      def self.method_name
        :coverage_table
      end

      def execute(options = {})
        sort_order = options.fetch(:sort_order, 'ascending').to_s
        raise ArgumentError, "Invalid sort_order: #{sort_order}" unless %w[ascending descending].include?(sort_order)

        # Capture the output of the CLI's table report
        output = StringIO.new
        cli = CoverageCLI.new
        cli.show_default_report(sort_order: sort_order.to_sym, output: output)
        output.string
      end
    end
  end
end