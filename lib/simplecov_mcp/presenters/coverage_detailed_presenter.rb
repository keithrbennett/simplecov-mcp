# frozen_string_literal: true

require_relative 'base_coverage_presenter'

module SimpleCovMcp
  module Presenters
    # Provides shared detailed coverage payloads for CLI and MCP callers.
    class CoverageDetailedPresenter < BaseCoveragePresenter
      private def build_payload
        model.detailed_for(path)
      end
    end
  end
end
