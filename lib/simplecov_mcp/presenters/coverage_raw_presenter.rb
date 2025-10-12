# frozen_string_literal: true

module SimpleCovMcp
  module Presenters
    # Provides shared raw coverage payloads for CLI and MCP callers.
    class CoverageRawPresenter
      attr_reader :model, :path

      def initialize(model:, path:)
        @model = model
        @path = path
      end

      # Returns the absolute-path raw payload augmented with stale metadata.
      def absolute_payload
        @absolute_payload ||= begin
          data = model.raw_for(path)
          data.merge('stale' => model.staleness_for(path))
        end
      end

      # Returns the raw payload with file paths relativized for presentation.
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
    end
  end
end
