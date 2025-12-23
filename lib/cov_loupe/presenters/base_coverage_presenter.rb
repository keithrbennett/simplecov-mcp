# frozen_string_literal: true

require_relative 'payload_caching'

module CovLoupe
  module Presenters
    # Shared presenter behavior for single-file coverage payloads.
    class BaseCoveragePresenter
      include PayloadCaching

      attr_reader :model, :path

      def initialize(model:, path:)
        @model = model
        @path = path
      end

      # Returns the cached stale status for the file.
      def stale
        absolute_payload['stale']
      end

      # Returns the relativized file path used in CLI output.
      def relative_path
        relativized_payload['file']
      end

      private def compute_absolute_payload
        payload = build_payload
        payload.merge('stale' => model.staleness_for(path))
      end

      private def build_payload
        raise NotImplementedError, "#{self.class} must implement #build_payload"
      end
    end
  end
end
