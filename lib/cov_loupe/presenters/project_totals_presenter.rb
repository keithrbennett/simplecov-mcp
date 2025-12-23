# frozen_string_literal: true

require_relative 'payload_caching'

module CovLoupe
  module Presenters
    # Provides aggregated line totals and average coverage across the project.
    class ProjectTotalsPresenter
      include PayloadCaching

      attr_reader :model, :raise_on_stale, :tracked_globs

      def initialize(model:, raise_on_stale:, tracked_globs:)
        @model = model
        @raise_on_stale = raise_on_stale
        @tracked_globs = tracked_globs
      end

      private def compute_absolute_payload
        model.project_totals(
          tracked_globs: tracked_globs,
          raise_on_stale: raise_on_stale
        )
      end
    end
  end
end
