# frozen_string_literal: true

require_relative 'base_coverage_presenter'

module CovLoupe
  module Presenters
    # Provides shared single-file coverage payloads for CLI and MCP callers.
    class CoveragePayloadPresenter < BaseCoveragePresenter
      def initialize(model:, path:, payload_method:, raise_on_stale: nil)
        super(model: model, path: path)
        @payload_method = payload_method
        @raise_on_stale = raise_on_stale
      end

      private def build_payload
        args = { raise_on_stale: @raise_on_stale }.compact
        model.public_send(@payload_method, path, **args)
      end
    end
  end
end
