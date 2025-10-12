# frozen_string_literal: true

require_relative 'base_coverage_presenter'

module SimpleCovMcp
  module Presenters
    # Provides shared raw coverage payloads for CLI and MCP callers.
    class CoverageRawPresenter < BaseCoveragePresenter
      private

      def build_payload
        model.raw_for(path)
      end
    end
  end
end
