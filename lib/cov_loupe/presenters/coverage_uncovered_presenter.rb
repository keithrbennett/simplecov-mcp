# frozen_string_literal: true

require_relative 'base_coverage_presenter'

module CovLoupe
  module Presenters
    # Provides shared uncovered coverage payloads for CLI and MCP callers.
    class CoverageUncoveredPresenter < BaseCoveragePresenter
      private def build_payload
        model.uncovered_for(path)
      end
    end
  end
end
