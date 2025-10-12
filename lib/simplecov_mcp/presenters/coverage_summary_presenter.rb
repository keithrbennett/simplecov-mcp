# frozen_string_literal: true

require_relative 'base_coverage_presenter'

module SimpleCovMcp
  module Presenters
    # Builds a consistent summary payload that both the CLI and MCP surfaces can use.
    class CoverageSummaryPresenter < BaseCoveragePresenter
      private

      def build_payload
        model.summary_for(path)
      end
    end
  end
end
