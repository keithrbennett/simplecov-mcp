# frozen_string_literal: true

module SimpleCovMcp
  module Presenters
    # Builds a consistent summary payload that both the CLI and MCP surfaces can use.
    # The presenter encapsulates the shared workflow of looking up summary data,
    # computing staleness, and relativizing paths.
    class CoverageSummaryPresenter
      attr_reader :model, :path

      def initialize(model:, path:)
        @model = model
        @path = path
      end

      # Returns the absolute-path summary hash augmented with stale metadata.
      def absolute_payload
        @absolute_payload ||= begin
          data = model.summary_for(path)
          data.merge('stale' => model.staleness_for(path))
        end
      end

      # Returns the summary payload with file paths relativized for presentation.
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
