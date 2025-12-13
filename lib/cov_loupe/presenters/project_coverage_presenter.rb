# frozen_string_literal: true

module CovLoupe
  module Presenters
    # Provides repository-wide coverage summaries shared by CLI and MCP surfaces.
    class ProjectCoveragePresenter
      attr_reader :model, :sort_order, :raise_on_stale, :tracked_globs

      def initialize(model:, sort_order:, raise_on_stale:, tracked_globs:)
        @model = model
        @sort_order = sort_order
        @raise_on_stale = raise_on_stale
        @tracked_globs = tracked_globs
      end

      # Returns the absolute-path payload including counts.
      def absolute_payload
        @absolute_payload ||= begin
          files = model.list(
            sort_order: sort_order,
            raise_on_stale: raise_on_stale,
            tracked_globs: tracked_globs
          )
          { 'files' => files, 'counts' => build_counts(files) }
        end
      end

      # Returns the payload with file paths relativized for presentation.
      def relativized_payload
        @relativized_payload ||= model.relativize(absolute_payload)
      end

      # Returns the relativized file rows.
      def relative_files
        relativized_payload['files']
      end

      # Returns the coverage counts with relative file paths.
      def relative_counts
        relativized_payload['counts']
      end

      private def build_counts(files)
        total = files.length
        stale = files.count { |f| f['stale'] }
        { 'total' => total, 'ok' => total - stale, 'stale' => stale }
      end
    end
  end
end
