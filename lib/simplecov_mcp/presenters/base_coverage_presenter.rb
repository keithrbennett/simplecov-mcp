# frozen_string_literal: true

module SimpleCovMcp
  module Presenters
    # Shared presenter behavior for single-file coverage payloads.
    class BaseCoveragePresenter
      attr_reader :model, :path

      def initialize(model:, path:)
        @model = model
        @path = path
      end

      # Returns the absolute-path payload augmented with stale metadata.
      def absolute_payload
        @absolute_payload ||= begin
          payload = build_payload
          payload.merge('stale' => model.staleness_for(path))
        end
      end

      # Returns the payload with file paths relativized for presentation.
      def relativized_payload
        @relativized_payload ||= model.relativize(absolute_payload)
      end

      # Returns the cached stale status for the file.
      def stale
        absolute_payload['stale']
      end

      # Returns the relativized file path used in CLI output.
      def relative_path
        relativized_payload['file']
      end

      private

      def build_payload
        raise NotImplementedError, "#{self.class} must implement #build_payload"
      end
    end
  end
end
