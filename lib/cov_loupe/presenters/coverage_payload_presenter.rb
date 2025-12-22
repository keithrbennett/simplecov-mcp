# frozen_string_literal: true

require_relative 'base_coverage_presenter'

module CovLoupe
  module Presenters
    # Provides shared single-file coverage payloads for CLI and MCP callers.
    class CoveragePayloadPresenter < BaseCoveragePresenter
      def initialize(model:, path:, payload_method:)
        super(model: model, path: path)
        @payload_method = payload_method
      end

      private def build_payload
        model.public_send(@payload_method, path)
      end
    end
  end
end
