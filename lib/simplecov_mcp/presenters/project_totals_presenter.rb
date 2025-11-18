# frozen_string_literal: true

module SimpleCovMcp
  module Presenters
    # Provides aggregated line totals and average coverage across the project.
    class ProjectTotalsPresenter
      attr_reader :model, :check_stale, :tracked_globs

      def initialize(model:, check_stale:, tracked_globs:)
        @model = model
        @check_stale = check_stale
        @tracked_globs = tracked_globs
      end

      def absolute_payload
        @absolute_payload ||= model.project_totals(
          tracked_globs: tracked_globs,
          check_stale: check_stale
        )
      end

      def relativized_payload
        @relativized_payload ||= model.relativize(absolute_payload)
      end
    end
  end
end
